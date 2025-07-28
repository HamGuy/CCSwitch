import XCTest
@testable import ccswitch
import Combine

final class ConfigurationEditorViewModelTests: XCTestCase {
    
    var viewModel: ConfigurationEditorViewModel!
    var mockConfigStore: MockConfigurationStore!
    var mockValidationService: MockValidationService!
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        mockConfigStore = MockConfigurationStore()
        mockValidationService = MockValidationService()
    }
    
    override func tearDown() {
        viewModel = nil
        mockConfigStore = nil
        mockValidationService = nil
        cancellables.removeAll()
        super.tearDown()
    }
    
    // 测试初始化新配置
    func testInitNewConfiguration() {
        // 创建新配置的视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: nil,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 验证结果
        XCTAssertTrue(viewModel.isNewConfiguration)
        XCTAssertEqual(viewModel.configuration.type, .custom)
        XCTAssertEqual(viewModel.configuration.name, "")
        XCTAssertEqual(viewModel.configuration.baseURL, "")
        XCTAssertEqual(viewModel.configuration.token, "")
        XCTAssertTrue(viewModel.configuration.isCustom)
        XCTAssertFalse(viewModel.configuration.isActive)
        XCTAssertTrue(viewModel.validationErrors.isEmpty)
    }
    
    // 测试初始化编辑现有配置
    func testInitExistingConfiguration() {
        // 创建测试配置
        let existingConfig = ConfigurationModel.preset(type: .gaccode, token: "sk-test123")
        
        // 创建编辑现有配置的视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: existingConfig,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 验证结果
        XCTAssertFalse(viewModel.isNewConfiguration)
        XCTAssertEqual(viewModel.configuration.id, existingConfig.id)
        XCTAssertEqual(viewModel.configuration.type, existingConfig.type)
        XCTAssertEqual(viewModel.configuration.name, existingConfig.name)
        XCTAssertEqual(viewModel.configuration.baseURL, existingConfig.baseURL)
        XCTAssertEqual(viewModel.configuration.token, existingConfig.token)
        XCTAssertEqual(viewModel.configuration.isCustom, existingConfig.isCustom)
        XCTAssertEqual(viewModel.configuration.isActive, existingConfig.isActive)
        XCTAssertTrue(viewModel.validationErrors.isEmpty)
    }
    
    // 测试配置类型变化时自动更新 URL
    func testTypeChangeUpdatesURL() {
        // 创建视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: nil,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 设置期望
        let expectation = XCTestExpectation(description: "URL should update after type change")
        
        // 监听配置变化
        viewModel.$configuration
            .dropFirst() // 忽略初始值
            .sink { config in
                XCTAssertEqual(config.baseURL, ConfigurationModel.ConfigurationType.gaccode.defaultURL)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // 更新类型
        viewModel.updateType(.gaccode)
        
        // 等待期望满足
        wait(for: [expectation], timeout: 1.0)
    }
    
    // 测试验证配置 - 有效配置
    func testValidateConfigurationValid() {
        // 设置有效配置
        let validConfig = ConfigurationModel.custom(
            name: "Valid Config",
            baseURL: "https://valid.api.com",
            token: "sk-valid123"
        )
        
        // 设置验证结果
        mockValidationService.validationResult = []
        
        // 创建视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: validConfig,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 执行验证
        let isValid = viewModel.validateConfiguration()
        
        // 验证结果
        XCTAssertTrue(isValid)
        XCTAssertTrue(viewModel.validationErrors.isEmpty)
        XCTAssertTrue(mockValidationService.validateConfigurationCalled)
        XCTAssertEqual(mockValidationService.lastConfig, validConfig)
    }
    
    // 测试验证配置 - 无效配置
    func testValidateConfigurationInvalid() {
        // 设置无效配置
        let invalidConfig = ConfigurationModel.custom(
            name: "",
            baseURL: "invalid-url",
            token: "invalid-token"
        )
        
        // 设置验证结果
        mockValidationService.validationResult = [
            ValidationError.emptyName,
            ValidationError.invalidURLFormat,
            ValidationError.invalidTokenFormat
        ]
        
        // 创建视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: invalidConfig,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 执行验证
        let isValid = viewModel.validateConfiguration()
        
        // 验证结果
        XCTAssertFalse(isValid)
        XCTAssertEqual(viewModel.validationErrors.count, 3)
        XCTAssertTrue(mockValidationService.validateConfigurationCalled)
        XCTAssertEqual(mockValidationService.lastConfig, invalidConfig)
    }
    
    // 测试保存配置 - 新配置
    func testSaveConfigurationNew() {
        // 设置新配置
        let newConfig = ConfigurationModel.custom(
            name: "New Config",
            baseURL: "https://new.api.com",
            token: "sk-new123"
        )
        
        // 设置验证结果和存储结果
        mockValidationService.validationResult = []
        mockConfigStore.addConfigurationResult = .success(newConfig)
        
        // 创建视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: nil,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 设置配置属性
        viewModel.updateName(newConfig.name)
        viewModel.updateURL(newConfig.baseURL)
        viewModel.updateToken(newConfig.token)
        
        // 执行保存
        let result = viewModel.saveConfiguration()
        
        // 验证结果
        switch result {
        case .success(let savedConfig):
            XCTAssertEqual(savedConfig.name, newConfig.name)
            XCTAssertEqual(savedConfig.baseURL, newConfig.baseURL)
            XCTAssertEqual(savedConfig.token, newConfig.token)
        case .failure(let error):
            XCTFail("保存配置失败: \(error.localizedDescription)")
        }
        
        // 验证调用
        XCTAssertTrue(mockValidationService.validateConfigurationCalled)
        XCTAssertTrue(mockConfigStore.addConfigurationCalled)
        XCTAssertEqual(mockConfigStore.lastAddedConfig?.name, newConfig.name)
        XCTAssertEqual(mockConfigStore.lastAddedConfig?.baseURL, newConfig.baseURL)
        XCTAssertEqual(mockConfigStore.lastAddedConfig?.token, newConfig.token)
    }
    
    // 测试保存配置 - 更新现有配置
    func testSaveConfigurationUpdate() {
        // 设置现有配置
        let existingConfig = ConfigurationModel.preset(type: .gaccode, token: "sk-old")
        let updatedConfig = existingConfig.copy()
        updatedConfig.token = "sk-updated123"
        
        // 设置验证结果和存储结果
        mockValidationService.validationResult = []
        mockConfigStore.updateConfigurationResult = .success(updatedConfig)
        
        // 创建视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: existingConfig,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 更新 token
        viewModel.updateToken("sk-updated123")
        
        // 执行保存
        let result = viewModel.saveConfiguration()
        
        // 验证结果
        switch result {
        case .success(let savedConfig):
            XCTAssertEqual(savedConfig.token, "sk-updated123")
        case .failure(let error):
            XCTFail("保存配置失败: \(error.localizedDescription)")
        }
        
        // 验证调用
        XCTAssertTrue(mockValidationService.validateConfigurationCalled)
        XCTAssertTrue(mockConfigStore.updateConfigurationCalled)
        XCTAssertEqual(mockConfigStore.lastUpdatedConfig?.token, "sk-updated123")
    }
    
    // 测试保存配置 - 验证失败
    func testSaveConfigurationValidationFailure() {
        // 设置无效配置
        let invalidConfig = ConfigurationModel.custom(
            name: "",
            baseURL: "invalid-url",
            token: "invalid-token"
        )
        
        // 设置验证结果
        mockValidationService.validationResult = [
            ValidationError.emptyName,
            ValidationError.invalidURLFormat,
            ValidationError.invalidTokenFormat
        ]
        
        // 创建视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: invalidConfig,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 执行保存
        let result = viewModel.saveConfiguration()
        
        // 验证结果
        switch result {
        case .success:
            XCTFail("无效配置不应保存成功")
        case .failure:
            // 验证失败，符合预期
            break
        }
        
        // 验证调用
        XCTAssertTrue(mockValidationService.validateConfigurationCalled)
        XCTAssertFalse(mockConfigStore.addConfigurationCalled)
        XCTAssertFalse(mockConfigStore.updateConfigurationCalled)
    }
    
    // 测试删除配置 - 自定义配置
    func testDeleteConfigurationCustom() {
        // 设置自定义配置
        let customConfig = ConfigurationModel.custom(
            name: "Custom Config",
            baseURL: "https://custom.api.com",
            token: "sk-custom123"
        )
        
        // 设置存储结果
        mockConfigStore.deleteConfigurationResult = .success(())
        
        // 创建视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: customConfig,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 执行删除
        let (success, errorMessage) = viewModel.deleteConfiguration()
        
        // 验证结果
        XCTAssertTrue(success)
        XCTAssertNil(errorMessage)
        XCTAssertTrue(mockConfigStore.deleteConfigurationCalled)
        XCTAssertEqual(mockConfigStore.lastDeletedConfig, customConfig)
    }
    
    // 测试删除配置 - 预设配置
    func testDeleteConfigurationPreset() {
        // 设置预设配置
        let presetConfig = ConfigurationModel.preset(type: .gaccode)
        
        // 创建视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: presetConfig,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 执行删除
        let (success, errorMessage) = viewModel.deleteConfiguration()
        
        // 验证结果
        XCTAssertFalse(success)
        XCTAssertEqual(errorMessage, "不能删除预设配置")
        XCTAssertFalse(mockConfigStore.deleteConfigurationCalled)
    }
    
    // 测试删除配置 - 删除失败
    func testDeleteConfigurationFailure() {
        // 设置自定义配置
        let customConfig = ConfigurationModel.custom(
            name: "Custom Config",
            baseURL: "https://custom.api.com",
            token: "sk-custom123"
        )
        
        // 设置存储结果
        mockConfigStore.deleteConfigurationResult = .failure(.configurationNotFound("配置未找到"))
        
        // 创建视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: customConfig,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 执行删除
        let (success, errorMessage) = viewModel.deleteConfiguration()
        
        // 验证结果
        XCTAssertFalse(success)
        XCTAssertEqual(errorMessage, "配置未找到")
        XCTAssertTrue(mockConfigStore.deleteConfigurationCalled)
    }
    
    // 测试检查配置是否可以删除
    func testCanDeleteConfiguration() {
        // 测试自定义配置
        let customConfig = ConfigurationModel.custom(
            name: "Custom Config",
            baseURL: "https://custom.api.com",
            token: "sk-custom123"
        )
        
        viewModel = ConfigurationEditorViewModel(
            configuration: customConfig,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        XCTAssertTrue(viewModel.canDeleteConfiguration())
        
        // 测试预设配置
        let presetConfig = ConfigurationModel.preset(type: .gaccode)
        
        viewModel = ConfigurationEditorViewModel(
            configuration: presetConfig,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        XCTAssertFalse(viewModel.canDeleteConfiguration())
    }
    
    // 测试更新配置属性
    func testUpdateConfigurationProperties() {
        // 创建视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: nil,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 更新名称
        viewModel.updateName("New Name")
        XCTAssertEqual(viewModel.configuration.name, "New Name")
        
        // 更新类型
        viewModel.updateType(.gaccode)
        XCTAssertEqual(viewModel.configuration.type, .gaccode)
        XCTAssertEqual(viewModel.configuration.baseURL, ConfigurationModel.ConfigurationType.gaccode.defaultURL)
        
        // 更新 URL
        viewModel.updateURL("https://custom.url.com")
        XCTAssertEqual(viewModel.configuration.baseURL, "https://custom.url.com")
        
        // 更新 Token
        viewModel.updateToken("sk-newtoken123")
        XCTAssertEqual(viewModel.configuration.token, "sk-newtoken123")
    }
    
    // 测试重置编辑器 - 新配置
    func testResetNew() {
        // 创建视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: nil,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 设置一些值
        viewModel.updateName("Test Name")
        viewModel.updateURL("https://test.url.com")
        viewModel.updateToken("sk-test123")
        
        // 执行重置
        viewModel.reset()
        
        // 验证结果
        XCTAssertEqual(viewModel.configuration.name, "")
        XCTAssertEqual(viewModel.configuration.baseURL, "")
        XCTAssertEqual(viewModel.configuration.token, "")
        XCTAssertTrue(viewModel.validationErrors.isEmpty)
    }
    
    // 测试重置编辑器 - 现有配置
    func testResetExisting() {
        // 设置原始配置
        let originalConfig = ConfigurationModel.preset(type: .gaccode, token: "sk-original")
        
        // 设置 mock 存储返回原始配置
        mockConfigStore.configurations = [originalConfig]
        
        // 创建视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: originalConfig,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 修改配置
        viewModel.updateName("Modified Name")
        viewModel.updateToken("sk-modified")
        
        // 执行重置
        viewModel.reset()
        
        // 验证结果
        XCTAssertEqual(viewModel.configuration.name, originalConfig.name)
        XCTAssertEqual(viewModel.configuration.token, originalConfig.token)
    }
    
    // 测试检查配置是否已更改 - 新配置
    func testHasChangesNew() {
        // 创建视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: nil,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 初始状态应该没有更改
        XCTAssertFalse(viewModel.hasChanges())
        
        // 更新名称
        viewModel.updateName("New Name")
        XCTAssertTrue(viewModel.hasChanges())
        
        // 重置
        viewModel.reset()
        XCTAssertFalse(viewModel.hasChanges())
        
        // 更新 URL
        viewModel.updateURL("https://new.url.com")
        XCTAssertTrue(viewModel.hasChanges())
        
        // 重置
        viewModel.reset()
        XCTAssertFalse(viewModel.hasChanges())
        
        // 更新 Token
        viewModel.updateToken("sk-new123")
        XCTAssertTrue(viewModel.hasChanges())
    }
    
    // 测试检查配置是否已更改 - 现有配置
    func testHasChangesExisting() {
        // 设置原始配置
        let originalConfig = ConfigurationModel.preset(type: .gaccode, token: "sk-original")
        
        // 设置 mock 存储返回原始配置
        mockConfigStore.configurations = [originalConfig]
        
        // 创建视图模型
        viewModel = ConfigurationEditorViewModel(
            configuration: originalConfig,
            configurationStore: mockConfigStore,
            validationService: mockValidationService
        )
        
        // 初始状态应该没有更改
        XCTAssertFalse(viewModel.hasChanges())
        
        // 更新名称
        viewModel.updateName("Modified Name")
        XCTAssertTrue(viewModel.hasChanges())
        
        // 重置
        viewModel.reset()
        XCTAssertFalse(viewModel.hasChanges())
        
        // 更新 Token
        viewModel.updateToken("sk-modified")
        XCTAssertTrue(viewModel.hasChanges())
        
        // 重置
        viewModel.reset()
        XCTAssertFalse(viewModel.hasChanges())
        
        // 更新类型
        viewModel.updateType(.anyrouter)
        XCTAssertTrue(viewModel.hasChanges())
    }
}