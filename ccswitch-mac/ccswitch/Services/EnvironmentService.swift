import Foundation
import os.log

/// 环境变量服务错误类型
enum EnvironmentServiceError: Error, LocalizedError {
    /// 环境变量设置失败
    case setEnvironmentFailed(String)
    /// Shell 配置文件更新失败
    case shellConfigUpdateFailed(String)
    /// 权限不足
    case insufficientPermissions(String)
    /// 执行脚本失败
    case scriptExecutionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .setEnvironmentFailed(let message):
            return "设置环境变量失败: \(message)"
        case .shellConfigUpdateFailed(let message):
            return "更新 Shell 配置文件失败: \(message)"
        case .insufficientPermissions(let message):
            return "权限不足: \(message)"
        case .scriptExecutionFailed(let message):
            return "执行脚本失败: \(message)"
        }
    }
}

/// 环境变量服务，负责管理环境变量的读取和更新
class EnvironmentService {
    /// 日志对象
    private let logger = Logger(subsystem: "com.ccswitch.app", category: "EnvironmentService")
    
    /// 获取真实的用户主目录（非沙盒路径）
    private func getRealHomeDirectory() -> String {
        // 方法1: 尝试从环境变量获取
        if let homeEnv = ProcessInfo.processInfo.environment["HOME"], !homeEnv.contains("Containers") {
            return homeEnv
        }
        
        // 方法2: 使用getpwuid获取真实的主目录
        let uid = getuid()
        if let passwd = getpwuid(uid) {
            let homeDir = String(cString: passwd.pointee.pw_dir)
            if !homeDir.contains("Containers") {
                return homeDir
            }
        }
        
        // 方法3: 尝试通过用户名构建路径
        if let username = ProcessInfo.processInfo.environment["USER"] {
            let homePath = "/Users/\(username)"
            if FileManager.default.fileExists(atPath: homePath) {
                return homePath
            }
        }
        
        // 备用方法: 使用NSHomeDirectory，但这可能返回沙盒路径
        let sandboxHome = NSHomeDirectory()
        logger.warning("无法获取真实主目录，使用沙盒路径: \(sandboxHome)")
        return sandboxHome
    }
    
    /// 环境变量名称常量
    private struct EnvVarNames {
        static let baseURL = "ANTHROPIC_BASE_URL"
        static let token = "ANTHROPIC_AUTH_TOKEN"
    }
    
    /// 初始化环境变量服务
    init() {
        logger.info("环境变量服务已初始化")
    }
    
    // 用于防止频繁更新的节流控制
    private var updateWorkItem: DispatchWorkItem?
    private let updateThrottleInterval: TimeInterval = 0.3 // 300毫秒节流间隔
    
    // 缓存最近的环境变量值，避免重复更新
    private var cachedBaseURL: String?
    private var cachedToken: String?
    
