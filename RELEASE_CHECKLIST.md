# 发布检查清单

## 📋 发布前准备

### 代码准备
- [ ] 确保所有功能正常工作
- [ ] 运行所有测试并确保通过
- [ ] 更新版本号（在项目设置中）
- [ ] 完善翻译文件 (Localizable.xcstrings)
- [ ] 检查代码注释和文档

### 构建测试
- [ ] 本地构建成功
- [ ] DMG 文件创建成功
- [ ] DMG 可以正常挂载
- [ ] 应用程序可以从 DMG 正常安装
- [ ] 在干净的 macOS 系统上测试安装和运行

### 文档准备
- [ ] 更新 README.md
- [ ] 完善 INSTALL.md 安装指南
- [ ] 准备 Release Notes
- [ ] 检查链接和图片

## 🚀 发布步骤

### 方式一：手动发布

1. **本地构建**
   ```bash
   ./release.sh
   ```

2. **提交代码**
   ```bash
   git add .
   git commit -m "Release v1.0.0"
   git push origin main
   ```

3. **创建标签**
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```

4. **在 GitHub 创建 Release**
   - 访问 GitHub 仓库的 Releases 页面
   - 点击 "Create a new release"
   - 选择刚创建的标签 `v1.0.0`
   - 填写 Release 标题和说明
   - 上传构建好的 DMG 文件
   - 发布

### 方式二：自动发布（推荐）

1. **提交所有代码**
   ```bash
   git add .
   git commit -m "Release v1.0.0"
   git push origin main
   ```

2. **创建并推送标签**
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```

3. **GitHub Actions 自动构建**
   - 标签推送后会自动触发 GitHub Actions
   - 等待构建完成
   - Release 将自动创建并上传 DMG

## 📝 Release Notes 模板

```markdown
## CCSwitch v1.0.0

🎉 **首个正式版本发布！**

CCSwitch 是一个帮助您快速切换 Claude Code API 配置的 macOS 菜单栏应用程序。

### ✨ 主要功能

- 🔄 快速切换 Claude Code API 配置
- 🎯 支持多种 API 提供商（官方、Kimi、GAC Code、Anyrouter 等）
- ⚡ 菜单栏快速访问
- 🛠 自定义配置管理
- 🌐 多语言支持（中文、英文）
- 🚀 开机自启动选项

### 📥 安装说明

**重要：由于应用程序未经 Apple 签名，请按照以下步骤安装：**

1. 下载 `CCSwitch-1.0.0.dmg`
2. 双击挂载 DMG 文件
3. 将 `CCSwitch.app` 拖拽到 `Applications` 文件夹
4. 首次运行时：
   - 按住 `Control` 键点击应用程序
   - 选择"打开"，然后在弹出对话框中再次点击"打开"

详细安装指南请参考：[INSTALL.md](https://github.com/yourusername/CCSwitch/blob/main/INSTALL.md)

### 🔧 系统要求

- macOS 10.15 或更高版本
- 支持 Intel 和 Apple Silicon Mac

### 🐛 已知问题

- 首次运行需要手动授权（macOS 安全限制）

### 📋 文件校验

```
shasum -a 256 CCSwitch-1.0.0.dmg
```

### 🙏 感谢

感谢所有测试用户的反馈和建议！

如有问题，请在 Issues 中反馈。

### 💖 支持项目

如果 CCSwitch 对您有帮助，欢迎通过以下方式支持项目发展：

☕ **Buy me a coffee**: https://coff.ee/wangrui15f

您的支持将帮助我们：
- 持续改进和修复 bug
- 开发更多实用功能
- 购买 Apple 开发者证书提供签名版本

⭐ 别忘了给项目点个 Star！
```

## ✅ 发布后检查

### 验证发布
- [ ] GitHub Release 页面显示正常
- [ ] DMG 文件可以正常下载
- [ ] 下载的 DMG 文件可以正常挂载和安装
- [ ] 应用程序在全新系统上正常运行

### 用户支持
- [ ] 监控 GitHub Issues
- [ ] 回复用户问题
- [ ] 收集用户反馈

### 后续计划
- [ ] 规划下一版本功能
- [ ] 修复用户报告的 bug
- [ ] 考虑申请开发者证书进行代码签名

---

## 🛡️ 无签名应用说明

### 为什么没有签名？

1. **成本考虑**：Apple 开发者证书需要每年支付 $99
2. **开源性质**：个人开源项目，暂未购买证书
3. **透明度**：用户可以查看全部源代码确保安全

### 如何获得用户信任？

1. **开源透明**：所有代码在 GitHub 公开
2. **详细文档**：提供完整的安装和使用指南
3. **社区验证**：鼓励技术用户审查代码
4. **文件校验**：提供 SHA256 校验和

### 未来计划

- 考虑众筹或赞助方式购买开发者证书
- 提供签名版本以改善用户体验
- 探索其他分发方式（如 Homebrew）