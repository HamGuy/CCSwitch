#!/bin/bash

# CCSwitch DMG 构建脚本
# 用于创建无签名的 macOS 应用程序分发包

set -e

# 配置变量
APP_NAME="CCSwitch"
VERSION="1.0.0"
BUNDLE_ID="com.ccswitch.app"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
DIST_DIR="${BUILD_DIR}/dist"
APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"

echo "🚀 开始构建 ${APP_NAME} v${VERSION}"

# 清理之前的构建
echo "🧹 清理构建目录..."
rm -rf "${BUILD_DIR}"
mkdir -p "${DIST_DIR}"

# 构建应用程序
echo "🔨 构建 macOS 应用程序..."
cd "${PROJECT_DIR}/ccswitch-mac"

# 使用 xcodebuild 构建项目
xcodebuild -project ccswitch.xcodeproj \
    -scheme ccswitch \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}" \
    -destination 'platform=macOS,arch=x86_64,variant=Mac Catalyst' \
    build

# 检查应用程序是否构建成功
if [ ! -d "${APP_PATH}" ]; then
    echo "❌ 应用程序构建失败"
    exit 1
fi

echo "✅ 应用程序构建成功: ${APP_PATH}"

# 创建临时 DMG 目录
TEMP_DMG_DIR="${BUILD_DIR}/dmg_temp"
mkdir -p "${TEMP_DMG_DIR}"

# 复制应用程序到临时目录
echo "📦 准备 DMG 内容..."
cp -R "${APP_PATH}" "${TEMP_DMG_DIR}/"

# 创建应用程序文件夹的符号链接
ln -s /Applications "${TEMP_DMG_DIR}/Applications"

# 添加安装说明文件
cat > "${TEMP_DMG_DIR}/安装说明.txt" << 'EOF'
CCSwitch 安装说明

由于此应用程序未经 Apple 签名，您需要按照以下步骤进行安装：

1. 将 CCSwitch.app 拖拽到 Applications 文件夹
2. 首次运行时，如果系统提示"无法打开，因为它来自身份不明的开发者"：
   - 按住 Control 键并点击 CCSwitch.app
   - 选择"打开"
   - 在弹出的对话框中点击"打开"

3. 或者在系统偏好设置中允许运行：
   - 打开"系统偏好设置" > "安全性与隐私"
   - 在"通用"选项卡中，点击"仍要打开"

注意：CCSwitch 是开源软件，您可以在 GitHub 上查看源代码以确保安全性。

GitHub 地址: https://github.com/yourusername/CCSwitch
EOF

# 创建 DMG
echo "💿 创建 DMG 文件..."
hdiutil create -srcfolder "${TEMP_DMG_DIR}" \
    -volname "${APP_NAME} ${VERSION}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDBZ \
    -size 100m \
    "${DMG_PATH}"

# 清理临时文件
rm -rf "${TEMP_DMG_DIR}"

echo "✅ DMG 创建成功: ${DMG_PATH}"

# 计算文件大小和校验和
FILE_SIZE=$(ls -lh "${DMG_PATH}" | awk '{print $5}')
CHECKSUM=$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')

echo ""
echo "📊 构建信息:"
echo "   应用版本: ${VERSION}"
echo "   文件大小: ${FILE_SIZE}"
echo "   SHA256:   ${CHECKSUM}"
echo "   输出路径: ${DMG_PATH}"
echo ""
echo "🎉 构建完成！"
echo ""
echo "📝 发布检查清单:"
echo "   □ 测试 DMG 挂载和应用程序安装"
echo "   □ 验证应用程序在全新系统上的运行"
echo "   □ 准备 GitHub Release 说明"
echo "   □ 上传 DMG 到 GitHub Releases"