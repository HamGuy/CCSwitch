import Foundation
import os.log

/// 验证错误类型
enum ValidationError: Error, LocalizedError {
    /// URL 为空
    case emptyURL
    /// URL 格式无效
    case invalidURLFormat
    /// URL 不是 HTTPS
    case notHTTPS
    /// Token 为空
    case emptyToken
    /// Token 格式无效
    case invalidTokenFormat
    /// 名称为空
    case emptyName
    /// 名称过长
    case nameTooLong
    
    var errorDescription: String? {
        switch self {
        case .emptyURL:
            return String(localized: "API URL cannot be empty")
        case .invalidURLFormat:
            return String(localized: "Invalid API URL format")
        case .notHTTPS:
            return String(localized: "API URL must use HTTPS protocol")
        case .emptyToken:
            return String(localized: "API Token cannot be empty")
        case .invalidTokenFormat:
            return String(localized: "Invalid API Token format, should start with sk-")
        case .emptyName:
            return String(localized: "Configuration name cannot be empty")
        case .nameTooLong:
            return String(localized: "Configuration name is too long, maximum 50 characters")
        }
    }
}

/// 验证服务，负责验证配置的有效性
class ValidationService {
    /// 日志对象
    private let logger = Logger(subsystem: "com.ccswitch.app", category: "ValidationService")
    
    /// 初始化验证服务
    init() {
        logger.info("验证服务已初始化")
    }
    
    /// 验证 URL 格式
    /// - Parameter url: 要验证的 URL 字符串
    /// - Returns: 验证结果
    func validateURL(_ url: String) -> Result<Void, ValidationError> {
        logger.info("正在验证 URL: \(url)")
        
        // 检查 URL 是否为空
        guard !url.isEmpty else {
            logger.error("URL 为空")
            return .failure(.emptyURL)
        }
        
        // 检查 URL 格式是否有效
        guard let urlObj = URL(string: url) else {
            logger.error("URL 格式无效: \(url)")
            return .failure(.invalidURLFormat)
        }
        
        // 检查 URL 是否使用 HTTPS 协议
        guard urlObj.scheme?.lowercased() == "https" else {
            logger.error("URL 不是 HTTPS: \(url)")
            return .failure(.notHTTPS)
        }
        
        logger.info("URL 验证通过")
        return .success(())
    }
    
    /// 验证 Token 格式
    /// - Parameter token: 要验证的 Token 字符串
    /// - Parameter required: Token 是否必填，默认为 true
    /// - Returns: 验证结果
    func validateToken(_ token: String, required: Bool = true) -> Result<Void, ValidationError> {
        logger.info("正在验证 Token")
        
        // 如果 Token 不是必填，且为空，则验证通过
        if !required && token.isEmpty {
            logger.info("Token 为空，但不是必填，验证通过")
            return .success(())
        }
        
        // 检查 Token 是否为空
        guard !token.isEmpty else {
            logger.error("Token 为空")
            return .failure(.emptyToken)
        }
        
        // 检查 Token 格式是否有效（以 sk- 开头）
        guard token.hasPrefix("sk-") else {
            logger.error("Token 格式无效，应以 sk- 开头")
            return .failure(.invalidTokenFormat)
        }
        
        // 检查 Token 长度是否合理（通常至少 20 个字符）
        guard token.count >= 20 else {
            logger.error("Token 长度不足，可能无效")
            return .failure(.invalidTokenFormat)
        }
        
        logger.info("Token 验证通过")
        return .success(())
    }
    
    /// 验证配置名称
    /// - Parameter name: 要验证的配置名称
    /// - Returns: 验证结果
    func validateName(_ name: String) -> Result<Void, ValidationError> {
        logger.info("正在验证配置名称: \(name)")
        
        // 检查名称是否为空
        guard !name.isEmpty else {
            logger.error("配置名称为空")
            return .failure(.emptyName)
        }
        
        // 检查名称长度是否合理
        guard name.count <= 50 else {
            logger.error("配置名称过长: \(name.count) 个字符")
            return .failure(.nameTooLong)
        }
        
        logger.info("配置名称验证通过")
        return .success(())
    }
    
    /// 验证完整配置
    /// - Parameter configuration: 要验证的配置模型
    /// - Returns: 验证错误列表，如果没有错误则为空数组
    func validateConfiguration(_ configuration: ConfigurationModel) -> [ValidationError] {
        logger.info("正在验证配置: \(configuration.name)")
        
        var errors = [ValidationError]()
        
        // 验证名称
        switch validateName(configuration.name) {
        case .success:
            break
        case .failure(let error):
            errors.append(error)
        }
        
        // 验证 URL
        switch validateURL(configuration.baseURL) {
        case .success:
            break
        case .failure(let error):
            errors.append(error)
        }
        
        // 验证 Token（对于官方配置，Token 可以为空）
        let tokenRequired = configuration.type != .official
        switch validateToken(configuration.token, required: tokenRequired) {
        case .success:
            break
        case .failure(let error):
            errors.append(error)
        }
        
        logger.info("配置验证完成，发现 \(errors.count) 个错误")
        return errors
    }
    
    /// 获取验证错误的描述信息
    /// - Parameter errors: 验证错误列表
    /// - Returns: 错误描述信息列表
    func getErrorDescriptions(_ errors: [ValidationError]) -> [String] {
        errors.map { $0.localizedDescription }
    }
}