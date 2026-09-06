#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
app_dir="$project_dir/dist/MyGPXStudio.app"
binary_dir="$project_dir/.build/release"

cd "$project_dir"
swift build -c release

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/RouteToGPX" "$app_dir/Contents/MacOS/RouteToGPX"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Resources/MyGPXStudio.icns" "$app_dir/Contents/Resources/MyGPXStudio.icns"

codesign --force --deep --sign - "$app_dir"
echo "已生成：$app_dir"
