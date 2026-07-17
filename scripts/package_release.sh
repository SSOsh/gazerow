#!/usr/bin/env bash
# gazerow.app을 Developer ID로 서명하고 notarize/staple하여 Gatekeeper
# 정식 배포용 번들을 만든다.
#
# 로컬 개발용 번들(build_local_app.sh, dev.local.gazerow)과 달리, 이 스크립트는
# 배포 identifier(io.github.ssosh.gazerow) + Hardened Runtime + Apple notarization을
# 적용해 다른 사용자의 Mac에서 Gatekeeper 경고 없이 실행되도록 한다.
#
# 사전 준비(자격증명은 스크립트가 지어내지 않으며, 없으면 중단한다):
#   1) Developer ID Application 인증서가 login keychain에 있어야 한다.
#      SIGNING_IDENTITY="Developer ID Application: NAME (TEAMID)"
#   2) notarytool 자격증명 profile을 미리 저장해 둔다.
#      xcrun notarytool store-credentials "gazerow-notary" \
#        --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-pw"
#      NOTARY_PROFILE="gazerow-notary"
#
# 사용 예:
#   SIGNING_IDENTITY="Developer ID Application: Suho Do (ABCDE12345)" \
#   NOTARY_PROFILE="gazerow-notary" \
#   scripts/package_release.sh
#
# @author suho.do
# @since 2026-07-07
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUNDLE_ID="${BUNDLE_ID:-io.github.ssosh.gazerow}"
APP_DIR="${APP_DIR:-${ROOT_DIR}/.build/release-app/gazerow.app}"
ENTITLEMENTS="${ENTITLEMENTS:-${ROOT_DIR}/scripts/GazeRow.entitlements}"
MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
BUILD_VERSION="${BUILD_VERSION:-1}"
APP_ICON="${APP_ICON:-${ROOT_DIR}/Assets/AppIcon.icns}"

# 자격증명이 없으면 지어내지 않고 안내 후 중단한다.
if [[ -z "${SIGNING_IDENTITY:-}" ]]; then
  echo "SIGNING_IDENTITY is required (e.g. 'Developer ID Application: NAME (TEAMID)')." >&2
  echo "List available identities: security find-identity -v -p codesigning" >&2
  exit 1
fi

if [[ -z "${NOTARY_PROFILE:-}" ]]; then
  echo "NOTARY_PROFILE is required (a notarytool keychain profile name)." >&2
  echo "Create it once: xcrun notarytool store-credentials <profile> \\" >&2
  echo "  --apple-id <email> --team-id <TEAMID> --password <app-specific-password>" >&2
  exit 1
fi

if [[ ! -d "${DEVELOPER_DIR}" ]]; then
  echo "Xcode developer directory not found: ${DEVELOPER_DIR}" >&2
  exit 1
fi

if [[ ! -f "${ENTITLEMENTS}" ]]; then
  echo "Entitlements file not found: ${ENTITLEMENTS}" >&2
  exit 1
fi

if [[ ! -f "${APP_ICON}" ]]; then
  echo "App icon not found: ${APP_ICON}" >&2
  echo "Regenerate it with: DEVELOPER_DIR=${DEVELOPER_DIR} scripts/generate_app_icon.swift" >&2
  exit 1
fi

cd "${ROOT_DIR}"
export DEVELOPER_DIR

echo "==> Using DEVELOPER_DIR=${DEVELOPER_DIR}"
echo "==> Building gazerow (release)"
swift build -c release --product gazerow

BIN_DIR="$(swift build -c release --show-bin-path)"
EXECUTABLE_PATH="${BIN_DIR}/gazerow"

if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
  echo "Built executable not found: ${EXECUTABLE_PATH}" >&2
  exit 1
fi

echo "==> Assembling app bundle: ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${EXECUTABLE_PATH}" "${APP_DIR}/Contents/MacOS/gazerow"
cp "${APP_ICON}" "${APP_DIR}/Contents/Resources/AppIcon.icns"
chmod +x "${APP_DIR}/Contents/MacOS/gazerow"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>gazerow</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>gazerow</string>
  <key>CFBundleDisplayName</key>
  <string>gazerow</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${MARKETING_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSCameraUsageDescription</key>
  <string>gazerow uses the camera only when you enable experimental gaze focus. Frames stay local and clicks still require keyboard confirmation.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Signing with Developer ID + Hardened Runtime"
codesign \
  --force \
  --timestamp \
  --options runtime \
  --entitlements "${ENTITLEMENTS}" \
  --sign "${SIGNING_IDENTITY}" \
  "${APP_DIR}"

echo "==> Verifying signature (pre-notarization)"
codesign --verify --strict --verbose=2 "${APP_DIR}"

ZIP_PATH="${APP_DIR%.app}.zip"
echo "==> Zipping for notarization: ${ZIP_PATH}"
rm -f "${ZIP_PATH}"
/usr/bin/ditto -c -k --keepParent "${APP_DIR}" "${ZIP_PATH}"

echo "==> Submitting to Apple notary service (this can take a while)"
xcrun notarytool submit "${ZIP_PATH}" \
  --keychain-profile "${NOTARY_PROFILE}" \
  --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "${APP_DIR}"

echo "==> Gatekeeper assessment"
spctl --assess --type execute --verbose=4 "${APP_DIR}"

echo "==> Release bundle ready"
echo "${APP_DIR}"
