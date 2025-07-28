import XCTest
@testable import ccswitch

class MenuBarUITests: BaseUITests {
    
    func testMenuBarIconExists() {
        // Test that the menu bar icon is displayed
        let menuBarIcon = findMenuBarIcon()
        XCTAssertNotNil(menuBarIcon, "Menu bar icon should be visible")
    }
    
    func testMenuDisplaysOnClick() {
        // Test that clicking the menu bar icon displays the dropdown menu
        XCTAssertTrue(openMenuBarMenu(), "Menu should open when icon is clicked")
        
        // Verify that the menu contains expected items
        let menuItems = app.menuItems
        XCTAssertTrue(menuItems.count > 0, "Menu should contain items")
        
        // Check for specific menu sections (current configuration, presets, etc.)
        let currentConfigSection = menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Current Configuration")).firstMatch
        XCTAssertTrue(currentConfigSection.exists, "Menu should show current configuration section")
    }
    
    func testConfigurationGrouping() {
        // Test that configurations are properly grouped in the menu
        XCTAssertTrue(openMenuBarMenu(), "Menu should open when icon is clicked")
        
        // Check for preset configurations section
        let presetSection = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Preset Configurations")).firstMatch
        XCTAssertTrue(presetSection.exists, "Menu should show preset configurations section")
        
        // Check for custom configurations section if any exist
        let customSection = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Custom Configurations")).firstMatch
        // This might not exist if no custom configurations have been added
        if customSection.exists {
            XCTAssertTrue(true, "Menu shows custom configurations section")
        }
    }
    
    func testActiveConfigurationMarking() {
        // Test that the active configuration is properly marked in the menu
        XCTAssertTrue(openMenuBarMenu(), "Menu should open when icon is clicked")
        
        // Find the active configuration (should have a checkmark)
        let activeConfig = app.menuItems.containing(NSPredicate(format: "value == 1")).firstMatch
        XCTAssertTrue(activeConfig.exists, "An active configuration should be marked")
    }
    
    func testManagementOptionsExist() {
        // Test that management options are displayed in the menu
        XCTAssertTrue(openMenuBarMenu(), "Menu should open when icon is clicked")
        
        // Check for management options section
        let managementSection = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Management Options")).firstMatch
        XCTAssertTrue(managementSection.exists, "Menu should show management options section")
        
        // Check for specific management options
        let addConfigOption = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Add Configuration")).firstMatch
        XCTAssertTrue(addConfigOption.exists, "Menu should show 'Add Configuration' option")
        
        let resetOption = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Reset to Default")).firstMatch
        XCTAssertTrue(resetOption.exists, "Menu should show 'Reset to Default' option")
        
        let quitOption = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Quit")).firstMatch
        XCTAssertTrue(quitOption.exists, "Menu should show 'Quit' option")
    }
    
    func testConfigurationSwitching() {
        // Test switching between configurations
        XCTAssertTrue(openMenuBarMenu(), "Menu should open when icon is clicked")
        
        // Find a non-active configuration to switch to
        let nonActiveConfigs = app.menuItems.containing(NSPredicate(format: "value == 0")).allElementsBoundByIndex
        
        // Skip test if there are no non-active configurations
        guard !nonActiveConfigs.isEmpty else {
            XCTAssertTrue(true, "No non-active configurations to test switching")
            return
        }
        
        // Get the name of the configuration before switching
        let activeConfigBefore = app.menuItems.containing(NSPredicate(format: "value == 1")).firstMatch
        let activeNameBefore = activeConfigBefore.label
        
        // Click on a non-active configuration to switch
        let configToSwitch = nonActiveConfigs[0]
        let newConfigName = configToSwitch.label
        configToSwitch.click()
        
        // Wait for the switch to complete and notification to appear
        let notificationPredicate = NSPredicate(format: "exists == true")
        let notification = app.otherElements.containing(NSPredicate(format: "label CONTAINS %@", "配置切换成功")).firstMatch
        
        // Use expectation for the notification to appear
        let expectation = XCTNSPredicateExpectation(predicate: notificationPredicate, object: notification)
        let result = XCTWaiter.wait(for: [expectation], timeout: 5.0)
        
        // Reopen the menu to check if the active configuration has changed
        XCTAssertTrue(openMenuBarMenu(), "Menu should reopen after switching configuration")
        
        // Find the new active configuration
        let activeConfigAfter = app.menuItems.containing(NSPredicate(format: "value == 1")).firstMatch
        let activeNameAfter = activeConfigAfter.label
        
        // Verify that the active configuration has changed
        XCTAssertNotEqual(activeNameBefore, activeNameAfter, "Active configuration should have changed")
    }
    
    func testResetToDefault() {
        // Test resetting to default configuration
        XCTAssertTrue(openMenuBarMenu(), "Menu should open when icon is clicked")
        
        // Click on the Reset to Default option
        let resetOption = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Reset to Default")).firstMatch
        XCTAssertTrue(resetOption.exists, "Reset to Default option should exist")
        resetOption.click()
        
        // Wait for the reset to complete and notification to appear
        let notificationPredicate = NSPredicate(format: "exists == true")
        let notification = app.otherElements.containing(NSPredicate(format: "label CONTAINS %@", "重置成功")).firstMatch
        
        // Use expectation for the notification to appear
        let expectation = XCTNSPredicateExpectation(predicate: notificationPredicate, object: notification)
        let result = XCTWaiter.wait(for: [expectation], timeout: 5.0)
        
        // Reopen the menu to check if the official configuration is now active
        XCTAssertTrue(openMenuBarMenu(), "Menu should reopen after resetting to default")
        
        // Find the active configuration
        let activeConfig = app.menuItems.containing(NSPredicate(format: "value == 1")).firstMatch
        
        // Verify that the active configuration is the official one
        XCTAssertTrue(activeConfig.label.contains("official") || activeConfig.label.contains("Official"), 
                     "Active configuration should be the official one after reset")
    }
    
    func testRightClickMenuOptions() {
        // Test right-click menu options on configuration items
        XCTAssertTrue(openMenuBarMenu(), "Menu should open when icon is clicked")
        
        // Find a configuration item
        let configItems = app.menuItems.matching(NSPredicate(format: "NOT (label CONTAINS %@)", "Management Options"))
                                      .matching(NSPredicate(format: "NOT (label CONTAINS %@)", "Current Configuration"))
                                      .matching(NSPredicate(format: "NOT (label CONTAINS %@)", "Preset Configurations"))
                                      .matching(NSPredicate(format: "NOT (label CONTAINS %@)", "Custom Configurations"))
                                      .matching(NSPredicate(format: "NOT (label CONTAINS %@)", "Quit"))
                                      .matching(NSPredicate(format: "NOT (label CONTAINS %@)", "Add Configuration"))
                                      .matching(NSPredicate(format: "NOT (label CONTAINS %@)", "Reset to Default"))
        
        // Skip test if there are no configuration items
        guard configItems.count > 0 else {
            XCTAssertTrue(true, "No configuration items to test right-click menu")
            return
        }
        
        // Right-click on the first configuration item
        let configItem = configItems.element(boundBy: 0)
        configItem.rightClick()
        
        // Check for Edit option in the context menu
        let editOption = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Edit")).firstMatch
        XCTAssertTrue(editOption.exists, "Context menu should show Edit option")
        
        // Check for Delete option in the context menu
        let deleteOption = app.menuItems.containing(NSPredicate(format: "label CONTAINS %@", "Delete")).firstMatch
        XCTAssertTrue(deleteOption.exists, "Context menu should show Delete option")
    }
}