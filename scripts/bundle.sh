#!/usr/bin/env bash
set -euo pipefail

# Build release binary and create .app bundle for ActionBar

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_NAME="ActionBar"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building release binary..."
cd "$PROJECT_DIR"
swift build -c release

echo "Creating app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"

# Create bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Sources/ActionBar/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Codesign (ad-hoc)
echo "Signing app bundle..."
codesign --force --sign - "$APP_BUNDLE"

echo ""
echo "Done! App bundle created at:"
echo "  $APP_BUNDLE"
echo ""
echo "To run: open $APP_BUNDLE"
