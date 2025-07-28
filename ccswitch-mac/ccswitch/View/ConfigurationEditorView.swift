import Combine
import SwiftUI

/// 验证输入字段组件
struct ValidatedTextField: View {
    let placeholder: String
    @Binding var text: String
    let isDisabled: Bool
    let isSecure: Bool
    let showError: Bool
    let errorMessage: String?
    let infoMessage: String?
    let onBlur: (() -> Void)?
    
    @State private var isPasswordVisible: Bool = false
    @FocusState private var isFocused: Bool
    
    private let inputBackgroundColor = Color(NSColor.textBackgroundColor)
    private let borderColor = Color(NSColor.separatorColor)
    private let errorColor = Color.red
    private let secondaryTextColor = Color.secondary
    
    init(
        placeholder: String,
        text: Binding<String>,
        isDisabled: Bool = false,
        isSecure: Bool = false,
        showError: Bool = false,
        errorMessage: String? = nil,
        infoMessage: String? = nil,
        onBlur: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isDisabled = isDisabled
        self.isSecure = isSecure
        self.showError = showError
        self.errorMessage = errorMessage
        self.infoMessage = infoMessage
        self.onBlur = onBlur
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isSecure {
                secureField()
            } else {
                standardTextField()
            }
            
            if showError && errorMessage != nil && !isFocused {
                Text(errorMessage!)
                    .font(.system(size: 10))
                    .foregroundColor(errorColor)
            } else if infoMessage != nil {
                Text(infoMessage!)
                    .font(.system(size: 10))
                    .foregroundColor(secondaryTextColor)
            }
        }
    }
    
    private func standardTextField() -> some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(PlainTextFieldStyle())
            .font(.system(size: 13))
            .disableAutocorrection(true)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isDisabled ? inputBackgroundColor.opacity(0.5) : inputBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: 0.5)
            )
            .disabled(isDisabled)
            .focused($isFocused)
            .onSubmit {
                isFocused = false
                onBlur?()
            }
            .onChange(of: isFocused) { newValue in
                if !newValue {  // 当失去焦点时
                    onBlur?()
                }
            }
    }
    
    private func secureField() -> some View {
        HStack(spacing: 6) {
            if isPasswordVisible {
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 13))
                    .disableAutocorrection(true)
                    .focused($isFocused)
                    .onSubmit {
                        isFocused = false
                        onBlur?()
                    }
            } else {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 13))
                    .disableAutocorrection(true)
                    .focused($isFocused)
                    .onSubmit {
                        isFocused = false
                        onBlur?()
                    }
            }
            
            if !text.isEmpty {
                Button(action: {
                    isPasswordVisible.toggle()
                }) {
                    Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                        .foregroundColor(secondaryTextColor)
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(inputBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderColor, lineWidth: 0.5)
        )
        .onChange(of: isFocused) { newValue in
            if !newValue {  // 当失去焦点时
                onBlur?()
            }
        }
    }
}

/// 配置编辑器视图，用于创建和编辑配置
struct ConfigurationEditorView: View {
  @ObservedObject var viewModel: ConfigurationEditorViewModel
  @Binding var isPresented: Bool
  @State private var showingDeleteConfirmation = false
  @State private var deleteErrorMessage: String? = nil
  @State private var showingDeleteError = false
  @State private var selectedType: ConfigurationModel.ConfigurationType
  @State private var nameFieldTouched: Bool = false
  @State private var urlFieldTouched: Bool = false
  @State private var tokenFieldTouched: Bool = false
  @State private var attemptedSave: Bool = false
  
  private let accentColor = Color.orange
  private let inputBackgroundColor = Color(NSColor.textBackgroundColor)
  private let borderColor = Color(NSColor.separatorColor)
  private let errorColor = Color.red
  private let textColor = Color.primary
  private let secondaryTextColor = Color.secondary
  private let disabledColor = Color(NSColor.disabledControlTextColor)

  init(viewModel: ConfigurationEditorViewModel, isPresented: Binding<Bool>) {
    self.viewModel = viewModel
    self._isPresented = isPresented
    self._selectedType = State(initialValue: viewModel.configuration.type)
  }
  
  private func typeIcon(for type: ConfigurationModel.ConfigurationType) -> String {
    switch type {
    case .gaccode: return "g.circle"
    case .anyrouter: return "network"
    case .kimi: return "k.circle"
    case .custom: return "gearshape"
    case .official: return "checkmark.seal"
    }
  }

