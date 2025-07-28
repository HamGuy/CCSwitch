import Foundation
import Combine

/// 配置存储错误类型
enum ConfigurationStoreError: Error {
    /// 文件读取错误
    case fileReadError(String)
    /// 文件写入错误
    case fileWriteError(String)
    /// 数据解码错误
    case decodingError(String)
    /// 数据编码错误
    case encodingError(String)
    /// 配置不存在错误
    case configurationNotFound(String)
    /// 无效配置错误
    case invalidConfiguration(String)
}

/// 配置存储类，负责管理配置的存储、加载和更新
class ConfigurationStore: ObservableObject {
    /// 所有配置列表
    @Published private(set) var configurations: [ConfigurationModel] = []
    
    /// 当前活动配置
    @Published private(set) var activeConfiguration: ConfigurationModel?
    
    /// 存储文件的 URL
    private let fileURL: URL
    
    /// 存储数据结构
    private struct StoreData: Codable {
        var configurations: [ConfigurationModel]
        var activeConfigurationId: UUID?
    }
    
    /// 初始化配置存储
    /// - Parameter fileManager: 文件管理器，默认为 FileManager.default
    init(fileManager: FileManager = .default) {
        // 获取应用支持目录
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        
        // 创建应用目录
        let appDirectoryURL = appSupportURL.appendingPathComponent("com.ccswitch.app")
        
        // 确保目录存在
        try? fileManager.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true)
        
        // 设置存储文件 URL
        self.fileURL = appDirectoryURL.appendingPathComponent("configurations.json")
        
