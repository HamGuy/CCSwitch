import Foundation
import Carbon
import AppKit

/// 热键服务，负责管理全局热键
class HotKeyService {
    /// 热键ID
    private var hotKeyID = EventHotKeyID()
    
    /// 热键引用
    private var hotKeyRef: EventHotKeyRef?
    
    /// 热键事件处理器
    private var eventHandler: EventHandlerRef?
    
    /// 初始化热键服务
    init() {
        // 设置热键ID
        hotKeyID.signature = OSType(0x43435357) // 'CCSW' 的十六进制表示
        hotKeyID.id = UInt32(1)
        
        // 注册热键
        registerHotKey()
    }
    
    /// 注册热键
    private func registerHotKey() {
        // 创建事件类型规范
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // 安装事件处理器
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, eventRef, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let service = Unmanaged<HotKeyService>.fromOpaque(userData).takeUnretainedValue()
                return service.handleHotKeyEvent(eventRef)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        
        // 注册热键 - Shift+Command+C
        let keyCode = UInt32(kVK_ANSI_C)  // C 键的虚拟键码
        let modifiers = UInt32(cmdKey | shiftKey)  // Command+Shift 修饰键
        
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
    
    /// 处理热键事件
    private func handleHotKeyEvent(_ eventRef: EventRef?) -> OSStatus {
        // 获取热键ID
        var receivedHotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &receivedHotKeyID
        )
        
        // 检查是否是我们的热键
        if status == noErr && receivedHotKeyID.signature == hotKeyID.signature && receivedHotKeyID.id == hotKeyID.id {
            // 在主线程上执行UI操作
            DispatchQueue.main.async {
                // 激活应用程序
                NSApp.activate(ignoringOtherApps: true)
                
                // 如果应用程序有窗口，则显示窗口
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
                
                // 发送通知，以便其他组件可以响应热键
                NotificationCenter.default.post(name: NSNotification.Name("HotKeyPressed"), object: nil)
            }
            
            return noErr
        }
        
        return OSStatus(eventNotHandledErr)
    }
    
    /// 取消注册热键
    func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    /// 析构函数
    deinit {
        unregisterHotKey()
    }
}