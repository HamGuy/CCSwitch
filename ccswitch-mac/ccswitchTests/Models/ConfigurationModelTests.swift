import XCTest
@testable import ccswitch

final class ConfigurationModelTests: XCTestCase {
    
    // 测试初始化方法
    func testInit() {
        // 测试默认初始化
        let config = ConfigurationModel(
            name: "Test Config",
            type: .gaccode,
            token: "sk-test123"
        )
        
        XCTAssertEqual(config.name, "Test Config")
        XCTAssertEqual(config.type, .gaccode)
        XCTAssertEqual(config.baseURL, "https://api.tu-zi.com")
        XCTAssertEqual(config.token, "sk-test123")
        XCTAssertFalse(config.isActive)
        XCTAssertFalse(config.isCustom)
        
        // 测试自定义 URL 初始化
        let customURLConfig = ConfigurationModel(
            name: "Custom URL",
            type: .gaccode,
            baseURL: "https://custom.api.com",
            token: "sk-test456"
        )
        
        XCTAssertEqual(customURLConfig.baseURL, "https://custom.api.com")
    }
    
    // 测试预设配置创建
    func testPresetCreation() {
        // 测试 gaccode 预设
        let gaccode = ConfigurationModel.preset(type: .gaccode, token: "sk-gaccode")
        XCTAssertEqual(gaccode.name, "GAC Code")
        XCTAssertEqual(gaccode.type, .gaccode)
        XCTAssertEqual(gaccode.baseURL, "https://api.tu-zi.com")
        XCTAssertEqual(gaccode.token, "sk-gaccode")
        XCTAssertFalse(gaccode.isCustom)
        
        // 测试 anyrouter 预设
        let anyrouter = ConfigurationModel.preset(type: .anyrouter)
        XCTAssertEqual(anyrouter.name, "Anyrouter")
        XCTAssertEqual(anyrouter.type, .anyrouter)
        XCTAssertEqual(anyrouter.baseURL, "https://api.anyrouter.cn/anthropic")
        XCTAssertEqual(anyrouter.token, "")
        
        // 测试 kimi 预设
        let kimi = ConfigurationModel.preset(type: .kimi)
        XCTAssertEqual(kimi.name, "Kimi")
        XCTAssertEqual(kimi.baseURL, "https://api.moonshot.cn/anthropic")
    }
    
    // 测试自定义配置创建
    func testCustomCreation() {
        let custom = ConfigurationModel.custom(
            name: "My API",
            baseURL: "https://my-api.com",
            token: "sk-custom123"
        )
        
        XCTAssertEqual(custom.name, "My API")
        XCTAssertEqual(custom.type, .custom)
        XCTAssertEqual(custom.baseURL, "https://my-api.com")
        XCTAssertEqual(custom.token, "sk-custom123")
        XCTAssertTrue(custom.isCustom)
    }
    
    // 测试官方配置创建
    func testOfficialCreation() {
        let official = ConfigurationModel.official(token: "sk-official")
        
        XCTAssertEqual(official.name, "Claude 官方")
        XCTAssertEqual(official.type, .official)
        XCTAssertEqual(official.baseURL, "https://api.anthropic.com")
        XCTAssertEqual(official.token, "sk-official")
        XCTAssertFalse(official.isCustom)
    }
    
    // 测试配置验证
    func testValidation() {
        // 有效配置
        let validConfig = ConfigurationModel(
            name: "Valid",
            type: .custom,
            baseURL: "https://valid-api.com",
            token: "sk-valid123"
        )
        XCTAssertTrue(validConfig.isValid())
        XCTAssertTrue(validConfig.validationErrors().isEmpty)
        
        // 无效名称
        let invalidNameConfig = ConfigurationModel(
            name: "",
            type: .custom,
            baseURL: "https://valid-api.com",
            token: "sk-valid123"
        )
        XCTAssertFalse(invalidNameConfig.isValid())
        XCTAssertTrue(invalidNameConfig.validationErrors().contains("配置名称不能为空"))
        
        // 无效 URL
        let invalidURLConfig = ConfigurationModel(
            name: "Invalid URL",
            type: .custom,
            baseURL: "",
            token: "sk-valid123"
        )
        XCTAssertFalse(invalidURLConfig.isValid())
        XCTAssertTrue(invalidURLConfig.validationErrors().contains("API URL 不能为空"))
        
        let malformedURLConfig = ConfigurationModel(
            name: "Malformed URL",
            type: .custom,
            baseURL: "not-a-url",
            token: "sk-valid123"
        )
        XCTAssertFalse(malformedURLConfig.isValid())
        XCTAssertTrue(malformedURLConfig.validationErrors().contains("API URL 格式无效"))
        
        // 无效 Token
        let invalidTokenConfig = ConfigurationModel(
            name: "Invalid Token",
            type: .custom,
            baseURL: "https://valid-api.com",
            token: "invalid-token"
        )
        XCTAssertFalse(invalidTokenConfig.isValid())
        XCTAssertTrue(invalidTokenConfig.validationErrors().contains("API Token 格式无效，应以 sk- 开头"))
        
        // 空 Token 是有效的
        let emptyTokenConfig = ConfigurationModel(
            name: "Empty Token",
            type: .custom,
            baseURL: "https://valid-api.com",
            token: ""
        )
        XCTAssertTrue(emptyTokenConfig.isValid())
    }
    
    // 测试配置复制
    func testCopy() {
        let original = ConfigurationModel(
            id: UUID(),
            name: "Original",
            type: .custom,
            baseURL: "https://original.com",
            token: "sk-original",
            isActive: true,
            isCustom: true
        )
        
        let copy = original.copy()
        
        XCTAssertEqual(copy.id, original.id)
        XCTAssertEqual(copy.name, original.name)
        XCTAssertEqual(copy.type, original.type)
        XCTAssertEqual(copy.baseURL, original.baseURL)
        XCTAssertEqual(copy.token, original.token)
        XCTAssertEqual(copy.isActive, original.isActive)
        XCTAssertEqual(copy.isCustom, original.isCustom)
    }
    
    // 测试激活和取消激活
    func testActivation() {
        let config = ConfigurationModel(
            name: "Test",
            type: .custom,
            baseURL: "https://test.com",
            isActive: false
        )
        
        let activated = config.activated()
        XCTAssertTrue(activated.isActive)
        
        let deactivated = activated.deactivated()
        XCTAssertFalse(deactivated.isActive)
    }
    
    // 测试 Equatable 实现
    func testEquatable() {
        let id = UUID()
        let config1 = ConfigurationModel(
            id: id,
            name: "Config 1",
            type: .custom,
            baseURL: "https://config1.com"
        )
        
        let config2 = ConfigurationModel(
            id: id,
            name: "Different Name",  // 名称不同
            type: .gaccode,          // 类型不同
            baseURL: "https://different.com"  // URL 不同
        )
        
        // 即使其他属性不同，只要 ID 相同，两个配置就被认为是相等的
        XCTAssertEqual(config1, config2)
        
        let config3 = ConfigurationModel(
            id: UUID(),  // 不同的 ID
            name: "Config 1",
            type: .custom,
            baseURL: "https://config1.com"
        )
        
        // ID 不同，即使其他属性相同，两个配置也被认为是不相等的
        XCTAssertNotEqual(config1, config3)
    }
}