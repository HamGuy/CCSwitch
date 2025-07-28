import Foundation

/// 表示单个 API 配置的数据模型
struct ConfigurationModel: Identifiable, Codable, Equatable {
    /// 配置的唯一标识符
    var id: UUID
    /// 配置名称
    var name: String
    /// 配置类型
    var type: ConfigurationType
    /// API 基础 URL
    var baseURL: String
    /// API 访问令牌
    var token: String
    /// 是否为当前激活的配置
    var isActive: Bool
    /// 是否为用户自定义配置
    var isCustom: Bool
    
    /// 配置类型枚举
    enum ConfigurationType: String, Codable, CaseIterable {
        /// GAC Code 配置类型
        case gaccode
        /// Anyrouter 配置类型
        case anyrouter
        /// Kimi 配置类型
        case kimi
        /// 自定义配置类型
        case custom
        /// 官方默认配置类型
        case official
        
        /// 返回配置类型的显示名称
        var displayName: String {
            switch self {
            case .gaccode:
                return NSLocalizedString("GAC Code", comment: "")
            case .anyrouter:
                return NSLocalizedString("Anyrouter", comment: "")
            case .kimi:
                return NSLocalizedString("Kimi", comment: "")
            case .custom:
                return NSLocalizedString("Custom", comment: "")
            case .official:
                return NSLocalizedString("Official", comment: "")
            }
        }
        
        /// 返回配置类型的默认 URL
        var defaultURL: String {
            switch self {
            case .gaccode:
                return "https://gaccode.com/claudecode"
            case .anyrouter:
                return "https://api.anyrouter.cn/anthropic"
            case .kimi:
                return "https://api.moonshot.cn/anthropic"
            case .official:
                return "https://api.anthropic.com"
            case .custom:
                return ""
            }
        }
    }
    
    /// 创建一个新的配置模型
    /// - Parameters:
    ///   - id: 配置的唯一标识符，默认为新的 UUID
    ///   - name: 配置名称
    ///   - type: 配置类型
    ///   - baseURL: API 基础 URL，如果为空则使用类型的默认 URL
    ///   - token: API 访问令牌
    ///   - isActive: 是否为当前激活的配置，默认为 false
    ///   - isCustom: 是否为用户自定义配置，默认为 false
    init(
        id: UUID = UUID(),
        name: String,
        type: ConfigurationType,
        baseURL: String? = nil,
        token: String = "",
        isActive: Bool = false,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.baseURL = baseURL ?? type.defaultURL
        self.token = token
        self.isActive = isActive
        self.isCustom = isCustom
    }
    
    /// 创建一个预设配置
    /// - Parameters:
    ///   - type: 配置类型
    ///   - token: API 访问令牌，默认为空
    /// - Returns: 新的预设配置
    static func preset(type: ConfigurationType, token: String = "") -> ConfigurationModel {
        ConfigurationModel(
            name: type.displayName,
            type: type,
            token: token,
            isCustom: false
        )
    }
    
    /// 创建一个自定义配置
    /// - Parameters:
    ///   - name: 配置名称
    ///   - baseURL: API 基础 URL
    ///   - token: API 访问令牌，默认为空
    /// - Returns: 新的自定义配置
    static func custom(name: String, baseURL: String, token: String = "") -> ConfigurationModel {
        ConfigurationModel(
            name: name,
            type: .custom,
            baseURL: baseURL,
            token: token,
            isCustom: true
        )
    }
    
    /// 创建官方默认配置
    /// - Parameter token: API 访问令牌，默认为空
    /// - Returns: 官方默认配置
    static func official(token: String = "") -> ConfigurationModel {
        ConfigurationModel(
            name: ConfigurationType.official.displayName,
            type: .official,
            token: token,
            isCustom: false
        )
    }
    
    /// 验证配置是否有效
    /// - Returns: 如果配置有效则返回 true，否则返回 false
    func isValid() -> Bool {
        // 名称不能为空
        guard !name.isEmpty else { return false }
        
        // URL 不能为空
        guard !baseURL.isEmpty else { return false }
        
        // URL 必须是有效的 URL 格式
        guard URL(string: baseURL) != nil else { return false }
        
        // Token 验证逻辑
        if type == .official {
            // 官方配置可以有空token或者有效的sk-开头token
            if !token.isEmpty && !token.hasPrefix("sk-") {
                return false
            }
        } else {
            // 非官方配置需要有有效的token（以 sk- 开头）
            if token.isEmpty || !token.hasPrefix("sk-") {
                return false
            }
        }
        
        return true
    }
    
    /// 返回配置的验证错误信息
    /// - Returns: 错误信息数组，如果没有错误则为空数组
    func validationErrors() -> [String] {
        var errors = [String]()
        
        if name.isEmpty {
            errors.append(NSLocalizedString("Configuration name cannot be empty", comment: ""))
        }
        
        if baseURL.isEmpty {
            errors.append(NSLocalizedString("API URL cannot be empty", comment: ""))
        } else if URL(string: baseURL) == nil {
            errors.append(NSLocalizedString("Invalid API URL format", comment: ""))
        }
        
        // Token 验证错误
        if type == .official {
            // 官方配置：token可以为空，但如果不为空必须以sk-开头
            if !token.isEmpty && !token.hasPrefix("sk-") {
                errors.append(NSLocalizedString("Invalid API Token format, should start with sk-", comment: ""))
            }
        } else {
            // 非官方配置：token不能为空且必须以sk-开头
            if token.isEmpty {
                errors.append(NSLocalizedString("API Token cannot be empty", comment: ""))
            } else if !token.hasPrefix("sk-") {
                errors.append(NSLocalizedString("Invalid API Token format, should start with sk-", comment: ""))
            }
        }
        
        return errors
    }
    
    /// 创建此配置的副本
    /// - Returns: 配置的副本
    func copy() -> ConfigurationModel {
        ConfigurationModel(
            id: id,
            name: name,
            type: type,
            baseURL: baseURL,
            token: token,
            isActive: isActive,
            isCustom: isCustom
        )
    }
    
    /// 创建此配置的激活副本
    /// - Returns: 激活的配置副本
    func activated() -> ConfigurationModel {
        var copy = self.copy()
        copy.isActive = true
        return copy
    }
    
    /// 获取配置的唯一标识符（基于名称和URL的hash）
    /// - Returns: 配置的hash标识符
    func getConfigurationHash() -> String {
        let combinedString = "\(name)|\(baseURL)"
        return String(combinedString.hashValue.magnitude)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: ConfigurationModel, rhs: ConfigurationModel) -> Bool {
        lhs.id == rhs.id
    }
}
