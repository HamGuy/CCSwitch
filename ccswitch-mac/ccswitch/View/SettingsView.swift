

import SwiftUI
import AppKit

/// 设置视图，让用户配置应用设置
struct SettingsView: View {
    /// 应用视图模型
    @ObservedObject var viewModel: AppViewModel
    
    /// 设置服务
    private var settingsService: SettingsService {
        viewModel.getSettingsService()
    }
    
    /// Shell配置服务
    private var shellConfigService: ShellConfigService {
        viewModel.getShellConfigService()
    }
    
    /// 是否使用自定义配置文件路径
    @State private var useCustomPath: Bool = false
    
    /// 自定义配置文件路径
    @State private var customPath: String = ""
    
    /// 是否启用开机启动
    @State private var launchAtLogin: Bool = false
    
    /// 路径验证结果
    @State private var pathValidation: (isValid: Bool, error: String?) = (true, nil)
    
    /// 是否显示保存成功提示
    @State private var showingSaveSuccess: Bool = false
    
    /// 颜色定义
    private let accentColor = Color.orange
    private let inputBackgroundColor = Color(NSColor.textBackgroundColor)
    private let borderColor = Color(NSColor.separatorColor)
    private let errorColor = Color.red
    private let secondaryTextColor = Color.secondary
    
    var body: some View {
        CommonWindowView(
            title: NSLocalizedString("settings.title", comment: "Title for the settings window"),
            subtitle: NSLocalizedString("settings.subtitle", comment: "Subtitle for the settings window"),
            iconName: "EditorIcon",
            content: {
                VStack(spacing: 16) {
                    // 用户配置文件设置
                    VStack(alignment: .leading, spacing: 16) {
                        FormRow(icon: "doc.text", title: String(localized: "Shell Config")) {
                            Toggle(LocalizedStringKey("Use custom config file"), isOn: $useCustomPath)
                                .onChange(of: useCustomPath) { newValue in
                                    settingsService.useCustomShellConfigPath = newValue
                                    if !newValue {
                                        customPath = ""
                                        settingsService.customShellConfigPath = nil
                                    }
                                }
                        }
                        
                        if useCustomPath {
                            FormRow(icon: "folder", title: String(localized: "Config Path"), required: true) {
                                HStack {
                                    ValidatedTextField(
                                        placeholder: "~/.zshrc",
                                        text: $customPath,
                                        showError: !pathValidation.isValid,
                                        errorMessage: pathValidation.error,
                                        onBlur: {
                                            validatePath(customPath)
                                            if pathValidation.isValid {
                                                settingsService.customShellConfigPath = customPath
                                            }
                                        }
                                    )
                                    
                                    Button(LocalizedStringKey("Browse")) {
                                        selectConfigFile()
                                    }
                                    .commonStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // 开机启动设置
                    VStack(alignment: .leading, spacing: 16) {
                        FormRow(icon: "power", title: String(localized: "Startup")) {
                            Toggle(LocalizedStringKey("Launch at login"), isOn: $launchAtLogin)
                                .onChange(of: launchAtLogin) { newValue in
                                    do {
                                        try settingsService.toggleLaunchAtLogin()
                                        settingsService.launchAtLogin = newValue
                                    } catch {
                                        launchAtLogin = !newValue
                                        showError("Failed to set startup preference: \(error.localizedDescription)")
                                    }
                                }
                        }
                        
                        Text(LocalizedStringKey("Automatically start CCSwitch when you log in"))
                            .font(.system(size: 12))
                            .foregroundColor(secondaryTextColor)
                            .padding(.leading, 128)
                    }
                    
                    if showingSaveSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(LocalizedStringKey("Settings saved successfully"))
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        }
                        .padding(.top, 8)
                        .transition(.opacity)
                    }
                    
                    Spacer()
                }
            },
            buttons: {
                HStack {
                    Spacer()
                    
                    Button(LocalizedStringKey("Save")) {
                        saveSettings()
                    }
                    .commonStyle(.primary)
                    .keyboardShortcut(.return, modifiers: [.command])
                }
            }
        )
        .frame(width: 480, height: 320)
        .onAppear {
            loadSettings()
        }
    }
    
    /// 加载设置
    private func loadSettings() {
        useCustomPath = settingsService.useCustomShellConfigPath
        customPath = settingsService.customShellConfigPath ?? ""
        launchAtLogin = settingsService.launchAtLogin
        
        if useCustomPath {
            validatePath(customPath)
        }
    }
    
    /// 保存设置
    private func saveSettings() {
        // 保存自定义路径设置
        settingsService.useCustomShellConfigPath = useCustomPath
        if useCustomPath && pathValidation.isValid {
            settingsService.customShellConfigPath = customPath
        } else if !useCustomPath {
            settingsService.customShellConfigPath = nil
        }
        
        // 显示保存成功提示
        withAnimation {
            showingSaveSuccess = true
        }
        
        // 3秒后隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showingSaveSuccess = false
            }
        }
    }
    
