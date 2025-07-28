import XCTest
@testable import ccswitch

final class NotificationServiceTests: XCTestCase {
    
    var notificationService: MockNotificationService!
    
    override func setUp() {
        super.setUp()
        notificationService = MockNotificationService()
    }
    
    override func tearDown() {
        notificationService = nil
        super.tearDown()
    }
    
    // 测试发送通知
    func testSendNotification() {
        // 设置测试数据
        let title = "测试标题"
        let message = "测试消息"
        let type: NotificationType = .info
        
        // 执行发送通知
        var completionCalled = false
        var completionResult: Result<Void, NotificationServiceError>?
        
        notificationService.sendNotification(title: title, message: message, type: type) { result in
            completionCalled = true
            completionResult = result
        }
        
        // 验证结果
        XCTAssertTrue(notificationService.sendNotificationCalled)
        XCTAssertEqual(notificationService.lastTitle, title)
        XCTAssertEqual(notificationService.lastMessage, message)
        XCTAssertEqual(notificationService.lastType, type)
        XCTAssertTrue(completionCalled)
        
        if case .success = completionResult {
            // 成功，符合预期
        } else {
            XCTFail("发送通知应该成功")
        }
    }
    
    // 测试发送配置切换成功通知
    func testSendConfigurationSwitchSuccessNotification() {
        // 设置测试数据
        let configName = "测试配置"
        
        // 执行发送通知
        notificationService.sendConfigurationSwitchSuccessNotification(configName: configName)
        
        // 验证结果
        XCTAssertTrue(notificationService.sendConfigurationSwitchSuccessCalled)
        XCTAssertEqual(notificationService.lastConfigName, configName)
        XCTAssertTrue(notificationService.sendNotificationCalled)
        XCTAssertEqual(notificationService.lastTitle, "配置切换成功")
        XCTAssertEqual(notificationService.lastMessage, "已切换到配置: \(configName)")
        XCTAssertEqual(notificationService.lastType, .success)
    }
    
    // 测试发送配置切换失败通知
    func testSendConfigurationSwitchFailedNotification() {
        // 设置测试数据
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "测试错误"])
        
        // 执行发送通知
        notificationService.sendConfigurationSwitchFailedNotification(error: error)
        
        // 验证结果
        XCTAssertTrue(notificationService.sendConfigurationSwitchFailedCalled)
        XCTAssertEqual((notificationService.lastError as NSError?)?.domain, "test")
        XCTAssertTrue(notificationService.sendNotificationCalled)
        XCTAssertEqual(notificationService.lastTitle, "配置切换失败")
        XCTAssertEqual(notificationService.lastMessage, "测试错误")
        XCTAssertEqual(notificationService.lastType, .error)
    }
    
    // 测试发送重置成功通知
    func testSendResetSuccessNotification() {
        // 执行发送通知
        notificationService.sendResetSuccessNotification()
        
        // 验证结果
        XCTAssertTrue(notificationService.sendResetSuccessCalled)
        XCTAssertTrue(notificationService.sendNotificationCalled)
        XCTAssertEqual(notificationService.lastTitle, "重置成功")
        XCTAssertEqual(notificationService.lastMessage, "已重置为官方默认配置")
        XCTAssertEqual(notificationService.lastType, .success)
    }
    
    // 测试发送重置失败通知
    func testSendResetFailedNotification() {
        // 设置测试数据
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "重置错误"])
        
        // 执行发送通知
        notificationService.sendResetFailedNotification(error: error)
        
        // 验证结果
        XCTAssertTrue(notificationService.sendResetFailedCalled)
        XCTAssertEqual((notificationService.lastError as NSError?)?.domain, "test")
        XCTAssertTrue(notificationService.sendNotificationCalled)
        XCTAssertEqual(notificationService.lastTitle, "重置失败")
        XCTAssertEqual(notificationService.lastMessage, "重置错误")
        XCTAssertEqual(notificationService.lastType, .error)
    }
    
    // 测试发送错误通知
    func testSendErrorNotification() {
        // 设置测试数据
        let title = "错误标题"
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "一般错误"])
        
        // 执行发送通知
        notificationService.sendErrorNotification(title: title, error: error)
        
        // 验证结果
        XCTAssertTrue(notificationService.sendErrorNotificationCalled)
        XCTAssertEqual(notificationService.lastTitle, title)
        XCTAssertEqual((notificationService.lastError as NSError?)?.domain, "test")
        XCTAssertTrue(notificationService.sendNotificationCalled)
        XCTAssertEqual(notificationService.lastMessage, "一般错误")
        XCTAssertEqual(notificationService.lastType, .error)
    }
    
    // 测试通知权限被拒绝的情况
    func testNotificationPermissionDenied() {
        // 设置模拟通知权限被拒绝
        notificationService.mockPermissionDenied = true
        
        // 执行发送通知
        var completionCalled = false
        var completionResult: Result<Void, NotificationServiceError>?
        
        notificationService.sendNotification(title: "测试", message: "测试") { result in
            completionCalled = true
            completionResult = result
        }
        
        // 验证结果
        XCTAssertTrue(completionCalled)
        
        if case .failure(let error) = completionResult {
            XCTAssertEqual(error, NotificationServiceError.permissionDenied)
        } else {
            XCTFail("权限被拒绝时应该返回失败")
        }
    }
    
    // 测试通知发送失败的情况
    func testNotificationSendFailed() {
        // 设置模拟通知发送失败
        notificationService.mockSendFailed = true
        notificationService.mockErrorMessage = "发送失败原因"
        
        // 执行发送通知
        var completionCalled = false
        var completionResult: Result<Void, NotificationServiceError>?
        
        notificationService.sendNotification(title: "测试", message: "测试") { result in
            completionCalled = true
            completionResult = result
        }
        
        // 验证结果
        XCTAssertTrue(completionCalled)
        
        if case .failure(let error) = completionResult {
            if case .sendFailed(let message) = error {
                XCTAssertEqual(message, "发送失败原因")
            } else {
                XCTFail("应该返回 sendFailed 错误")
            }
        } else {
            XCTFail("发送失败时应该返回失败")
        }
    }
}

// MARK: - Mock NotificationService

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
    
    var mockPermissionDenied = false
    var mockSendFailed = false
    var mockErrorMessage = ""
    
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
        
        if mockPermissionDenied {
            completion?(.failure(.permissionDenied))
        } else if mockSendFailed {
            completion?(.failure(.sendFailed(mockErrorMessage)))
        } else {
            completion?(.success(()))
        }
    }
    
    override func sendConfigurationSwitchSuccessNotification(configName: String) {
        sendConfigurationSwitchSuccessCalled = true
        lastConfigName = configName
        super.sendConfigurationSwitchSuccessNotification(configName: configName)
    }
    
    override func sendConfigurationSwitchFailedNotification(error: Error) {
        sendConfigurationSwitchFailedCalled = true
        lastError = error
        super.sendConfigurationSwitchFailedNotification(error: error)
    }
    
    override func sendResetSuccessNotification() {
        sendResetSuccessCalled = true
        super.sendResetSuccessNotification()
    }
    
    override func sendResetFailedNotification(error: Error) {
        sendResetFailedCalled = true
        lastError = error
        super.sendResetFailedNotification(error: error)
    }
    
    override func sendErrorNotification(title: String, error: Error) {
        sendErrorNotificationCalled = true
        lastTitle = title
        lastError = error
        super.sendErrorNotification(title: title, error: error)
    }
}