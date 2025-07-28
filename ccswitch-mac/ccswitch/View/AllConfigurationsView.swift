import SwiftUI

/// 所有配置视图，用于显示所有配置
struct AllConfigurationsView: View {
    /// 视图模型
    @ObservedObject var viewModel: AppViewModel
    
    /// 是否显示此视图
    @Binding var isPresented: Bool
    
    /// 颜色常量
    private let accentColor = Color.orange
    private let backgroundColor = Color(NSColor.windowBackgroundColor)
    private let cardBackgroundColor = Color(NSColor.controlBackgroundColor).opacity(0.7)
    private let textColor = Color.primary
    private let secondaryTextColor = Color.secondary
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack(spacing: 16) {
                // Logo 图标
                Circle()
                    .fill(accentColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "c.circle.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("All Configurations"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(textColor)
                    
                    Text(LocalizedStringKey("View and manage all available configurations"))
                        .font(.system(size: 14))
                        .foregroundColor(secondaryTextColor)
                }
                
                Spacer()
                
                // 关闭按钮
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(secondaryTextColor)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // 配置列表
            ScrollView {
                VStack(spacing: 16) {
                    // 预设配置部分
                    if !viewModel.presetConfigurations.isEmpty {
                        configurationSection(
                            title: LocalizedStringKey("Preset Configurations"),
                            configs: viewModel.presetConfigurations
                        )
                    }
                    
                    // 自定义配置部分
                    if !viewModel.customConfigurations.isEmpty {
                        configurationSection(
                            title: LocalizedStringKey("Custom Configurations"),
                            configs: viewModel.customConfigurations
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            
            // 底部按钮区域
            HStack {
                Button(LocalizedStringKey("Add New Configuration")) {
                    isPresented = false
                    // 延迟一点时间再打开配置编辑器，避免窗口切换问题
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("OpenConfigurationEditor"),
                            object: nil
                        )
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor)
                )
                .foregroundColor(.white)
                
                Spacer()
                
                Button(LocalizedStringKey("Close")) {
                    isPresented = false
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                )
                .foregroundColor(textColor)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(backgroundColor)
        .frame(width: 600, height: 500)
    }
    
    /// 创建配置部分
    private func configurationSection(title: LocalizedStringKey, configs: [ConfigurationModel]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 部分标题
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(textColor)
                .padding(.bottom, 4)
            
            // 配置列表
            ForEach(configs) { config in
                configurationCard(config: config)
            }
        }
    }
    
    /// 创建配置卡片
    private func configurationCard(config: ConfigurationModel) -> some View {
        HStack(spacing: 16) {
            // 配置图标
            Image(systemName: configTypeIcon(for: config.type))
                .font(.system(size: 20))
                .foregroundColor(accentColor)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(cardBackgroundColor)
                )
            
            // 配置信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(config.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(textColor)
                    
                    if config.isActive {
                        Text(LocalizedStringKey("Active"))
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(accentColor)
                            )
                            .foregroundColor(.white)
                    }
                }
                
                Text(config.baseURL)
                    .font(.system(size: 12))
                    .foregroundColor(secondaryTextColor)
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 12) {
                // 编辑按钮
                Button(action: {
                    editConfiguration(config)
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(accentColor)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(cardBackgroundColor)
                                .overlay(
                                    Circle()
                                        .stroke(accentColor, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                // 激活按钮
                if !config.isActive {
                    Button(action: {
                        activateConfiguration(config)
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(accentColor)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // 删除按钮（仅自定义配置可删除）
                if config.isCustom {
                    Button(action: {
                        deleteConfiguration(config)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(cardBackgroundColor)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.red, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    /// 返回配置类型对应的图标
    private func configTypeIcon(for type: ConfigurationModel.ConfigurationType) -> String {
        switch type {
        case .gaccode:
            return "g.circle"
        case .anyrouter:
            return "network"
        case .kimi:
            return "k.circle"
        case .custom:
            return "gearshape"
        case .official:
            return "checkmark.seal"
        }
    }
    
    /// 编辑配置
    private func editConfiguration(_ config: ConfigurationModel) {
        isPresented = false
        // 延迟一点时间再打开配置编辑器，避免窗口切换问题
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: NSNotification.Name("EditConfiguration"),
                object: nil,
                userInfo: ["configId": config.id.uuidString]
            )
        }
    }
    
    /// 激活配置
    private func activateConfiguration(_ config: ConfigurationModel) {
        let result = viewModel.switchToConfiguration(config)
        
        if case .failure(let error) = result {
            // 显示错误提示
            print("配置切换失败: \(error.localizedDescription)")
        }
    }
    
    /// 删除配置
    private func deleteConfiguration(_ config: ConfigurationModel) {
        // 显示确认对话框
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Confirm Deletion", comment: "")
        alert.informativeText = String(format: NSLocalizedString("Are you sure you want to delete the configuration '%@'? This action cannot be undone.", comment: ""), config.name)
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Delete", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let result = viewModel.deleteConfiguration(config)
            
            if case .failure(let error) = result {
                // 显示错误提示
                let errorAlert = NSAlert()
                errorAlert.messageText = NSLocalizedString("Deletion Failed", comment: "")
                errorAlert.informativeText = error.localizedDescription
                errorAlert.alertStyle = .warning
                errorAlert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                errorAlert.runModal()
            }
        }
    }
}
