import XCTest
@testable import ccswitch

final class AppViewModelTests: XCTestCase {
    
    var appViewModel: AppViewModel!
    var mockConfigStore: MockConfigurationStore!
    var mockEnvService: MockEnvironmentService!
    var mockShellService: MockShellConfigService!
    var mockValidationService: MockValidationService!
    var mockNotificationService: MockNotificationService!
    
    override func setUp() {
        super.setUp()
        mockConfigStore = MockConfigurationStore()
        mockEnvService = MockEnvironmentService()
        mockShellService = MockShellConfigService()
        mockValidationService = MockValidationService()
        mockNotificationService = MockNotificationService()
        
        appViewModel = AppViewModel(
            configurationStore: mockConfigStore,
            environmentService: mockEnvService,
            shellConfigService: mockShellService,
            validationService: mockValidationService,
            notificationService: mockNotificationService
        )
    }
    
    override func tearDown() {
        appViewModel = nil
        mockConfigStore = nil
        mockEnvService = nil
        mockShellService = nil
        mockValidationService = nil
        mockNotificationService = nil
        super.tearDown()
    }
    
    // 测试加载配置
    func testLoadConfigurations() {
        // 设置 mock 数据
        let config1 = ConfigurationModel.preset(type: .gaccode)
        let config2 = ConfigurationModel.preset(type: .anyrouter)
        let activeConfig = ConfigurationModel.official().activated()
        
        mockConfigStore.configurations = [config1, config2, activeConfig]
        mockConfigStore.activeConfiguration = activeConfig
        
        // 执行加载
        appViewModel.loadConfigurations()
        
        // 验证结果
        XCTAssertEqual(appViewModel.configurations.count, 3)
        XCTAssertEqual(appViewModel.activeConfiguration, activeConfig)
        XCTAssertEqual(appViewModel.presetConfigurations.count, 3) // 所有配置都是预设的
        XCTAssertEqual(appViewModel.customConfigurations.count, 0) // 没有自定义配置
        
        // 验证环境变量同步
        XCTAssertTrue(mockEnvService.updateEnvironmentVariablesCalled)
        XCTAssertEqual(mockEnvService.lastBaseURL, activeConfig.baseURL)
        XCTAssertEqual(mockEnvService.lastToken, activeConfig.token)
    }
    
    // 测试切换配置
    func testSwitchToConfiguration() {
        // 设置 mock 数据
        let config = ConfigurationModel.preset(type: .gaccode, token: "sk-test123")
        mockValidationService.validationResult = []  // 没有验证错误
        
        // 执行切换
        let result = appViewModel.switchToConfiguration(config)
        
        // 验证结果
        switch result {
        case .success(let resultConfig):
            XCTAssertEqual(resultConfig, config)
        case .failure(let error):
            XCTFail("切换配置失败: \(error.localizedDescription)")
        }
        
        // 验证环境变量更新
        XCTAssertTrue(mockEnvService.updateEnvironmentVariablesCalled)
        XCTAssertEqual(mockEnvService.lastBaseURL, config.baseURL)
        XCTAssertEqual(mockEnvService.lastToken, config.token)
        
        // 验证 Shell 配置更新
        XCTAssertTrue(mockShellService.updateShellConfigCalled)
        XCTAssertEqual(mockShellService.lastBaseURL, config.baseURL)
        XCTAssertEqual(mockShellService.lastToken, config.token)
        
        // 验证配置存储更新
        XCTAssertTrue(mockConfigStore.setActiveConfigurationCalled)
        XCTAssertEqual(mockConfigStore.lastActiveConfig, config)
        
        // 验证通知发送
        XCTAssertTrue(mockNotificationService.sendConfigurationSwitchSuccessCalled)
        XCTAssertEqual(mockNotificationService.lastConfigName, config.name)
    }
    
    // 测试切换配置失败 - 验证错误
    func testSwitchToConfigurationValidationFailure() {
        // 设置 mock 数据
        let config = ConfigurationModel.preset(type: .gaccode, token: "invalid-token")
        mockValidationService.validationResult = [ValidationError.invalidTokenFormat]  // 设置验证错误
        
        // 执行切换
        let result = appViewModel.switchToConfiguration(config)
        
        // 验证结果
        switch result {
        case .success:
            XCTFail("验证应该失败")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("配置切换失败"))
        }
        