  var body: some View {
    CommonWindowView(
      title: viewModel.isNewConfiguration ? String(localized: "Add New Configuration") : String(localized: "Edit Configuration"),
      subtitle: viewModel.isNewConfiguration ? String(localized: "Create a new configuration") : String(localized: "Modify an existing configuration"),
      iconName: "EditorIcon",
      content: {
        VStack(spacing: 16) {
          // 配置名称
          FormRow(icon: "pencil", title: String(localized:"Configuration Name"), required: true) {
            ValidatedTextField(
              placeholder: String(localized: "Enter configuration name"),
              text: Binding(
                get: { viewModel.configuration.name },
                set: { viewModel.updateName($0) }
              ),
              showError: (nameFieldTouched || attemptedSave) && viewModel.configuration.name.isEmpty,
              errorMessage: String(localized: "Configuration name cannot be empty"),
              onBlur: { nameFieldTouched = true }
            )
          }

          // 配置类型
          FormRow(icon: "square.grid.2x2", title: String(localized:"Configuration Type"), required: true) {
            Picker("", selection: $selectedType) {
              ForEach(ConfigurationModel.ConfigurationType.allCases, id: \.self) { type in
                HStack {
                  Image(systemName: typeIcon(for: type))
                    .foregroundColor(accentColor)
                  Text(type.displayName)
                }
                .tag(type)
              }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
              RoundedRectangle(cornerRadius: 6)
                .fill(inputBackgroundColor)
                .overlay(
                  RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: 0.5)
                )
            )
            .onChange(of: selectedType) { newType in
              viewModel.updateType(newType)
            }
          }

          // API URL
          FormRow(icon: "link", title: String(localized: "API URL"), required: viewModel.configuration.type == .custom) {
            ValidatedTextField(
              placeholder: String(localized: "Enter API URL"),
              text: Binding(
                get: { viewModel.configuration.baseURL },
                set: { viewModel.updateURL($0) }
              ),
              isDisabled: viewModel.configuration.type != .custom,
              showError: (urlFieldTouched || attemptedSave) && viewModel.configuration.type == .custom && viewModel.configuration.baseURL.isEmpty,
              errorMessage: String(localized: "API URL cannot be empty"),
              infoMessage: viewModel.configuration.type != .custom ? String(format: NSLocalizedString("Using preset URL: %@", comment: ""), viewModel.configuration.type.defaultURL) : nil,
              onBlur: { urlFieldTouched = true }
            )
          }

          // API Token
          FormRow(icon: "key.fill", title: String(localized: "API Token"), required: viewModel.configuration.type != .official) {
            ValidatedTextField(
              placeholder: String(localized: "Enter API Token (sk-...)"),
              text: Binding(
                get: { viewModel.configuration.token },
                set: { viewModel.updateToken($0) }
              ),
              isSecure: true,
              showError: (tokenFieldTouched || attemptedSave) && 
                        ((viewModel.configuration.type != .official && viewModel.configuration.token.isEmpty) || 
                         (!viewModel.configuration.token.isEmpty && !viewModel.configuration.token.hasPrefix("sk-"))),
              errorMessage: viewModel.configuration.token.isEmpty ? 
                           String(localized: "API Token cannot be empty") : 
                           String(localized: "API Token must start with sk-"),
              infoMessage: viewModel.configuration.type == .official ? String(localized: "Official configuration can omit Token") : nil,
              onBlur: { tokenFieldTouched = true }
            )
          }
        }
      },
      buttons: {
        HStack(spacing: 12) {
          Button(LocalizedStringKey("Cancel")) {
            isPresented = false
          }
          .commonStyle(.secondary)
          .keyboardShortcut(.escape, modifiers: [])

          Spacer()

          // 删除按钮
          if !viewModel.isNewConfiguration && viewModel.canDeleteConfiguration() {
            Button(LocalizedStringKey("Delete")) {
              showingDeleteConfirmation = true
            }
            .commonStyle(.destructive)
            .alert(isPresented: $showingDeleteConfirmation) {
              Alert(
                title: Text(LocalizedStringKey("Confirm Deletion")),
                message: Text(LocalizedStringKey("Are you sure you want to delete this configuration? This action cannot be undone.")),
                primaryButton: .destructive(Text(LocalizedStringKey("Delete"))) {
                  let (success, errorMessage) = viewModel.deleteConfiguration()
                  if success {
                    isPresented = false
                  } else {
                    deleteErrorMessage = errorMessage
                    showingDeleteError = true
                  }
                },
                secondaryButton: .cancel(Text(String(localized: "Cancel")))
              )
            }
            .alert(isPresented: $showingDeleteError) {
              Alert(
                title: Text(LocalizedStringKey("Deletion Failed")),
                message: Text(deleteErrorMessage ?? String(localized:"Unknown error")),
                dismissButton: .default(Text(LocalizedStringKey("OK")))
              )
            }
          }

          // 保存按钮
          let canSave = !viewModel.configuration.name.isEmpty
          
          Button(LocalizedStringKey("Save")) {
            attemptedSave = true
            if canSave {
              let result = viewModel.saveConfiguration()
              switch result {
              case .success:
                isPresented = false
                NotificationCenter.default.post(
                  name: NSNotification.Name("ConfigurationsDidChange"),
                  object: nil
                )
              case .failure:
                break
              }
            }
          }
          .commonStyle(canSave ? .primary : .disabled)
          .keyboardShortcut(.return, modifiers: [.command])
          .disabled(!canSave)
        }
      }
    )
    .frame(width: 480, height: 380)
    .onAppear {
      selectedType = viewModel.configuration.type
    }
    .onChange(of: viewModel.configuration.type) { newType in
      selectedType = newType
    }
  }
}
