import Combine
import Foundation
import os.log
import AppKit

/// 应用视图模型错误类型
enum AppViewModelError: Error, LocalizedError {
  /// 配置切换失败
  case configurationSwitchFailed(String)
  /// 配置更新失败
  case configurationUpdateFailed(String)
  /// 配置删除失败
  case configurationDeleteFailed(String)
  /// 重置失败
  case resetFailed(String)
  /// 环境变量更新失败
  case environmentUpdateFailed(String)
  /// Shell 配置更新失败
  case shellConfigUpdateFailed(String)

  var errorDescription: String? {
    switch self {
    case .configurationSwitchFailed(let message):
      return "配置切换失败: \(message)"
    case .configurationUpdateFailed(let message):
      return "配置更新失败: \(message)"
    case .configurationDeleteFailed(let message):
      return "配置删除失败: \(message)"
    case .resetFailed(let message):
      return "重置失败: \(message)"
    case .environmentUpdateFailed(let message):
      return "环境变量更新失败: \(message)"
    case .shellConfigUpdateFailed(let message):
      return "Shell 配置更新失败: \(message)"
    }
  }
}

/// 应用状态枚举
enum AppState {
  /// 空闲状态
  case idle
  /// 加载中状态
  case loading
  /// 成功状态
  case success(String)
  /// 错误状态
  case error(Error)
}

/// 应用的主视图模型，管理应用状态和业务逻辑
class AppViewModel: ObservableObject {
  /// 所有配置列表
  @Published private(set) var configurations: [ConfigurationModel] = []

  /// 当前活动配置
  @Published private(set) var activeConfiguration: ConfigurationModel?

  /// 应用状态
  @Published private(set) var appState: AppState = .idle

  /// 预设配置列表
  @Published private(set) var presetConfigurations: [ConfigurationModel] = []

  /// 自定义配置列表
  @Published private(set) var customConfigurations: [ConfigurationModel] = []

  /// 日志对象
  private let logger = Logger(subsystem: "com.ccswitch.app", category: "AppViewModel")

  /// 配置存储
  private let configurationStore: ConfigurationStore

  /// 环境变量服务
  private let environmentService: EnvironmentService

  /// Shell 配置服务
  private let shellConfigService: ShellConfigService

  /// 验证服务
  private let validationService: ValidationService

  /// 通知服务
  private let notificationService: NotificationService
  
  /// 设置服务
  private let settingsService: SettingsService

  /// 取消令牌集合
  private var cancellables = Set<AnyCancellable>()

  /// 初始化应用视图模型
  /// - Parameters:
  ///   - configurationStore: 配置存储
  ///   - environmentService: 环境变量服务
  ///   - shellConfigService: Shell 配置服务
  ///   - validationService: 验证服务
  ///   - notificationService: 通知服务
  ///   - settingsService: 设置服务
  init(
    configurationStore: ConfigurationStore = ConfigurationStore(),
    environmentService: EnvironmentService = EnvironmentService(),
    shellConfigService: ShellConfigService? = nil,
    validationService: ValidationService = ValidationService(),
    notificationService: NotificationService = NotificationService(),
    settingsService: SettingsService = SettingsService()
  ) {
    self.configurationStore = configurationStore
    self.environmentService = environmentService
    self.validationService = validationService
    self.notificationService = notificationService
    self.settingsService = settingsService
    
    // 创建Shell配置服务，传入设置服务
    self.shellConfigService = shellConfigService ?? ShellConfigService(settingsService: settingsService)

    logger.info("应用视图模型已初始化")
    
    // 设置 Shell 配置服务的权限请求处理器
    setupPermissionHandler()

    // 设置观察者
    setupObservers()

    // 加载配置
    loadConfigurations()
  }
  
