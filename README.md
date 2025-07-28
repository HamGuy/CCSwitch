# CC Switch for Mac

<div align="center">

![CC Switch Logo](ccswitch-mac/ccswitch/Assets.xcassets/AppIcon.appiconset/icon_128x128.png)

**The elegant macOS menu bar app for managing Claude Code API configurations**

[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/release/hamguy/CCSwitch.svg)](https://github.com/hamguy/CCSwitch/releases)

[中文](#中文) | [English](#english) 

</div>

## 中文

### 概述

CC Switch 是一个原生 macOS 菜单栏应用程序，让您可以轻松切换不同的 Claude Code API 配置。无论您使用的是 GAC Code、Kimi、Anyrouter 还是自定义端点，CC Switch 都能让环境管理变得简单直观。

### ✨ 特性

- **🔄 一键切换**：从菜单栏即时切换 API 配置
- **⚙️ 多服务商支持**：内置支持 GAC Code、Kimi、Anyrouter 和自定义端点
- **🔐 安全存储**：所有配置都本地存储在您的设备上
- **🎯 智能 Shell 集成**：自动更新您的 shell 配置文件（.zshrc、.bashrc）
- **⌨️ 键盘快捷键**：全局热键支持（Shift+Cmd+C）
- **🎨 原生设计**：使用 SwiftUI 构建，遵循 Apple 人机界面指南
- **🌙 系统集成**：支持亮色和暗色模式
- **📱 菜单栏便利**：快速访问，不占用程序坞空间

### 📋 系统要求

- macOS 13.0 或更高版本
- 已安装 Claude Code CLI

### 📥 安装

#### 方式一：从发布页面下载（推荐）

**⚠️ 重要：由于应用程序未经 Apple 签名，首次安装需要特殊步骤**

1. 从 [GitHub Releases](https://github.com/hamguy/CCSwitch/releases/latest) 下载最新版本的 `CCSwitch-x.x.x.dmg`
2. 双击挂载 DMG 文件
3. 将 `CCSwitch.app` 拖拽到 `Applications` 文件夹
4. **首次运行**：
   - 在 Applications 文件夹中，按住 `Control` 键并点击 `CCSwitch.app`
   - 选择"打开"，然后在安全对话框中再次点击"打开"
   - 或者在 `系统偏好设置` > `安全性与隐私` > `通用` 中点击"仍要打开"

📖 **详细安装指南**：请查看 [INSTALL.md](INSTALL.md) 获取完整的安装说明和故障排除方法。

#### 方式二：从源代码构建

```bash
# 克隆仓库
git clone https://github.com/hamguy/CCSwitch.git
cd CCSwitch

# 在 Xcode 中打开
open ccswitch-mac/ccswitch.xcodeproj

# 使用 Xcode 构建和运行
```

### 🚀 快速开始

1. **启动 CC Switch**：在菜单栏中找到 CC Switch 图标
2. **添加配置**：点击菜单栏图标 → "添加配置..."
3. **配置 API**：输入您的 API 端点和令牌
4. **切换环境**：点击任何配置即可立即切换

### 📖 使用方法

#### 添加新配置

1. 点击 CC Switch 菜单栏图标
2. 选择"添加配置..."
3. 选择配置类型：
   - **GAC Code**：GAC Code API 预配置
   - **Kimi**：Kimi API 预配置
   - **Anyrouter**：Anyrouter API 预配置
   - **自定义**：您自己的 API 端点
4. 输入您的 API 令牌并保存

#### 切换配置

- **通过菜单栏**：点击 CC Switch 图标并选择所需配置
- **通过热键**：按 `Shift+Cmd+C` 打开快速切换器

#### Shell 集成

CC Switch 会自动更新您的 shell 配置文件以设置相应的环境变量：

```bash
export ANTHROPIC_API_KEY="your-api-key"
export ANTHROPIC_BASE_URL="your-api-endpoint"
```

支持的 shell 配置文件：
- `~/.zshrc`（默认）
- `~/.bashrc`
- 自定义配置文件（可在设置中配置）

### ⚙️ 配置类型

| 类型 | 描述 | 默认 URL |
|------|------|----------|
| **官方** | Claude 官方 API | `https://api.anthropic.com` |
| **GAC Code** | GAC Code 服务 | `https://api.gaccode.com` |
| **Kimi** | 月之暗面 Kimi 服务 | `https://api.moonshot.cn` |
| **Anyrouter** | Anyrouter 服务 | `https://api.anyrouter.cc` |
| **自定义** | 您自己的端点 | 用户定义 |

### 🔧 设置

通过菜单栏图标 → "设置..." 或按 `Cmd+,` 访问设置：

- **开机启动**：登录时自动启动 CC Switch
- **自定义配置文件**：使用自定义 shell 配置文件
- **通知**：启用/禁用切换通知

### 🛡️ 权限

CC Switch 需要以下权限才能正常运行：

- **文件和文件夹访问**：读取和修改您的 shell 配置文件
- **通知**（可选）：显示配置切换通知

### 🔌 Shell 命令行工具

CC Switch 还包含一个跨平台命令行工具，用于快速环境切换：

#### 安装

```bash
# macOS/Linux/WSL
curl -fsSL https://raw.githubusercontent.com/hamguy/CCSwitch/main/shell/install.sh | bash

# Windows PowerShell
irm https://raw.githubusercontent.com/hamguy/CCSwitch/main/shell/install.ps1 | iex
```

#### 使用

```bash
# 切换到 GAC Code
ccswitch --type gaccode --token sk-xxx

# 切换到 Kimi
ccswitch --type kimi --token sk-xxx

# 交互模式
ccswitch

# 重置为默认
ccswitch --reset
```

### 💖 支持项目

如果 CCSwitch 对您有帮助，欢迎支持开源项目的发展！您的支持将帮助我们：
- 🛠 持续改进和修复 bug
- ✨ 开发更多实用功能
- 🔐 购买 Apple 开发者证书提供签名版本
- 📚 完善文档和用户指南

#### 捐赠方式

<div align="center">

**☕ Buy Me a Coffee**

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-支持开发-orange?style=for-the-badge&logo=buy-me-a-coffee)](https://coff.ee/wangrui15f)

**💰 国内支付**

<table>
<tr>
<td>
<img src="imgs/alipay.PNG" width="200" alt="支付宝收款码"><br>
<b>支付宝</b>
</td>
<td>
<img src="imgs/wechat.JPG" width="200" alt="微信收款码"><br>
<b>微信支付</b>
</td>
</tr>
</table>

</div>

---

### 📜 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

### 🙏 致谢

- 受 Claude Code 社区启发
- 使用 Apple 原生技术用心构建
- 感谢所有贡献者和测试用户

### 📞 支持

- **错误报告**：[GitHub Issues](https://github.com/hamguy/CCSwitch/issues)
- **功能请求**：[GitHub Discussions](https://github.com/hamguy/CCSwitch/discussions)
- **文档**：[项目 Wiki](https://github.com/hamguy/CCSwitch/wiki)

---

## English

### Overview

CC Switch is a native macOS menu bar application that allows you to effortlessly switch between different Claude Code API configurations. Whether you're using GAC Code, Kimi, Anyrouter, or custom endpoints, CC Switch makes environment management simple and intuitive.

### ✨ Features

- **🔄 One-Click Switching**: Switch between API configurations instantly from your menu bar
- **⚙️ Multiple Providers**: Built-in support for GAC Code, Kimi, Anyrouter, and custom endpoints
- **🔐 Secure Storage**: All configurations are stored locally on your device
- **🎯 Smart Shell Integration**: Automatically updates your shell configuration files (.zshrc, .bashrc)
- **⌨️ Keyboard Shortcuts**: Global hotkey support (Shift+Cmd+C)
- **🎨 Native Design**: Built with SwiftUI following Apple's Human Interface Guidelines
- **🌙 System Integration**: Supports both light and dark modes
- **📱 Menu Bar Convenience**: Quick access without cluttering your dock

### 🎬 Demo

![CC Switch Demo](screenshots/demo.gif)

### 📋 Requirements

- macOS 13.0 or later
- Claude Code CLI installed

### 📥 Installation

#### Option 1: Download from Releases (Recommended)

**⚠️ Important: Since the app is not signed by Apple, special steps are required for first-time installation**

1. Download the latest `CCSwitch-x.x.x.dmg` from [GitHub Releases](https://github.com/hamguy/CCSwitch/releases/latest)
2. Double-click to mount the DMG file
3. Drag `CCSwitch.app` to your `Applications` folder
4. **First launch**:
   - In Applications folder, hold `Control` and click `CCSwitch.app`
   - Select "Open", then click "Open" again in the security dialog
   - Or go to `System Preferences` > `Security & Privacy` > `General` and click "Open Anyway"

📖 **Detailed Installation Guide**: See [INSTALL.md](INSTALL.md) for complete installation instructions and troubleshooting.

#### Option 2: Build from Source

```bash
# Clone the repository
git clone https://github.com/hamguy/CCSwitch.git
cd CCSwitch

# Open in Xcode
open ccswitch-mac/ccswitch.xcodeproj

# Build and run using Xcode
```

### 🚀 Quick Start

1. **Launch CC Switch**: Find the CC Switch icon in your menu bar
2. **Add Configuration**: Click the menu bar icon → "Add Configuration..."
3. **Configure API**: Enter your API endpoint and token
4. **Switch Environments**: Click on any configuration to switch instantly

### 📖 Usage

#### Adding a New Configuration

1. Click the CC Switch menu bar icon
2. Select "Add Configuration..."
3. Choose configuration type:
   - **GAC Code**: Pre-configured for GAC Code API
   - **Kimi**: Pre-configured for Kimi API  
   - **Anyrouter**: Pre-configured for Anyrouter API
   - **Custom**: Your own API endpoint
4. Enter your API token and save

#### Switching Configurations

- **Via Menu Bar**: Click the CC Switch icon and select your desired configuration
- **Via Hotkey**: Press `Shift+Cmd+C` to open the quick switcher

#### Shell Integration

CC Switch automatically updates your shell configuration files to set the appropriate environment variables:

```bash
export ANTHROPIC_API_KEY="your-api-key"
export ANTHROPIC_BASE_URL="your-api-endpoint"
```

Supported shell configuration files:
- `~/.zshrc` (default)
- `~/.bashrc`
- Custom configuration files (configurable in Settings)

### ⚙️ Configuration Types

| Type | Description | Default URL |
|------|-------------|-------------|
| **Official** | Claude's official API | `https://api.anthropic.com` |
| **GAC Code** | GAC Code service | `https://api.gaccode.com` |
| **Kimi** | Moonshot AI Kimi service | `https://api.moonshot.cn` |
| **Anyrouter** | Anyrouter service | `https://api.anyrouter.cc` |
| **Custom** | Your own endpoint | User-defined |

### 🔧 Settings

Access settings through the menu bar icon → "Settings..." or press `Cmd+,`:

- **Launch at Login**: Start CC Switch automatically when you log in
- **Custom Config File**: Use a custom shell configuration file
- **Notifications**: Enable/disable switch notifications

### 🛡️ Permissions

CC Switch requires the following permissions to function properly:

- **Files and Folders Access**: To read and modify your shell configuration files
- **Notifications** (Optional): To show configuration switch notifications

### 🔌 Shell Command Line Tool

CC Switch also includes a cross-platform command-line tool for quick environment switching:

#### Installation

```bash
# macOS/Linux/WSL
curl -fsSL https://raw.githubusercontent.com/hamguy/CCSwitch/main/shell/install.sh | bash

# Windows PowerShell
irm https://raw.githubusercontent.com/hamguy/CCSwitch/main/shell/install.ps1 | iex
```

#### Usage

```bash
# Switch to GAC Code
ccswitch --type gaccode --token sk-xxx

# Switch to Kimi
ccswitch --type kimi --token sk-xxx

# Interactive mode
ccswitch

# Reset to default
ccswitch --reset
```

### 💖 Support the Project

If CCSwitch has been helpful to you, consider supporting the development of this open-source project! Your support helps us:
- 🛠 Continue improving and fixing bugs
- ✨ Develop more useful features  
- 🔐 Purchase Apple Developer Certificate for signed versions
- 📚 Improve documentation and user guides

#### Donation Options

<div align="center">

**☕ Buy Me a Coffee**

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support%20Development-orange?style=for-the-badge&logo=buy-me-a-coffee)](https://coff.ee/wangrui15f)

**💰 Chinese Payment Methods**

<table>
<tr>
<td>
<img src="imgs/alipay.PNG" width="200" alt="Alipay QR Code"><br>
<b>Alipay</b>
</td>
<td>
<img src="imgs/wechat.JPG" width="200" alt="WeChat Pay QR Code"><br>
<b>WeChat Pay</b>
</td>
</tr>
</table>

</div>

---

### 🧩 Architecture

CC Switch is built with modern Swift technologies:

- **SwiftUI**: Native user interface
- **Combine**: Reactive programming
- **Core Data**: Configuration persistence
- **UserNotifications**: System notifications
- **Carbon**: Global hotkey support

### 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

#### Development Setup

1. Clone the repository
2. Open `ccswitch-mac/ccswitch.xcodeproj` in Xcode
3. Build and run the project

#### Running Tests

```bash
# Run unit tests
xcodebuild test -project ccswitch-mac/ccswitch.xcodeproj -scheme ccswitch

# Run UI tests
xcodebuild test -project ccswitch-mac/ccswitch.xcodeproj -scheme ccswitch -testPlan UITests
```

### 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### 🙏 Acknowledgments

- Inspired by the Claude Code community
- Built with love using Apple's native technologies
- Thanks to all contributors and beta testers

### 📞 Support

- **Bug Reports**: [GitHub Issues](https://github.com/hamguy/CCSwitch/issues)
- **Feature Requests**: [GitHub Discussions](https://github.com/hamguy/CCSwitch/discussions)
- **Documentation**: [Project Wiki](https://github.com/hamguy/CCSwitch/wiki)

---

<div align="center">

Made with ❤️ for the Claude Code community

---

💖 **如果觉得有用，请考虑 [支持一下开发者](https://coff.ee/wangrui15f) ☕**

⭐ **Don't forget to star this repo if you find it helpful!**

</div>