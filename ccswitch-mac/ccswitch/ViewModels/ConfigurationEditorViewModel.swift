import Combine
import Foundation
import os.log

/// 配置编辑器视图模型，负责管理配置编辑界面的状态和逻辑
class ConfigurationEditorViewModel: ObservableObject {
  /// 编辑中的配置
  @Published var configuration: ConfigurationModel

  /// 验证错误信息
  @Published private(set) var validationErrors: [String] = []

  /// 是否为新配置
  let isNewConfiguration: Bool

  /// 日志对象
  private let logger = Logger(
    subsystem: "com.ccswitch.app", category: "ConfigurationEditorViewModel")

  /// 验证服务
  private let validationService: ValidationService

  /// 配置存储
  private let configurationStore: ConfigurationStore

  /// 取消令牌集合
  private var cancellables = Set<AnyCancellable>()

  /// 初始化配置编辑器视图模型
  /// - Parameters:
  ///   - configuration: 要编辑的配置，如果为 nil 则创建新配置
  ///   - configurationStore: 配置存储
  ///   - validationService: 验证服务
  init(
    configuration: ConfigurationModel? = nil,
    configurationStore: ConfigurationStore = ConfigurationStore(),
    validationService: ValidationService = ValidationService()
  ) {
    self.validationService = validationService
    self.configurationStore = configurationStore

    if let config = configuration {
      // 编辑现有配置
      self.configuration = config.copy()
      self.isNewConfiguration = false
      logger.info("正在编辑配置: \(config.name)")
    } else {
      // 创建新配置
      self.configuration = ConfigurationModel.custom(name: "", baseURL: "", token: "")
      self.isNewConfiguration = true
      logger.info("正在创建新配置")
    }

    // 设置观察者
    setupObservers()
  }

  /// 设置观察者
  private func setupObservers() {
    // 当配置类型变化时，自动更新 URL
    $configuration
      .map { $0.type }
      .removeDuplicates()
      .sink { [weak self] type in
        guard let self = self else { return }

        // 如果不是自定义类型，则使用默认 URL
        if type != .custom {
          var updatedConfig = self.configuration
          updatedConfig.baseURL = type.defaultURL
          self.configuration = updatedConfig
        }
      }
      .store(in: &cancellables)
  }

  /// 验证配置
  /// - Returns: 如果配置有效则返回 true，否则返回 false
  func validateConfiguration() -> Bool {
    logger.info("正在验证配置")

    // 使用验证服务验证配置
    let errors = validationService.validateConfiguration(configuration)

    // 更新验证错误信息
    validationErrors = validationService.getErrorDescriptions(errors)

    return validationErrors.isEmpty
  }

  /// 保存配置
  /// - Returns: 操作结果
  func saveConfiguration() -> Result<ConfigurationModel, Error> {
    logger.info("正在保存配置")

    // 验证配置
    guard validateConfiguration() else {
      let errorMessage = validationErrors.joined(separator: ", ")
      logger.error("配置验证失败: \(errorMessage)")
      return .failure(
        NSError(
          domain: "ConfigurationEditorViewModel", code: 1,
          userInfo: [NSLocalizedDescriptionKey: errorMessage]))
    }

    // 保存配置
    if isNewConfiguration {
      // 添加新配置
      return configurationStore.addConfiguration(configuration).mapError { $0 as Error }
    } else {
      // 更新现有配置
      return configurationStore.updateConfiguration(configuration).mapError { $0 as Error }
    }
  }

  /// 删除配置
  /// - Returns: 操作结果，成功返回 true，失败返回 false 和错误信息
  func deleteConfiguration() -> (success: Bool, errorMessage: String?) {
      logger.info("正在删除配置: \(self.configuration.name)")

    // 检查是否为预设配置
    if !configuration.isCustom {
      let errorMessage = "不能删除预设配置"
      logger.error("\(errorMessage)")
      return (false, errorMessage)
    }

    // 删除配置
    let result = configurationStore.deleteConfiguration(configuration)

    switch result {
    case .success:
      logger.info("配置删除成功")
      return (true, nil)
    case .failure(let error):
      let errorMessage: String
      switch error {
      case .invalidConfiguration(let message):
        errorMessage = message
      case .configurationNotFound(let message):
        errorMessage = message
      default:
        errorMessage = "删除配置失败: \(error)"
      }
      logger.error("\(errorMessage)")
      return (false, errorMessage)
    }
  }

  /// 检查配置是否可以删除
  /// - Returns: 如果配置可以删除则返回 true，否则返回 false
  func canDeleteConfiguration() -> Bool {
    // 只有自定义配置可以删除
    return configuration.isCustom
  }

  /// 更新配置名称
  /// - Parameter name: 新的配置名称
  func updateName(_ name: String) {
    var updatedConfig = configuration
    updatedConfig.name = name
    configuration = updatedConfig
  }

  /// 更新配置类型
  /// - Parameter type: 新的配置类型
  func updateType(_ type: ConfigurationModel.ConfigurationType) {
    var updatedConfig = configuration
    updatedConfig.type = type

    // 如果不是自定义类型，则使用默认 URL
    if type != .custom {
      updatedConfig.baseURL = type.defaultURL
    }

    configuration = updatedConfig
  }

  /// 更新配置 URL
  /// - Parameter url: 新的配置 URL
  func updateURL(_ url: String) {
    var updatedConfig = configuration
    updatedConfig.baseURL = url
    configuration = updatedConfig
  }

  /// 更新配置 Token
  /// - Parameter token: 新的配置 Token
  func updateToken(_ token: String) {
    var updatedConfig = configuration
    updatedConfig.token = token
    configuration = updatedConfig
  }

  /// 重置编辑器
  func reset() {
    if isNewConfiguration {
      // 重置为空白自定义配置
      configuration = ConfigurationModel.custom(name: "", baseURL: "", token: "")
    } else {
      // 重置为原始配置
      if let originalConfig = configurationStore.getConfiguration(withId: configuration.id) {
        configuration = originalConfig.copy()
      }
    }

    // 清除验证错误
    validationErrors = []
  }

  /// 检查配置是否已更改
  /// - Returns: 如果配置已更改则返回 true，否则返回 false
  func hasChanges() -> Bool {
    if isNewConfiguration {
      // 新配置，检查是否填写了必要信息
      return !configuration.name.isEmpty || !configuration.baseURL.isEmpty
        || !configuration.token.isEmpty
    } else {
      // 现有配置，检查是否与原始配置不同
      if let originalConfig = configurationStore.getConfiguration(withId: configuration.id) {
        return configuration.name != originalConfig.name
          || configuration.baseURL != originalConfig.baseURL
          || configuration.token != originalConfig.token
          || configuration.type != originalConfig.type
      }
      return false
    }
  }
}