  /// 设置权限请求处理器
  private func setupPermissionHandler() {
    shellConfigService.setPermissionHandler { [weak self] message, completion in
      guard let self = self else {
        completion(false)
        return
      }
      
      // 在主线程显示权限请求对话框
      DispatchQueue.main.async {
        // 确保应用图标已设置
        self.ensureAppIconIsSet()
        
        let alert = NSAlert()
        alert.messageText = "需要权限"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "允许")
        alert.addButton(withTitle: "拒绝")
        
        // 设置应用图标
        self.setAlertIcon(alert)
        
        let response = alert.runModal()
        let granted = response == .alertFirstButtonReturn
        
        self.logger.info("用户\(granted ? "授予" : "拒绝")了权限请求")
        completion(granted)
      }
    }
  }
  
  // MARK: - 图标设置方法
  
  /// 设置 NSAlert 的应用图标
  private func setAlertIcon(_ alert: NSAlert) {
    // 直接尝试加载EditorIcon
    if let editIcon = NSImage(named: "EditorIcon") {
      alert.icon = editIcon
      return
    }
    
    // 备选方案
    if let appIcon = NSApp.applicationIconImage {
      alert.icon = appIcon
    } else if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
              let icon = NSImage(contentsOfFile: iconPath) {
      alert.icon = icon
    } else if let icon = NSImage(named: "AppIcon") {
      alert.icon = icon
    } else {
      // 使用默认的应用图标
      alert.icon = NSImage(named: NSImage.applicationIconName)
    }
  }
  
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

  /// 设置观察者
  private func setupObservers() {
    // 观察配置存储的变化
    configurationStore.$configurations
      .sink { [weak self] configurations in
        guard let self = self else { return }
        self.configurations = configurations
        self.updateConfigurationLists()
      }
      .store(in: &cancellables)

    configurationStore.$activeConfiguration
      .sink { [weak self] configuration in
        guard let self = self else { return }
        self.activeConfiguration = configuration
      }
      .store(in: &cancellables)
  }

  /// 更新配置列表
  private func updateConfigurationLists() {
    presetConfigurations = configurations.filter { !$0.isCustom }
    customConfigurations = configurations.filter { $0.isCustom }
    
    // 配置列表更新日志
    print("配置列表已更新 - 总数: \(configurations.count), 预设: \(presetConfigurations.count), 自定义: \(customConfigurations.count)")
    
    // 发送配置变更通知，确保菜单更新
    DispatchQueue.main.async {
      NotificationCenter.default.post(
        name: NSNotification.Name("ConfigurationsDidChange"),
        object: nil
      )
    }
  }

  /// 加载所有配置
  func loadConfigurations() {
    logger.info("正在加载配置")

    appState = .loading

    do {
      // 从配置存储加载配置
      try configurationStore.loadConfigurations()
      
      // 强制同步更新配置列表
      self.configurations = configurationStore.configurations
      
      // 更新预设和自定义配置列表
      updateConfigurationLists()

      // 检查是否有活动配置
      if activeConfiguration == nil {
        logger.warning("没有找到活动配置")

        // 如果有任何配置，设置第一个为活动配置
        if !self.configurations.isEmpty {
          logger.info("设置第一个配置为活动配置: \(self.configurations[0].name)")
          _ = switchToConfiguration(self.configurations[0])
        } else {
          logger.info("没有任何配置，需要创建默认配置")
          // 只有在完全没有配置时才创建默认配置
//          _ = resetToDefault()
        }
      } else {
        logger.info("已加载活动配置: \(self.activeConfiguration!.name)")

        // 确保环境变量与当前活动配置一致
        syncEnvironmentWithActiveConfiguration()
      }   


      // 更新配置列表
      updateConfigurationLists()

      appState = .success("配置加载成功")
    } catch {
      logger.error("加载配置失败: \(error.localizedDescription)")
      appState = .error(error)

      // 尝试恢复默认配置
      _ = resetToDefault()
    }
  }

  // 用于防止频繁同步的节流控制
  private var syncWorkItem: DispatchWorkItem?
  private let syncThrottleInterval: TimeInterval = 0.5 // 500毫秒节流间隔
  
  // 缓存最近的环境变量值，避免重复更新
  private var lastSyncedBaseURL: String?
  private var lastSyncedToken: String?
  
  /// 同步环境变量与当前活动配置，使用节流控制避免频繁更新
  private func syncEnvironmentWithActiveConfiguration() {
    guard let activeConfig = activeConfiguration else { return }

    logger.info("同步环境变量与当前活动配置: \(activeConfig.name)")
    
    // 检查是否与上次同步的值相同，如果相同则跳过更新
    if activeConfig.baseURL == lastSyncedBaseURL && activeConfig.token == lastSyncedToken {
        logger.info("环境变量未变化，跳过同步")
        return
    }
    
    // 更新缓存
    lastSyncedBaseURL = activeConfig.baseURL
    lastSyncedToken = activeConfig.token

    // 立即在当前进程中设置环境变量，确保快速响应
    setenv("ANTHROPIC_BASE_URL", activeConfig.baseURL, 1)
    setenv("ANTHROPIC_AUTH_TOKEN", activeConfig.token, 1)
    
    // 取消之前的同步任务
    syncWorkItem?.cancel()
    
    // 创建新的同步任务
    let workItem = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        
        // 获取当前环境变量
        let currentEnv = self.environmentService.getCurrentEnvironmentVariables()

        // 如果环境变量与当前配置不一致，更新环境变量
        if currentEnv.baseURL != activeConfig.baseURL || currentEnv.token != activeConfig.token {
            self.logger.info("环境变量与当前配置不一致，正在更新环境变量")

            // 使用并发队列和操作组来并行执行多个更新任务
            let group = DispatchGroup()
            let queue = DispatchQueue.global(qos: .userInitiated)
            
            // 任务1: 更新环境变量
            group.enter()
            queue.async {
                let envResult = self.environmentService.updateEnvironmentVariables(
                    baseURL: activeConfig.baseURL,
                    token: activeConfig.token
                )

                if case .failure(let error) = envResult {
                    self.logger.error("环境变量更新失败: \(error.localizedDescription)")
                }
                group.leave()
            }
            
            // 任务2: 更新 Shell 配置文件
            group.enter()
            queue.async {
                let shellResult = self.shellConfigService.updateShellConfig(
                    baseURL: activeConfig.baseURL,
                    token: activeConfig.token
                )

                if case .failure(let error) = shellResult {
                    self.logger.error("Shell 配置更新失败: \(error.localizedDescription)")
                }
                group.leave()
            }
            
            // 等待所有任务完成，设置超时以避免无限等待
            let timeout = DispatchTime.now() + 2.0 // 2秒超时
            if group.wait(timeout: timeout) == .timedOut {
                self.logger.warning("环境变量更新操作超时")
            }
            
            // 尝试使环境变量立即生效
            _ = self.shellConfigService.sourceShellConfig()

            // 直接设置环境变量，确保在当前进程和子进程中立即生效
            _ = self.shellConfigService.setEnvironmentVariablesDirectly(
                baseURL: activeConfig.baseURL,
                token: activeConfig.token
            )
        }
    }
    
    // 保存引用以便后续可以取消
    syncWorkItem = workItem
    
    // 延迟执行，实现节流效果
    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + syncThrottleInterval, execute: workItem)
  }

  // 用于防止频繁切换的节流控制
  private var switchWorkItem: DispatchWorkItem?
  private let switchThrottleInterval: TimeInterval = 0.2 // 200毫秒节流间隔
  
  /// 切换到指定配置
  /// - Parameter configuration: 要切换到的配置
  /// - Returns: 操作结果
  @discardableResult
  func switchToConfiguration(_ configuration: ConfigurationModel) -> Result<
    ConfigurationModel, AppViewModelError
  > {
    logger.info("正在切换到配置: \(configuration.name)")

    // 检查是否与当前活动配置相同，如果相同则跳过切换
    if let activeConfig = activeConfiguration, 
       activeConfig.id == configuration.id,
       activeConfig.baseURL == configuration.baseURL,
       activeConfig.token == configuration.token {
        logger.info("配置未变化，跳过切换")
        return .success(configuration)
    }

    appState = .loading

    // 验证配置 - 这是轻量级操作，在主线程执行
    let validationErrors = validationService.validateConfiguration(configuration)
    if !validationErrors.isEmpty {
      let errorMessage = validationService.getErrorDescriptions(validationErrors).joined(
        separator: ", ")
      logger.error("配置验证失败: \(errorMessage)")

      let error = AppViewModelError.configurationSwitchFailed(errorMessage)
      appState = .error(error)

      // 发送配置切换失败通知
      notificationService.sendConfigurationSwitchFailedNotification(error: error)

      return .failure(error)
    }

    // 立即设置活动配置，提高UI响应性
    let storeResult = configurationStore.setActiveConfiguration(configuration)

    if case .failure(let error) = storeResult {
      logger.error("设置活动配置失败: \(error.localizedDescription)")

      appState = .error(AppViewModelError.configurationSwitchFailed(error.localizedDescription))
      return .failure(.configurationSwitchFailed(error.localizedDescription))
    }

    // 立即在当前进程中设置环境变量，确保快速响应
    setenv("ANTHROPIC_BASE_URL", configuration.baseURL, 1)
    setenv("ANTHROPIC_AUTH_TOKEN", configuration.token, 1)
    
    // 打印确认环境变量已在当前进程中设置
    logger.info("当前进程环境变量已设置: ANTHROPIC_BASE_URL=\(configuration.baseURL)")
    logger.info("当前进程环境变量已设置: ANTHROPIC_AUTH_TOKEN=***")
    
    // 强制刷新当前进程环境变量
    print("=== 配置切换调试信息 ===")
    print("切换到配置: \(configuration.name)")
    print("目标 BASE_URL: \(configuration.baseURL)")
    print("目标 TOKEN: \(configuration.token.isEmpty ? "空" : "***")")
    
    // 立即验证环境变量是否设置成功
    let immediateBaseURL = ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"]
    let immediateToken = ProcessInfo.processInfo.environment["ANTHROPIC_AUTH_TOKEN"]
    print("立即验证 - BASE_URL: \(immediateBaseURL ?? "nil")")
    print("立即验证 - TOKEN: \(immediateToken == nil ? "nil" : "***")")
    
    // 使用getenv直接检查
    if let envURL = getenv("ANTHROPIC_BASE_URL") {
        let urlString = String(cString: envURL)
        print("getenv 检查 - BASE_URL: \(urlString)")
    } else {
        print("getenv 检查 - BASE_URL: nil")
    }
    
    // 立即调用环境变量服务更新环境变量（同步调用以确保立即生效）
    let envResult = environmentService.updateEnvironmentVariables(
      baseURL: configuration.baseURL,
      token: configuration.token
    )
    
    if case .failure(let error) = envResult {
      logger.warning("环境变量服务更新失败: \(error.localizedDescription)")
      // 不阻断流程，因为当前进程的环境变量已经设置
    }
    
    // 立即尝试直接设置环境变量，确保在当前进程和子进程中立即生效
    let directResult = shellConfigService.setEnvironmentVariablesDirectly(
      baseURL: configuration.baseURL,
      token: configuration.token
    )
    
    if case .failure(let error) = directResult {
      logger.warning("直接设置环境变量失败: \(error.localizedDescription)")
      // 不阻断流程，因为当前进程的环境变量已经设置
    }
    
    // 更新同步缓存，避免后续不必要的同步
    lastSyncedBaseURL = configuration.baseURL
    lastSyncedToken = configuration.token

    // 验证环境变量是否已正确设置
    let currentBaseURL = ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"]
    let currentToken = ProcessInfo.processInfo.environment["ANTHROPIC_AUTH_TOKEN"]
    
    if currentBaseURL == configuration.baseURL && currentToken == configuration.token {
      logger.info("环境变量验证成功 - 已正确设置")
    } else {
      logger.warning("环境变量验证失败 - 预期: \(configuration.baseURL), 实际: \(currentBaseURL ?? "nil")")
      // 再次尝试设置
      setenv("ANTHROPIC_BASE_URL", configuration.baseURL, 1)
      setenv("ANTHROPIC_AUTH_TOKEN", configuration.token, 1)
    }

    // 更新UI状态为成功
    appState = .success("已切换到配置: \(configuration.name)")
    
    // 取消之前的切换任务
    switchWorkItem?.cancel()
    
    // 创建新的后台任务，用于更新Shell配置文件（非关键任务）
    let workItem = DispatchWorkItem { [weak self] in
      guard let self = self else { return }
      
      // 更新 Shell 配置文件（这是为了让新的终端会话也能使用正确的环境变量）
      let shellResult = self.shellConfigService.updateShellConfig(
        baseURL: configuration.baseURL,
        token: configuration.token
      )

      // 在主线程发送通知
      DispatchQueue.main.async {
        if case .failure(let error) = shellResult {
          self.logger.error("Shell 配置更新失败: \(error.localizedDescription)")
          let appError = AppViewModelError.shellConfigUpdateFailed(error.localizedDescription)
          // 发送 Shell 配置更新失败通知
          self.notificationService.sendErrorNotification(title: "Shell 配置更新失败", error: appError)
        } else {
          self.logger.info("Shell 配置文件更新成功")
          // 发送配置切换成功通知（在 Shell 配置更新成功后）
          self.notificationService.sendConfigurationSwitchSuccessNotification(configName: configuration.name)
        }
      }
      
      // 尝试使环境变量在新终端中生效
      let sourceResult = self.shellConfigService.sourceShellConfig()
      
      if case .failure(let error) = sourceResult {
        self.logger.error("执行 Shell 配置文件失败: \(error.localizedDescription)")
        // 不发送错误通知，因为这不是关键错误
      }
    }
    
    // 保存引用以便后续可以取消
    switchWorkItem = workItem
    
    // 延迟执行，实现节流效果
    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + switchThrottleInterval, execute: workItem)

    return .success(configuration)
  }

  /// 添加新配置
  /// - Parameter configuration: 要添加的配置
  /// - Returns: 操作结果
  @discardableResult
  func addConfiguration(_ configuration: ConfigurationModel) -> Result<
    ConfigurationModel, AppViewModelError
  > {
    logger.info("正在添加新配置: \(configuration.name)")

    appState = .loading

    // 验证配置 - 这是轻量级操作，在主线程执行
    let validationErrors = validationService.validateConfiguration(configuration)
    if !validationErrors.isEmpty {
      let errorMessage = validationService.getErrorDescriptions(validationErrors).joined(
        separator: ", ")
      logger.error("配置验证失败: \(errorMessage)")

      appState = .error(AppViewModelError.configurationUpdateFailed(errorMessage))
      return .failure(.configurationUpdateFailed(errorMessage))
    }

    // 添加配置 - 这个操作已经在 ConfigurationStore 中被优化为异步
    let result = configurationStore.addConfiguration(configuration)

    switch result {
    case .success(let config):
      logger.info("配置添加成功: \(config.name)")
      appState = .success("配置添加成功: \(config.name)")
      return .success(config)

    case .failure(let error):
      logger.error("配置添加失败: \(error.localizedDescription)")
      appState = .error(AppViewModelError.configurationUpdateFailed(error.localizedDescription))
      return .failure(.configurationUpdateFailed(error.localizedDescription))
    }
  }

  /// 更新配置
  /// - Parameter configuration: 要更新的配置
  /// - Returns: 操作结果
  @discardableResult
  func updateConfiguration(_ configuration: ConfigurationModel) -> Result<
    ConfigurationModel, AppViewModelError
  > {
    logger.info("正在更新配置: \(configuration.name)")

    appState = .loading

    // 验证配置
    let validationErrors = validationService.validateConfiguration(configuration)
    if !validationErrors.isEmpty {
      let errorMessage = validationService.getErrorDescriptions(validationErrors).joined(
        separator: ", ")
      logger.error("配置验证失败: \(errorMessage)")

      appState = .error(AppViewModelError.configurationUpdateFailed(errorMessage))
      return .failure(.configurationUpdateFailed(errorMessage))
    }

    // 更新配置
    let result = configurationStore.updateConfiguration(configuration)

    switch result {
    case .success(let config):
      logger.info("配置更新成功: \(config.name)")

      // 如果更新的是当前活动配置，则需要更新环境变量
      if config.isActive {
        _ = switchToConfiguration(config)
      }

      appState = .success("配置更新成功: \(config.name)")
      return .success(config)

    case .failure(let error):
      logger.error("配置更新失败: \(error.localizedDescription)")
      appState = .error(AppViewModelError.configurationUpdateFailed(error.localizedDescription))
      return .failure(.configurationUpdateFailed(error.localizedDescription))
    }
  }

  /// 删除配置
  /// - Parameter configuration: 要删除的配置
  /// - Returns: 操作结果
  @discardableResult
  func deleteConfiguration(_ configuration: ConfigurationModel) -> Result<Void, AppViewModelError> {
    logger.info("正在删除配置: \(configuration.name)")

    appState = .loading

    // 不允许删除预设配置
    if !configuration.isCustom {
      let errorMessage = "不能删除预设配置"

      logger.error("\(errorMessage)")

      appState = .error(AppViewModelError.configurationDeleteFailed(errorMessage))
      return .failure(.configurationDeleteFailed(errorMessage))
    }

    // 删除配置
    let result = configurationStore.deleteConfiguration(configuration)

    switch result {
    case .success:
      logger.info("配置删除成功: \(configuration.name)")
      appState = .success("配置删除成功: \(configuration.name)")
      return .success(())

    case .failure(let error):
      logger.error("配置删除失败: \(error.localizedDescription)")
      appState = .error(AppViewModelError.configurationDeleteFailed(error.localizedDescription))
      return .failure(.configurationDeleteFailed(error.localizedDescription))
    }
  }

  // 用于防止频繁重置的节流控制
  private var resetWorkItem: DispatchWorkItem?
  private let resetThrottleInterval: TimeInterval = 0.2 // 200毫秒节流间隔
  
  /// 重置为官方默认配置
  /// - Returns: 操作结果
  @discardableResult
  func resetToDefault() -> Result<ConfigurationModel, AppViewModelError> {
    logger.info("正在重置为官方默认配置")

    appState = .loading

    // 重置为官方默认配置
    let result = configurationStore.resetToDefault()

    switch result {
    case .success(let config):
      logger.info("重置为官方默认配置成功")

      // 立即在当前进程中设置环境变量，确保快速响应
      setenv("ANTHROPIC_BASE_URL", config.baseURL, 1)
      setenv("ANTHROPIC_AUTH_TOKEN", config.token, 1)
      
      // 更新同步缓存，避免后续不必要的同步
      lastSyncedBaseURL = config.baseURL
      lastSyncedToken = config.token

      // 更新UI状态为成功
      appState = .success("已重置为官方默认配置")

      // 发送重置成功通知
      notificationService.sendResetSuccessNotification()
      
      // 取消之前的重置任务
      resetWorkItem?.cancel()
      
      // 创建新的重置任务
      let workItem = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        
        // 使用并发队列和操作组来并行执行多个更新任务
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        // 任务1: 更新环境变量
        group.enter()
        queue.async {
          let envResult = self.environmentService.updateEnvironmentVariables(
            baseURL: config.baseURL,
            token: config.token
          )

          if case .failure(let error) = envResult {
            self.logger.error("环境变量更新失败: \(error.localizedDescription)")

            // 在主线程发送通知
            DispatchQueue.main.async {
              let appError = AppViewModelError.environmentUpdateFailed(error.localizedDescription)
              // 不更新appState，因为我们已经显示了成功状态

              // 发送环境变量更新失败通知
              self.notificationService.sendErrorNotification(title: "环境变量更新失败", error: appError)
            }
          }
          group.leave()
        }

        // 任务2: 更新 Shell 配置文件
        group.enter()
        queue.async {
          let shellResult = self.shellConfigService.updateShellConfig(
            baseURL: config.baseURL,
            token: config.token
          )

          if case .failure(let error) = shellResult {
            self.logger.error("Shell 配置更新失败: \(error.localizedDescription)")

            // 在主线程发送通知
            DispatchQueue.main.async {
              let appError = AppViewModelError.shellConfigUpdateFailed(error.localizedDescription)
              // 不更新appState，因为我们已经显示了成功状态

              // 发送 Shell 配置更新失败通知
              self.notificationService.sendErrorNotification(title: "Shell 配置更新失败", error: appError)
            }
          }
          group.leave()
        }
        
        // 等待所有任务完成，设置超时以避免无限等待
        let timeout = DispatchTime.now() + 2.0 // 2秒超时
        if group.wait(timeout: timeout) == .timedOut {
          self.logger.warning("重置操作超时")
        }

        // 尝试使环境变量立即生效 - 这些操作可能比较耗时，但不影响UI响应
        _ = self.shellConfigService.sourceShellConfig()

        // 直接设置环境变量，确保在当前进程和子进程中立即生效
        _ = self.shellConfigService.setEnvironmentVariablesDirectly(
          baseURL: config.baseURL,
          token: config.token
        )
      }
      
      // 保存引用以便后续可以取消
      resetWorkItem = workItem
      
      // 延迟执行，实现节流效果
      DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + resetThrottleInterval, execute: workItem)

      return .success(config)

    case .failure(let error):
      logger.error("重置为官方默认配置失败: \(error.localizedDescription)")

      let appError = AppViewModelError.resetFailed(error.localizedDescription)
      appState = .error(appError)

      // 发送重置失败通知
      notificationService.sendResetFailedNotification(error: appError)

      return .failure(appError)
    }
  }

  /// 获取配置列表
  /// - Parameter type: 配置类型，nil 表示所有配置
  /// - Returns: 配置列表
  func getConfigurations(ofType type: ConfigurationModel.ConfigurationType? = nil)
    -> [ConfigurationModel]
  {
    if let type = type {
      return configurations.filter { $0.type == type }
    } else {
      return configurations
    }
  }

  /// 获取指定 ID 的配置
  /// - Parameter id: 配置 ID
  /// - Returns: 指定 ID 的配置，如果不存在则返回 nil
  func getConfiguration(withId id: UUID) -> ConfigurationModel? {
    configurations.first { $0.id == id }
  }

  /// 清除当前状态
  func clearState() {
    appState = .idle
  }

  /// 获取环境变量服务
  /// - Returns: 环境变量服务实例
  func getEnvironmentService() -> EnvironmentService {
    return environmentService
  }

  /// 获取 Shell 配置服务
  /// - Returns: Shell 配置服务实例
  func getShellConfigService() -> ShellConfigService {
    return shellConfigService
  }

  /// 获取通知服务
  /// - Returns: 通知服务实例
  func getNotificationService() -> NotificationService {
    return notificationService
  }
  
  /// 获取配置存储
  /// - Returns: 配置存储实例
  func getConfigurationStore() -> ConfigurationStore {
    return configurationStore
  }
  
  /// 获取设置服务
  /// - Returns: 设置服务实例
  func getSettingsService() -> SettingsService {
    return settingsService
  }
}
