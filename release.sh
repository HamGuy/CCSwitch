#!/bin/bash

# CCSwitch 发布脚本
# 用于创建第一个 release

set -e

VERSION="1.0.0"
APP_NAME="CCSwitch"

echo "🚀 准备发布 ${APP_NAME} v${VERSION}"

# 检查是否在正确的目录
if [ ! -f "build_dmg.sh" ]; then
    echo "❌ 请在项目根目录运行此脚本"
    exit 1
fi

# 确保构建脚本可执行
chmod +x build_dmg.sh

echo "🔨 开始构建 DMG..."
./build_dmg.sh

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 构建成功！"
    echo ""
    echo "📋 发布步骤："
    echo "1. 测试 DMG 文件是否能正常挂载和安装"
    echo "2. 在 macOS 上测试应用程序功能"
    echo "3. 提交并推送所有更改到 GitHub"
    echo "4. 创建 Git 标签："
    echo "   git tag -a v${VERSION} -m 'Release v${VERSION}'"
    echo "   git push origin v${VERSION}"
    echo "5. 在 GitHub 上创建 Release，上传 DMG 文件"
    echo ""
    echo "或者使用 GitHub Actions 自动发布："
    echo "   在 GitHub 仓库的 Actions 标签页中手动触发 'Build and Release' workflow"
    echo ""
else
    echo "❌ 构建失败"
    exit 1
fi