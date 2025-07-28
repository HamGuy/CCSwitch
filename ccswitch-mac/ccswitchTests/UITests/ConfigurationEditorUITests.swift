import XCTest
@testable import ccswitch

class ConfigurationEditorUITests: BaseUITests {
    
    // Helper method to open the configuration editor
    func openConfigurationEditor() -> Bool {
        // First open the menu
        guard openMenuBarMenu() else {
            XCTFail("Failed to open menu bar menu")
            return false
        }
        
        // Click on the Add Configuration option
        let addConfigOption = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Add Configuration")).firstMatch
        guard addConfigOption.exists else {
            XCTFail("Add Configuration option not found")
            return false
        }
        
        addConfigOption.click()
        
        // Wait for the configuration editor window to appear
        let editorWindow = app.windows.containing(NSPredicate(format: "title CONTAINS %@", "添加新配置")).firstMatch
        let windowPredicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: windowPredicate, object: editorWindow)
        let result = XCTWaiter.wait(for: [expectation], timeout: 3.0)
        
        return result == .completed
    }
    
    func testConfigurationEditorOpens() {
        // Test that the configuration editor window opens correctly
        XCTAssertTrue(openConfigurationEditor(), "Configuration editor should open")
        
        // Verify that the editor window contains the expected elements
        let editorWindow = app.windows.element(boundBy: 0)
        XCTAssertTrue(editorWindow.exists, "Editor window should exist")
        
        // Check for form fields
        let nameField = editorWindow.textFields["请输入配置名称"]
        XCTAssertTrue(nameField.exists, "Name field should exist")
        
        let typeSegment = editorWindow.segmentedControls.firstMatch
        XCTAssertTrue(typeSegment.exists, "Configuration type segmented control should exist")
        
        let urlField = editorWindow.textFields["请输入 API URL"]
        XCTAssertTrue(urlField.exists, "URL field should exist")
        
        let tokenField = editorWindow.secureTextFields["请输入 API Token"]
        XCTAssertTrue(tokenField.exists, "Token field should exist")
        
        // Check for buttons
        let saveButton = editorWindow.buttons["保存"]
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        
        let cancelButton = editorWindow.buttons["取消"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist")
    }
    
    func testConfigurationTypeSelection() {
        // Test that selecting different configuration types updates the URL field
        XCTAssertTrue(openConfigurationEditor(), "Configuration editor should open")
        
        let editorWindow = app.windows.element(boundBy: 0)
        let typeSegment = editorWindow.segmentedControls.firstMatch
        let urlField = editorWindow.textFields["请输入 API URL"]
        
        // Check initial URL value
        let initialURL = urlField.value as? String
        
        // Select a different configuration type
        if typeSegment.buttons.count > 1 {
            // Click on the second segment (assuming it's different from the initial selection)
            typeSegment.buttons.element(boundBy: 1).click()
            
            // Wait a moment for the URL to update
            Thread.sleep(forTimeInterval: 0.5)
            
            // Check that the URL has changed
            let newURL = urlField.value as? String
            XCTAssertNotEqual(initialURL, newURL, "URL should change when configuration type changes")
            
            // Check that the URL field is disabled for preset configurations
            XCTAssertFalse(urlField.isEnabled, "URL field should be disabled for preset configurations")
        }
        
        // Select custom configuration type
        let customButton = typeSegment.buttons["custom"]
        if customButton.exists {
            customButton.click()
            
            // Wait a moment for the URL to update
            Thread.sleep(forTimeInterval: 0.5)
            
            // Check that the URL field is enabled for custom configurations
            XCTAssertTrue(urlField.isEnabled, "URL field should be enabled for custom configurations")
        }
    }
    
    func testValidationFeedback() {
        // Test that validation errors are displayed correctly
        XCTAssertTrue(openConfigurationEditor(), "Configuration editor should open")
        
        let editorWindow = app.windows.element(boundBy: 0)
        let nameField = editorWindow.textFields["请输入配置名称"]
        let typeSegment = editorWindow.segmentedControls.firstMatch
        let urlField = editorWindow.textFields["请输入 API URL"]
        let tokenField = editorWindow.secureTextFields["请输入 API Token"]
        let saveButton = editorWindow.buttons["保存"]
        
        // Select custom configuration type to enable URL field
        let customButton = typeSegment.buttons["custom"]
        if customButton.exists {
            customButton.click()
        }
        
        // Try to save with empty fields
        saveButton.click()
        
        // Check for validation error messages
        let errorTexts = editorWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "不能为空"))
        XCTAssertTrue(errorTexts.count > 0, "Validation error messages should be displayed")
        
        // Enter invalid URL
        urlField.click()
        urlField.typeText("invalid-url")
        
        // Enter invalid token
        tokenField.click()
        tokenField.typeText("invalid-token")
        
        // Check for URL validation error
        let urlError = editorWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "API URL 必须是有效的")).firstMatch
        XCTAssertTrue(urlError.exists, "URL validation error should be displayed")
        
        // Check for token validation error
        let tokenError = editorWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "API Token 必须以 sk-")).firstMatch
        XCTAssertTrue(tokenError.exists, "Token validation error should be displayed")
        
        // Check that save button is disabled
        XCTAssertFalse(saveButton.isEnabled, "Save button should be disabled when validation fails")
    }
    
    func testCancelButton() {
        // Test that the cancel button closes the editor without saving
        XCTAssertTrue(openConfigurationEditor(), "Configuration editor should open")
        
        let editorWindow = app.windows.element(boundBy: 0)
        let nameField = editorWindow.textFields["请输入配置名称"]
        let cancelButton = editorWindow.buttons["取消"]
        
        // Enter some text in the name field
        nameField.click()
        nameField.typeText("Test Configuration")
        
        // Click cancel
        cancelButton.click()
        
        // Wait for the editor to close
        Thread.sleep(forTimeInterval: 0.5)
        
        // Check that the editor window is closed
        XCTAssertFalse(editorWindow.exists, "Editor window should be closed after clicking cancel")
        
        // Reopen the menu and check that the new configuration was not added
        XCTAssertTrue(openMenuBarMenu(), "Menu should reopen")
        
        let testConfig = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Test Configuration")).firstMatch
        XCTAssertFalse(testConfig.exists, "Test configuration should not exist after canceling")
    }
    
    func testCreateNewConfiguration() {
        // Test creating a new configuration
        XCTAssertTrue(openConfigurationEditor(), "Configuration editor should open")
        
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
        nameField.typeText("UI Test Config")
        
        urlField.click()
        urlField.typeText("https://api.example.com")
        
        tokenField.click()
        tokenField.typeText("sk-test-token-12345678901234567890")
        
        // Click save
        saveButton.click()
        
        // Wait for the editor to close
        Thread.sleep(forTimeInterval: 0.5)
        
        // Check that the editor window is closed
        XCTAssertFalse(editorWindow.exists, "Editor window should be closed after saving")
        
        // Reopen the menu and check that the new configuration was added
        XCTAssertTrue(openMenuBarMenu(), "Menu should reopen")
        
        let testConfig = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "UI Test Config")).firstMatch
        XCTAssertTrue(testConfig.exists, "New configuration should exist after saving")
    }
    
    func testEditExistingConfiguration() {
        // First create a configuration to edit
        testCreateNewConfiguration()
        
        // Find and right-click the test configuration
        let testConfig = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "UI Test Config")).firstMatch
        XCTAssertTrue(testConfig.exists, "Test configuration should exist")
        
        testConfig.rightClick()
        
        // Click on the Edit option
        let editOption = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Edit")).firstMatch
        XCTAssertTrue(editOption.exists, "Edit option should exist")
        editOption.click()
        
        // Wait for the editor window to appear
        let editorWindow = app.windows.containing(NSPredicate(format: "title CONTAINS %@", "编辑配置")).firstMatch
        let windowPredicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: windowPredicate, object: editorWindow)
        let result = XCTWaiter.wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(result, .completed, "Editor window should appear")
        
        // Modify the configuration name
        let nameField = editorWindow.textFields.firstMatch
        nameField.click()
        nameField.deleteText()
        nameField.typeText("Updated UI Test Config")
        
        // Save the changes
        let saveButton = editorWindow.buttons["保存"]
        saveButton.click()
        
        // Wait for the editor to close
        Thread.sleep(forTimeInterval: 0.5)
        
        // Reopen the menu and check that the configuration was updated
        XCTAssertTrue(openMenuBarMenu(), "Menu should reopen")
        
        let updatedConfig = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Updated UI Test Config")).firstMatch
        XCTAssertTrue(updatedConfig.exists, "Updated configuration should exist after saving")
    }
    
    func testDeleteConfiguration() {
        // First create a configuration to delete
        testCreateNewConfiguration()
        
        // Find and right-click the test configuration
        let testConfig = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "UI Test Config")).firstMatch
        XCTAssertTrue(testConfig.exists, "Test configuration should exist")
        
        testConfig.rightClick()
        
        // Click on the Edit option
        let editOption = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Edit")).firstMatch
        XCTAssertTrue(editOption.exists, "Edit option should exist")
        editOption.click()
        
        // Wait for the editor window to appear
        let editorWindow = app.windows.containing(NSPredicate(format: "title CONTAINS %@", "编辑配置")).firstMatch
        let windowPredicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: windowPredicate, object: editorWindow)
        let result = XCTWaiter.wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(result, .completed, "Editor window should appear")
        
        // Click the delete button
        let deleteButton = editorWindow.buttons["删除"]
        XCTAssertTrue(deleteButton.exists, "Delete button should exist")
        deleteButton.click()
        
        // Wait for the confirmation dialog
        let confirmDialog = app.dialogs.containing(NSPredicate(format: "label CONTAINS %@", "确认删除")).firstMatch
        let dialogPredicate = NSPredicate(format: "exists == true")
        let dialogExpectation = XCTNSPredicateExpectation(predicate: dialogPredicate, object: confirmDialog)
        let dialogResult = XCTWaiter.wait(for: [dialogExpectation], timeout: 3.0)
        XCTAssertEqual(dialogResult, .completed, "Confirmation dialog should appear")
        
        // Click the delete button in the confirmation dialog
        let confirmDeleteButton = confirmDialog.buttons["删除"]
        XCTAssertTrue(confirmDeleteButton.exists, "Confirm delete button should exist")
        confirmDeleteButton.click()
        
        // Wait for the editor to close
        Thread.sleep(forTimeInterval: 0.5)
        
        // Reopen the menu and check that the configuration was deleted
        XCTAssertTrue(openMenuBarMenu(), "Menu should reopen")
        
        let deletedConfig = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "UI Test Config")).firstMatch
        XCTAssertFalse(deletedConfig.exists, "Deleted configuration should not exist")
    }
}

extension XCUIElement {
    func deleteText() {
        guard let stringValue = self.value as? String else {
            return
        }
        
        // Select all text
        self.typeText(XCUIKeyboardKey.command.rawValue + "a")
        
        // Delete the selected text
        self.typeText(XCUIKeyboardKey.delete.rawValue)
    }
}