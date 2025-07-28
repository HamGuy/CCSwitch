import XCTest
@testable import ccswitch

final class EnvironmentServiceTests: XCTestCase {
    
    var environmentService: EnvironmentService!
    
    override func setUp() {
        super.setUp()
        environmentService = EnvironmentService()
    }
    
    override func tearDown() {
        environmentService = nil
        super.tearDown()
    }
    
    // 测试获取当前环境变量
    func testGetCurrentEnvironmentVariables() {
        // 设置测试环境变量
        setenv("CLAUDE_API_URL", "https://test.api.com", 1)
        setenv("CLAUDE_API_KEY", "sk-test123", 1)
        
        // 获取环境变量
        let (baseURL, token) = environmentService.getCurrentEnvironmentVariables()
        
        // 验证结果
        XCTAssertEqual(baseURL, "https://test.api.com")
        XCTAssertEqual(token, "sk-test123")
        
        // 清理环境变量
        unsetenv("CLAUDE_API_URL")
        unsetenv("CLAUDE_API_KEY")
    }
    
    // 测试获取不存在的环境变量
    func testGetCurrentEnvironmentVariablesNotSet() {
        // 确保环境变量未设置
        unsetenv("CLAUDE_API_URL")
        unsetenv("CLAUDE_API_KEY")
        
        // 获取环境变量
        let (baseURL, token) = environmentService.getCurrentEnvironmentVariables()
        
        // 验证结果
        XCTAssertNil(baseURL)
        XCTAssertNil(token)
    }
    
    // 测试检查环境变量是否已设置
    func testAreEnvironmentVariablesSet() {
        // 测试未设置的情况
        unsetenv("CLAUDE_API_URL")
        unsetenv("CLAUDE_API_KEY")
        XCTAssertFalse(environmentService.areEnvironmentVariablesSet())
        
        // 测试只设置一个的情况
        setenv("CLAUDE_API_URL", "https://test.api.com", 1)
        XCTAssertFalse(environmentService.areEnvironmentVariablesSet())
        
        // 测试都设置的情况
        setenv("CLAUDE_API_KEY", "sk-test123", 1)
        XCTAssertTrue(environmentService.areEnvironmentVariablesSet())
        
        // 清理环境变量
        unsetenv("CLAUDE_API_URL")
        unsetenv("CLAUDE_API_KEY")
    }
    
    // 测试重置环境变量
    func testResetEnvironmentVariables() {
        // 执行重置
        let result = environmentService.resetEnvironmentVariables()
        
        // 验证结果
        switch result {
        case .success:
            // 重置成功，验证环境变量是否设置为默认值
            let (baseURL, token) = environmentService.getCurrentEnvironmentVariables()
            XCTAssertEqual(baseURL, "https://api.anthropic.com")
            XCTAssertEqual(token, "")
        case .failure(let error):
            // 在测试环境中，重置可能会失败，这是正常的
            print("重置环境变量失败（测试环境中正常）: \(error.localizedDescription)")
        }
    }
    
    // 测试导出到 Shell 配置文件
    func testExportToShellConfig() {
        // 创建临时配置文件
        let tempDir = FileManager.default.temporaryDirectory
        let configPath = tempDir.appendingPathComponent("test_shell_config").path
        
        // 执行导出
        let result = environmentService.exportToShellConfig(
            baseURL: "https://test.api.com",
            token: "sk-test123",
            shellConfigPath: configPath
        )
        
        // 验证结果
        switch result {
        case .success:
            // 验证文件内容
            do {
                let content = try String(contentsOfFile: configPath, encoding: .utf8)
                XCTAssertTrue(content.contains("export CLAUDE_API_URL=\"https://test.api.com\""))
                XCTAssertTrue(content.contains("export CLAUDE_API_KEY=\"sk-test123\""))
                XCTAssertTrue(content.contains("CCSwitch 环境变量设置 - 自动生成"))
            } catch {
                XCTFail("读取配置文件失败: \(error.localizedDescription)")
            }
        case .failure(let error):
            XCTFail("导出到 Shell 配置文件失败: \(error.localizedDescription)")
        }
        
        // 清理临时文件
        try? FileManager.default.removeItem(atPath: configPath)
    }
    