        // 验证环境变量未更新
        XCTAssertFalse(mockEnvService.updateEnvironmentVariablesCalled)
        
        // 验证 Shell 配置未更新
        XCTAssertFalse(mockShellService.updateShellConfigCalled)
        
        // 验证配置存储未更新
        XCTAssertFalse(mockConfigStore.setActiveConfigurationCalled)
        
        // 验证失败通知发送
        XCTAssertTrue(mockNotificationService.sendConfigurationSwitchFailedCalled)
    }
    
    // 测试添加配置
    func testAddConfiguration() {
        // 设置 mock 数据
        let config = ConfigurationModel.custom(
            name: "Test Custom",
            baseURL: "https://test.api.com",
            token: "sk-test123"
        )
        mockValidationService.validationResult = []  // 没有验证错误
        mockConfigStore.addConfigurationResult = .success(config)
        
        // 执行添加
        let result = appViewModel.addConfiguration(config)
        
        // 验证结果
        switch result {
        case .success(let resultConfig):
            XCTAssertEqual(resultConfig, config)
        case .failure(let error):
            XCTFail("添加配置失败: \(error.localizedDescription)")
        }
        
        // 验证配置存储更新
        XCTAssertTrue(mockConfigStore.addConfigurationCalled)
        XCTAssertEqual(mockConfigStore.lastAddedConfig, config)
    }
    
    // 测试更新配置
    func testUpdateConfiguration() {
        // 设置 mock 数据
        let config = ConfigurationModel.preset(type: .gaccode, token: "sk-updated")
        mockValidationService.validationResult = []  // 没有验证错误
        mockConfigStore.updateConfigurationResult = .success(config)
        
        // 执行更新
        let result = appViewModel.updateConfiguration(config)
        
        // 验证结果
        switch result {
        case .success(let resultConfig):
            XCTAssertEqual(resultConfig, config)
        case .failure(let error):
            XCTFail("更新配置失败: \(error.localizedDescription)")
        }
        
        // 验证配置存储更新
        XCTAssertTrue(mockConfigStore.updateConfigurationCalled)
        XCTAssertEqual(mockConfigStore.lastUpdatedConfig, config)
    }
    
    // 测试删除配置
    func testDeleteConfiguration() {
        // 设置 mock 数据
        let config = ConfigurationModel.custom(
            name: "Test Custom",
            baseURL: "https://test.api.com",
            token: "sk-test123"
        )
        mockConfigStore.deleteConfigurationResult = .success(())
        
        // 执行删除
        let result = appViewModel.deleteConfiguration(config)
        
        // 验证结果
        switch result {
        case .success:
            // 删除成功
            break
        case .failure(let error):
            XCTFail("删除配置失败: \(error.localizedDescription)")
        }
        
        // 验证配置存储更新
        XCTAssertTrue(mockConfigStore.deleteConfigurationCalled)
        XCTAssertEqual(mockConfigStore.lastDeletedConfig, config)
    }
    
    // 测试重置为默认配置
    func testResetToDefault() {
        // 设置 mock 数据
        let officialConfig = ConfigurationModel.official()
        mockConfigStore.resetToDefaultResult = .success(officialConfig)
        
        // 执行重置
        let result = appViewModel.resetToDefault()
        
        // 验证结果
        switch result {
        case .success(let resultConfig):
            XCTAssertEqual(resultConfig.type, .official)
        case .failure(let error):
            XCTFail("重置为默认配置失败: \(error.localizedDescription)")
        }
        
        // 验证配置存储重置
        XCTAssertTrue(mockConfigStore.resetToDefaultCalled)
        
        // 验证环境变量更新
        XCTAssertTrue(mockEnvService.updateEnvironmentVariablesCalled)
        XCTAssertEqual(mockEnvService.lastBaseURL, officialConfig.baseURL)
        XCTAssertEqual(mockEnvService.lastToken, officialConfig.token)
        
        // 验证 Shell 配置更新
        XCTAssertTrue(mockShellService.updateShellConfigCalled)
        XCTAssertEqual(mockShellService.lastBaseURL, officialConfig.baseURL)
        XCTAssertEqual(mockShellService.lastToken, officialConfig.token)
        
        // 验证通知发送
        XCTAssertTrue(mockNotificationService.sendResetSuccessCalled)
    }
}

