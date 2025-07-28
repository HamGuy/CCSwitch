import XCTest
@testable import ccswitch

class BaseUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDown() {
        app.terminate()
        super.tearDown()
    }
    
    // Helper method to find the menu bar icon
    func findMenuBarIcon() -> XCUIElement? {
        let menuBars = XCUIApplication(bundleIdentifier: "com.apple.systemuiserver").menuBars
        return menuBars.buttons["CCSwitch"]
    }
    
    // Helper method to click the menu bar icon and wait for the menu to appear
    func openMenuBarMenu() -> Bool {
        guard let menuBarIcon = findMenuBarIcon() else {
            XCTFail("Menu bar icon not found")
            return false
        }
        
        menuBarIcon.click()
        // Wait a moment for the menu to appear
        Thread.sleep(forTimeInterval: 0.5)
        return true
    }
    
    // Helper method to wait for a notification to appear
    func waitForNotification(containing text: String, timeout: TimeInterval = 5.0) -> Bool {
        let notification = app.otherElements.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        let notificationPredicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: notificationPredicate, object: notification)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    // Helper method to wait for a window to appear
    func waitForWindow(containing title: String, timeout: TimeInterval = 3.0) -> Bool {
        let window = app.windows.containing(NSPredicate(format: "title CONTAINS %@", title)).firstMatch
        let windowPredicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: windowPredicate, object: window)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    // Helper method to wait for an alert to appear
    func waitForAlert(containing title: String, timeout: TimeInterval = 3.0) -> Bool {
        let alert = app.alerts.containing(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        let alertPredicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: alertPredicate, object: alert)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    // Helper method to create a test configuration
    func createTestConfiguration(name: String = "UI Test Config") -> Bool {
        // Open the menu
        guard openMenuBarMenu() else {
            return false
        }
        
        // Click on the Add Configuration option
        let addConfigOption = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Add Configuration")).firstMatch
        guard addConfigOption.exists else {
            return false
        }
        
        addConfigOption.click()
        
        // Wait for the configuration editor window to appear
        guard waitForWindow(containing: "添加新配置") else {
            return false
        }
        
        let editorWindow = app.windows.element(boundBy: 0)
        let nameField = editorWindow.textFields["请输入配置名称"]
        let typeSegment = editorWindow.segmentedControls.firstMatch
        let urlField = editorWindow.textFields["请输入 API URL"]
        let tokenField = editorWindow.secureTextFields["请输入 API Token"]
        let saveButton = editorWindow.buttons["保存"]
        
        // Select custom configuration type
        let customButton = typeSegment.buttons["custom"]
        if customButton.exists {
            customButton.click()
        }
        
        // Enter valid configuration details
        nameField.click()
        nameField.typeText(name)
        
        urlField.click()
        urlField.typeText("https://api.example.com")
        
        tokenField.click()
        tokenField.typeText("sk-test-token-12345678901234567890")
        
        // Click save
        saveButton.click()
        
        // Wait for the editor to close
        Thread.sleep(forTimeInterval: 0.5)
        
        return true
    }
    
    // Helper method to delete a test configuration
    func deleteTestConfiguration(name: String = "UI Test Config") -> Bool {
        // Open the menu
        guard openMenuBarMenu() else {
            return false
        }
        
        // Find the test configuration
        let testConfig = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        guard testConfig.exists else {
            return false
        }
        
        // Right-click on the configuration
        testConfig.rightClick()
        
        // Click on the Delete option
        let deleteOption = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Delete")).firstMatch
        guard deleteOption.exists else {
            return false
        }
        
        deleteOption.click()
        
        // Wait for and confirm the deletion
        guard waitForAlert(containing: "确认删除") else {
            return false
        }
        
        let confirmDeleteButton = app.alerts.buttons["删除"]
        guard confirmDeleteButton.exists else {
            return false
        }
        
        confirmDeleteButton.click()
        
        return true
    }
}