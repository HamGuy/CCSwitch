import SwiftUI

/// 配置编辑器窗口控制器
class ConfigurationEditorWindowController {
    private var windowController: CommonWindowController<AnyView>?
    
    /// 显示配置编辑器窗口
    /// - Parameters:
    ///   - viewModel: 配置编辑器视图模型
    ///   - onDismiss: 窗口关闭时的回调
    func showConfigurationEditor(viewModel: ConfigurationEditorViewModel, onDismiss: @escaping () -> Void) {
        // 使用 @State 变量来跟踪窗口是否应该关闭
        let isPresented = Binding<Bool>(
            get: { true },
            set: { newValue in
                if !newValue {
                    onDismiss()
                }
            }
        )
        
        windowController = CommonWindowController(
            windowTitle: viewModel.isNewConfiguration ? 
                NSLocalizedString("Add New Configuration", comment: "") : 
                NSLocalizedString("Edit Configuration", comment: ""),
            frameName: "ConfigurationEditorWindow",
            size: CGSize(width: 480, height: 380),
            contentProvider: { 
                AnyView(ConfigurationEditorView(viewModel: viewModel, isPresented: isPresented))
            }
        )
        
        windowController?.showWindow()
    }
}