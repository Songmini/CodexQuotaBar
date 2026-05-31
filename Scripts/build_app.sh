#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Codex Usage"
INTERNAL_BINARY_NAME="CodexUsage"
APP_DIR="$ROOT_DIR/.build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/Resources/AppIcon.iconset"
ICON_FILE="$ROOT_DIR/Resources/AppIcon.icns"

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
export SWIFTPM_CACHE_PATH="$ROOT_DIR/.build/swiftpm-cache"

swift build --package-path "$ROOT_DIR" -c release
BIN_DIR="$(swift build --package-path "$ROOT_DIR" -c release --show-bin-path)"

swift "$ROOT_DIR/Scripts/generate_app_icon.swift" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_DIR/$INTERNAL_BINARY_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ICON_FILE" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$MACOS_DIR/$APP_NAME"

codesign --force --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "$APP_DIR"
