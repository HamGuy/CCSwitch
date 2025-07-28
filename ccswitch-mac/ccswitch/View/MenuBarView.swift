//
//  MenuBarView.swift
//  ccswitch
//
//  Created by Kiro on 2025/7/22.
//

import SwiftUI
import AppKit

/// 菜单栏视图控制器，负责管理菜单栏图标和下拉菜单
class MenuBarController: ObservableObject {
    /// 状态栏项
    var statusItem: NSStatusItem
    
    /// 菜单对象
    private var menu: NSMenu
    
    /// 应用视图模型
    private var viewModel: AppViewModel
    
    /// 初始化菜单栏控制器
    /// - Parameter viewModel: 应用视图模型
    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        
        // 创建状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        
        // 设置菜单属性，避免系统默认的蓝色样式
        menu.autoenablesItems = false
        
        // 设置菜单栏图标
        if let button = statusItem.button {
            // 尝试使用不同的图标源，找到最适合菜单栏的版本
            var menuBarImage: NSImage?
            
            // 尝试直接使用 16x16 的图标（最适合菜单栏）
            if let smallIcon = NSImage(named: "icon_16x16") {
                menuBarImage = smallIcon
            } else if let appIcon = NSImage(named: "AppIcon") {
                // 如果没有小图标，则从应用图标创建
                let resizedIcon = NSImage(size: NSSize(width: 16, height: 16))
                resizedIcon.lockFocus()
                appIcon.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16))
                resizedIcon.unlockFocus()
                menuBarImage = resizedIcon
            }
            
            if let image = menuBarImage {
                // 不设置为模板图标，保持原始颜色
                image.isTemplate = false
                button.image = image
            } else {
                // 后备选项：使用系统符号
                button.image = NSImage(systemSymbolName: "c.circle.fill", accessibilityDescription: "CCSwitch")
            }
            button.imagePosition = .imageLeft
        }
        
        // 设置观察者
        setupObservers()
        
        // 延迟设置菜单，确保配置已完全加载
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.setupMenu()
        }
    }
    
    /// 设置观察者
    private func setupObservers() {
        // 观察配置变化，更新菜单
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenu),
            name: NSNotification.Name("ConfigurationsDidChange"),
            object: nil
        )
        
        // 观察活动配置变化，更新当前配置显示
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateActiveConfiguration),
            name: NSNotification.Name("ActiveConfigurationDidChange"),
            object: nil
        )
    }
    
    // 缓存常用的字体和颜色，避免重复创建
    private lazy var boldSystemFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
    private lazy var smallSystemFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    private lazy var normalSystemFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    private lazy var labelColor = NSColor.labelColor
    private lazy var secondaryLabelColor = NSColor.secondaryLabelColor
    private lazy var accentColor = NSColor(Color.accentColor)
    
    // 缓存菜单项，避免频繁重建
    private var cachedMenuItems: [NSMenuItem] = []
    private var lastConfigCount = 0
    private var lastActiveConfigId: UUID?
    
    /// 设置菜单
    private func setupMenu() {
        // 检查是否需要完全重建菜单
        let currentConfigCount = viewModel.configurations.count
        let currentActiveConfigId = viewModel.activeConfiguration?.id
        let currentPresetCount = viewModel.presetConfigurations.count
        
        let needsFullRebuild = currentConfigCount != lastConfigCount || 
                              cachedMenuItems.isEmpty || 
                              currentPresetCount == 0 // 如果预设配置为空，强制重建
        
        if needsFullRebuild {
            // 完全重建菜单
            rebuildFullMenu()
            
            // 更新缓存状态
            lastConfigCount = currentConfigCount
            lastActiveConfigId = currentActiveConfigId
        } else if currentActiveConfigId != lastActiveConfigId {
            // 只更新活动状态
            updateActiveConfigurationInMenu()
            lastActiveConfigId = currentActiveConfigId
        }
    }
    
    /// 完全重建菜单
    private func rebuildFullMenu() {
        // 清空现有菜单项
        menu.removeAllItems()
        cachedMenuItems.removeAll()
        
        // 确保菜单栏不使用系统默认的选中样式
        menu.allowsContextMenuPlugIns = false
        

        
        // 当前配置部分 - 显示当前激活的配置
        let currentConfig = viewModel.activeConfiguration
        let currentItem = NSMenuItem(title: NSLocalizedString("Current Configuration", comment: ""), action: nil, keyEquivalent: "")
        
        if let config = currentConfig {
            // 添加配置名称和 URL 作为富文本
            let nameAttributedString = NSAttributedString(
                string: config.name + "\n",
                attributes: [
                    .font: boldSystemFont,
                    .foregroundColor: labelColor
                ]
            )
            
            let urlAttributedString = NSAttributedString(
                string: config.baseURL,
                attributes: [
                    .font: smallSystemFont,
                    .foregroundColor: secondaryLabelColor
                ]
            )
            
            let mutableAttributedTitle = NSMutableAttributedString()
            mutableAttributedTitle.append(nameAttributedString)
            mutableAttributedTitle.append(urlAttributedString)
            currentItem.attributedTitle = mutableAttributedTitle
        } else {
            // 如果没有活动配置，显示默认文本
            currentItem.title = NSLocalizedString("Current: Default", comment: "")
        }
        
        currentItem.isEnabled = false
        menu.addItem(currentItem)
        cachedMenuItems.append(currentItem)
        
        let separator1 = NSMenuItem.separator()
        menu.addItem(separator1)
        cachedMenuItems.append(separator1)
        
        // 配置部分 - 显示所有配置
        let configurationsTitle = NSMenuItem(title: NSLocalizedString("Configurations", comment: ""), action: nil, keyEquivalent: "")
        configurationsTitle.isEnabled = false
        
        // 使用富文本设置标题样式
        let configurationsTitleAttributedString = NSAttributedString(
            string: NSLocalizedString("Configurations", comment: ""),
            attributes: [
                .font: boldSystemFont,
                .foregroundColor: secondaryLabelColor
            ]
        )
        configurationsTitle.attributedTitle = configurationsTitleAttributedString
        menu.addItem(configurationsTitle)
        cachedMenuItems.append(configurationsTitle)
        
        // 添加所有配置菜单项，最多显示10个
        let maxItems = 10
        let allConfigs = viewModel.configurations
        
        // 日志：配置数量
        print("MenuBarView: 配置数量: \(allConfigs.count)")
        
        // 强制显示至少一些测试菜单项
        if allConfigs.isEmpty {
            print("MenuBarView: 配置为空，使用硬编码配置")
            
            // 直接创建硬编码的配置菜单项
            let testConfigs = [
                ("GAC Code", "https://api.gaccode.com"),
                ("Anyrouter", "https://api.anyrouter.cc"),
                ("Kimi", "https://api.moonshot.cn"),
                ("Claude 官方", "https://api.anthropic.com")
            ]
            
            for (name, url) in testConfigs {
                let item = NSMenuItem(title: name, action: #selector(AppDelegate.switchConfiguration(_:)), keyEquivalent: "")
                item.representedObject = "test-\(name)"
                
                let nameAttributedString = NSAttributedString(
                    string: name + "\n",
                    attributes: [.font: normalSystemFont]
                )
                
                let urlAttributedString = NSAttributedString(
                    string: url,
                    attributes: [
                        .font: smallSystemFont,
                        .foregroundColor: secondaryLabelColor
                    ]
                )
                
                let mutableAttributedTitle = NSMutableAttributedString(attributedString: nameAttributedString)
                mutableAttributedTitle.append(urlAttributedString)
                item.attributedTitle = mutableAttributedTitle
                
                menu.addItem(item)
                cachedMenuItems.append(item)
            }
        } else if allConfigs.count <= maxItems {
            // 如果配置不超过10个，全部显示
            for config in allConfigs {
                let item = createConfigMenuItem(config)
                menu.addItem(item)
                cachedMenuItems.append(item)
            }
        } else {
            // 如果配置超过10个，只显示前10个，其余的放在"更多配置..."菜单项中
            for i in 0..<maxItems {
                let item = createConfigMenuItem(allConfigs[i])
                menu.addItem(item)
                cachedMenuItems.append(item)
            }
            
            // 添加"更多配置..."菜单项
            let moreItem = NSMenuItem(title: NSLocalizedString("More Configurations...", comment: ""), action: #selector(AppDelegate.showAllConfigurations), keyEquivalent: "")
            moreItem.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "More")
            menu.addItem(moreItem)
            cachedMenuItems.append(moreItem)
        }
        
        let separator3 = NSMenuItem.separator()
        menu.addItem(separator3)
        cachedMenuItems.append(separator3)
        
        // 管理选项菜单
        let managementTitle = NSMenuItem(title: NSLocalizedString("Management Options", comment: ""), action: nil, keyEquivalent: "")
        managementTitle.isEnabled = false
        
        // 使用富文本设置标题样式
        let managementTitleAttributedString = NSAttributedString(
            string: NSLocalizedString("Management Options", comment: ""),
            attributes: [
                .font: boldSystemFont,
                .foregroundColor: secondaryLabelColor
            ]
        )
        managementTitle.attributedTitle = managementTitleAttributedString
        menu.addItem(managementTitle)
        cachedMenuItems.append(managementTitle)
        
        // 添加新配置选项
        let addItem = NSMenuItem(title: NSLocalizedString("Add Configuration...", comment: ""), action: #selector(AppDelegate.addConfiguration), keyEquivalent: "n")
        addItem.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: "Add")
        menu.addItem(addItem)
        cachedMenuItems.append(addItem)
        
        // 重置为默认选项
        let resetItem = NSMenuItem(title: NSLocalizedString("Reset to Default", comment: ""), action: #selector(AppDelegate.resetToDefault), keyEquivalent: "r")
        resetItem.image = NSImage(systemSymbolName: "arrow.counterclockwise.circle", accessibilityDescription: "Reset")
        menu.addItem(resetItem)
        cachedMenuItems.append(resetItem)
        
        // 设置选项
        let settingsItem = NSMenuItem(title: NSLocalizedString("Settings...", comment: ""), action: #selector(AppDelegate.showSettings), keyEquivalent: ",")
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)
        cachedMenuItems.append(settingsItem)
        
        let separator4 = NSMenuItem.separator()
        menu.addItem(separator4)
        cachedMenuItems.append(separator4)
        
        // 退出应用选项
        let quitItem = NSMenuItem(title: NSLocalizedString("Quit", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit")
        menu.addItem(quitItem)
        cachedMenuItems.append(quitItem)
        
        // 设置菜单
        statusItem.menu = menu
    }
    
    /// 创建配置菜单项
    private func createConfigMenuItem(_ config: ConfigurationModel) -> NSMenuItem {
        // 显示配置名称和 URL 信息
        let item = NSMenuItem(title: config.name, action: #selector(AppDelegate.switchConfiguration(_:)), keyEquivalent: "")
        item.representedObject = config.getConfigurationHash()  // 使用配置hash
        
        // 强制设置所有菜单项为非选中状态，避免蓝色背景
        item.state = .off
        
        // 创建富文本标题
        let attributedTitle: NSMutableAttributedString
        
        if config.isActive {
            // 为活动配置添加自定义的视觉指示（使用橙色标识）
            let nameWithCheck = config.name + " ◉"
            let nameAttributedString = NSAttributedString(
                string: nameWithCheck + "\n",
                attributes: [
                    .font: boldSystemFont,
                    .foregroundColor: accentColor
                ]
            )
            
            let urlAttributedString = NSAttributedString(
                string: config.baseURL,
                attributes: [
                    .font: smallSystemFont,
                    .foregroundColor: secondaryLabelColor
                ]
            )
            
            attributedTitle = NSMutableAttributedString()
            attributedTitle.append(nameAttributedString)
            attributedTitle.append(urlAttributedString)
        } else {
            // 普通配置
            let nameAttributedString = NSAttributedString(
                string: config.name + "\n",
                attributes: [.font: normalSystemFont]
            )
            
            let urlAttributedString = NSAttributedString(
                string: config.baseURL,
                attributes: [
                    .font: smallSystemFont,
                    .foregroundColor: secondaryLabelColor
                ]
            )
            
            attributedTitle = NSMutableAttributedString(attributedString: nameAttributedString)
            attributedTitle.append(urlAttributedString)
        }
        
        item.attributedTitle = attributedTitle
        
        // 添加右键菜单支持
        let submenu = NSMenu()
        
        // 编辑选项
        let editItem = NSMenuItem(title: NSLocalizedString("Edit", comment: ""), action: #selector(AppDelegate.editConfiguration(_:)), keyEquivalent: "")
        editItem.representedObject = config.getConfigurationHash()  // 使用配置hash
        submenu.addItem(editItem)
        
        // 删除选项
        let deleteItem = NSMenuItem(title: NSLocalizedString("Delete", comment: ""), action: #selector(AppDelegate.deleteConfiguration(_:)), keyEquivalent: "")
        deleteItem.representedObject = config.getConfigurationHash()  // 使用配置hash
        deleteItem.isEnabled = config.isCustom  // 只有自定义配置可以删除
        submenu.addItem(deleteItem)
        
        item.submenu = submenu
        
        return item
    }
    
    /// 只更新菜单中的活动配置状态
    private func updateActiveConfigurationInMenu() {
        guard let activeConfig = viewModel.activeConfiguration else { return }
        
        // 更新当前配置显示
        if let currentItem = menu.item(at: 0) {
            let nameAttributedString = NSAttributedString(
                string: activeConfig.name + "\n",
                attributes: [
                    .font: boldSystemFont,
                    .foregroundColor: labelColor
                ]
            )
            
            let urlAttributedString = NSAttributedString(
                string: activeConfig.baseURL,
                attributes: [
                    .font: smallSystemFont,
                    .foregroundColor: secondaryLabelColor
                ]
            )
            
            let mutableAttributedTitle = NSMutableAttributedString()
            mutableAttributedTitle.append(nameAttributedString)
            mutableAttributedTitle.append(urlAttributedString)
            currentItem.attributedTitle = mutableAttributedTitle
        }
        
        // 更新配置项的活动状态
        for i in 0..<menu.items.count {
            let item = menu.items[i]
            
            // 检查是否是配置菜单项
            if let configHash = item.representedObject as? String {
                
                if let config = viewModel.configurations.first(where: { $0.getConfigurationHash() == configHash }) {
                    // 更新菜单项的显示状态
                    let isActive = config.id == activeConfig.id
                    
                    if isActive {
                        // 活动配置
                        let nameWithCheck = config.name + " ◉"
                        let nameAttributedString = NSAttributedString(
                            string: nameWithCheck + "\n",
                            attributes: [
                                .font: boldSystemFont,
                                .foregroundColor: accentColor
                            ]
                        )
                        
                        let urlAttributedString = NSAttributedString(
                            string: config.baseURL,
                            attributes: [
                                .font: smallSystemFont,
                                .foregroundColor: secondaryLabelColor
                            ]
                        )
                        
                        let mutableAttributedTitle = NSMutableAttributedString()
                        mutableAttributedTitle.append(nameAttributedString)
                        mutableAttributedTitle.append(urlAttributedString)
                        item.attributedTitle = mutableAttributedTitle
                    } else {
                        // 非活动配置
                        let nameAttributedString = NSAttributedString(
                            string: config.name + "\n",
                            attributes: [.font: normalSystemFont]
                        )
                        
                        let urlAttributedString = NSAttributedString(
                            string: config.baseURL,
                            attributes: [
                                .font: smallSystemFont,
                                .foregroundColor: secondaryLabelColor
                            ]
                        )
                        
                        let mutableAttributedTitle = NSMutableAttributedString(attributedString: nameAttributedString)
                        mutableAttributedTitle.append(urlAttributedString)
                        item.attributedTitle = mutableAttributedTitle
                    }
                }
            }
        }
    }
    
    /// 更新菜单
    @objc private func updateMenu() {
        setupMenu()
    }
    
    /// 更新当前活动配置
    @objc private func updateActiveConfiguration() {
        // 使用优化后的方法更新菜单
        setupMenu()
    }
    
    /// 更新当前配置显示
    /// - Parameter name: 配置名称
    func updateCurrentConfiguration(name: String) {
        // 查找对应的配置
        let configs = viewModel.configurations
        if configs.first(where: { $0.name == name }) != nil {
            updateActiveConfiguration()
        } else if let item = menu.item(at: 0) {
            item.title = String(format: NSLocalizedString("Current: %@", comment: ""), name)
        }
    }
    
    /// 创建使用主题色的自定义选中标记
    private func createCustomCheckmarkImage() -> NSImage? {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // 使用主题色绘制选中标记 - 使用template模式确保在不同状态下都可见
        let accentColor = NSColor(Color.accentColor)
        accentColor.setFill()
        
        // 绘制一个实心的对勾符号，不使用圆形背景
        let checkPath = NSBezierPath()
        checkPath.move(to: NSPoint(x: 4, y: 8))
        checkPath.line(to: NSPoint(x: 7, y: 5))
        checkPath.line(to: NSPoint(x: 12, y: 10))
        checkPath.lineWidth = 2.0
        checkPath.lineCapStyle = .round
        checkPath.lineJoinStyle = .round
        checkPath.stroke()
        
        image.unlockFocus()
        
        // 设置为template模式，这样系统会根据上下文自动调整颜色
        image.isTemplate = true
        
        return image
    }
}
