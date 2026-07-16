#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
CONFIGURATION="${CONFIGURATION:-debug}"
APP_DIR="${APP_DIR:-${ROOT_DIR}/.build/local-app/GazeRow.app}"
APP_ICON="${APP_ICON:-${ROOT_DIR}/Assets/AppIcon.icns}"

cd "${ROOT_DIR}"
export DEVELOPER_DIR

if [[ ! -d "${DEVELOPER_DIR}" ]]; then
  echo "Xcode developer directory not found: ${DEVELOPER_DIR}" >&2
  exit 1
fi

echo "==> Using DEVELOPER_DIR=${DEVELOPER_DIR}"
echo "==> Building GazeRow (${CONFIGURATION})"
swift build -c "${CONFIGURATION}"

BIN_DIR="$(swift build -c "${CONFIGURATION}" --show-bin-path)"
EXECUTABLE_PATH="${BIN_DIR}/GazeRow"

if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
  echo "Built executable not found: ${EXECUTABLE_PATH}" >&2
  exit 1
fi

if [[ ! -f "${APP_ICON}" ]]; then
  echo "App icon not found: ${APP_ICON}" >&2
  echo "Regenerate it with: DEVELOPER_DIR=${DEVELOPER_DIR} scripts/generate_app_icon.swift" >&2
  exit 1
fi

echo "==> Creating app bundle: ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${EXECUTABLE_PATH}" "${APP_DIR}/Contents/MacOS/GazeRow"
cp "${APP_ICON}" "${APP_DIR}/Contents/Resources/AppIcon.icns"
chmod +x "${APP_DIR}/Contents/MacOS/GazeRow"

cat > "${APP_DIR}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>GazeRow</string>
  <key>CFBundleIdentifier</key>
  <string>dev.local.gazerow</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>keyCursor</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSCameraUsageDescription</key>
  <string>GazeRow uses the camera only when you enable experimental gaze focus. Frames stay local and clicks still require keyboard confirmation.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Signing local app bundle"
codesign \
  --force \
  --sign - \
  --identifier dev.local.gazerow \
  --requirements '=designated => identifier "dev.local.gazerow"' \
  "${APP_DIR}" >/dev/null

echo "==> Local app ready"
echo "${APP_DIR}"