// MARK: - Mock Classes

// Mock ConfigurationStore
class MockConfigurationStore: ConfigurationStore {
    var configurations: [ConfigurationModel] = []
    var activeConfiguration: ConfigurationModel?
    
    var loadConfigurationsCalled = false
    var addConfigurationCalled = false
    var updateConfigurationCalled = false
    var deleteConfigurationCalled = false
    var setActiveConfigurationCalled = false
    var resetToDefaultCalled = false
    
    var lastAddedConfig: ConfigurationModel?
    var lastUpdatedConfig: ConfigurationModel?
    var lastDeletedConfig: ConfigurationModel?
    var lastActiveConfig: ConfigurationModel?
    
    var addConfigurationResult: Result<ConfigurationModel, ConfigurationStoreError> = .failure(.invalidConfiguration("Mock error"))
    var updateConfigurationResult: Result<ConfigurationModel, ConfigurationStoreError> = .failure(.invalidConfiguration("Mock error"))
    var deleteConfigurationResult: Result<Void, ConfigurationStoreError> = .failure(.invalidConfiguration("Mock error"))
    var setActiveConfigurationResult: Result<ConfigurationModel, ConfigurationStoreError> = .failure(.invalidConfiguration("Mock error"))
    var resetToDefaultResult: Result<ConfigurationModel, ConfigurationStoreError> = .failure(.invalidConfiguration("Mock error"))
    
    override func loadConfigurations() throws {
        loadConfigurationsCalled = true
        // 不调用父类方法，直接使用 mock 数据
    }
    
    @discardableResult
    override func addConfiguration(_ configuration: ConfigurationModel) -> Result<ConfigurationModel, ConfigurationStoreError> {
        addConfigurationCalled = true
        lastAddedConfig = configuration
        return addConfigurationResult
    }
    
    @discardableResult
    override func updateConfiguration(_ configuration: ConfigurationModel) -> Result<ConfigurationModel, ConfigurationStoreError> {
        updateConfigurationCalled = true
        lastUpdatedConfig = configuration
        return updateConfigurationResult
    }
    
    @discardableResult
    override func deleteConfiguration(_ configuration: ConfigurationModel) -> Result<Void, ConfigurationStoreError> {
        deleteConfigurationCalled = true
        lastDeletedConfig = configuration
        return deleteConfigurationResult
    }
    
    @discardableResult
    override func setActiveConfiguration(_ configuration: ConfigurationModel) -> Result<ConfigurationModel, ConfigurationStoreError> {
        setActiveConfigurationCalled = true
        lastActiveConfig = configuration
        return setActiveConfigurationResult
    }
    
    @discardableResult
    override func resetToDefault() -> Result<ConfigurationModel, ConfigurationStoreError> {
        resetToDefaultCalled = true
        return resetToDefaultResult
    }
}

// Mock EnvironmentService
class MockEnvironmentService: EnvironmentService {
    var updateEnvironmentVariablesCalled = false
    var resetEnvironmentVariablesCalled = false
    
    var lastBaseURL: String?
    var lastToken: String?
    
    var updateEnvironmentVariablesResult: Result<Void, EnvironmentServiceError> = .success(())
    var resetEnvironmentVariablesResult: Result<Void, EnvironmentServiceError> = .success(())
    var currentEnvironmentVariables: (baseURL: String?, token: String?) = (nil, nil)
    
    override func updateEnvironmentVariables(baseURL: String, token: String) -> Result<Void, EnvironmentServiceError> {
        updateEnvironmentVariablesCalled = true
        lastBaseURL = baseURL
        lastToken = token
        return updateEnvironmentVariablesResult
    }
    
    override func resetEnvironmentVariables() -> Result<Void, EnvironmentServiceError> {
        resetEnvironmentVariablesCalled = true
        return resetEnvironmentVariablesResult
    }
    
    override func getCurrentEnvironmentVariables() -> (baseURL: String?, token: String?) {
        return currentEnvironmentVariables
    }
}

// Mock ShellConfigService
class MockShellConfigService: ShellConfigService {
    var updateShellConfigCalled = false
    var sourceShellConfigCalled = false
    var setEnvironmentVariablesDirectlyCalled = false
    var checkEnvironmentVariablesCalled = false
    
