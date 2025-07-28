import Foundation
import os.log
import AppKit

/// Process 等待结果类型
private enum ProcessWaitResult {
  case completed
  case timedOut
}

/// Shell 配置服务错误类型
enum ShellConfigServiceError: Error, LocalizedError {
  /// 无法确定 Shell 类型
  case unknownShellType
  /// 配置文件不存在
  case configFileNotFound(String)
  /// 配置文件写入失败
  case configFileWriteFailed(String)
  /// 权限不足
  case insufficientPermissions(String)
  /// 执行脚本失败
  case scriptExecutionFailed(String)

  var errorDescription: String? {
    switch self {
    case .unknownShellType:
      return "无法确定当前 Shell 类型"
    case .configFileNotFound(let path):
      return "配置文件不存在: \(path)"
    case .configFileWriteFailed(let message):
      return "配置文件写入失败: \(message)"
    case .insufficientPermissions(let path):
      return "权限不足，无法写入配置文件: \(path)"
    case .scriptExecutionFailed(let message):
      return "执行脚本失败: \(message)"
    }
  }
}

/// Shell 类型枚举
enum ShellType: String {
  /// Bash Shell
  case bash
  /// Zsh Shell
  case zsh
  /// Fish Shell
  case fish
  /// 未知 Shell 类型
  case unknown

  /// 返回 Shell 的配置文件名
  var configFileName: String {
    switch self {
    case .bash:
      return ".bashrc"
    case .zsh:
      return ".zshrc"
    case .fish:
      return "config.fish"
    case .unknown:
      return ""
    }
  }

  /// 返回 Shell 的配置文件目录
  var configFileDirectory: String {
    // 获取真实的用户主目录，而不是沙盒目录
    let realHomeDir: String
    if let homeEnv = ProcessInfo.processInfo.environment["HOME"], !homeEnv.contains("Containers") {
      realHomeDir = homeEnv
    } else {
      // 使用getpwuid获取真实的主目录
      let uid = getuid()
      if let passwd = getpwuid(uid) {
        let homeDir = String(cString: passwd.pointee.pw_dir)
        if !homeDir.contains("Containers") {
          realHomeDir = homeDir
        } else {
          realHomeDir = NSHomeDirectory()
        }
      } else {
        realHomeDir = NSHomeDirectory()
      }
    }
    
    switch self {
    case .bash, .zsh:
      return realHomeDir
    case .fish:
      return realHomeDir + "/.config/fish"
    case .unknown:
      return ""
    }
  }

  /// 返回 Shell 的配置文件完整路径
  var configFilePath: String {
    if self == .unknown {
      return ""
    }
    return configFileDirectory + "/" + configFileName
  }

  /// 返回 Shell 的环境变量导出命令
  func exportCommand(name: String, value: String) -> String {
    switch self {
    case .bash, .zsh:
      return "export \(name)=\"\(value)\""
    case .fish:
      return "set -x \(name) \"\(value)\""
    case .unknown:
      return ""
    }
  }
}

