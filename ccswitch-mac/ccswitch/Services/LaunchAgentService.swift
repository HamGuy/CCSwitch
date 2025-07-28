import Foundation
import os.log

/// Errors related to the launch agent service.
enum LaunchAgentServiceError: Error, LocalizedError {
    /// Failed to create the launch item.
    case failedToCreateLaunchItem(String)
    /// Failed to remove the launch item.
    case failedToRemoveLaunchItem(String)
    /// Failed to check the status of the launch item.
    case failedToCheckLaunchItemStatus(String)
    /// Insufficient permissions to perform the operation.
    case insufficientPermissions(String)
    
    var errorDescription: String? {
        switch self {
        case .failedToCreateLaunchItem(let message):
            return String(format: NSLocalizedString("launch.error.create.failed", comment: "Failed to create launch item"), message)
        case .failedToRemoveLaunchItem(let message):
            return String(format: NSLocalizedString("launch.error.remove.failed", comment: "Failed to remove launch item"), message)
        case .failedToCheckLaunchItemStatus(let message):
            return String(format: NSLocalizedString("launch.error.check.failed", comment: "Failed to check launch item status"), message)
        case .insufficientPermissions(let message):
            return String(format: NSLocalizedString("launch.error.permission.denied", comment: "Insufficient permissions"), message)
        }
    }
}

/// 开机启动服务，负责管理应用的开机启动功能
class LaunchAgentService {
    /// 日志对象
    private let logger = Logger(subsystem: "com.ccswitch.app", category: "LaunchAgentService")
    
    /// 启动项标识符
    private let launchItemIdentifier = "com.ccswitch.app"
    private let launchItemName = "CCSwitch"
    
    /// 初始化开机启动服务
    init() {
        logger.info("开机启动服务已初始化")
    }
    
    /// 检查是否已启用开机启动
    func isLaunchAtLoginEnabled() -> Bool {
        let launchItems = getLaunchItems()
        let enabled = launchItems.contains { item in
            item.contains(launchItemIdentifier) || item.contains(launchItemName)
        }
        logger.info("开机启动状态: \(enabled)")
        return enabled
    }
    
    /// 启用开机启动
    func enableLaunchAtLogin() throws {
        do {
            let appPath = Bundle.main.bundlePath
            let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "CCSwitch"
            
            // 先确保没有旧的启动项
            if isLaunchAtLoginEnabled() {
                try disableLaunchAtLogin()
            }
            
            let script = """
            tell application "System Events"
                if not (exists login item "\(appName)") then
                    make login item at end with properties {name:"\(appName)", path:"\(appPath)", hidden:false}
                end if
            end tell
            """
            
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                logger.info("开机启动已启用")
                // 验证设置是否成功
                if !isLaunchAtLoginEnabled() {
                    throw LaunchAgentServiceError.failedToCreateLaunchItem("无法验证启动项创建")
                }
            } else {
                throw LaunchAgentServiceError.failedToCreateLaunchItem("AppleScript执行失败，状态码: \(task.terminationStatus)")
            }
        } catch let error as LaunchAgentServiceError {
            logger.error("启用开机启动失败: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("启用开机启动失败: \(error.localizedDescription)")
            throw LaunchAgentServiceError.failedToCreateLaunchItem(error.localizedDescription)
        }
    }
    
    /// 禁用开机启动
    func disableLaunchAtLogin() throws {
        do {
            let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "CCSwitch"
            
            let script = """
            tell application "System Events"
                if exists login item "\(appName)" then
                    delete login item "\(appName)"
                end if
            end tell
            """
            
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                logger.info("开机启动已禁用")
                // 验证设置是否成功
                if isLaunchAtLoginEnabled() {
                    throw LaunchAgentServiceError.failedToRemoveLaunchItem("无法验证启动项删除")
                }
            } else {
                throw LaunchAgentServiceError.failedToRemoveLaunchItem("AppleScript执行失败，状态码: \(task.terminationStatus)")
            }
        } catch let error as LaunchAgentServiceError {
            logger.error("禁用开机启动失败: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("禁用开机启动失败: \(error.localizedDescription)")
            throw LaunchAgentServiceError.failedToRemoveLaunchItem(error.localizedDescription)
        }
    }
    
    /// 切换开机启动状态
    func toggleLaunchAtLogin() throws {
        if isLaunchAtLoginEnabled() {
            try disableLaunchAtLogin()
        } else {
            try enableLaunchAtLogin()
        }
    }
    
    /// 获取当前启动项列表
    private func getLaunchItems() -> [String] {
        do {
            let script = """
            tell application "System Events"
                get name of every login item
            end tell
            """
            
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return output.components(separatedBy: ", ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } catch {
            logger.error("获取启动项列表失败: \(error.localizedDescription)")
            return []
        }
    }
}