    /// 验证路径
    private func validatePath(_ path: String) {
        if path.isEmpty {
            pathValidation = (false, NSLocalizedString("Path cannot be empty", comment: ""))
            return
        }
        
        // 展开路径中的波浪号
        let expandedPath = (path as NSString).expandingTildeInPath
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: expandedPath) {
            pathValidation = (false, NSLocalizedString("File does not exist", comment: ""))
        } else if !fileManager.isReadableFile(atPath: expandedPath) {
            pathValidation = (false, NSLocalizedString("File is not readable", comment: ""))
        } else {
            pathValidation = (true, nil)
        }
    }
    
    /// 选择配置文件
    private func selectConfigFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.text, .plainText]
        panel.message = NSLocalizedString("Select your Shell configuration file", comment: "")
        panel.prompt = NSLocalizedString("Select", comment: "")
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                customPath = url.path
                validatePath(url.path)
                if pathValidation.isValid {
                    settingsService.customShellConfigPath = url.path
                }
            }
        }
    }
    
    /// 显示错误信息
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Error", comment: "")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
    }
}



/// 通用窗口控制器
class CommonWindowController<Content: View>: NSObject, NSWindowDelegate {
    // 使用强引用存储窗口
    private var window: NSWindow?
    // 使用强引用存储内容视图，防止被过早释放
    private var hostingView: NSHostingView<Content>?
    private let windowTitle: String
    private let frameName: String
    private let size: CGSize
    private let contentProvider: () -> Content
    
    /// 初始化通用窗口控制器
    /// - Parameters:
    ///   - windowTitle: 窗口标题
    ///   - frameName: 窗口框架名称（用于保存窗口位置和大小）
    ///   - size: 窗口大小
    ///   - contentProvider: 内容视图提供者
    init(windowTitle: String, frameName: String, size: CGSize, contentProvider: @escaping () -> Content) {
        self.windowTitle = windowTitle
        self.frameName = frameName
        self.size = size
        self.contentProvider = contentProvider
        super.init()
        print("CommonWindowController 初始化: \(windowTitle)")
    }
    
    /// 显示窗口
    func showWindow() {
        print("CommonWindowController.showWindow() 被调用: \(windowTitle)")
        
        // 如果窗口已存在，就激活它
        if let existingWindow = window {
            print("使用现有窗口: \(windowTitle)")
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        print("创建新窗口: \(windowTitle)")
        
        // 创建内容视图
        let contentView = contentProvider()
        
        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = windowTitle
        
        // 创建 NSHostingView 并保存为强引用
        let hostingView = NSHostingView(rootView: contentView)
        self.hostingView = hostingView
        window.contentView = hostingView
        
        window.center()
        window.setFrameAutosaveName(frameName)
        
        // 设置窗口关闭时的行为
        window.isReleasedWhenClosed = false
        
        // 直接使用self作为窗口代理，避免额外的代理类
        window.delegate = self
        
        // 保存窗口的强引用
        self.window = window
        
        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        print("窗口已显示: \(windowTitle)")
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        print("windowWillClose 被调用: \(windowTitle)")
        
        // 清理窗口引用
        if let closedWindow = notification.object as? NSWindow {
            // 确保是我们的窗口
            if closedWindow == self.window {
                // 安全地移除引用
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // 移除代理引用，避免循环引用
                    closedWindow.delegate = nil
                    
                    // 清除内容视图引用
                    self.hostingView = nil
                    
                    // 清除窗口引用
                    self.window = nil
                    
                    print("窗口引用已清除: \(self.windowTitle)")
                }
            }
        }
    }
    
    // 析构函数，用于调试
    deinit {
        print("CommonWindowController 被释放: \(windowTitle)")
        
        // 确保窗口被释放
        if let window = self.window {
            window.delegate = nil
            self.window = nil
            print("在deinit中清理窗口引用: \(windowTitle)")
        }
    }
}

/// 设置窗口控制器
class SettingsWindowController: NSObject {
    // 使用强引用存储窗口控制器
    private var windowController: CommonWindowController<SettingsView>?
    
    // 使用强引用存储视图模型，防止被过早释放
    private var viewModelRef: AppViewModel?
    
    /// 显示设置窗口
    /// - Parameter viewModel: 应用视图模型
    func showSettings(viewModel: AppViewModel) {
        print("SettingsWindowController.showSettings 被调用")
        
        // 保存视图模型的强引用
        self.viewModelRef = viewModel
        
        // 如果窗口控制器不存在，创建一个新的
        if windowController == nil {
            print("创建新的 CommonWindowController")
            
            // 使用 autoreleasepool 确保内存管理正确
            autoreleasepool {
                // 创建窗口控制器
                windowController = CommonWindowController(
                    windowTitle: NSLocalizedString("CCSwitch Settings", comment: ""),
                    frameName: "SettingsWindow",
                    size: CGSize(width: 480, height: 320),
                    contentProvider: { [weak self] in
                        // 使用强引用的视图模型创建视图
                        guard let viewModel = self?.viewModelRef else {
                            // 如果视图模型不存在，创建一个空视图
                            return SettingsView(viewModel: AppViewModel())
                        }
                        return SettingsView(viewModel: viewModel)
                    }
                )
            }
        } else {
            print("使用现有的 CommonWindowController")
        }
        
        // 显示窗口
        windowController?.showWindow()
    }
    
    /// 关闭窗口
    func closeWindow() {
        print("SettingsWindowController.closeWindow 被调用")
        
        // 清理窗口控制器引用
        windowController = nil
        
        // 清理视图模型引用
        viewModelRef = nil
    }
    
    // 析构函数，用于调试
    deinit {
        print("SettingsWindowController 被释放")
        
        // 确保窗口控制器被释放
        windowController = nil
        viewModelRef = nil
    }
}

// WindowDelegate 类已移除，使用 CommonWindowController 作为窗口代理 
