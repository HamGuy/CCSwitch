import SwiftUI

/// 通用窗口视图组件，提供一致的窗口样式和布局
struct CommonWindowView<Content: View>: View {
    // 窗口标题
    let title: String
    // 窗口副标题
    let subtitle: String?
    // 窗口图标
    let iconName: String
    // 内容视图构建器
    let content: () -> Content
    // 底部按钮区域构建器
    let buttons: () -> AnyView
    
    // 颜色定义
    private let backgroundColor = Color(NSColor.windowBackgroundColor)
    private let textColor = Color.primary
    private let secondaryTextColor = Color.secondary
    
    /// 初始化通用窗口视图
    /// - Parameters:
    ///   - title: 窗口标题
    ///   - subtitle: 窗口副标题（可选）
    ///   - iconName: 窗口图标名称
    ///   - content: 内容视图构建器
    ///   - buttons: 底部按钮区域构建器
    init(
        title: String,
        subtitle: String? = nil,
        iconName: String,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder buttons: @escaping () -> some View
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.content = content
        self.buttons = { AnyView(buttons()) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack(spacing: 12) {
                Image(iconName)
                    .resizable()
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(textColor)
                    
                    if let subtitle = subtitle {
                        Text(LocalizedStringKey(subtitle))
                            .font(.system(size: 12))
                            .foregroundColor(secondaryTextColor)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // 内容区域
            content()
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            
            // 按钮区域
            buttons()
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .background(Color.clear)
    }
}

/// 通用表单行组件
struct FormRow<Content: View>: View {
    // 图标名称
    let icon: String
    // 标题
    let title: String
    // 是否必填
    let required: Bool
    // 内容视图构建器
    let content: () -> Content
    
    // 颜色定义
    private let accentColor = Color.orange
    private let textColor = Color.primary
    private let errorColor = Color.red
    
    /// 初始化表单行组件
    /// - Parameters:
    ///   - icon: 图标名称
    ///   - title: 标题
    ///   - required: 是否必填
    ///   - content: 内容视图构建器
    init(
        icon: String,
        title: String,
        required: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.required = required
        self.content = content
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(accentColor)
                    .frame(width: 16)
                
                Text(LocalizedStringKey(title))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textColor)
                
                if required {
                    Text("*")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(errorColor)
                }
            }
            .frame(width: 100, alignment: .leading)
            
            content()
        }
    }
}

/// 通用按钮样式
struct CommonButtonStyle: ButtonStyle {
    // 按钮类型
    enum ButtonType {
        case primary
        case secondary
        case destructive
        case disabled
    }
    
    // 按钮类型
    let type: ButtonType
    
    // 颜色定义
    private let accentColor = Color.orange
    private let inputBackgroundColor = Color(NSColor.textBackgroundColor)
    private let borderColor = Color(NSColor.separatorColor)
    private let errorColor = Color.red
    private let textColor = Color.primary
    private let disabledColor = Color(NSColor.disabledControlTextColor)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor(for: type, isPressed: configuration.isPressed))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(borderColor(for: type), lineWidth: type == .primary ? 0 : 1)
                    )
            )
            .foregroundColor(foregroundColor(for: type))
    }
    
    private func backgroundColor(for type: ButtonType, isPressed: Bool) -> Color {
        switch type {
        case .primary:
            return isPressed ? accentColor.opacity(0.8) : accentColor
        case .secondary:
            return isPressed ? inputBackgroundColor.opacity(0.8) : inputBackgroundColor
        case .destructive:
            return isPressed ? errorColor.opacity(0.2) : errorColor.opacity(0.1)
        case .disabled:
            return inputBackgroundColor.opacity(0.5)
        }
    }
    
    private func borderColor(for type: ButtonType) -> Color {
        switch type {
        case .destructive:
            return errorColor
        default:
            return borderColor
        }
    }
    
    private func foregroundColor(for type: ButtonType) -> Color {
        switch type {
        case .primary:
            return .white
        case .secondary:
            return textColor
        case .destructive:
            return errorColor
        case .disabled:
            return disabledColor
        }
    }
}

extension Button {
    /// 应用通用按钮样式
    /// - Parameter type: 按钮类型
    /// - Returns: 应用了样式的按钮
    func commonStyle(_ type: CommonButtonStyle.ButtonType) -> some View {
        self.buttonStyle(CommonButtonStyle(type: type))
    }
}