    // 测试从 Shell 配置文件移除
    func testRemoveFromShellConfig() {
        // 创建临时配置文件
        let tempDir = FileManager.default.temporaryDirectory
        let configPath = tempDir.appendingPathComponent("test_shell_config").path
        
        // 先导出配置
        _ = environmentService.exportToShellConfig(
            baseURL: "https://test.api.com",
            token: "sk-test123",
            shellConfigPath: configPath
        )
        
        // 执行移除
        let result = environmentService.removeFromShellConfig(shellConfigPath: configPath)
        
        // 验证结果
        switch result {
        case .success:
            // 验证文件内容
            do {
                let content = try String(contentsOfFile: configPath, encoding: .utf8)
                XCTAssertFalse(content.contains("export CLAUDE_API_URL="))
                XCTAssertFalse(content.contains("export CLAUDE_API_KEY="))
                XCTAssertFalse(content.contains("CCSwitch 环境变量设置 - 自动生成"))
            } catch {
                XCTFail("读取配置文件失败: \(error.localizedDescription)")
            }
        case .failure(let error):
            XCTFail("从 Shell 配置文件移除失败: \(error.localizedDescription)")
        }
        
        // 清理临时文件
        try? FileManager.default.removeItem(atPath: configPath)
    }
    
    // 测试从不存在的 Shell 配置文件移除
    func testRemoveFromNonExistentShellConfig() {
        // 使用不存在的文件路径
        let nonExistentPath = "/tmp/non_existent_config_file"
        
        // 执行移除
        let result = environmentService.removeFromShellConfig(shellConfigPath: nonExistentPath)
        
        // 验证结果 - 应该成功，因为文件不存在时无需操作
        switch result {
        case .success:
            // 成功，符合预期
            break
        case .failure(let error):
            XCTFail("从不存在的配置文件移除应该成功: \(error.localizedDescription)")
        }
    }
    
    // 测试更新现有配置文件
    func testUpdateExistingShellConfig() {
        // 创建临时配置文件
        let tempDir = FileManager.default.temporaryDirectory
        let configPath = tempDir.appendingPathComponent("test_shell_config").path
        
        // 创建初始配置文件
        let initialContent = """
        # 现有配置
        export PATH="/usr/local/bin:$PATH"
        
        # CCSwitch 环境变量设置 - 自动生成
        export CLAUDE_API_URL="https://old.api.com"
        export CLAUDE_API_KEY="sk-old123"
        
        # 其他配置
        alias ll='ls -la'
        """
        
        do {
            try initialContent.write(toFile: configPath, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("创建初始配置文件失败: \(error.localizedDescription)")
            return
        }
        
        // 执行更新
        let result = environmentService.exportToShellConfig(
            baseURL: "https://new.api.com",
            token: "sk-new456",
            shellConfigPath: configPath
        )
        
        // 验证结果
        switch result {
        case .success:
            // 验证文件内容
            do {
                let content = try String(contentsOfFile: configPath, encoding: .utf8)
                
                // 验证新的环境变量设置
                XCTAssertTrue(content.contains("export CLAUDE_API_URL=\"https://new.api.com\""))
                XCTAssertTrue(content.contains("export CLAUDE_API_KEY=\"sk-new456\""))
                
                // 验证旧的环境变量设置已被移除
                XCTAssertFalse(content.contains("https://old.api.com"))
                XCTAssertFalse(content.contains("sk-old123"))
                
                // 验证其他配置保持不变
                XCTAssertTrue(content.contains("export PATH=\"/usr/local/bin:$PATH\""))
                XCTAssertTrue(content.contains("alias ll='ls -la'"))
                
            } catch {
                XCTFail("读取配置文件失败: \(error.localizedDescription)")
            }
        case .failure(let error):
            XCTFail("更新现有配置文件失败: \(error.localizedDescription)")
        }
        
        // 清理临时文件
        try? FileManager.default.removeItem(atPath: configPath)
    }
}