/// Shell 配置服务，负责管理 Shell 配置文件的更新
class ShellConfigService {
  /// 日志对象
  private let logger = Logger(subsystem: "com.ccswitch.app", category: "ShellConfigService")
  
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
    static let shell = "SHELL"
  }
  
  /// 用户是否已授权修改 Shell 配置文件
  private var hasUserPermission = false
  
  /// 用户授权回调
  typealias PermissionCallback = (Bool) -> Void
  
  /// 权限请求处理器
  private var permissionHandler: ((String, @escaping PermissionCallback) -> Void)?
  
  /// 设置服务
  private let settingsService: SettingsService

  /// 初始化 Shell 配置服务
  /// - Parameters:
  ///   - permissionHandler: 权限请求处理器，用于向用户请求权限
  ///   - settingsService: 设置服务
  init(permissionHandler: ((String, @escaping PermissionCallback) -> Void)? = nil, settingsService: SettingsService = SettingsService()) {
    self.permissionHandler = permissionHandler
    self.settingsService = settingsService
    logger.info("Shell 配置服务已初始化")
    
    // 尝试恢复之前保存的文件访问权限
    restoreSavedFileAccess()
  }  

  /// 恢复保存的文件访问权限
  private func restoreSavedFileAccess() {
    guard let bookmarkData = UserDefaults.standard.data(forKey: "HomeDirectoryBookmark") else {
      logger.info("没有找到保存的文件访问权限")
      return
    }
    
    do {
      var isStale = false
      let url = try URL(
        resolvingBookmarkData: bookmarkData,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
      
      if isStale {
        logger.warning("保存的文件访问权限已过期，清除旧的书签")
        UserDefaults.standard.removeObject(forKey: "HomeDirectoryBookmark")
        return
      }
      
      let accessing = url.startAccessingSecurityScopedResource()
      if accessing {
        // 验证权限是否真正有效
        let testPath = url.appendingPathComponent(".zshrc").path
        let canAccess = FileManager.default.isWritableFile(atPath: testPath) || 
                       FileManager.default.fileExists(atPath: testPath) ||
                       FileManager.default.isWritableFile(atPath: url.path)
        
        if canAccess {
          hasUserPermission = true
          logger.info("成功恢复文件访问权限: \(url.path)")
        } else {
          logger.warning("文件访问权限无效，清除书签")
          UserDefaults.standard.removeObject(forKey: "HomeDirectoryBookmark")
          url.stopAccessingSecurityScopedResource()
        }
      } else {
        logger.warning("无法恢复文件访问权限，清除书签")
        UserDefaults.standard.removeObject(forKey: "HomeDirectoryBookmark")
      }
    } catch {
      logger.error("恢复文件访问权限失败: \(error.localizedDescription)")
      UserDefaults.standard.removeObject(forKey: "HomeDirectoryBookmark")
    }
  }
  
  /// 设置权限请求处理器
  /// - Parameter handler: 权限请求处理器
  func setPermissionHandler(_ handler: @escaping (String, @escaping PermissionCallback) -> Void) {
    permissionHandler = handler
  }
  
  /// 验证配置文件是否可用，如果不可用则引导用户设置
  /// - Returns: 验证结果和错误信息
  func validateConfigFile() -> (isValid: Bool, error: String?, needsUserSetup: Bool) {
    let configPath = getConfigFilePath()
    
    // 检查文件是否存在
    if !FileManager.default.fileExists(atPath: configPath) {
      // 尝试创建配置文件
      let directory = NSString(string: configPath).deletingLastPathComponent
      
      // 确保目录存在
      if !FileManager.default.fileExists(atPath: directory) {
        do {
          try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
        } catch {
          return (false, "无法创建配置文件目录: \(error.localizedDescription)", true)
        }
      }
      
      // 尝试创建空的配置文件
      do {
        try "".write(toFile: configPath, atomically: true, encoding: .utf8)
        logger.info("已创建新的配置文件: \(configPath)")
      } catch {
        return (false, "无法创建配置文件: \(error.localizedDescription)", true)
      }
    }
    
    // 检查文件是否可写
    if !FileManager.default.isWritableFile(atPath: configPath) {
      return (false, "配置文件不可写: \(configPath)", true)
    }
    
    return (true, nil, false)
  }
  
  /// 获取配置文件的诊断信息
  /// - Returns: 诊断信息字符串
  func getConfigFileDiagnostics() -> String {
    var diagnostics = "Shell 配置文件诊断信息:\n\n"
    
    // 当前Shell信息
    let currentShell = getCurrentShellType()
    diagnostics += "当前Shell类型: \(currentShell.rawValue)\n"
    
    // 配置文件路径信息
    let configPath = getConfigFilePath()
    diagnostics += "配置文件路径: \(configPath)\n"
    
    // 文件存在性检查
    let fileExists = FileManager.default.fileExists(atPath: configPath)
    diagnostics += "文件是否存在: \(fileExists ? "是" : "否")\n"
    
    if fileExists {
      // 文件权限检查
      let isWritable = FileManager.default.isWritableFile(atPath: configPath)
      diagnostics += "文件是否可写: \(isWritable ? "是" : "否")\n"
      
      // 文件大小
      do {
        let attributes = try FileManager.default.attributesOfItem(atPath: configPath)
        if let size = attributes[.size] as? Int {
          diagnostics += "文件大小: \(size) 字节\n"
        }
      } catch {
        diagnostics += "无法获取文件属性: \(error.localizedDescription)\n"
      }
    }
    
    // 自定义路径设置
    if settingsService.useCustomShellConfigPath {
      diagnostics += "使用自定义路径: 是\n"
      diagnostics += "自定义路径: \(settingsService.customShellConfigPath ?? "未设置")\n"
    } else {
      diagnostics += "使用自定义路径: 否\n"
    }
    return diagnostics
  }
  
  /// 获取推荐的配置文件路径列表
  /// - Returns: 推荐的配置文件路径数组
  private func getRecommendedConfigPaths() -> [String] {
    let homeDir = getRealHomeDirectory()
    
    var paths: [String] = []
    
    // 根据当前Shell类型推荐路径
    if let shell = ProcessInfo.processInfo.environment["SHELL"] {
      if shell.contains("zsh") {
        paths.append(homeDir + "/.zshrc")
        paths.append(homeDir + "/.zprofile")
      } else if shell.contains("bash") {
        paths.append(homeDir + "/.bashrc")
        paths.append(homeDir + "/.bash_profile")
        paths.append(homeDir + "/.profile")
      } else if shell.contains("fish") {
        paths.append(homeDir + "/.config/fish/config.fish")
      }
    }
    
    // 添加通用路径
    let commonPaths = [
      homeDir + "/.zshrc",
      homeDir + "/.bashrc",
      homeDir + "/.bash_profile",
      homeDir + "/.profile",
      homeDir + "/.zprofile",
      homeDir + "/.config/fish/config.fish"
    ]
    
    // 去重并只保留存在的文件
    let allPaths = Array(Set(paths + commonPaths))
    return allPaths.filter { FileManager.default.fileExists(atPath: $0) }
  }
 
  /// 获取当前 Shell 类型
  /// - Returns: Shell 类型
  func getCurrentShellType() -> ShellType {
    logger.info("正在获取当前 Shell 类型")

    // 从环境变量获取当前 Shell 路径
    guard let shellPath = ProcessInfo.processInfo.environment[EnvVarNames.shell] else {
      logger.warning("无法从环境变量获取 Shell 路径")
      return .unknown
    }

    // 根据路径确定 Shell 类型
    if shellPath.contains("bash") {
      logger.info("当前 Shell 类型: bash")
      return .bash
    } else if shellPath.contains("zsh") {
      logger.info("当前 Shell 类型: zsh")
      return .zsh
    } else if shellPath.contains("fish") {
      logger.info("当前 Shell 类型: fish")
      return .fish
    // ...existing code...
    } else {
      logger.warning("未知 Shell 类型: \(shellPath)")
      return .unknown
    }
  }

  /// 获取配置文件路径
  /// - Parameter shellType: Shell 类型，默认为当前 Shell
  /// - Returns: 配置文件路径
  func getConfigFilePath(shellType: ShellType? = nil) -> String {
    // 如果用户设置了自定义路径且启用了自定义路径，则使用自定义路径
    if settingsService.useCustomShellConfigPath,
       let customPath = settingsService.customShellConfigPath,
       !customPath.isEmpty {
      let expandedPath = NSString(string: customPath).expandingTildeInPath
      logger.info("使用自定义配置文件路径: \(expandedPath)")
      return expandedPath
    }
    
    // 否则使用自动检测的路径
    return getDetectedConfigFilePath(shellType: shellType)
  }
  
  /// 检测并获取最佳的配置文件路径
  /// - Parameter shellType: Shell 类型，默认为当前 Shell
  /// - Returns: 检测到的配置文件路径
  private func getDetectedConfigFilePath(shellType: ShellType? = nil) -> String {
    let type = shellType ?? getCurrentShellType()
    
    // 首先尝试标准路径
    let standardPath = type.configFilePath
    if FileManager.default.fileExists(atPath: standardPath) {
      logger.info("使用标准配置文件路径: \(standardPath)")
      return standardPath
    }
    
    // 如果标准路径不存在，尝试其他可能的路径
    let alternativePaths = getAlternativeConfigPaths(for: type)
    for path in alternativePaths {
      if FileManager.default.fileExists(atPath: path) {
        logger.info("使用替代配置文件路径: \(path)")
        return path
      }
    }
    
    // 如果都不存在，返回标准路径（将会被创建）
    logger.info("未找到现有配置文件，将使用标准路径: \(standardPath)")
    return standardPath
  }
  
  /// 获取指定Shell类型的替代配置文件路径
  /// - Parameter shellType: Shell类型
  /// - Returns: 替代路径数组
  private func getAlternativeConfigPaths(for shellType: ShellType) -> [String] {
    let homeDir = getRealHomeDirectory()
    
    switch shellType {
    case .zsh:
      return [
        homeDir + "/.zprofile",
        homeDir + "/.zshenv"
      ]
    case .bash:
      return [
        homeDir + "/.bash_profile",
        homeDir + "/.profile",
        homeDir + "/.bashrc"
      ]
    case .fish:
      return [
        homeDir + "/.config/fish/config.fish"
      ]
    default:
      return []
    }
  }
  /// 请求用户权限
  /// - Parameters:
  ///   - message: 权限请求消息
  ///   - completion: 完成回调，传递用户是否授权
  private func requestPermission(message: String, completion: @escaping (Bool) -> Void) {
      logger.info("权限请求被调用，当前权限状态: \(self.hasUserPermission)")
    
    // 如果已经有权限，直接返回
    if hasUserPermission {
      logger.info("已有权限，直接返回成功")
      completion(true)
      return
    }
    
    logger.info("没有权限，显示权限请求对话框")
    
    // 确保在主线程上执行UI操作
    if Thread.isMainThread {
      showPermissionDialog(message: message, completion: completion)
    } else {
      DispatchQueue.main.async { [weak self] in
        self?.showPermissionDialog(message: message, completion: completion)
      }
    }
  }
  
  /// 显示权限请求对话框
  /// - Parameters:
  ///   - message: 权限请求消息
  ///   - completion: 完成回调，传递用户是否授权
  private func showPermissionDialog(message: String, completion: @escaping (Bool) -> Void) {
    // 确保应用图标已设置
    ensureAppIconIsSet()
    
    // 显示权限请求对话框
    let alert = NSAlert()
    alert.messageText = "需要文件访问权限"
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: "授权访问")
    alert.addButton(withTitle: "取消")
    
    // 设置图标
    if let editIcon = NSImage(named: "EditorIcon") {
      alert.icon = editIcon
    } else if let appIcon = NSApp.applicationIconImage {
      alert.icon = appIcon
    } else if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
              let icon = NSImage(contentsOfFile: iconPath) {
      alert.icon = icon
    } else if let icon = NSImage(named: "AppIcon") {
      alert.icon = icon
    }
    
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      // 用户选择授权，现在请求系统级文件访问权限
      requestSystemFileAccess { [weak self] granted in
        if granted {
          self?.hasUserPermission = true
          self?.logger.info("用户授予了文件访问权限")
        } else {
          self?.logger.warning("系统文件访问权限被拒绝")
        }
        completion(granted)
      }
    } else {
      logger.warning("用户拒绝了权限请求")
      completion(false)
    }
  }
  
  /// 请求系统文件访问权限
  /// - Parameter completion: 完成回调
  private func requestSystemFileAccess(completion: @escaping (Bool) -> Void) {
    // 获取用户主目录
    let homeURL = FileManager.default.homeDirectoryForCurrentUser
    
    // 使用 NSOpenPanel 请求文件夹访问权限
    let openPanel = NSOpenPanel()
    openPanel.message = "请选择您的用户主目录以授权CCSwitch访问Shell配置文件"
    openPanel.prompt = "授权访问"
    openPanel.allowsMultipleSelection = false
    openPanel.canChooseDirectories = true
    openPanel.canChooseFiles = false
    openPanel.canCreateDirectories = false
    openPanel.directoryURL = homeURL
    
    // 设置图标
    if NSApp.applicationIconImage != nil {
      openPanel.appearance = NSAppearance(named: .aqua)
    }
    
    // 确保在主线程上显示面板
    if Thread.isMainThread {
      showFileAccessPanel(openPanel, completion: completion)
    } else {
      DispatchQueue.main.async { [weak self] in
        self?.showFileAccessPanel(openPanel, completion: completion)
      }
    }
  }
  
  /// 显示文件访问面板
  /// - Parameters:
  ///   - openPanel: 文件选择面板
  ///   - completion: 完成回调
  private func showFileAccessPanel(_ openPanel: NSOpenPanel, completion: @escaping (Bool) -> Void) {
    openPanel.begin { [weak self] response in
      guard let self = self else {
        completion(false)
        return
      }
      
      if response == .OK, let url = openPanel.url {
        // 用户选择了目录，开始访问资源
        let accessing = url.startAccessingSecurityScopedResource()
        if accessing {
          self.logger.info("获得了安全作用域资源访问权限: \(url.path)")
          
          // 保存书签以便将来使用
          do {
            let bookmarkData = try url.bookmarkData(
              options: .withSecurityScope,
              includingResourceValuesForKeys: nil,
              relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: "HomeDirectoryBookmark")
            
            // 验证权限是否真正有效
            let testPath = url.appendingPathComponent(".zshrc").path
            let canAccess = FileManager.default.isWritableFile(atPath: testPath) || 
                           FileManager.default.fileExists(atPath: testPath) ||
                           FileManager.default.isWritableFile(atPath: url.path)
            
            if canAccess {
              self.logger.info("文件访问权限验证成功")
              completion(true)
            } else {
              self.logger.warning("文件访问权限验证失败")
              completion(false)
            }
          } catch {
            self.logger.error("保存书签失败: \(error.localizedDescription)")
            completion(false)
          }
        } else {
          self.logger.error("无法访问安全作用域资源")
          completion(false)
        }
      } else {
        self.logger.warning("用户取消了文件访问授权")
        completion(false)
      }
    }
  }
  
  /// 更新 Shell 配置文件
  /// - Parameters:
  ///   - baseURL: API 基础 URL
  ///   - token: API 访问令牌
  /// - Returns: 操作结果
  func updateShellConfig(baseURL: String, token: String) -> Result<Void, ShellConfigServiceError> {
    logger.info("正在更新 Shell 配置文件")
      logger.info("当前权限状态: hasUserPermission = \(self.hasUserPermission)")

    // 使用后台队列异步更新配置文件
    let dispatchGroup = DispatchGroup()
    var updateResult: Result<Void, ShellConfigServiceError> = .success(())

    dispatchGroup.enter()
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else {
        dispatchGroup.leave()
        return
      }
      
      // 获取当前 Shell 类型
      let shellType = self.getCurrentShellType()
      
      // 检查 Shell 类型是否已知
      guard shellType != .unknown else {
        self.logger.error("无法确定 Shell 类型，无法更新配置文件")
        updateResult = .failure(.unknownShellType)
        dispatchGroup.leave()
        return
      }
      
      // 获取配置文件路径（现在使用改进的检测逻辑）
      let configPath = self.getConfigFilePath()
      self.logger.info("目标配置文件路径: \(configPath)")
      
      // 检查是否需要请求权限
      let needsPermission = !self.hasUserPermission || !FileManager.default.isWritableFile(atPath: configPath)
      self.logger.info("是否需要请求权限: \(needsPermission)")
      
      if needsPermission {
        // 请求用户权限
        let shellFileName = shellType.configFileName
        let friendlyPath: String
        switch shellType {
        case .bash, .zsh:
          friendlyPath = "~/\(shellFileName)"
        case .fish:
          friendlyPath = "~/.config/fish/\(shellFileName)"
        // ...existing code...
        case .unknown:
          friendlyPath = shellFileName
        }
        let permissionMessage = "CCSwitch 需要修改您的 \(shellType.rawValue) 配置文件 (\(friendlyPath)) 以设置 Claude 环境变量。\n\n这将允许您的终端和其他应用程序使用选定的 Claude 配置。是否允许？"
        
        // 请求用户权限
        self.requestPermission(message: permissionMessage) { granted in
          if !granted {
            self.logger.warning("用户拒绝了修改 Shell 配置文件的权限")
            updateResult = .failure(.insufficientPermissions(configPath))
            dispatchGroup.leave()
            return
          }
          
          // 用户授权，继续更新配置文件
          self.performShellConfigUpdate(shellType: shellType, configPath: configPath, baseURL: baseURL, token: token) { result in
            updateResult = result
            dispatchGroup.leave()
          }
        }
      } else {
        // 已有权限，直接更新配置文件
        self.logger.info("已有权限，直接更新配置文件")
        self.performShellConfigUpdate(shellType: shellType, configPath: configPath, baseURL: baseURL, token: token) { result in
          updateResult = result
          dispatchGroup.leave()
        }
      }
    }

    // 等待异步操作完成，但设置更长的超时以允许用户完成权限授权
    let timeout = DispatchTime.now() + 30.0  // 30秒超时，给用户足够时间授权
    if dispatchGroup.wait(timeout: timeout) == .timedOut {
      logger.warning("Shell 配置文件更新操作超时")
      return .failure(.configFileWriteFailed("操作超时，请重试"))
    }

    return updateResult
  }
  
  /// 执行 Shell 配置文件更新的具体操作
  private func performShellConfigUpdate(shellType: ShellType, configPath: String, baseURL: String, token: String, completion: @escaping (Result<Void, ShellConfigServiceError>) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else {
        completion(.failure(.configFileWriteFailed("服务已释放")))
        return
      }
      // 检查配置文件目录是否存在，如果不存在则创建
      let configDir = shellType.configFileDirectory
      if !FileManager.default.fileExists(atPath: configDir) {
        do {
          try FileManager.default.createDirectory(
            atPath: configDir,
            withIntermediateDirectories: true,
            attributes: nil
          )
        } catch {
          self.logger.error("创建配置文件目录失败: \(error.localizedDescription)")
          completion(.failure(.configFileWriteFailed(error.localizedDescription)))
          return
        }
      }

      do {
        // 读取现有配置文件内容
        var configContent: String
        if FileManager.default.fileExists(atPath: configPath) {
          configContent = try String(contentsOfFile: configPath, encoding: .utf8)
        } else {
          configContent = ""
        }

        // 移除现有的环境变量设置，包括注释行和任何已存在的环境变量设置
        let commentPattern = "# CCSwitch 环境变量设置 - 自动生成.*"
        let baseURLPattern: String
        let tokenPattern: String

        switch shellType {
        case .bash, .zsh:
          baseURLPattern = "export \(EnvVarNames.baseURL)=.*"
          tokenPattern = "export \(EnvVarNames.token)=.*"
        case .fish:
          baseURLPattern = "set -x \(EnvVarNames.baseURL) .*"
          tokenPattern = "set -x \(EnvVarNames.token) .*"
        case .unknown:
          completion(.failure(.unknownShellType))
          return
        }

        // 使用字符串替换方法，避免正则表达式范围问题
        var newContent = configContent

        // 分步移除现有的环境变量设置
        newContent = newContent.replacingOccurrences(
          of: commentPattern,
          with: "",
          options: .regularExpression
        )
        newContent = newContent.replacingOccurrences(
          of: baseURLPattern,
          with: "",
          options: .regularExpression
        )
        newContent = newContent.replacingOccurrences(
          of: tokenPattern,
          with: "",
          options: .regularExpression
        )
        
        // 清理多余的空行
        while newContent.contains("\n\n\n") {
          newContent = newContent.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        // 添加新的环境变量设置
        let commentMarker = "#"  // 所有支持的 shell 都使用 # 作为注释

        let newConfig = """

          \(commentMarker) CCSwitch 环境变量设置 - 自动生成
          \(shellType.exportCommand(name: EnvVarNames.baseURL, value: baseURL))
          \(shellType.exportCommand(name: EnvVarNames.token, value: token))
          """

        // 使用原子写入操作，确保文件写入的完整性
        try (newContent + newConfig).write(toFile: configPath, atomically: true, encoding: .utf8)

        self.logger.info("Shell 配置文件更新成功: \(configPath)")
        
        // 创建或更新环境变量辅助文件
        let helperFilePath = self.getRealHomeDirectory() + "/.env-ccswitch"
        let helperFileContent = """
        # CCSwitch 环境变量 - 自动生成
        # 此文件由 CCSwitch 应用程序自动生成，用于帮助其他应用程序读取环境变量
        export \(EnvVarNames.baseURL)="\(baseURL)"
        export \(EnvVarNames.token)="\(token)"
        """
        
        try helperFileContent.write(toFile: helperFilePath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: helperFilePath)
        
        self.logger.info("环境变量辅助文件更新成功: \(helperFilePath)")
        
        // 尝试立即使环境变量生效
        let _ = self.setEnvironmentVariablesDirectly(baseURL: baseURL, token: token)
        
        completion(.success(()))

      } catch {
        self.logger.error("更新 Shell 配置文件失败: \(error.localizedDescription)")
        completion(.failure(.configFileWriteFailed(error.localizedDescription)))
      }
    }
  }

  /// 从 Shell 配置文件中移除环境变量设置
  /// - Returns: 操作结果
  func removeFromShellConfig() -> Result<Void, ShellConfigServiceError> {
    logger.info("正在从 Shell 配置文件移除环境变量设置")

    // 获取当前 Shell 类型
    let shellType = getCurrentShellType()

    // 检查 Shell 类型是否已知
    guard shellType != .unknown else {
      logger.error("无法确定 Shell 类型，无法更新配置文件")
      return .failure(.unknownShellType)
    }

    // 获取配置文件路径
    let configPath = shellType.configFilePath

    // 检查配置文件是否存在
    guard FileManager.default.fileExists(atPath: configPath) else {
      logger.warning("配置文件不存在，无需移除环境变量设置")
      return .success(())
    }

    do {
      // 读取现有配置文件内容
      var configContent = try String(contentsOfFile: configPath, encoding: .utf8)

      // 移除环境变量设置
      let commentMarker: String
      let baseURLPattern: String
      let tokenPattern: String

      switch shellType {
      case .bash, .zsh:
        commentMarker = "#"
        baseURLPattern = "export \(EnvVarNames.baseURL)=.*"
        tokenPattern = "export \(EnvVarNames.token)=.*"
      case .fish:
        commentMarker = "#"
        baseURLPattern = "set -x \(EnvVarNames.baseURL) .*"
        tokenPattern = "set -x \(EnvVarNames.token) .*"
      case .unknown:
        return .failure(.unknownShellType)
      }

      // 移除注释行和环境变量设置行
      let pattern = "\(commentMarker) CCSwitch 环境变量设置 - 自动生成\n\(baseURLPattern)\n\(tokenPattern)"
      configContent = configContent.replacingOccurrences(
        of: pattern, with: "", options: .regularExpression
      )

      // 写入配置文件
      try configContent.write(toFile: configPath, atomically: true, encoding: .utf8)

      logger.info("环境变量设置已从 Shell 配置文件移除")
      return .success(())

    } catch {
      logger.error("从 Shell 配置文件移除环境变量设置失败: \(error.localizedDescription)")
      return .failure(.configFileWriteFailed(error.localizedDescription))
    }
  }

  /// 检查 Shell 配置文件是否包含环境变量设置
  /// - Returns: 如果配置文件包含环境变量设置则返回 true，否则返回 false
  func shellConfigContainsEnvVars() -> Bool {
    logger.info("正在检查 Shell 配置文件是否包含环境变量设置")

    // 获取当前 Shell 类型
    let shellType = getCurrentShellType()

    // 检查 Shell 类型是否已知
    guard shellType != .unknown else {
      logger.warning("无法确定 Shell 类型，无法检查配置文件")
      return false
    }

    // 获取配置文件路径
    let configPath = shellType.configFilePath

    // 检查配置文件是否存在
    guard FileManager.default.fileExists(atPath: configPath) else {
      logger.warning("配置文件不存在")
      return false
    }

    do {
      // 读取配置文件内容
      let configContent = try String(contentsOfFile: configPath, encoding: .utf8)

      // 检查是否包含环境变量设置
      let marker = "CCSwitch 环境变量设置 - 自动生成"
      return configContent.contains(marker)

    } catch {
      logger.error("读取配置文件失败: \(error.localizedDescription)")
      return false
    }
  } 
 /// 执行 Shell 配置文件以使环境变量立即生效
  /// - Returns: 操作结果
  func sourceShellConfig() -> Result<Void, ShellConfigServiceError> {
    logger.info("正在执行 Shell 配置文件以使环境变量立即生效")

    // 获取当前 Shell 类型
    let shellType = getCurrentShellType()

    // 检查 Shell 类型是否已知
    guard shellType != .unknown else {
      logger.error("无法确定 Shell 类型，无法执行配置文件")
      return .failure(.unknownShellType)
    }

    // 获取配置文件路径
    let configPath = shellType.configFilePath

    // 检查配置文件是否存在
    guard FileManager.default.fileExists(atPath: configPath) else {
      logger.warning("配置文件不存在，无法执行")
      return .failure(.configFileNotFound(configPath))
    }

    // 创建临时脚本文件
    let tempDir = FileManager.default.temporaryDirectory
    let scriptURL = tempDir.appendingPathComponent("source_config.sh")

    // 改进脚本内容，确保环境变量正确加载
    let scriptContent: String

    switch shellType {
    case .bash, .zsh:
      scriptContent = """
        #!/bin/bash

        # 直接从配置文件中提取环境变量设置
        if [ -f "\(configPath)" ]; then
          # 查找并提取环境变量设置行，不管是否有 CCSwitch 标记
          BASE_URL_LINE=$(grep "export \(EnvVarNames.baseURL)=" "\(configPath)" | tail -n 1)
          TOKEN_LINE=$(grep "export \(EnvVarNames.token)=" "\(configPath)" | tail -n 1)
          
          # 直接执行这些行，而不是整个配置文件
          if [ ! -z "$BASE_URL_LINE" ]; then
            eval "$BASE_URL_LINE"
            echo "已设置: $BASE_URL_LINE"
          else
            echo "未找到 \(EnvVarNames.baseURL) 设置行"
          fi
          
          if [ ! -z "$TOKEN_LINE" ]; then
            eval "$TOKEN_LINE"
            echo "已设置: TOKEN=***"
          else
            echo "未找到 \(EnvVarNames.token) 设置行"
          fi
          
          # 验证环境变量是否已设置
          echo "当前环境变量值:"
          echo "\(EnvVarNames.baseURL)=$\(EnvVarNames.baseURL)"
          echo "\(EnvVarNames.token)=***"
        else
          echo "配置文件不存在: \(configPath)"
          exit 1
        fi
        
        # 创建或更新环境变量辅助文件
        if [ ! -z "$\(EnvVarNames.baseURL)" ] && [ ! -z "$\(EnvVarNames.token)" ]; then
          cat > ~/.env-ccswitch << EOF
        # CCSwitch 环境变量 - 自动生成
        # 此文件由 CCSwitch 应用程序自动生成，用于帮助其他应用程序读取环境变量
        export \(EnvVarNames.baseURL)="$\(EnvVarNames.baseURL)"
        export \(EnvVarNames.token)="$\(EnvVarNames.token)"
        EOF
          chmod 644 ~/.env-ccswitch
          echo "已更新环境变量辅助文件: ~/.env-ccswitch"
        fi
        
        # 直接设置当前 shell 的环境变量，确保立即生效
        export \(EnvVarNames.baseURL)="$\(EnvVarNames.baseURL)"
        export \(EnvVarNames.token)="$\(EnvVarNames.token)"
        """
    case .fish:
      scriptContent = """
        #!/bin/bash

        # 对于 fish shell，使用 fish 命令执行
        if [ -f "\(configPath)" ]; then
          # 提取环境变量设置，不管是否有 CCSwitch 标记
          BASE_URL_LINE=$(grep "set -x \(EnvVarNames.baseURL)" "\(configPath)" | tail -n 1)
          TOKEN_LINE=$(grep "set -x \(EnvVarNames.token)" "\(configPath)" | tail -n 1)
          
          # 使用 fish 执行这些命令
          if [ ! -z "$BASE_URL_LINE" ]; then
            fish -c "$BASE_URL_LINE"
            echo "已设置: $BASE_URL_LINE"
          else
            echo "未找到 \(EnvVarNames.baseURL) 设置行"
          fi
          
          if [ ! -z "$TOKEN_LINE" ]; then
            fish -c "$TOKEN_LINE"
            echo "已设置: TOKEN=***"
          else
            echo "未找到 \(EnvVarNames.token) 设置行"
          fi
          
          # 验证环境变量
          echo "当前环境变量值:"
          fish -c "echo \(EnvVarNames.baseURL)=$\(EnvVarNames.baseURL)"
          fish -c "echo \(EnvVarNames.token)=***"
        else
          echo "配置文件不存在: \(configPath)"
          exit 1
        fi
        
        # 创建环境变量辅助文件 (bash 格式，方便其他程序使用)
        BASE_URL=$(fish -c "echo $\(EnvVarNames.baseURL)")
        TOKEN=$(fish -c "echo $\(EnvVarNames.token)")
        
        if [ ! -z "$BASE_URL" ] && [ ! -z "$TOKEN" ]; then
          cat > ~/.env-ccswitch << EOF
        # CCSwitch 环境变量 - 自动生成
        # 此文件由 CCSwitch 应用程序自动生成，用于帮助其他应用程序读取环境变量
        export \(EnvVarNames.baseURL)="$BASE_URL"
        export \(EnvVarNames.token)="$TOKEN"
        EOF
          chmod 644 ~/.env-ccswitch
          echo "已更新环境变量辅助文件: ~/.env-ccswitch"
        fi
        
        # 直接设置当前 shell 的环境变量，确保立即生效
        fish -c "set -x \(EnvVarNames.baseURL) '$BASE_URL'"
        fish -c "set -x \(EnvVarNames.token) '$TOKEN'"
        """
    case .unknown:
      return .failure(.unknownShellType)
    }

    do {
      // 写入脚本文件
      try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)

      // 设置脚本可执行权限
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

      // 执行脚本
      let task = Process()
      task.executableURL = URL(fileURLWithPath: "/bin/bash")
      task.arguments = [scriptURL.path]

      let outputPipe = Pipe()
      task.standardOutput = outputPipe
      task.standardError = outputPipe

      try task.run()
      
      // 设置更长的超时时间
      let timeout = DispatchTime.now() + 3.0  // 3秒超时
      let waitResult = task.waitUntilExit(timeout: timeout)
      
      if waitResult == .timedOut {
        logger.warning("Shell 配置文件执行超时，但环境变量可能已部分更新")
        // 尝试终止任务
        task.terminate()
      } else if task.terminationStatus != 0 {
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? "未知错误"
        logger.error("Shell 配置文件执行失败: \(output)")
        throw ShellConfigServiceError.scriptExecutionFailed(output)
      } else {
        // 读取并记录脚本输出
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: outputData, encoding: .utf8) {
          logger.info("Shell 配置文件执行输出: \(output)")
        }
      }

      // 删除临时脚本文件
      try? FileManager.default.removeItem(at: scriptURL)

      logger.info("Shell 配置文件执行成功")
      
      // 验证当前进程的环境变量
      let currentBaseURL = ProcessInfo.processInfo.environment[EnvVarNames.baseURL]
      let currentToken = ProcessInfo.processInfo.environment[EnvVarNames.token]
      
      logger.info("当前进程环境变量: \(EnvVarNames.baseURL)=\(currentBaseURL ?? "未设置")")
      logger.info("当前进程环境变量: \(EnvVarNames.token)=\(currentToken != nil ? "已设置" : "未设置")")
      
      return .success(())

    } catch {
      logger.error("执行 Shell 配置文件失败: \(error.localizedDescription)")
      return .failure(.scriptExecutionFailed(error.localizedDescription))
    }
  }
  
  /// 直接设置环境变量，使其在当前进程和子进程中立即生效
  /// - Parameters:
  ///   - baseURL: API 基础 URL
  ///   - token: API 访问令牌
  /// - Returns: 操作结果
  func setEnvironmentVariablesDirectly(baseURL: String, token: String) -> Result<
    Void, ShellConfigServiceError
  > {
    logger.info("正在直接设置环境变量")

    // 在当前进程中设置环境变量 - 这是同步操作，确保立即在当前进程生效
    setenv(EnvVarNames.baseURL, baseURL, 1)
    setenv(EnvVarNames.token, token, 1)
    
    // 打印确认环境变量已在当前进程中设置
    logger.info("当前进程环境变量已设置: \(EnvVarNames.baseURL)=\(baseURL)")
    logger.info("当前进程环境变量已设置: \(EnvVarNames.token)=***")

    // 使用后台队列异步处理子进程环境变量设置
    let dispatchGroup = DispatchGroup()

    dispatchGroup.enter()
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else {
        dispatchGroup.leave()
        return
      }

      // 创建临时脚本文件，用于在子进程中设置环境变量
      let tempDir = FileManager.default.temporaryDirectory
      let scriptURL = tempDir.appendingPathComponent("set_env_vars.sh")

      // 改进脚本内容，确保环境变量正确设置
      let scriptContent = """
        #!/bin/bash

        # 设置环境变量
        export \(EnvVarNames.baseURL)="\(baseURL)"
        export \(EnvVarNames.token)="\(token)"

        # 创建或更新 ~/.env-ccswitch 文件，用于其他应用程序读取
        cat > ~/.env-ccswitch << EOF
        # CCSwitch 环境变量 - 自动生成
        # 此文件由 CCSwitch 应用程序自动生成，用于帮助其他应用程序读取环境变量
        export \(EnvVarNames.baseURL)="\(baseURL)"
        export \(EnvVarNames.token)="\(token)"
        EOF

        # 确保文件权限正确
        chmod 644 ~/.env-ccswitch

        # 尝试更新当前 shell 的环境变量
        if [ -n "$SHELL" ]; then
          if [[ "$SHELL" == *"zsh"* ]]; then
            # 对于 zsh
            if [ -f ~/.zshrc ]; then
              source ~/.zshrc 2>/dev/null || true
            fi
          elif [[ "$SHELL" == *"bash"* ]]; then
            # 对于 bash
            if [ -f ~/.bashrc ]; then
              source ~/.bashrc 2>/dev/null || true
            fi
            if [ -f ~/.bash_profile ]; then
              source ~/.bash_profile 2>/dev/null || true
            fi
          fi
        fi

        # 验证环境变量是否已设置
        echo "环境变量已设置:"
        echo "\(EnvVarNames.baseURL)=$\(EnvVarNames.baseURL)"
        echo "\(EnvVarNames.token)=***"
        """

      do {
        // 使用原子写入操作，确保文件写入的完整性
        try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)

        // 设置脚本可执行权限
        try FileManager.default.setAttributes(
          [.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        // 执行脚本
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [scriptURL.path]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = outputPipe

        try task.run()

        // 设置超时，避免无限等待
        let timeout = DispatchTime.now() + 2.0  // 增加超时时间到2秒
        let waitResult = task.waitUntilExit(timeout: timeout)

        if waitResult == .timedOut {
          self.logger.warning("环境变量设置脚本执行超时，但进程内变量已更新")
          // 尝试终止任务
          task.terminate()
        } else if task.terminationStatus != 0 {
          let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
          let output = String(data: outputData, encoding: .utf8) ?? "未知错误"
          self.logger.error("环境变量设置脚本执行失败: \(output)")
          throw ShellConfigServiceError.scriptExecutionFailed(output)
        } else {
          // 读取并记录脚本输出
          let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
          if let output = String(data: outputData, encoding: .utf8) {
            self.logger.info("环境变量设置脚本输出: \(output)")
          }
        }

        // 删除临时脚本文件
        try? FileManager.default.removeItem(at: scriptURL)

        self.logger.info("环境变量直接设置成功")
        
        // 再次验证当前进程的环境变量
        let currentBaseURL = ProcessInfo.processInfo.environment[EnvVarNames.baseURL]
        let currentToken = ProcessInfo.processInfo.environment[EnvVarNames.token]
        
        self.logger.info("验证当前进程环境变量: \(EnvVarNames.baseURL)=\(currentBaseURL ?? "未设置")")
        self.logger.info("验证当前进程环境变量: \(EnvVarNames.token)=\(currentToken != nil ? "已设置" : "未设置")")

      } catch {
        self.logger.error("直接设置环境变量失败: \(error.localizedDescription)")
        // 尝试清理临时文件
        try? FileManager.default.removeItem(at: scriptURL)
      }

      dispatchGroup.leave()
    }

    // 不等待异步操作完成，立即返回成功结果
    // 因为当前进程的环境变量已经设置，子进程的设置是额外的优化
    return .success(())
  }

  /// 检查环境变量是否已正确设置
  /// - Parameters:
  ///   - baseURL: 预期的 API 基础 URL
  ///   - token: 预期的 API 访问令牌
  /// - Returns: 如果环境变量已正确设置则返回 true，否则返回 false
  func checkEnvironmentVariables(baseURL: String, token: String) -> Bool {
    logger.info("正在检查环境变量是否已正确设置")

    // 获取当前环境变量
    let currentBaseURL = ProcessInfo.processInfo.environment[EnvVarNames.baseURL]
    let currentToken = ProcessInfo.processInfo.environment[EnvVarNames.token]

    // 检查环境变量是否与预期值匹配
    let baseURLMatches = currentBaseURL == baseURL
    let tokenMatches = currentToken == token

    if !baseURLMatches {
      logger.warning("环境变量 \(EnvVarNames.baseURL) 不匹配: 预期 \(baseURL)，实际 \(currentBaseURL ?? "nil")")
    }

    if !tokenMatches {
      logger.warning(
        "环境变量 \(EnvVarNames.token) 不匹配: 预期 ***，实际 \(currentToken != nil ? "***" : "nil")")
    }

    return baseURLMatches && tokenMatches
  }
  
  // MARK: - 图标设置方法
  
  /// 确保应用图标已设置
  private func ensureAppIconIsSet() {
    if NSApp.applicationIconImage == nil {
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = icon
        } else if let icon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = icon
        } else if let icon = NSImage(named: NSImage.applicationIconName) {
            NSApp.applicationIconImage = icon
        }
    }
  }
}

// MARK: - Process Extension
extension Process {
  fileprivate func waitUntilExit(timeout: DispatchTime) -> ProcessWaitResult {
    let waitSemaphore = DispatchSemaphore(value: 0)

    // 在后台监控进程终止，使用与调用者相同的优先级避免优先级反转
    DispatchQueue.global(qos: .userInitiated).async {
      self.waitUntilExit()
      waitSemaphore.signal()
    }

    // 等待进程终止或超时
    return waitSemaphore.wait(timeout: timeout) == .timedOut ? .timedOut : .completed
  }
}
