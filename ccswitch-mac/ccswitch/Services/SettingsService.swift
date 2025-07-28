 import Foundation
import os.log

/// 设置服务，负责管理用户的应用设置
class SettingsService {
    /// 日志对象
    private let logger = Logger(subsystem: "com.ccswitch.app", category: "SettingsService")
    
    /// UserDefaults 键值常量
    private struct Keys {
        static let customShellConfigPath = "customShellConfigPath"
        static let useCustomShellConfigPath = "useCustomShellConfigPath"
        static let launchAtLogin = "launchAtLogin"
    }
    
    /// 开机启动服务
    private let launchAgentService = LaunchAgentService()
    
    /// 初始化设置服务
    init() {
        logger.info("设置服务已初始化")
    }
    
    /// 获取自定义Shell配置文件路径
    var customShellConfigPath: String? {
        get {
            UserDefaults.standard.string(forKey: Keys.customShellConfigPath)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.customShellConfigPath)
            logger.info("自定义Shell配置文件路径已更新: \(newValue ?? "nil")")
        }
    }
    
    /// 是否使用自定义Shell配置文件路径
    var useCustomShellConfigPath: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.useCustomShellConfigPath)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.useCustomShellConfigPath)
            logger.info("使用自定义Shell配置文件路径设置已更新: \(newValue)")
        }
    }
    
    
    /// 是否启用开机启动
    var launchAtLogin: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.launchAtLogin)
            logger.info("开机启动设置已更新: \(newValue)")
        }
    }
    
    /// 检查开机启动状态
    func checkLaunchAtLoginStatus() -> Bool {
        return launchAgentService.isLaunchAtLoginEnabled()
    }
    
    /// 切换开机启动状态
    func toggleLaunchAtLogin() throws {
        try launchAgentService.toggleLaunchAtLogin()
        launchAtLogin = launchAgentService.isLaunchAtLoginEnabled()
    }
    
    /// 重置所有设置为默认值
    func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: Keys.customShellConfigPath)
        UserDefaults.standard.removeObject(forKey: Keys.useCustomShellConfigPath)
        UserDefaults.standard.removeObject(forKey: Keys.launchAtLogin)
        logger.info("所有设置已重置为默认值")
    }
}