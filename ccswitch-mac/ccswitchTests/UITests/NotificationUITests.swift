import XCTest
@testable import ccswitch

class NotificationUITests: BaseUITests {
    
    func testConfigurationSwitchSuccessNotification() {
        // Test that a success notification appears when switching configurations
        XCTAssertTrue(openMenuBarMenu(), "Menu should open when icon is clicked")
        
        // Find a non-active configuration to switch to
        let nonActiveConfigs = app.menuItems.containing(NSPredicate(format: "value == 0")).allElementsBoundByIndex
        
        // Skip test if there are no non-active configurations
        guard !nonActiveConfigs.isEmpty else {
            XCTAssertTrue(true, "No non-active configurations to test switching")
            return
        }
        
        // Click on a non-active configuration to switch
        let configToSwitch = nonActiveConfigs[0]
        configToSwitch.click()
        
        // Wait for the notification to appear
        let notification = app.otherElements.containing(NSPredicate(format: "label CONTAINS %@", "配置切换成功")).firstMatch
        let notificationPredicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: notificationPredicate, object: notification)
        let result = XCTWaiter.wait(for: [expectation], timeout: 5.0)
        
        XCTAssertEqual(result, .completed, "Success notification should appear after switching configuration")
    }
    
    func testResetSuccessNotification() {
        // Test that a success notification appears when resetting to default
        XCTAssertTrue(openMenuBarMenu(), "Menu should open when icon is clicked")
        
        // Click on the Reset to Default option
        let resetOption = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Reset to Default")).firstMatch
        XCTAssertTrue(resetOption.exists, "Reset to Default option should exist")
        resetOption.click()
        
        // Wait for the notification to appear
        let notification = app.otherElements.containing(NSPredicate(format: "label CONTAINS %@", "重置成功")).firstMatch
        let notificationPredicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: notificationPredicate, object: notification)
        let result = XCTWaiter.wait(for: [expectation], timeout: 5.0)
        
        XCTAssertEqual(result, .completed, "Success notification should appear after resetting to default")
    }
    
    func testInvalidConfigurationValidation() {
        // Test validation error feedback when creating an invalid configuration
        XCTAssertTrue(openMenuBarMenu(), "Menu should open when icon is clicked")
        
        // Click on the Add Configuration option
        let addConfigOption = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Add Configuration")).firstMatch
        XCTAssertTrue(addConfigOption.exists, "Add Configuration option should exist")
        addConfigOption.click()
        
        // Wait for the configuration editor window to appear
        let editorWindow = app.windows.containing(NSPredicate(format: "title CONTAINS %@", "添加新配置")).firstMatch
        let windowPredicate = NSPredicate(format: "exists == true")
        let windowExpectation = XCTNSPredicateExpectation(predicate: windowPredicate, object: editorWindow)
        let windowResult = XCTWaiter.wait(for: [windowExpectation], timeout: 3.0)
        XCTAssertEqual(windowResult, .completed, "Editor window should appear")
        
        // Select custom configuration type
        let typeSegment = editorWindow.segmentedControls.firstMatch
        let customButton = typeSegment.buttons["custom"]
        if customButton.exists {
            customButton.click()
        }
        
        // Enter invalid configuration details
        let nameField = editorWindow.textFields["请输入配置名称"]
        nameField.click()
        nameField.typeText("Invalid Config")
        
        let urlField = editorWindow.textFields["请输入 API URL"]
        urlField.click()
        urlField.typeText("invalid-url")
        
        let tokenField = editorWindow.secureTextFields["请输入 API Token"]
        tokenField.click()
        tokenField.typeText("invalid-token")
        
        // Check for validation error messages
        let urlError = editorWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "API URL 必须是有效的")).firstMatch
        XCTAssertTrue(urlError.exists, "URL validation error should be displayed")
        
        let tokenError = editorWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "API Token 必须以 sk-")).firstMatch
        XCTAssertTrue(tokenError.exists, "Token validation error should be displayed")
        
        // Check that save button is disabled
        let saveButton = editorWindow.buttons["保存"]
        XCTAssertFalse(saveButton.isEnabled, "Save button should be disabled when validation fails")
    }
    
    func testDeleteProtectionForPresetConfigurations() {
        // Test that preset configurations cannot be deleted
        XCTAssertTrue(openMenuBarMenu(), "Menu should open when icon is clicked")
        
        // Find a preset configuration
        let presetSection = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Preset Configurations")).firstMatch
        XCTAssertTrue(presetSection.exists, "Preset configurations section should exist")
        
        // Get the first preset configuration after the section header
        let presetIndex = app.menuItems.allElementsBoundByIndex.firstIndex(of: presetSection)
        guard let index = presetIndex, index + 1 < app.menuItems.count else {
            XCTAssertTrue(true, "No preset configurations found")
            return
        }
        
        let presetConfig = app.menuItems.element(boundBy: index + 1)
        presetConfig.rightClick()
        
        // Click on the Edit option
        let editOption = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Edit")).firstMatch
        XCTAssertTrue(editOption.exists, "Edit option should exist")
        editOption.click()
        
        // Wait for the editor window to appear
        let editorWindow = app.windows.containing(NSPredicate(format: "title CONTAINS %@", "编辑配置")).firstMatch
        let windowPredicate = NSPredicate(format: "exists == true")
        let windowExpectation = XCTNSPredicateExpectation(predicate: windowPredicate, object: editorWindow)
        let windowResult = XCTWaiter.wait(for: [windowExpectation], timeout: 3.0)
        XCTAssertEqual(windowResult, .completed, "Editor window should appear")
        
        // Check that the delete button is disabled or not present for preset configurations
        let deleteButton = editorWindow.buttons["删除"]
        if deleteButton.exists {
            XCTAssertFalse(deleteButton.isEnabled, "Delete button should be disabled for preset configurations")
        } else {
            XCTAssertTrue(true, "Delete button is not present for preset configurations")
        }
    }
    
    func testErrorHandlingForInvalidToken() {
        // Create a test for handling invalid token errors
        // This is a more complex test that would require mocking API responses
        // For UI testing purposes, we'll just verify that the validation works
        
        XCTAssertTrue(openMenuBarMenu(), "Menu should open when icon is clicked")
        
        // Click on the Add Configuration option
        let addConfigOption = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Add Configuration")).firstMatch
        XCTAssertTrue(addConfigOption.exists, "Add Configuration option should exist")
        addConfigOption.click()
        
        // Wait for the configuration editor window to appear
        let editorWindow = app.windows.containing(NSPredicate(format: "title CONTAINS %@", "添加新配置")).firstMatch
        let windowPredicate = NSPredicate(format: "exists == true")
        let windowExpectation = XCTNSPredicateExpectation(predicate: windowPredicate, object: editorWindow)
        let windowResult = XCTWaiter.wait(for: [windowExpectation], timeout: 3.0)
        XCTAssertEqual(windowResult, .completed, "Editor window should appear")
        
        // Enter a valid name and URL but an invalid token
        let nameField = editorWindow.textFields["请输入配置名称"]
        nameField.click()
        nameField.typeText("Test Config")
        
        let tokenField = editorWindow.secureTextFields["请输入 API Token"]
        tokenField.click()
        tokenField.typeText("invalid-token")
        
        // Check for token validation error
        let tokenError = editorWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "API Token 必须以 sk-")).firstMatch
        XCTAssertTrue(tokenError.exists, "Token validation error should be displayed")
    }
}