    /// 更新环境变量，使用优化的更新机制
    /// - Parameters:
    ///   - baseURL: API 基础 URL
    ///   - token: API 访问令牌
    /// - Returns: 操作结果
    func updateEnvironmentVariables(baseURL: String, token: String) -> Result<Void, EnvironmentServiceError> {
        // 检查是否与缓存值相同，如果相同则跳过更新
        if baseURL == cachedBaseURL && token == cachedToken {
            logger.info("环境变量未变化，跳过更新")
            return .success(())
        }
        
        logger.info("正在更新环境变量: URL=\(baseURL), Token=***")
        
        // 更新缓存
        cachedBaseURL = baseURL
        cachedToken = token
        
        // 1. 立即更新当前进程的环境变量 - 这是同步操作，确保立即在当前进程生效
        setenv(EnvVarNames.baseURL, baseURL, 1)
        setenv(EnvVarNames.token, token, 1)
        
        // 取消之前的更新任务
        updateWorkItem?.cancel()
        
        // 创建新的更新任务
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // 使用并发队列处理其他环境变量更新操作
            let queue = DispatchQueue.global(qos: .userInitiated)
            let group = DispatchGroup()
            
            // 用于存储可能的错误
            var updateError: EnvironmentServiceError?
            
            // 2. 使用优化的方法更新全局环境变量 - 异步执行
            group.enter()
            queue.async {
                do {
                    try self.updateGlobalEnvironmentVariables(baseURL: baseURL, token: token)
                    self.logger.info("全局环境变量更新成功")
                } catch {
                    self.logger.error("全局环境变量更新失败: \(error.localizedDescription)")
                    updateError = .setEnvironmentFailed(error.localizedDescription)
                }
                group.leave()
            }
            
            // 3. 创建环境变量辅助文件 - 异步执行
            group.enter()
            queue.async {
                do {
                    try self.createEnvironmentHelperFile(baseURL: baseURL, token: token)
                    self.logger.info("环境变量辅助文件创建成功")
                } catch {
                    self.logger.error("环境变量辅助文件创建失败: \(error.localizedDescription)")
                    // 这不是致命错误，不设置 updateError
                }
                group.leave()
            }
            
            // 等待所有异步操作完成，但设置超时以避免无限等待
            let timeout = DispatchTime.now() + 2.0 // 2秒超时，比原来更短
            if group.wait(timeout: timeout) == .timedOut {
                self.logger.warning("环境变量更新操作超时，但进程内变量已更新")
            }
            
            // 如果有错误，记录但不阻止应用继续运行
            if let error = updateError {
                self.logger.error("环境变量更新过程中发生错误: \(error.localizedDescription)")
            }
        }
        
        // 保存引用以便后续可以取消
        updateWorkItem = workItem
        
