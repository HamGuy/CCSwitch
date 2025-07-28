import XCTest
@testable import ccswitch

/// 集成测试：配置存储和加载
final class ConfigurationIntegrationTests: XCTestCase {
    
    var configStore: ConfigurationStore!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // 创建临时目录用于测试
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // 创建使用临时目录的配置存储
        configStore = ConfigurationStore(storageDirectory: tempDirectory.path)
    }
    
    override func tearDown() {
        configStore = nil
        
        // 清理临时目录
        try? FileManager.default.removeItem(at: tempDirectory)
        
        super.tearDown()
    }
    
    /// 测试配置的完整保存和加载流程
    func testConfigurationSaveAndLoad() throws {
        // 1. 创建测试配置
        let config1 = ConfigurationModel.preset(type: .gaccode, token: "sk-test1")
        let config2 = ConfigurationModel.preset(type: .anyrouter, token: "sk-test2")
        let config3 = ConfigurationModel.custom(
            name: "Custom Config",
            baseURL: "https://custom.api.com",
            token: "sk-test3"
        )
        
        // 2. 添加配置
        let result1 = configStore.addConfiguration(config1)
        let result2 = configStore.addConfiguration(config2)
        let result3 = configStore.addConfiguration(config3)
        
        // 验证添加结果
        XCTAssertTrue(result1.isSuccess)
        XCTAssertTrue(result2.isSuccess)
        XCTAssertTrue(result3.isSuccess)
        
        // 3. 设置活动配置
        let activeResult = configStore.setActiveConfiguration(config2)
        XCTAssertTrue(activeResult.isSuccess)
        
        // 4. 验证配置文件已创建
        let configFilePath = tempDirectory.appendingPathComponent("configurations.json").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: configFilePath))
        
        // 5. 创建新的配置存储实例，从文件加载配置
        let newConfigStore = ConfigurationStore(storageDirectory: tempDirectory.path)
        try newConfigStore.loadConfigurations()
        
        // 6. 验证配置已正确加载
        XCTAssertEqual(newConfigStore.configurations.count, 3)
        
        // 验证活动配置
        XCTAssertNotNil(newConfigStore.activeConfiguration)
        XCTAssertEqual(newConfigStore.activeConfiguration?.type, .anyrouter)
        
        // 验证配置内容
        let loadedGaccode = newConfigStore.configurations.first { $0.type == .gaccode }
        let loadedAnyrouter = newConfigStore.configurations.first { $0.type == .anyrouter }
        let loadedCustom = newConfigStore.configurations.first { $0.isCustom }
        
        XCTAssertNotNil(loadedGaccode)
        XCTAssertNotNil(loadedAnyrouter)
        XCTAssertNotNil(loadedCustom)
        
        XCTAssertEqual(loadedGaccode?.token, "sk-test1")
        XCTAssertEqual(loadedAnyrouter?.token, "sk-test2")
        XCTAssertEqual(loadedCustom?.token, "sk-test3")
        XCTAssertEqual(loadedCustom?.name, "Custom Config")
        XCTAssertEqual(loadedCustom?.baseURL, "https://custom.api.com")
    }
    
    /// 测试配置更新
    func testConfigurationUpdate() throws {
        // 1. 创建并添加测试配置
        let config = ConfigurationModel.preset(type: .gaccode, token: "sk-original")
        let addResult = configStore.addConfiguration(config)
        XCTAssertTrue(addResult.isSuccess)
        
        // 2. 更新配置
        var updatedConfig = config
        updatedConfig.token = "sk-updated"
        
        let updateResult = configStore.updateConfiguration(updatedConfig)
        XCTAssertTrue(updateResult.isSuccess)
        
        // 3. 创建新的配置存储实例，从文件加载配置
        let newConfigStore = ConfigurationStore(storageDirectory: tempDirectory.path)
        try newConfigStore.loadConfigurations()
        
        // 4. 验证配置已正确更新
        let loadedConfig = newConfigStore.configurations.first { $0.type == .gaccode }
        XCTAssertNotNil(loadedConfig)
        XCTAssertEqual(loadedConfig?.token, "sk-updated")
    }
    
    /// 测试配置删除
    func testConfigurationDelete() throws {
        // 1. 创建并添加测试配置
        let config1 = ConfigurationModel.preset(type: .gaccode)
        let config2 = ConfigurationModel.custom(
            name: "Custom Config",
            baseURL: "https://custom.api.com",
            token: "sk-test"
        )
        
        _ = configStore.addConfiguration(config1)
        _ = configStore.addConfiguration(config2)
        
        // 2. 删除自定义配置
        let deleteResult = configStore.deleteConfiguration(config2)
        XCTAssertTrue(deleteResult.isSuccess)
        
        // 3. 创建新的配置存储实例，从文件加载配置
        let newConfigStore = ConfigurationStore(storageDirectory: tempDirectory.path)
        try newConfigStore.loadConfigurations()
        
        // 4. 验证配置已正确删除
        XCTAssertEqual(newConfigStore.configurations.count, 1)
        XCTAssertEqual(newConfigStore.configurations.first?.type, .gaccode)
        
        // 验证自定义配置已被删除
        let loadedCustom = newConfigStore.configurations.first { $0.isCustom }
        XCTAssertNil(loadedCustom)
    }
    
    /// 测试重置为默认配置
    func testResetToDefault() throws {
        // 1. 创建并添加测试配置
        let config1 = ConfigurationModel.preset(type: .gaccode, token: "sk-test1")
        let config2 = ConfigurationModel.preset(type: .anyrouter, token: "sk-test2")
        
        _ = configStore.addConfiguration(config1)
        _ = configStore.addConfiguration(config2)
        _ = configStore.setActiveConfiguration(config1)
        
        // 2. 重置为默认配置
        let resetResult = configStore.resetToDefault()
        XCTAssertTrue(resetResult.isSuccess)
        
        // 3. 验证活动配置已更新为官方配置
        XCTAssertEqual(configStore.activeConfiguration?.type, .official)
        XCTAssertEqual(configStore.activeConfiguration?.baseURL, "https://api.anthropic.com")
        XCTAssertEqual(configStore.activeConfiguration?.token, "")
        
        // 4. 创建新的配置存储实例，从文件加载配置
        let newConfigStore = ConfigurationStore(storageDirectory: tempDirectory.path)
        try newConfigStore.loadConfigurations()
        
        // 5. 验证活动配置已正确保存
        XCTAssertEqual(newConfigStore.activeConfiguration?.type, .official)
    }
    
    /// 测试配置文件损坏恢复
    func testCorruptedConfigurationRecovery() throws {
        // 1. 创建损坏的配置文件
        let configFilePath = tempDirectory.appendingPathComponent("configurations.json").path
        let corruptedContent = "{ this is not valid JSON }"
        try corruptedContent.write(toFile: configFilePath, atomically: true, encoding: .utf8)
        
        // 2. 尝试加载配置
        let newConfigStore = ConfigurationStore(storageDirectory: tempDirectory.path)
        try newConfigStore.loadConfigurations()
        
        // 3. 验证已恢复默认配置
        XCTAssertFalse(newConfigStore.configurations.isEmpty)
        
        // 应该包含预设配置
        let hasGaccode = newConfigStore.configurations.contains { $0.type == .gaccode }
        let hasAnyrouter = newConfigStore.configurations.contains { $0.type == .anyrouter }
        let hasKimi = newConfigStore.configurations.contains { $0.type == .kimi }
        let hasOfficial = newConfigStore.configurations.contains { $0.type == .official }
        
        XCTAssertTrue(hasGaccode)
        XCTAssertTrue(hasAnyrouter)
        XCTAssertTrue(hasKimi)
        XCTAssertTrue(hasOfficial)
    }
}