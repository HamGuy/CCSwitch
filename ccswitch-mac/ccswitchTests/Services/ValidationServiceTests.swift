import XCTest
@testable import ccswitch

final class ValidationServiceTests: XCTestCase {
    
    var validationService: ValidationService!
    
    override func setUp() {
        super.setUp()
        validationService = ValidationService()
    }
    
    override func tearDown() {
        validationService = nil
        super.tearDown()
    }
    
    // 测试 URL 验证
    func testURLValidation() {
        // 有效 URL
        let validResult = validationService.validateURL("https://api.example.com")
        switch validResult {
        case .success:
            // 验证通过，测试成功
            break
        case .failure(let error):
            XCTFail("有效 URL 验证失败: \(error.localizedDescription)")
        }
        
        // 空 URL
        let emptyResult = validationService.validateURL("")
        switch emptyResult {
        case .success:
            XCTFail("空 URL 应该验证失败")
        case .failure(let error):
            XCTAssertEqual(error, ValidationError.emptyURL)
        }
        
        // 无效格式 URL
        let invalidFormatResult = validationService.validateURL("not-a-url")
        switch invalidFormatResult {
        case .success:
            XCTFail("无效格式 URL 应该验证失败")
        case .failure(let error):
            XCTAssertEqual(error, ValidationError.invalidURLFormat)
        }
        
        // 非 HTTPS URL
        let nonHttpsResult = validationService.validateURL("http://api.example.com")
        switch nonHttpsResult {
        case .success:
            XCTFail("非 HTTPS URL 应该验证失败")
        case .failure(let error):
            XCTAssertEqual(error, ValidationError.notHTTPS)
        }
    }
    
    // 测试 Token 验证
    func testTokenValidation() {
        // 有效 Token
        let validResult = validationService.validateToken("sk-test123456789012345")
        switch validResult {
        case .success:
            // 验证通过，测试成功
            break
        case .failure(let error):
            XCTFail("有效 Token 验证失败: \(error.localizedDescription)")
        }
        
        // 空 Token（必填）
        let emptyRequiredResult = validationService.validateToken("", required: true)
        switch emptyRequiredResult {
        case .success:
            XCTFail("空 Token（必填）应该验证失败")
        case .failure(let error):
            XCTAssertEqual(error, ValidationError.emptyToken)
        }
        
        // 空 Token（非必填）
        let emptyNotRequiredResult = validationService.validateToken("", required: false)
        switch emptyNotRequiredResult {
        case .success:
            // 验证通过，测试成功
            break
        case .failure(let error):
            XCTFail("空 Token（非必填）验证失败: \(error.localizedDescription)")
        }
        
        // 无效格式 Token
        let invalidFormatResult = validationService.validateToken("invalid-token")
        switch invalidFormatResult {
        case .success:
            XCTFail("无效格式 Token 应该验证失败")
        case .failure(let error):
            XCTAssertEqual(error, ValidationError.invalidTokenFormat)
        }
        
        // Token 太短
        let tooShortResult = validationService.validateToken("sk-short")
        switch tooShortResult {
        case .success:
            XCTFail("太短的 Token 应该验证失败")
        case .failure(let error):
            XCTAssertEqual(error, ValidationError.invalidTokenFormat)
        }
    }
    
    // 测试名称验证
    func testNameValidation() {
        // 有效名称
        let validResult = validationService.validateName("Test Configuration")
        switch validResult {
        case .success:
            // 验证通过，测试成功
            break
        case .failure(let error):
            XCTFail("有效名称验证失败: \(error.localizedDescription)")
        }
        
        // 空名称
        let emptyResult = validationService.validateName("")
        switch emptyResult {
        case .success:
            XCTFail("空名称应该验证失败")
        case .failure(let error):
            XCTAssertEqual(error, ValidationError.emptyName)
        }
        
        // 名称过长
        let longName = String(repeating: "A", count: 51)  // 51 个字符
        let tooLongResult = validationService.validateName(longName)
        switch tooLongResult {
        case .success:
            XCTFail("过长名称应该验证失败")
        case .failure(let error):
            XCTAssertEqual(error, ValidationError.nameTooLong)
        }
    }
    