        // 延迟执行，实现节流效果
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + updateThrottleInterval, execute: workItem)
        
        // 立即返回成功，因为进程内变量已更新，其他更新在后台进行
        return .success(())
    }
    
    /// 更新全局环境变量
    /// - Parameters:
    ///   - baseURL: API 基础 URL
    ///   - token: API 访问令牌
    /// - Throws: 如果更新失败则抛出错误
    private func updateGlobalEnvironmentVariables(baseURL: String, token: String) throws {
        // 使用 AppleScript 更新全局环境变量
        // 这种方法可以使新打开的终端和应用程序立即使用新的环境变量
        
        // 创建临时脚本文件
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("update_env.sh")
        
        // 脚本内容
        let scriptContent = """
        #!/bin/bash
        
        # 设置环境变量
        export \(EnvVarNames.baseURL)="\(baseURL)"
        export \(EnvVarNames.token)="\(token)"
        
        # 输出设置结果
        echo "环境变量已更新:"
        echo "\(EnvVarNames.baseURL)=\(baseURL)"
        echo "\(EnvVarNames.token)=***"
        """
        
        do {
            // 写入脚本文件
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            
            // 设置脚本可执行权限
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            
            // 执行脚本
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [scriptURL.path]
            
            let outputPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = outputPipe
            
            try task.run()
            task.waitUntilExit()
            
            // 检查执行结果
            if task.terminationStatus != 0 {
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? "未知错误"
                throw EnvironmentServiceError.scriptExecutionFailed(output)
            }
            
            // 删除临时脚本文件
            try FileManager.default.removeItem(at: scriptURL)
            
        } catch {
            logger.error("执行环境变量更新脚本失败: \(error.localizedDescription)")
            throw EnvironmentServiceError.scriptExecutionFailed(error.localizedDescription)
        }
    }
    
    /// 获取当前环境变量
    /// - Returns: 当前环境变量的元组 (baseURL, token)
    func getCurrentEnvironmentVariables() -> (baseURL: String?, token: String?) {
        logger.info("正在获取当前环境变量")
        
        // 从进程环境变量中获取
        var baseURL = ProcessInfo.processInfo.environment[EnvVarNames.baseURL]
        var token = ProcessInfo.processInfo.environment[EnvVarNames.token]
        
        // 如果进程环境变量中没有，尝试从 Shell 中获取
        if baseURL == nil || token == nil {
            let shellValues = getEnvironmentVariablesFromShell()
            
            // 只有在进程环境变量中没有值时才使用 Shell 中的值
            if baseURL == nil {
                baseURL = shellValues.baseURL
            }
            
            if token == nil {
                token = shellValues.token
            }
        }
        
        // 记录获取结果（不记录 token 的具体值）
        if let url = baseURL {
            logger.info("获取到环境变量 \(EnvVarNames.baseURL): \(url)")
        } else {
            logger.warning("未获取到环境变量 \(EnvVarNames.baseURL)")
        }
        
        if token != nil {
            logger.info("获取到环境变量 \(EnvVarNames.token): ***")
        } else {
            logger.warning("未获取到环境变量 \(EnvVarNames.token)")
        }
        
        return (baseURL, token)
    }
    
    /// 从 Shell 中获取环境变量
    /// - Returns: 从 Shell 中获取的环境变量元组 (baseURL, token)
    private func getEnvironmentVariablesFromShell() -> (baseURL: String?, token: String?) {
        logger.info("尝试从 Shell 中获取环境变量")
        
        var baseURL: String? = nil
        var token: String? = nil
        
        // 创建临时脚本文件
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("get_env.sh")
        
        // 脚本内容
        let scriptContent = """
        #!/bin/bash
        
        # 输出环境变量值
        echo "BASE_URL=$\(EnvVarNames.baseURL)"
        echo "TOKEN=$\(EnvVarNames.token)"
        """
        
        do {
            // 写入脚本文件
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            
            // 设置脚本可执行权限
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            
            // 执行脚本
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = ["-l", scriptURL.path]  // -l 表示作为登录 shell 执行，加载所有配置
            
            let outputPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = outputPipe
            
            try task.run()
            task.waitUntilExit()
            
            // 解析输出
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: outputData, encoding: .utf8) {
                // 解析 BASE_URL
                if let baseURLRange = output.range(of: "BASE_URL=") {
                    let startIndex = baseURLRange.upperBound
                    if let endIndex = output[startIndex...].firstIndex(of: "\n") {
                        let value = String(output[startIndex..<endIndex])
                        if !value.isEmpty && value != "nil" {
                            baseURL = value
                        }
                    }
                }
                
                // 解析 TOKEN
                if let tokenRange = output.range(of: "TOKEN=") {
                    let startIndex = tokenRange.upperBound
                    if let endIndex = output[startIndex...].firstIndex(of: "\n") {
                        let value = String(output[startIndex..<endIndex])
                        if !value.isEmpty && value != "nil" {
                            token = value
                        }
                    }
                }
            }
            
            // 删除临时脚本文件
            try FileManager.default.removeItem(at: scriptURL)
            
        } catch {
            logger.error("从 Shell 获取环境变量失败: \(error.localizedDescription)")
        }
        
        return (baseURL, token)
    }
    
    /// 重置环境变量为默认值
    /// - Returns: 操作结果
    func resetEnvironmentVariables() -> Result<Void, EnvironmentServiceError> {
        logger.info("正在重置环境变量为默认值")
        
        // 默认 URL 为官方 API
        let defaultURL = ConfigurationModel.ConfigurationType.official.defaultURL
        
        // 清空 token
        let emptyToken = ""
        
        return updateEnvironmentVariables(baseURL: defaultURL, token: emptyToken)
    }
    
    /// 检查环境变量是否已设置
    /// - Returns: 如果环境变量已设置则返回 true，否则返回 false
    func areEnvironmentVariablesSet() -> Bool {
        let (baseURL, token) = getCurrentEnvironmentVariables()
        return baseURL != nil && token != nil
    }
    
    /// 导出环境变量到指定的 Shell 配置文件
    /// - Parameters:
    ///   - baseURL: API 基础 URL
    ///   - token: API 访问令牌
    ///   - shellConfigPath: Shell 配置文件路径
    /// - Returns: 操作结果
    func exportToShellConfig(baseURL: String, token: String, shellConfigPath: String) -> Result<Void, EnvironmentServiceError> {
        logger.info("正在导出环境变量到 Shell 配置文件: \(shellConfigPath)")
        
        do {
            // 读取现有配置文件内容
            var configContent: String
            if FileManager.default.fileExists(atPath: shellConfigPath) {
                configContent = try String(contentsOfFile: shellConfigPath, encoding: .utf8)
            } else {
                configContent = ""
            }
            
            // 移除现有的环境变量设置
            let baseURLPattern = "export \(EnvVarNames.baseURL)=.*"
            let tokenPattern = "export \(EnvVarNames.token)=.*"
            
            configContent = configContent.replacingOccurrences(
                of: baseURLPattern, with: "", options: .regularExpression
            )
            configContent = configContent.replacingOccurrences(
                of: tokenPattern, with: "", options: .regularExpression
            )
            
            // 添加新的环境变量设置
            let newConfig = """
            
            # CCSwitch 环境变量设置 - 自动生成
            export \(EnvVarNames.baseURL)="\(baseURL)"
            export \(EnvVarNames.token)="\(token)"
            """
            
            configContent += newConfig
            
            // 写入配置文件
            try configContent.write(toFile: shellConfigPath, atomically: true, encoding: .utf8)
            
            logger.info("环境变量已成功导出到 Shell 配置文件")
            return .success(())
            
        } catch {
            logger.error("导出环境变量到 Shell 配置文件失败: \(error.localizedDescription)")
            return .failure(.shellConfigUpdateFailed(error.localizedDescription))
        }
    }
    
    /// 从 Shell 配置文件中移除环境变量设置
    /// - Parameter shellConfigPath: Shell 配置文件路径
    /// - Returns: 操作结果
    func removeFromShellConfig(shellConfigPath: String) -> Result<Void, EnvironmentServiceError> {
        logger.info("正在从 Shell 配置文件移除环境变量设置: \(shellConfigPath)")
        
        do {
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: shellConfigPath) else {
                return .success(()) // 文件不存在，无需操作
            }
            
            // 读取现有配置文件内容
            var configContent = try String(contentsOfFile: shellConfigPath, encoding: .utf8)
            
            // 移除环境变量设置
            let pattern = "# CCSwitch 环境变量设置 - 自动生成\nexport \(EnvVarNames.baseURL)=.*\nexport \(EnvVarNames.token)=.*"
            configContent = configContent.replacingOccurrences(
                of: pattern, with: "", options: .regularExpression
            )
            
            // 写入配置文件
            try configContent.write(toFile: shellConfigPath, atomically: true, encoding: .utf8)
            
            logger.info("环境变量设置已从 Shell 配置文件移除")
            return .success(())
            
        } catch {
            logger.error("从 Shell 配置文件移除环境变量设置失败: \(error.localizedDescription)")
            return .failure(.shellConfigUpdateFailed(error.localizedDescription))
        }
    }
      /// 创建环境变量辅助文件，帮助其他应用程序读取环境变量
  /// - Parameters:
  ///   - baseURL: API 基础 URL
  ///   - token: API 访问令牌
  /// - Throws: 如果创建失败则抛出错误
  private func createEnvironmentHelperFile(baseURL: String, token: String) throws {
    logger.info("正在创建环境变量辅助文件")
    
    // 辅助文件路径 - 使用真实的用户主目录
    let helperFilePath = getRealHomeDirectory() + "/.env-ccswitch"
        
        // 辅助文件内容
        let helperFileContent = """
        # CCSwitch 环境变量辅助文件 - 自动生成
        # 此文件由 CCSwitch 应用程序自动生成，用于帮助其他应用程序读取环境变量
        # 可以在 Shell 脚本中使用 source ~/.env-ccswitch 来加载这些环境变量
        
        export \(EnvVarNames.baseURL)="\(baseURL)"
        export \(EnvVarNames.token)="\(token)"
        
        # 以下是一些常用的别名，可以根据需要取消注释
        # alias cc-url='echo $\(EnvVarNames.baseURL)'
        # alias cc-token='echo $\(EnvVarNames.token) | cut -c1-10'
        """
        
        do {
            // 写入辅助文件
            try helperFileContent.write(toFile: helperFilePath, atomically: true, encoding: .utf8)
            
            // 设置文件权限
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: helperFilePath)
            
            logger.info("环境变量辅助文件创建成功: \(helperFilePath)")
        } catch {
            logger.error("创建环境变量辅助文件失败: \(error.localizedDescription)")
            throw EnvironmentServiceError.shellConfigUpdateFailed(error.localizedDescription)
        }
    }
}