    var lastBaseURL: String?
    var lastToken: String?
    
    var updateShellConfigResult: Result<Void, EnvironmentServiceError> = .success(())
    var sourceShellConfigResult: Result<Void, EnvironmentServiceError> = .success(())
    var setEnvironmentVariablesDirectlyResult: Result<Void, EnvironmentServiceError> = .success(())
    var checkEnvironmentVariablesResult = true
    
    override func updateShellConfig(baseURL: String, token: String) -> Result<Void, EnvironmentServiceError> {
        updateShellConfigCalled = true
        lastBaseURL = baseURL
        lastToken = token
        return updateShellConfigResult
    }
    
    override func sourceShellConfig() -> Result<Void, EnvironmentServiceError> {
        sourceShellConfigCalled = true
        return sourceShellConfigResult
    }
    
    override func setEnvironmentVariablesDirectly(baseURL: String, token: String) -> Result<Void, EnvironmentServiceError> {
        setEnvironmentVariablesDirectlyCalled = true
        lastBaseURL = baseURL
        lastToken = token
        return setEnvironmentVariablesDirectlyResult
    }
    
    override func checkEnvironmentVariables(baseURL: String, token: String) -> Bool {
        checkEnvironmentVariablesCalled = true
        lastBaseURL = baseURL
        lastToken = token
        return checkEnvironmentVariablesResult
    }
}

// Mock ValidationService
class MockValidationService: ValidationService {
    var validateURLCalled = false
    var validateTokenCalled = false
    var validateNameCalled = false
    var validateConfigurationCalled = false
    
    var lastURL: String?
    var lastToken: String?
    var lastName: String?
    var lastConfig: ConfigurationModel?
    
    var validateURLResult: Result<Void, ValidationError> = .success(())
    var validateTokenResult: Result<Void, ValidationError> = .success(())
    var validateNameResult: Result<Void, ValidationError> = .success(())
    var validationResult: [ValidationError] = []
    
    override func validateURL(_ url: String) -> Result<Void, ValidationError> {
        validateURLCalled = true
        lastURL = url
        return validateURLResult
    }
    
    override func validateToken(_ token: String, required: Bool = true) -> Result<Void, ValidationError> {
        validateTokenCalled = true
        lastToken = token
        return validateTokenResult
    }
    
    override func validateName(_ name: String) -> Result<Void, ValidationError> {
        validateNameCalled = true
        lastName = name
        return validateNameResult
    }
    
    override func validateConfiguration(_ configuration: ConfigurationModel) -> [ValidationError] {
        validateConfigurationCalled = true
        lastConfig = configuration
        return validationResult
    }
}

// Mock NotificationService
class MockNotificationService: NotificationService {
    var sendNotificationCalled = false
    var sendConfigurationSwitchSuccessCalled = false
    var sendConfigurationSwitchFailedCalled = false
    var sendResetSuccessCalled = false
    var sendResetFailedCalled = false
    var sendErrorNotificationCalled = false
    
    var lastTitle: String?
    var lastMessage: String?
    var lastType: NotificationType?
    var lastConfigName: String?
    var lastError: Error?
    
    override func sendNotification(
        title: String,
        message: String,
        type: NotificationType = .info,
        completion: ((Result<Void, NotificationServiceError>) -> Void)? = nil
    ) {
        sendNotificationCalled = true
        lastTitle = title
        lastMessage = message
        lastType = type
        completion?(.success(()))
    }
    
    override func sendConfigurationSwitchSuccessNotification(configName: String) {
        sendConfigurationSwitchSuccessCalled = true
        lastConfigName = configName
    }
    
    override func sendConfigurationSwitchFailedNotification(error: Error) {
        sendConfigurationSwitchFailedCalled = true
        lastError = error
    }
    
    override func sendResetSuccessNotification() {
        sendResetSuccessCalled = true
    }
    
    override func sendResetFailedNotification(error: Error) {
        sendResetFailedCalled = true
        lastError = error
    }
    
    override func sendErrorNotification(title: String, error: Error) {
        sendErrorNotificationCalled = true
        lastTitle = title
        lastError = error
    }
}