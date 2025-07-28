//
//  ccswitchApp.swift
//  ccswitch
//
//  Created by HamGuy on 2025/7/26.
//

import AppKit
import Combine
import SwiftUI
import UserNotifications

@main
struct ccswitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate,
                   NSWindowDelegate, ObservableObject
{
    private var menuBarController: MenuBarController?
    private var viewModel = AppViewModel()
    
    // 热键服务
    private var hotKeyService: HotKeyService?
    
    // 配置编辑器窗口
    private var configurationEditorWindow: NSWindow?
    
    // 用于检测是否是首次启动
    private let userDefaults = UserDefaults.standard
    private let firstLaunchKey = "com.ccswitch.app.firstLaunch"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保应用图标已设置
        ensureAppIconIsSet()
        
        // 检查是否是首次启动
        let isFirstLaunch = checkFirstLaunch()
        
        // 加载保存的配置
        loadConfigurations()
        
        // 初始化菜单栏控制器
        menuBarController = MenuBarController(viewModel: viewModel)
        
        // 设置初始菜单状态
        setupInitialMenuState()
        
        // 初始化热键服务 - 注册 Shift+Command+C 快捷键
        initializeHotKeyService()
        
        // 注册配置变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configurationsDidChange),
            name: NSNotification.Name("ConfigurationsDidChange"),
            object: nil
        )
        
        // 注册热键按下通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotKeyPressed),
            name: NSNotification.Name("HotKeyPressed"),
            object: nil
        )
        
        // 请求通知权限
        requestNotificationPermissions()
        
        // 观察视图模型变化
        observeViewModel()
        
        // 如果是首次启动，显示欢迎信息
        if isFirstLaunch {
            showWelcomeMessage()
        }
        
        // 延迟隐藏 Dock 图标 - 让应用先完全启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
            print("Dock 图标已隐藏")
        }
    }
    
    /// 设置 NSAlert 的应用图标
    private func setAlertIcon(_ alert: NSAlert) {
        // 直接尝试加载EditorIcon
        if let editIcon = NSImage(named: "EditorIcon") {
            alert.icon = editIcon
            print("✅ 成功使用EditorIcon设置Alert图标")
            return
        }
        
                print("❌ 无法加载EditorIcon，尝试其他图标...")
        
        // 备选方案
        if let appIcon = NSApp.applicationIconImage {
            alert.icon = appIcon
            print("使用NSApp.applicationIconImage设置Alert图标")
        } else if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
                  let icon = NSImage(contentsOfFile: iconPath) {
            alert.icon = icon
            print("使用icns文件设置Alert图标")
        } else if let icon = NSImage(named: "AppIcon") {
            alert.icon = icon
            print("使用NSImage(named: AppIcon)设置Alert图标")
        } else {
            // 使用默认的应用图标
            alert.icon = NSImage(named: NSImage.applicationIconName)
            print("使用系统默认图标")
        }
    }
    
    /// 确保应用图标已设置
    private func ensureAppIconIsSet() {
        print("当前应用图标: \(NSApp.applicationIconImage != nil ? "已设置" : "未设置")")
        
        // 即使已经设置了图标，也尝试重新设置以确保正确显示
        
        // 首先尝试使用 Assets.xcassets 中的 AppIcon
        if let icon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = icon
            print("✅ 使用NSImage(named: AppIcon)设置应用图标")
            return
        }
        
        // 尝试使用 EditorIcon
        if let icon = NSImage(named: "EditorIcon") {
            NSApp.applicationIconImage = icon
            print("✅ 使用NSImage(named: EditorIcon)设置应用图标")
            return
        }
        
        // 尝试从文件加载
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = icon
            print("✅ 使用icns文件设置应用图标")
            return
        }
        
        // 尝试从 Assets 目录中的 PNG 文件加载
        if let iconPath = Bundle.main.path(forResource: "icon_512x512", ofType: "png", inDirectory: "Assets.xcassets/AppIcon.appiconset"),
           let icon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = icon
            print("✅ 使用512x512 png文件设置应用图标")
            return
        }
        
        // 尝试使用系统应用图标名称
        if let icon = NSImage(named: NSImage.applicationIconName) {
            NSApp.applicationIconImage = icon
            print("✅ 使用NSImage.applicationIconName设置应用图标")
            return
        }
        
        print("❌ 警告: 无法加载应用图标")
    }
    
    /// 初始化热键服务
    private func initializeHotKeyService() {
        // 创建热键服务实例
        hotKeyService = HotKeyService()
        
        print("已注册全局热键: Shift+Command+C")
    }
    
    /// 处理热键按下事件
    @objc func hotKeyPressed() {
        print("检测到热键: Shift+Command+C")
        
        // 激活应用程序
        NSApp.activate(ignoringOtherApps: true)
        
        // 显示菜单栏下拉菜单，而不是配置编辑器
        if let statusItem = menuBarController?.statusItem {
            statusItem.button?.performClick(nil)
        }
    }
    
    /// 检查是否是首次启动
    /// - Returns: 如果是首次启动则返回 true，否则返回 false
    private func checkFirstLaunch() -> Bool {
        if userDefaults.bool(forKey: firstLaunchKey) {
            return false
        } else {
            userDefaults.set(true, forKey: firstLaunchKey)
            return true
        }
    }
    
    /// 加载保存的配置
    private func loadConfigurations() {
        print("正在加载保存的配置")
        
        // 加载配置
        viewModel.loadConfigurations()
        
        // 如果没有活动配置但有保存的配置，设置第一个为活动配置
        if viewModel.activeConfiguration == nil && !viewModel.configurations.isEmpty {
            print("没有活动配置，设置第一个配置为活动配置")
            if let officialConfig = viewModel.getConfigurations(ofType: .official).first {
                _ = viewModel.switchToConfiguration(officialConfig)
            } else {
                _ = viewModel.switchToConfiguration(viewModel.configurations[0])
            }
        }
        
        // 确保环境变量与当前活动配置一致
        syncEnvironmentWithActiveConfiguration()
    }
    
    /// 同步环境变量与当前活动配置
    private func syncEnvironmentWithActiveConfiguration() {
        guard let activeConfig = viewModel.activeConfiguration else { return }
        
        // 获取环境服务和 Shell 配置服务
        let environmentService = viewModel.getEnvironmentService()
        let shellConfigService = viewModel.getShellConfigService()
        
        // 获取当前环境变量
        let currentEnv = environmentService.getCurrentEnvironmentVariables()
        
        // 如果环境变量与当前配置不一致，更新环境变量
        if currentEnv.baseURL != activeConfig.baseURL || currentEnv.token != activeConfig.token {
            print("环境变量与当前配置不一致，正在更新环境变量")
            
            // 更新环境变量
            let envResult = environmentService.updateEnvironmentVariables(
                baseURL: activeConfig.baseURL,
                token: activeConfig.token
            )
            
            if case .failure(let error) = envResult {
                print("环境变量更新失败: \(error.localizedDescription)")
                
                // 显示错误提示
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "环境变量更新失败"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "确定")
                    
                    // 设置应用图标
                    self.setAlertIcon(alert)
                    
                    alert.runModal()
                }
            }
            
            // 更新 Shell 配置文件
            let shellResult = shellConfigService.updateShellConfig(
                baseURL: activeConfig.baseURL,
                token: activeConfig.token
            )
            
            if case .failure(let error) = shellResult {
                print("Shell 配置更新失败: \(error.localizedDescription)")
                
                // 显示错误提示
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Shell 配置更新失败"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "确定")
                    
                    // 设置应用图标
                    self.setAlertIcon(alert)
                    
                    alert.runModal()
                }
            }
            
            // 尝试使环境变量立即生效
            let sourceResult = shellConfigService.sourceShellConfig()
            
            if case .failure(let error) = sourceResult {
                print("使环境变量立即生效失败: \(error.localizedDescription)")
                
                // 显示错误提示，但不阻止应用继续运行
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "环境变量可能需要重启终端才能生效"
                    alert.informativeText = "无法使环境变量立即生效: \(error.localizedDescription)"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "确定")
                    
                    // 设置应用图标
                    self.setAlertIcon(alert)
                    
                    alert.runModal()
                }
            }
        }
    }
    
    /// 设置初始菜单状态
    private func setupInitialMenuState() {
        // 如果有活动配置，更新菜单显示
        if let activeConfig = viewModel.activeConfiguration {
            menuBarController?.updateCurrentConfiguration(name: activeConfig.name)
        }
    }
    
    /// 请求通知权限
    private func requestNotificationPermissions() {
        // 创建通知类别
        let category = UNNotificationCategory(
            identifier: "CCSwitch",
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // 注册通知类别
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        // 请求通知权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
            granted, error in
            if let error = error {
                print("通知授权错误: \(error.localizedDescription)")
            } else if granted {
                print("通知权限已授予")
                
                // 在主线程上确保应用图标已设置
                DispatchQueue.main.async {
                    self.ensureAppIconIsSet()
                }
            } else {
                print("通知权限被拒绝")
            }
        }
        
        // 设置通知代理
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// 当应用在前台时收到通知的处理方法
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 在前台也显示通知
        completionHandler([.banner, .sound, .list])
    }
    
    /// 显示欢迎信息
    private func showWelcomeMessage() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Welcome to CCSwitch", comment: "Welcome dialog title")
            alert.informativeText = NSLocalizedString("CCSwitch is a menu bar application that helps you quickly switch between different Claude Code API configurations.\n\nThe app comes with several common configuration types pre-configured. You can click the menu bar icon to view and manage these configurations.", comment: "Welcome dialog message")
            alert.alertStyle = .informational
            alert.addButton(withTitle: NSLocalizedString("Get Started", comment: "Get Started button"))
            
            // 设置应用图标
            self.setAlertIcon(alert)
            
            alert.runModal()
        }
    }
    
    private func observeViewModel() {
        // Observe configurations changes
        viewModel.$configurations.sink { [weak self] _ in
            self?.postConfigurationsDidChangeNotification()
        }.store(in: &cancellables)
        
        // Observe active configuration changes
        viewModel.$activeConfiguration.sink { [weak self] _ in
            self?.postActiveConfigurationDidChangeNotification()
        }.store(in: &cancellables)
    }
    
    @objc func configurationsDidChange() {
        // This method is called when configurations change
    }
    
    @objc func postConfigurationsDidChangeNotification() {
        NotificationCenter.default.post(
            name: NSNotification.Name("ConfigurationsDidChange"), object: nil)
    }
    
    @objc func postActiveConfigurationDidChangeNotification() {
        NotificationCenter.default.post(
            name: NSNotification.Name("ActiveConfigurationDidChange"), object: nil)
    }
    
    @objc func switchConfiguration(_ sender: NSMenuItem) {
        guard let configHash = sender.representedObject as? String,
              let config = viewModel.configurations.first(where: { $0.getConfigurationHash() == configHash })
        else {
            return
        }
        
        // Switch to the selected configuration
        let result = viewModel.switchToConfiguration(config)
        
        // Update menu based on result
        switch result {
        case .success:
            menuBarController?.updateCurrentConfiguration(name: config.name)
            
            // 通知已经由 AppViewModel 发送，这里不需要重复发送
            
        case .failure(let error):
            // Show error alert
            let alert = NSAlert()
            alert.messageText = "配置切换失败"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
            
            // 通知已经由 AppViewModel 发送，这里不需要重复发送
        }
    }
    
    @objc func editConfiguration(_ sender: NSMenuItem) {
        print("=== editConfiguration called ===")
        print("Sender: \(sender)")
        print("RepresentedObject: \(sender.representedObject ?? "nil")")
        
        guard let configHash = sender.representedObject as? String,
              let config = viewModel.configurations.first(where: { $0.getConfigurationHash() == configHash })
        else {
            print("❌ 无法获取配置信息")
            print("ConfigHash: \(sender.representedObject as? String ?? "nil")")
            return
        }
        
        print("✅ 找到配置: \(config.name)")
        // 显示配置编辑器窗口
        showConfigurationEditor(configuration: config)
    }
    
    @objc func deleteConfiguration(_ sender: NSMenuItem) {
        guard let configHash = sender.representedObject as? String,
              let config = viewModel.configurations.first(where: { $0.getConfigurationHash() == configHash })
        else {
            return
        }
        
        // This will be fully implemented in task 6.2
        // For now, just show a confirmation dialog for custom configurations
        if config.isCustom {
            let alert = NSAlert()
            alert.messageText = "Delete Configuration"
            alert.informativeText = "Are you sure you want to delete the configuration '\(config.name)'?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let result = viewModel.deleteConfiguration(config)
                
                switch result {
                case .success:
                    // Configuration deleted successfully
                    postConfigurationsDidChangeNotification()
                case .failure(let error):
                    // Show error alert
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Delete Failed"
                    errorAlert.informativeText = error.localizedDescription
                    errorAlert.alertStyle = .warning
                    errorAlert.addButton(withTitle: "OK")
                    errorAlert.runModal()
                }
            }
        } else {
            // Show error for preset configurations
            let alert = NSAlert()
            alert.messageText = "Cannot Delete Preset Configuration"
            alert.informativeText = "Preset configurations cannot be deleted."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    @objc func addConfiguration() {
        // 显示新配置编辑器窗口
        showConfigurationEditor(configuration: nil)
    }
    
    @objc func resetToDefault() {
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Reset to Default"
        alert.informativeText =
        "Are you sure you want to reset to the official default configuration? This will clear your current token."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Reset to default configuration
            let result = viewModel.resetToDefault()
            
            switch result {
            case .success(let config):
                menuBarController?.updateCurrentConfiguration(name: config.name)
                
                // 通知已经由 AppViewModel 发送，这里不需要重复发送
                
            case .failure(let error):
                // Show error alert
                let errorAlert = NSAlert()
                errorAlert.messageText = "重置失败"
                errorAlert.informativeText = error.localizedDescription
                errorAlert.alertStyle = .warning
                errorAlert.addButton(withTitle: "确定")
                errorAlert.runModal()
                
                // 通知已经由 AppViewModel 发送，这里不需要重复发送
            }
        }
    }
    
    // MARK: - All Configurations View
    
    /// 所有配置窗口
    private var allConfigurationsWindow: NSWindow?
    
    /// 设置窗口控制器 - 使用强引用确保不会被过早释放
    private var settingsWindowController: SettingsWindowController? = nil {
        didSet {
            print("settingsWindowController 被\(settingsWindowController == nil ? "清除" : "设置")")
        }
    }
    
    /// 显示所有配置窗口
    @objc func showAllConfigurations() {
        // 如果已经有窗口打开，先关闭
        if let existingWindow = allConfigurationsWindow {
            existingWindow.close()
            allConfigurationsWindow = nil
        }
        
        // 创建窗口引用的绑定
        let isPresentedBinding = Binding<Bool>(
            get: { [weak self] in
                return self?.allConfigurationsWindow != nil
            },
            set: { [weak self] newValue in
                if !newValue {
                    self?.allConfigurationsWindow?.close()
                    self?.allConfigurationsWindow = nil
                }
            }
        )
        
        // 创建所有配置视图
        let allConfigsView = AllConfigurationsView(
            viewModel: viewModel,
            isPresented: isPresentedBinding
        )
        
        // 创建并配置现代化窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = ""  // 移除系统标题，使用自定义标题
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden  // 隐藏系统标题栏
        window.isMovableByWindowBackground = true
        
        // 创建毛玻璃效果视图
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .menu
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        
        // 设置圆角
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        
        // 创建容器视图
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.masksToBounds = true
        
        // 添加阴影
        window.hasShadow = true
        
        // 设置内容视图
        let hostingView = NSHostingView(rootView: allConfigsView)
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        
        containerView.addSubview(visualEffectView)
        containerView.addSubview(hostingView)
        
        visualEffectView.frame = containerView.bounds
        visualEffectView.autoresizingMask = [.width, .height]
        
        window.contentView = containerView
        window.center()
        window.isReleasedWhenClosed = false
        
        // 设置窗口代理来处理关闭事件
        window.delegate = self
        
        // 保存窗口引用
        allConfigurationsWindow = window
        
        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        
        // 注册通知以处理从所有配置视图打开配置编辑器的请求
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openConfigurationEditor),
            name: NSNotification.Name("OpenConfigurationEditor"),
            object: nil
        )
        
        // 注册通知以处理从所有配置视图编辑特定配置的请求
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(editConfigurationFromNotification),
            name: NSNotification.Name("EditConfiguration"),
            object: nil
        )
    }
    
    /// 显示设置窗口
    @objc func showSettings() {
        print("AppDelegate.showSettings() 被调用")
        
        // 确保 settingsWindowController 被创建并强引用
        if settingsWindowController == nil {
            print("创建新的 SettingsWindowController")
            settingsWindowController = SettingsWindowController()
        } else {
            print("使用现有的 SettingsWindowController")
        }
        
        // 使用主线程显示设置窗口，避免线程问题
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 显示设置窗口
            self.settingsWindowController?.showSettings(viewModel: self.viewModel)
        }
    }
    
    /// 从通知中打开配置编辑器
    @objc func openConfigurationEditor() {
        showConfigurationEditor(configuration: nil)
    }
    
    /// 从通知中编辑特定配置
    @objc func editConfigurationFromNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let configIdString = userInfo["configId"] as? String,
           let configId = UUID(uuidString: configIdString),
           let config = viewModel.getConfiguration(withId: configId) {
            showConfigurationEditor(configuration: config)
        }
    }
    
    // MARK: - Configuration Editor
    
    /// 显示配置编辑器
    /// - Parameter configuration: 要编辑的配置，nil 表示创建新配置
    private func showConfigurationEditor(configuration: ConfigurationModel?) {
        print("=== showConfigurationEditor called ===")
        print("Configuration: \(configuration?.name ?? "new")")
        
        // 如果已经有编辑器窗口打开，先关闭
        if let existingWindow = configurationEditorWindow {
            print("关闭现有编辑器窗口")
            existingWindow.close()
            configurationEditorWindow = nil
        }
        
        // 创建配置编辑器视图模型
        let editorViewModel = ConfigurationEditorViewModel(
            configuration: configuration,
            configurationStore: viewModel.getConfigurationStore(),
            validationService: ValidationService()
        )
        print("ConfigurationEditorViewModel 创建成功")
        
        // 创建窗口引用的绑定
        let isPresentedBinding = Binding<Bool>(
            get: { [weak self] in
                let isPresented = self?.configurationEditorWindow != nil
                print("isPresentedBinding.get: \(isPresented)")
                return isPresented
            },
            set: { [weak self] newValue in
                print("isPresentedBinding.set: \(newValue)")
                if !newValue {
                    self?.configurationEditorWindow?.close()
                    self?.configurationEditorWindow = nil
                }
            }
        )
        
        // 创建配置编辑器视图
        let editorView = ConfigurationEditorView(
            viewModel: editorViewModel,
            isPresented: isPresentedBinding
        )
        print("ConfigurationEditorView 创建成功")
        
        // 创建并配置现代化窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        print("NSWindow 创建成功")
        
        window.title = ""  // 移除系统标题，使用自定义标题
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden  // 隐藏系统标题栏
        window.isMovableByWindowBackground = true
        
        // 创建毛玻璃效果视图
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .menu
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        
        // 设置圆角
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        
        // 创建容器视图
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.masksToBounds = true
        
        // 添加阴影
        window.hasShadow = true
        
        // 设置内容视图
        let hostingView = NSHostingView(rootView: editorView)
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        
        containerView.addSubview(visualEffectView)
        containerView.addSubview(hostingView)
        
        visualEffectView.frame = containerView.bounds
        visualEffectView.autoresizingMask = [.width, .height]
        
        window.contentView = containerView
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .modalPanel
        
        // 设置窗口代理来处理关闭事件
        window.delegate = self
        
        // 保存窗口引用
        configurationEditorWindow = window
        print("窗口引用已保存: \(configurationEditorWindow != nil)")
        
        // 显示窗口
        print("正在显示窗口...")
        window.makeKeyAndOrderFront(nil)
        print("window.makeKeyAndOrderFront 调用完成")
        print("窗口可见状态: \(window.isVisible)")
        print("窗口关键状态: \(window.isKeyWindow)")
        
        // 观察编辑器的保存操作
        observeEditorViewModel(editorViewModel, window: window)
        
        print("=== showConfigurationEditor 完成 ===")
    }
    
    /// 观察编辑器视图模型的变化
    /// - Parameters:
    ///   - editorViewModel: 编辑器视图模型
    ///   - window: 编辑器窗口
    private func observeEditorViewModel(
        _ editorViewModel: ConfigurationEditorViewModel, window: NSWindow
    ) {
        // 这里可以添加观察编辑器状态变化的逻辑
        // 比如监听保存成功后自动关闭窗口等
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        // 检查是否是配置编辑器窗口
        if let window = notification.object as? NSWindow,
           window == configurationEditorWindow
        {
            // 清除窗口引用
            configurationEditorWindow = nil
        }
        
        // 检查是否是所有配置窗口
        if let window = notification.object as? NSWindow,
           window == allConfigurationsWindow
        {
            // 清除窗口引用
            allConfigurationsWindow = nil
        }
    }
    
    // Cancellables for storing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// 应用程序将要终止时调用
    func applicationWillTerminate(_ notification: Notification) {
        print("应用程序将要终止")
        
        // 清理窗口控制器引用
        if settingsWindowController != nil {
            print("清理设置窗口控制器")
            settingsWindowController = nil
        }
        
        // 清理其他窗口引用
        if configurationEditorWindow != nil {
            print("清理配置编辑器窗口")
            configurationEditorWindow = nil
        }
        
        if allConfigurationsWindow != nil {
            print("清理所有配置窗口")
            allConfigurationsWindow = nil
        }
    }
}
