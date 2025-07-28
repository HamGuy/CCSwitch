import Foundation
import UserNotifications
import os.log
import AppKit

/// 通知服务错误类型
enum NotificationServiceError: Error, LocalizedError {
    /// 通知权限被拒绝
    case permissionDenied
    /// 通知发送失败
    case sendFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "通知权限被拒绝"
        case .sendFailed(let message):
            return "通知发送失败: \(message)"
        }
    }
}

/// 通知类型枚举
enum NotificationType {
    /// 成功通知
    case success
    /// 错误通知
    case error
    /// 警告通知
    case warning
    /// 信息通知
    case info
}

/// 通知服务，负责管理系统通知的发送
class NotificationService {
    /// 日志对象
    private let logger = Logger(subsystem: "com.ccswitch.app", category: "NotificationService")
    
    /// 通知中心
    private let notificationCenter = UNUserNotificationCenter.current()
    
    /// 初始化通知服务
    init() {
        logger.info("通知服务已初始化")
        
        // 请求通知权限
        requestNotificationPermissions()
    }
    
    /// 请求通知权限
    private func requestNotificationPermissions() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                self.logger.error("通知授权错误: \(error.localizedDescription)")
            } else if granted {
                self.logger.info("通知权限已授予")
            } else {
                self.logger.warning("通知权限被拒绝")
            }
        }
    }
    
    /// 发送通知
    /// - Parameters:
    ///   - title: 通知标题
    ///   - message: 通知内容
    ///   - type: 通知类型，默认为 .info
    ///   - completion: 完成回调，参数为操作结果
    func sendNotification(
        title: String,
        message: String,
        type: NotificationType = .info,
        completion: ((Result<Void, NotificationServiceError>) -> Void)? = nil
    ) {
        logger.info("正在发送通知: \(title)")
        
        // 确保应用图标已设置
        DispatchQueue.main.async {
            self.ensureAppIconIsSet()
        }
        
        // 检查通知权限
        notificationCenter.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                self.logger.warning("通知权限未授予，无法发送通知")
                completion?(.failure(.permissionDenied))
                return
            }
            
            // 创建通知内容
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            
            // 设置应用图标和通知类别
            content.categoryIdentifier = "CCSwitch"
            
            // 确保通知显示正确的应用图标
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                content.targetContentIdentifier = bundleIdentifier
            }
            
            // 尝试设置通知图标附件 - 使用 Assets.xcassets 中的图标
            // macOS 通知不支持直接附加 .icns 文件，尝试使用 PNG 格式
            if let iconURL = Bundle.main.url(forResource: "icon_512x512", withExtension: "png", 
                                           subdirectory: "Assets.xcassets/AppIcon.appiconset") {
                do {
                    let attachment = try UNNotificationAttachment(
                        identifier: "app-icon",
                        url: iconURL,
                        options: [UNNotificationAttachmentOptionsTypeHintKey: "public.png"]
                    )
                    content.attachments = [attachment]
                    self.logger.info("成功设置通知图标附件")
                } catch {
                    self.logger.warning("无法创建通知图标附件: \(error.localizedDescription)")
                }
            } else {
                self.logger.warning("未找到合适的图标文件用于通知")
            }
            
            // 根据通知类型设置声音
            switch type {
            case .success:
                content.sound = UNNotificationSound.default
            case .error:
                content.sound = UNNotificationSound.default
            case .warning:
                content.sound = UNNotificationSound.default
            case .info:
                content.sound = nil  // 信息通知不发出声音
            }
            
            // 创建通知请求
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil  // 立即发送通知
            )
            
            // 添加通知请求
            self.notificationCenter.add(request) { error in
                if let error = error {
                    self.logger.error("发送通知失败: \(error.localizedDescription)")
                    completion?(.failure(.sendFailed(error.localizedDescription)))
                } else {
                    self.logger.info("通知发送成功")
                    completion?(.success(()))
                }
            }
        }
    }
    
    /// 确保应用图标已设置
    private func ensureAppIconIsSet() {
        // 即使已经设置了图标，也尝试重新设置以确保正确显示
        
        // 首先尝试使用 Assets.xcassets 中的 AppIcon
        if let appIcon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = appIcon
            logger.info("已设置应用图标 (AppIcon)")
            return
        }
        
        // 尝试使用 EditorIcon
        if let editorIcon = NSImage(named: "EditorIcon") {
            NSApp.applicationIconImage = editorIcon
            logger.info("已设置应用图标 (EditorIcon)")
            return
        }
        
        // 尝试使用系统应用图标名称
        if let appIcon = NSImage(named: NSImage.applicationIconName) {
            NSApp.applicationIconImage = appIcon
            logger.info("已设置应用图标 (applicationIconName)")
            return
        }
        
        // 尝试从文件加载
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let appIcon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = appIcon
            logger.info("已设置应用图标 (icns文件)")
            return
        }
        
        // 尝试从 Assets 目录中的 PNG 文件加载
        if let iconPath = Bundle.main.path(forResource: "icon_512x512", ofType: "png", inDirectory: "Assets.xcassets/AppIcon.appiconset"),
           let appIcon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = appIcon
            logger.info("已设置应用图标 (512x512 png文件)")
            return
        }
        
        logger.warning("无法找到应用图标文件")
    }
    
    /// 发送配置切换成功通知
    /// - Parameter configName: 配置名称
    func sendConfigurationSwitchSuccessNotification(configName: String) {
        sendNotification(
            title: "配置切换成功",
            message: "已切换到配置: \(configName)",
            type: .success
        )
    }
    
    /// 发送配置切换失败通知
    /// - Parameter error: 错误信息
    func sendConfigurationSwitchFailedNotification(error: Error) {
        sendNotification(
            title: "配置切换失败",
            message: error.localizedDescription,
            type: .error
        )
    }
    
    /// 发送重置成功通知
    func sendResetSuccessNotification() {
        sendNotification(
            title: "重置成功",
            message: "已重置为官方默认配置",
            type: .success
        )
    }
    
    /// 发送重置失败通知
    /// - Parameter error: 错误信息
    func sendResetFailedNotification(error: Error) {
        sendNotification(
            title: "重置失败",
            message: error.localizedDescription,
            type: .error
        )
    }
    
    /// 发送错误通知
    /// - Parameters:
    ///   - title: 错误标题
    ///   - error: 错误信息
    func sendErrorNotification(title: String, error: Error) {
        sendNotification(
            title: title,
            message: error.localizedDescription,
            type: .error
        )
    }
}