    // 测试完整配置验证
    func testConfigurationValidation() {
        // 有效配置
        let validConfig = ConfigurationModel(
            name: "Valid Config",
            type: .custom,
            baseURL: "https://api.example.com",
            token: "sk-test123456789012345"
        )
        let validErrors = validationService.validateConfiguration(validConfig)
        XCTAssertTrue(validErrors.isEmpty, "有效配置不应有验证错误")
        
        // 无效配置 - 空名称
        let invalidNameConfig = ConfigurationModel(
            name: "",
            type: .custom,
            baseURL: "https://api.example.com",
            token: "sk-test123456789012345"
        )
        let nameErrors = validationService.validateConfiguration(invalidNameConfig)
        XCTAssertFalse(nameErrors.isEmpty, "无效名称配置应有验证错误")
        XCTAssertTrue(nameErrors.contains(ValidationError.emptyName), "应包含空名称错误")
        
        // 无效配置 - 无效 URL
        let invalidURLConfig = ConfigurationModel(
            name: "Invalid URL",
            type: .custom,
            baseURL: "http://api.example.com",  // 非 HTTPS
            token: "sk-test123456789012345"
        )
        let urlErrors = validationService.validateConfiguration(invalidURLConfig)
        XCTAssertFalse(urlErrors.isEmpty, "无效 URL 配置应有验证错误")
        XCTAssertTrue(urlErrors.contains(ValidationError.notHTTPS), "应包含非 HTTPS 错误")
        
        // 无效配置 - 无效 Token
        let invalidTokenConfig = ConfigurationModel(
            name: "Invalid Token",
            type: .custom,
            baseURL: "https://api.example.com",
            token: "invalid-token"
        )
        let tokenErrors = validationService.validateConfiguration(invalidTokenConfig)
        XCTAssertFalse(tokenErrors.isEmpty, "无效 Token 配置应有验证错误")
        XCTAssertTrue(tokenErrors.contains(ValidationError.invalidTokenFormat), "应包含无效 Token 格式错误")
        
        // 官方配置 - 空 Token 是有效的
        let officialEmptyTokenConfig = ConfigurationModel(
            name: "Official Empty Token",
            type: .official,
            baseURL: "https://api.anthropic.com",
            token: ""
        )
        let officialErrors = validationService.validateConfiguration(officialEmptyTokenConfig)
        XCTAssertTrue(officialErrors.isEmpty, "官方配置空 Token 应该有效")
        
        // 多个错误
        let multipleErrorsConfig = ConfigurationModel(
            name: "",
            type: .custom,
            baseURL: "not-a-url",
            token: "invalid-token"
        )
        let multipleErrors = validationService.validateConfiguration(multipleErrorsConfig)
        XCTAssertEqual(multipleErrors.count, 3, "应有 3 个验证错误")
        XCTAssertTrue(multipleErrors.contains(ValidationError.emptyName), "应包含空名称错误")
        XCTAssertTrue(multipleErrors.contains(ValidationError.invalidURLFormat), "应包含无效 URL 格式错误")
        XCTAssertTrue(multipleErrors.contains(ValidationError.invalidTokenFormat), "应包含无效 Token 格式错误")
    }
    
    // 测试错误描述
    func testErrorDescriptions() {
        let errors: [ValidationError] = [
            .emptyURL,
            .invalidURLFormat,
            .notHTTPS,
            .emptyToken,
            .invalidTokenFormat,
            .emptyName,
            .nameTooLong
        ]
        
        let descriptions = validationService.getErrorDescriptions(errors)
        XCTAssertEqual(descriptions.count, errors.count, "错误描述数量应与错误数量相同")
        
        // 验证每个错误都有对应的描述
        XCTAssertTrue(descriptions.contains("API URL 不能为空"))
        XCTAssertTrue(descriptions.contains("API URL 格式无效"))
        XCTAssertTrue(descriptions.contains("API URL 必须使用 HTTPS 协议"))
        XCTAssertTrue(descriptions.contains("API Token 不能为空"))
        XCTAssertTrue(descriptions.contains("API Token 格式无效，应以 sk- 开头"))
        XCTAssertTrue(descriptions.contains("配置名称不能为空"))
        XCTAssertTrue(descriptions.contains("配置名称过长，最多 50 个字符"))
    }
}