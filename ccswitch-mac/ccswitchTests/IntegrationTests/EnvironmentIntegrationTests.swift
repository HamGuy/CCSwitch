import XCTest
@testable import ccswitch

/// 集成测试：环境变量和 Shell 配置
final class EnvironmentIntegrationTests: XCTestCase {
    
    var environmentService: EnvironmentService!
    var shellConfigService: ShellConfigService!
    var tempShellConfigPath: String!
    
    override func setUp() {
        super.setUp()
        
        environmentService = EnvironmentService()
        shellConfigService = ShellConfigService()
        
        // 创建临时 Shell 配置文件路径
        let tempDir = FileManager.default.temporaryDirectory
        tempShellConfigPath = tempDir.appendingPathComponent("test_shell_config_\(UUID().uuidString)").path
    }
    
    override func tearDown() {
        environmentService = nil
        shellConfigService = nil
        
        // 清理临时文件
        if let path = tempShellConfigPath, FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
        
        super.tearDown()
    }
    
    /// 测试环境变量更新和读取
    func testEnvironmentVariableUpdateAndRead() {
        // 1. 设置测试环境变量
        let testURL = "https://test.api.com"
        let testToken = "sk-test123"
        
        let updateResult = environmentService.updateEnvironmentVariables(
            baseURL: testURL,
            token: testToken
        )
        
        // 验证更新成功
        switch updateResult {
        case .success:
            // 更新成功，继续测试
            break
        case .failure(let error):
            XCTFail("环境变量更新失败: \(error.localizedDescription)")
            return
        }
        
        // 2. 读取环境变量
        let (baseURL, token) = environmentService.getCurrentEnvironmentVariables()
        
        // 3. 验证环境变量已正确设置
        XCTAssertEqual(baseURL, testURL)
        XCTAssertEqual(token, testToken)
        
        // 4. 验证环境变量检查函数
        XCTAssertTrue(environmentService.areEnvironmentVariablesSet())
    }
    
    /// 测试环境变量重置
    func testEnvironmentVariableReset() {
        // 1. 先设置一些非默认值
        _ = environmentService.updateEnvironmentVariables(
            baseURL: "https://non-default.api.com",
            token: "sk-nondefault"
        )
        
        // 2. 重置环境变量
        let resetResult = environmentService.resetEnvironmentVariables()
        
        // 验证重置成功
        switch resetResult {
        case .success:
            // 重置成功，继续测试
            break
        case .failure(let error):
            XCTFail("环境变量重置失败: \(error.localizedDescription)")
            return
        }
        
        // 3. 读取环境变量
        let (baseURL, token) = environmentService.getCurrentEnvironmentVariables()
        
        // 4. 验证环境变量已重置为默认值
        XCTAssertEqual(baseURL, "https://api.anthropic.com")
        XCTAssertEqual(token, "")
    }
    
