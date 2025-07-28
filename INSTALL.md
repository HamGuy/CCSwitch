# CCSwitch 安装指南

## 📥 下载与安装

### 1. 下载应用程序

- 前往 [GitHub Releases](https://github.com/yourusername/CCSwitch/releases/latest)
- 下载最新版本的 `CCSwitch-x.x.x.dmg` 文件

### 2. 安装步骤

#### 方法一：DMG 安装（推荐）

1. **挂载 DMG**
   - 双击下载的 `CCSwitch-x.x.x.dmg` 文件
   - 系统会自动挂载磁盘映像

2. **安装应用程序**
   - 将 `CCSwitch.app` 拖拽到 `Applications` 文件夹
   - 等待复制完成

3. **首次运行**
   - 在 `Applications` 文件夹中找到 `CCSwitch.app`
   - 双击运行（如果遇到安全提示，请看下面的解决方案）

## 🔒 解决 macOS 安全限制

由于 CCSwitch 未经 Apple 官方签名，首次运行时可能会遇到安全提示。请按以下方法解决：

### 方法一：右键打开（推荐）

1. 在 `Applications` 文件夹中找到 `CCSwitch.app`
2. **按住 Control 键**并点击应用程序图标
3. 在弹出菜单中选择 **"打开"**
4. 在安全对话框中点击 **"打开"**
5. 应用程序将正常启动

### 方法二：系统偏好设置

1. 尝试双击运行应用程序（会显示安全提示）
2. 打开 **"系统偏好设置"** > **"安全性与隐私"**
3. 在 **"通用"** 选项卡中，找到关于 CCSwitch 的提示
4. 点击 **"仍要打开"** 按钮
5. 再次确认打开

### 方法三：命令行（高级用户）

```bash
# 移除隔离属性
sudo xattr -rd com.apple.quarantine /Applications/CCSwitch.app

# 添加执行权限
sudo chmod +x /Applications/CCSwitch.app/Contents/MacOS/CCSwitch
```

## 🚀 首次设置

1. **菜单栏图标**
   - 成功启动后，CCSwitch 图标会出现在菜单栏右侧
   - 点击图标打开配置菜单

2. **Shell 配置**
   - 首次运行会提示设置 Shell 配置文件
   - 通常会自动检测 `~/.zshrc`（zsh）或 `~/.bash_profile`（bash）
   - 如需手动指定，点击"浏览"选择配置文件

3. **开始使用**
   - 点击菜单栏图标查看预设配置
   - 选择所需的 API 配置即可自动切换

## ⚙️ 系统要求

- **操作系统**：macOS 10.15 (Catalina) 或更高版本
- **处理器**：支持 Intel 和 Apple Silicon (M1/M2) Mac
- **内存**：最少 50MB 可用空间
- **权限**：需要读写 Shell 配置文件的权限

## 🔧 卸载说明

如需卸载 CCSwitch：

1. **退出应用程序**
   - 点击菜单栏图标 > "退出"

2. **删除应用程序**
   ```bash
   rm -rf /Applications/CCSwitch.app
   ```

3. **清理配置文件（可选）**
   ```bash
   # 删除应用程序偏好设置
   defaults delete com.ccswitch.app
   
   # 手动清理 Shell 配置文件中的 CCSwitch 相关内容
   # 编辑 ~/.zshrc 或 ~/.bash_profile，删除包含 "CCSwitch" 或 "ANTHROPIC" 的行
   ```

## 🛡️ 安全说明

### 为什么会有安全提示？

- CCSwitch 是开源项目，未购买 Apple 开发者证书进行代码签名
- macOS 默认只允许运行经过签名的应用程序
- 这是 macOS 的安全保护机制

### 如何确保安全？

1. **查看源代码**
   - 项目完全开源：https://github.com/yourusername/CCSwitch
   - 可审查所有代码，确保无恶意行为

2. **验证文件完整性**
   ```bash
   # 使用 SHA256 校验和验证下载文件
   shasum -a 256 CCSwitch-x.x.x.dmg
   ```
   
3. **网络权限**
   - CCSwitch 仅在本地修改 Shell 配置文件
   - 不会发送任何数据到外部服务器

## ❓ 常见问题

### Q: 为什么不提供签名版本？
A: Apple 开发者证书费用较高（每年 $99），作为开源项目暂未购买。未来可能会考虑提供签名版本。

### Q: 应用程序无法启动？
A: 请确保：
- 已正确拖拽到 Applications 文件夹
- 按照上述方法解决安全限制
- 系统版本符合要求 (macOS 10.15+)

### Q: 如何更新应用程序？
A: 
- 下载新版本 DMG
- 删除旧版本应用程序
- 重新安装新版本

### Q: 会影响系统安全吗？
A: 不会。CCSwitch 只修改 Shell 配置文件中的环境变量，不会：
- 访问敏感系统文件
- 连接网络发送数据
- 安装系统级组件

## 🐛 问题反馈

如遇到安装或使用问题：

1. 查看 [FAQ](https://github.com/yourusername/CCSwitch/wiki/FAQ)
2. 搜索已有 [Issues](https://github.com/yourusername/CCSwitch/issues)
3. 创建新的 Issue 并提供：
   - macOS 版本
   - 处理器类型 (Intel/Apple Silicon)
   - 错误截图或日志
   - 复现步骤

---

**感谢使用 CCSwitch！** 🎉

如果觉得有用，请给项目一个 ⭐ Star，这对开源项目很重要！