        // 加载配置
        try? loadConfigurations()
    }
    
    /// 加载所有配置
    /// - Throws: ConfigurationStoreError 如果加载失败
    func loadConfigurations() throws {
        do {
            // 检查文件是否存在
            if FileManager.default.fileExists(atPath: fileURL.path) {
                // 使用 FileHandle 和 DispatchIO 进行高效的文件读取
                let fileHandle = try FileHandle(forReadingFrom: fileURL)
                defer {
                    try? fileHandle.close()
                }
                
                // 使用内存映射文件读取大型配置文件
                // 这比直接读取整个文件到内存更高效
                let data: Data
                if #available(macOS 10.15, *) {
                    // 使用现代 API 读取数据
                    data = try fileHandle.readToEnd() ?? Data()
                } else {
                    // 兼容旧版 macOS
                    data = fileHandle.readDataToEndOfFile()
                }
                
                // 如果文件为空，创建默认配置
                if data.isEmpty {
                    print("配置文件为空，创建默认配置")
                    createDefaultConfigurations()
                    return
                }
                
                // 使用更高效的 JSON 解码
                let decoder = JSONDecoder()
                
                // 解码数据
                let storeData: StoreData
                do {
                    storeData = try decoder.decode(StoreData.self, from: data)
                } catch {
                    throw ConfigurationStoreError.decodingError("无法解析配置数据: \(error.localizedDescription)")
                }
                
                // 更新配置列表 - 使用批量更新而不是逐个更新
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
    
                    self.configurations = storeData.configurations
                    
                    // 设置活动配置
                    if let activeId = storeData.activeConfigurationId,
                       let activeConfig = self.configurations.first(where: { $0.id == activeId }) {
                        self.activeConfiguration = activeConfig
                        
                        // 确保只有一个配置被标记为活动
                        self.updateActiveStatus(activeId: activeId)
                    } else if !self.configurations.isEmpty {
                        // 如果没有活动配置但有配置列表，设置第一个为活动配置
                        let firstConfig = self.configurations[0]
                        self.activeConfiguration = firstConfig
                        self.updateActiveStatus(activeId: firstConfig.id)
                    }
                }
                
                print("成功加载了 \(storeData.configurations.count) 个配置")
            } else {
                print("配置文件不存在，创建默认配置")
                // 文件不存在，创建默认配置
                createDefaultConfigurations()
            }
        } catch {
            print("加载配置失败: \(error.localizedDescription)")
            // 出错时创建默认配置
            createDefaultConfigurations()
            // 重新抛出错误以便上层处理
            throw error
        }
    }
    
    /// 创建默认预设配置，保留现有用户配置和token
    private func createDefaultConfigurations() {
        print("ConfigurationStore: 开始创建/更新默认配置，当前配置数量: \(self.configurations.count)")
        
        // 保存现有的自定义配置和用户修改的token
        let existingCustomConfigs = self.configurations.filter { $0.isCustom }
        let existingUserTokens: [ConfigurationModel.ConfigurationType: String] = Dictionary(
            uniqueKeysWithValues: self.configurations.compactMap { config in
                if !config.isCustom && !config.token.isEmpty {
                    return (config.type, config.token)
                }
                return nil
            }
        )
        
        print("ConfigurationStore: 保留 \(existingCustomConfigs.count) 个自定义配置")
        print("ConfigurationStore: 保留 \(existingUserTokens.count) 个用户token")
        
        // 创建预设配置，如果用户有保存的token则使用用户的token
        let gaccode = ConfigurationModel.preset(
            type: .gaccode, 
            token: existingUserTokens[.gaccode] ?? ""
        )
        let anyrouter = ConfigurationModel.preset(
            type: .anyrouter, 
            token: existingUserTokens[.anyrouter] ?? ""
        )
        let kimi = ConfigurationModel.preset(
            type: .kimi, 
            token: existingUserTokens[.kimi] ?? ""
        )
        let official = ConfigurationModel.official(
            token: existingUserTokens[.official] ?? ""
        )
        
        // 设置官方配置为默认活动配置
        var officialActive = official
        officialActive.isActive = true
        
        // 合并预设配置和自定义配置，保留用户数据
        var newConfigurations = [gaccode, anyrouter, kimi, officialActive]
        newConfigurations.append(contentsOf: existingCustomConfigs)
        
        // 更新配置列表
        self.configurations = newConfigurations
        self.activeConfiguration = officialActive
        
        print("ConfigurationStore: 创建默认配置完成，总计 \(self.configurations.count) 个配置")
        print("ConfigurationStore: 预设配置token状态:")
        for config in self.configurations.prefix(4) {
            print("  - \(config.name): \(config.token.isEmpty ? "无token" : "有token(\(config.token.prefix(10))...)")")
        }
        
        // 保存配置
        saveConfigurations()
    }
    
    // 用于防止频繁保存的节流控制
    private var saveWorkItem: DispatchWorkItem?
    private let saveThrottleInterval: TimeInterval = 0.5 // 500毫秒节流间隔
    
    /// 保存所有配置到文件，使用节流控制避免频繁写入
    private func saveConfigurations() {
        // 取消之前的保存任务
        saveWorkItem?.cancel()
        
        // 创建新的保存任务
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.performSave()
        }
        
        // 保存引用以便后续可以取消
        saveWorkItem = workItem
        
        // 延迟执行，实现节流效果
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + saveThrottleInterval, execute: workItem)
    }
    
    /// 执行实际的保存操作
    private func performSave() {
        // 创建临时文件路径，避免直接覆盖原文件
        let tempURL = fileURL.deletingLastPathComponent().appendingPathComponent("configurations.tmp.json")
        
        do {
            // 创建存储数据
            let storeData = StoreData(
                configurations: self.configurations,
                activeConfigurationId: self.activeConfiguration?.id
            )
            
            // 使用更高效的 JSON 编码
            let encoder = JSONEncoder()
            
            // 在生产环境中，可以考虑移除 .prettyPrinted 以减少文件大小
            if #available(macOS 10.15, *) {
                encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            } else {
                encoder.outputFormatting = [.sortedKeys]
            }
            
            // 编码数据
            let data = try encoder.encode(storeData)
            
            // 先写入临时文件
            try data.write(to: tempURL, options: [.atomic])
            
            // 如果原文件存在，先备份
            let backupURL = fileURL.deletingLastPathComponent().appendingPathComponent("configurations.backup.json")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: backupURL)
                try? FileManager.default.moveItem(at: fileURL, to: backupURL)
            }
            
            // 将临时文件移动到正式位置
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
            
            // 删除备份文件
            try? FileManager.default.removeItem(at: backupURL)
            
            print("配置保存成功")
        } catch {
            print("保存配置失败: \(error.localizedDescription)")
            
            // 尝试恢复备份
            let backupURL = fileURL.deletingLastPathComponent().appendingPathComponent("configurations.backup.json")
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
                try? FileManager.default.moveItem(at: backupURL, to: fileURL)
            }
        }
        
        // 清理临时文件
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    /// 更新配置的活动状态
    /// - Parameter activeId: 活动配置的 ID
    private func updateActiveStatus(activeId: UUID) {
        // 更新所有配置的活动状态
        configurations = configurations.map { config in
            var updatedConfig = config
            updatedConfig.isActive = config.id == activeId
            return updatedConfig
        }
    }
    
    /// 添加新配置
    /// - Parameter configuration: 要添加的配置
    /// - Returns: 操作结果
    @discardableResult
    func addConfiguration(_ configuration: ConfigurationModel) -> Result<ConfigurationModel, ConfigurationStoreError> {
        // 验证配置
        guard configuration.isValid() else {
            return .failure(.invalidConfiguration("配置无效: \(configuration.validationErrors().joined(separator: ", "))"))
        }
        
        // 确保配置 ID 唯一
        var newConfig = configuration
        if configurations.contains(where: { $0.id == configuration.id }) {
            newConfig.id = UUID()
        }
        
        // 添加配置
        configurations.append(newConfig)
        
        // 保存配置
        saveConfigurations()
        
        return .success(newConfig)
    }
    
    /// 更新配置
    /// - Parameter configuration: 要更新的配置
    /// - Returns: 操作结果
    @discardableResult
    func updateConfiguration(_ configuration: ConfigurationModel) -> Result<ConfigurationModel, ConfigurationStoreError> {
        // 验证配置
        guard configuration.isValid() else {
            return .failure(.invalidConfiguration("配置无效: \(configuration.validationErrors().joined(separator: ", "))"))
        }
        
        // 查找配置索引
        guard let index = configurations.firstIndex(where: { $0.id == configuration.id }) else {
            return .failure(.configurationNotFound("找不到 ID 为 \(configuration.id) 的配置"))
        }
        
        // 更新配置
        configurations[index] = configuration
        
        // 如果更新的是活动配置，也更新 activeConfiguration
        if configuration.isActive {
            activeConfiguration = configuration
            updateActiveStatus(activeId: configuration.id)
        }
        
        // 保存配置
        saveConfigurations()
        
        return .success(configuration)
    }
    
    /// 删除配置
    /// - Parameter configuration: 要删除的配置
    /// - Returns: 操作结果
    @discardableResult
    func deleteConfiguration(_ configuration: ConfigurationModel) -> Result<Void, ConfigurationStoreError> {
        // 不允许删除预设配置
        if !configuration.isCustom {
            return .failure(.invalidConfiguration("不能删除预设配置"))
        }
        
        // 查找配置索引
        guard let index = configurations.firstIndex(where: { $0.id == configuration.id }) else {
            return .failure(.configurationNotFound("找不到 ID 为 \(configuration.id) 的配置"))
        }
        
        // 如果删除的是活动配置，切换到官方默认配置
        if configuration.isActive {
            resetToDefault()
        } else {
            // 删除配置
            configurations.remove(at: index)
            
            // 保存配置
            saveConfigurations()
        }
        
        return .success(())
    }
    
    /// 设置活动配置
    /// - Parameter configuration: 要设置为活动的配置
    /// - Returns: 操作结果
    @discardableResult
    func setActiveConfiguration(_ configuration: ConfigurationModel) -> Result<ConfigurationModel, ConfigurationStoreError> {
        // 查找配置索引
        guard let index = configurations.firstIndex(where: { $0.id == configuration.id }) else {
            return .failure(.configurationNotFound("找不到 ID 为 \(configuration.id) 的配置"))
        }
        
        // 更新活动状态
        updateActiveStatus(activeId: configuration.id)
        
        // 更新活动配置
        activeConfiguration = configurations[index]
        
        // 保存配置
        saveConfigurations()
        
        return .success(activeConfiguration!)
    }
    
    /// 重置为官方默认配置（不覆盖用户保存的token）
    /// - Returns: 操作结果
    @discardableResult
    func resetToDefault() -> Result<ConfigurationModel, ConfigurationStoreError> {
        print("ConfigurationStore: 开始重置为官方默认配置")
        
        // 如果配置列表为空，创建默认配置
        if configurations.isEmpty {
            print("ConfigurationStore: 配置列表为空，创建默认配置")
            createDefaultConfigurations()
        } else {
            // 查找官方配置
            if let officialIndex = configurations.firstIndex(where: { $0.type == .official }) {
                print("ConfigurationStore: 找到现有官方配置，设置为活动配置")
                // 更新活动状态
                updateActiveStatus(activeId: configurations[officialIndex].id)
                
                // 更新活动配置
                activeConfiguration = configurations[officialIndex]
            } else {
                print("ConfigurationStore: 未找到官方配置，重新创建默认配置")
                // 重新创建所有默认配置（会保留用户token）
                createDefaultConfigurations()
            }
        }
        
        // 保存配置
        saveConfigurations()
        
        print("ConfigurationStore: 重置完成，当前活动配置: \(activeConfiguration?.name ?? "nil")")
        return .success(activeConfiguration!)
    }
    
    /// 获取所有预设配置
    /// - Returns: 预设配置列表
    func getPresetConfigurations() -> [ConfigurationModel] {
        configurations.filter { !$0.isCustom }
    }
    
    /// 获取所有自定义配置
    /// - Returns: 自定义配置列表
    func getCustomConfigurations() -> [ConfigurationModel] {
        configurations.filter { $0.isCustom }
    }
    
    /// 获取指定类型的配置
    /// - Parameter type: 配置类型
    /// - Returns: 指定类型的配置，如果不存在则返回 nil
    func getConfiguration(ofType type: ConfigurationModel.ConfigurationType) -> ConfigurationModel? {
        configurations.first { $0.type == type }
    }
    
    /// 获取指定 ID 的配置
    /// - Parameter id: 配置 ID
    /// - Returns: 指定 ID 的配置，如果不存在则返回 nil
    func getConfiguration(withId id: UUID) -> ConfigurationModel? {
        configurations.first { $0.id == id }
    }
}
