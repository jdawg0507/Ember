#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

APP_NAME="Ember"
APP_BUNDLE=".build/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔥 Building Ember (Release)..."
swift build -c release --product "${APP_NAME}"

BIN_PATH="$(swift build -c release --product "${APP_NAME}" --show-bin-path)"
EXECUTABLE="${BIN_PATH}/${APP_NAME}"

if [ ! -f "${EXECUTABLE}" ]; then
    echo "❌ Error: Could not locate compiled binary at ${EXECUTABLE}"
    exit 1
fi

echo "📦 Assembling application bundle at ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Copy compiled executable
cp "${EXECUTABLE}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist
cp "Info.plist" "${CONTENTS_DIR}/Info.plist"

# Ad-hoc sign for local execution on macOS
if command -v codesign >/dev/null 2>&1; then
    echo "✍️ Signing application bundle..."
    codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true
fi

echo "✅ Ember.app built successfully!"
echo "📍 Location: $(pwd)/${APP_BUNDLE}"
echo "🚀 To run: open \"${APP_BUNDLE}\""