    /// 测试 Shell 配置文件更新
    func testShellConfigFileUpdate() {
        // 1. 设置测试环境变量
        let testURL = "https://test.api.com"
        let testToken = "sk-test123"
        
        // 2. 更新 Shell 配置文件
        let updateResult = environmentService.exportToShellConfig(
            baseURL: testURL,
            token: testToken,
            shellConfigPath: tempShellConfigPath
        )
        
        // 验证更新成功
        switch updateResult {
        case .success:
            // 更新成功，继续测试
            break
        case .failure(let error):
            XCTFail("Shell 配置文件更新失败: \(error.localizedDescription)")
            return
        }
        
        // 3. 验证配置文件内容
        do {
            let content = try String(contentsOfFile: tempShellConfigPath, encoding: .utf8)
            
            // 验证环境变量设置
            XCTAssertTrue(content.contains("export CLAUDE_API_URL=\"\(testURL)\""))
            XCTAssertTrue(content.contains("export CLAUDE_API_KEY=\"\(testToken)\""))
            XCTAssertTrue(content.contains("CCSwitch 环境变量设置 - 自动生成"))
        } catch {
            XCTFail("读取 Shell 配置文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 测试 Shell 配置文件更新和移除
    func testShellConfigFileUpdateAndRemove() {
        // 1. 更新 Shell 配置文件
        _ = environmentService.exportToShellConfig(
            baseURL: "https://test.api.com",
            token: "sk-test123",
            shellConfigPath: tempShellConfigPath
        )
        
        // 2. 移除环境变量设置
        let removeResult = environmentService.removeFromShellConfig(shellConfigPath: tempShellConfigPath)
        
        // 验证移除成功
        switch removeResult {
        case .success:
            // 移除成功，继续测试
            break
        case .failure(let error):
            XCTFail("从 Shell 配置文件移除环境变量设置失败: \(error.localizedDescription)")
            return
        }
        
        // 3. 验证配置文件内容
        do {
            let content = try String(contentsOfFile: tempShellConfigPath, encoding: .utf8)
            
            // 验证环境变量设置已移除
            XCTAssertFalse(content.contains("export CLAUDE_API_URL="))
            XCTAssertFalse(content.contains("export CLAUDE_API_KEY="))
            XCTAssertFalse(content.contains("CCSwitch 环境变量设置 - 自动生成"))
        } catch {
            XCTFail("读取 Shell 配置文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 测试 Shell 配置文件更新（已存在其他内容）
    func testShellConfigFileUpdateWithExistingContent() {
        // 1. 创建带有现有内容的配置文件
        let existingContent = """
        # 现有配置
        export PATH="/usr/local/bin:$PATH"
        
        # 其他配置
        alias ll='ls -la'
        """
        
        do {
            try existingContent.write(toFile: tempShellConfigPath, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("创建测试配置文件失败: \(error.localizedDescription)")
            return
        }
        
        // 2. 更新 Shell 配置文件
        let updateResult = environmentService.exportToShellConfig(
            baseURL: "https://test.api.com",
            token: "sk-test123",
            shellConfigPath: tempShellConfigPath
        )
        
        // 验证更新成功
        switch updateResult {
        case .success:
            // 更新成功，继续测试
            break
        case .failure(let error):
            XCTFail("Shell 配置文件更新失败: \(error.localizedDescription)")
            return
        }
        
        // 3. 验证配置文件内容
        do {
            let content = try String(contentsOfFile: tempShellConfigPath, encoding: .utf8)
            
            // 验证环境变量设置已添加
            XCTAssertTrue(content.contains("export CLAUDE_API_URL=\"https://test.api.com\""))
            XCTAssertTrue(content.contains("export CLAUDE_API_KEY=\"sk-test123\""))
            
            // 验证现有内容保持不变
            XCTAssertTrue(content.contains("export PATH=\"/usr/local/bin:$PATH\""))
            XCTAssertTrue(content.contains("alias ll='ls -la'"))
        } catch {
            XCTFail("读取 Shell 配置文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 测试 Shell 配置服务的环境变量设置
    func testShellConfigServiceEnvironmentVariables() {
        // 1. 设置测试环境变量
        let testURL = "https://test.api.com"
        let testToken = "sk-test123"
        
        // 2. 使用 ShellConfigService 更新 Shell 配置
        let updateResult = shellConfigService.updateShellConfig(
            baseURL: testURL,
            token: testToken,
            configPath: tempShellConfigPath
        )
        
        // 验证更新成功
        switch updateResult {
        case .success:
            // 更新成功，继续测试
            break
        case .failure(let error):
            XCTFail("Shell 配置更新失败: \(error.localizedDescription)")
            return
        }
        
        // 3. 验证配置文件内容
        do {
            let content = try String(contentsOfFile: tempShellConfigPath, encoding: .utf8)
            
            // 验证环境变量设置
            XCTAssertTrue(content.contains("export CLAUDE_API_URL=\"\(testURL)\""))
            XCTAssertTrue(content.contains("export CLAUDE_API_KEY=\"\(testToken)\""))
        } catch {
            XCTFail("读取 Shell 配置文件失败: \(error.localizedDescription)")
        }
        
        // 4. 直接设置环境变量
        let directResult = shellConfigService.setEnvironmentVariablesDirectly(
            baseURL: testURL,
            token: testToken
        )
        
        // 验证直接设置成功
        switch directResult {
        case .success:
            // 设置成功
            break
        case .failure(let error):
            XCTFail("直接设置环境变量失败: \(error.localizedDescription)")
        }
        
        // 5. 检查环境变量是否已设置
        let isSet = shellConfigService.checkEnvironmentVariables(
            baseURL: testURL,
            token: testToken
        )
        
        // 验证环境变量已正确设置
        XCTAssertTrue(isSet)
    }
    
    /// 测试 AppViewModel 与环境服务的集成
    func testAppViewModelWithEnvironmentServices() {
        // 1. 创建 AppViewModel 实例
        let mockConfigStore = MockConfigurationStore()
        let appViewModel = AppViewModel(
            configurationStore: mockConfigStore,
            environmentService: environmentService,
            shellConfigService: shellConfigService,
            validationService: ValidationService(),
            notificationService: MockNotificationService()
        )
        
        // 2. 创建测试配置
        let testConfig = ConfigurationModel.custom(
            name: "Test Config",
            baseURL: "https://test.api.com",
            token: "sk-test123"
        )
        
        // 设置 mock 存储返回值
        mockConfigStore.setActiveConfigurationResult = .success(testConfig)
        
        // 3. 切换到测试配置
        let switchResult = appViewModel.switchToConfiguration(testConfig)
        
        // 验证切换成功
        switch switchResult {
        case .success:
            // 切换成功，继续测试
            break
        case .failure(let error):
            XCTFail("配置切换失败: \(error.localizedDescription)")
            return
        }
        
        // 4. 验证环境变量已更新
        let (baseURL, token) = environmentService.getCurrentEnvironmentVariables()
        XCTAssertEqual(baseURL, testConfig.baseURL)
        XCTAssertEqual(token, testConfig.token)
        
        // 5. 重置为默认配置
        mockConfigStore.resetToDefaultResult = .success(ConfigurationModel.official())
        
        let resetResult = appViewModel.resetToDefault()
        
        // 验证重置成功
        switch resetResult {
        case .success:
            // 重置成功，继续测试
            break
        case .failure(let error):
            XCTFail("重置为默认配置失败: \(error.localizedDescription)")
            return
        }
        
        // 6. 验证环境变量已重置
        let (resetBaseURL, resetToken) = environmentService.getCurrentEnvironmentVariables()
        XCTAssertEqual(resetBaseURL, "https://api.anthropic.com")
        XCTAssertEqual(resetToken, "")
    }
}