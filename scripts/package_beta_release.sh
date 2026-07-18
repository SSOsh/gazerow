#!/usr/bin/env bash
# Apple Developer Program 없이 공유할 Universal macOS 베타 ZIP을 만든다.
#
# 이 산출물은 ad-hoc 서명되어 Apple 공증을 통과하지 않는다. 사용자는 최초 실행 후
# 시스템 설정 > 개인정보 보호 및 보안에서 "확인 없이 열기(Open Anyway)"를 선택해야 한다.
#
# 사용 예:
#   scripts/package_beta_release.sh
#   MARKETING_VERSION=0.2.0 BUILD_VERSION=2 BETA_LABEL=beta.1 \
#     scripts/package_beta_release.sh
#
# @author suho.do
# @since 2026-07-17
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
BUILD_VERSION="${BUILD_VERSION:-1}"
BETA_LABEL="${BETA_LABEL:-beta.1}"
BUNDLE_ID="${BUNDLE_ID:-io.github.ssosh.gazerow}"
MINIMUM_SYSTEM_VERSION="${MINIMUM_SYSTEM_VERSION:-14.0}"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/.build/beta-release}"
APP_ICON="${APP_ICON:-${ROOT_DIR}/Assets/AppIcon.icns}"
ENTITLEMENTS="${ENTITLEMENTS:-${ROOT_DIR}/scripts/GazeRow.entitlements}"
ARTIFACT_NAME="gazerow-${MARKETING_VERSION}-${BETA_LABEL}-macos-universal"
ZIP_PATH="${OUTPUT_DIR}/${ARTIFACT_NAME}.zip"
CHECKSUM_PATH="${ZIP_PATH}.sha256"

if [[ ! "${MARKETING_VERSION}" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "MARKETING_VERSION must contain two or three numeric components." >&2
  exit 64
fi

if [[ ! "${BUILD_VERSION}" =~ ^[1-9][0-9]*$ ]]; then
  echo "BUILD_VERSION must be a positive integer." >&2
  exit 64
fi

if [[ ! "${BETA_LABEL}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "BETA_LABEL contains unsupported characters." >&2
  exit 64
fi

if [[ ! "${BUNDLE_ID}" =~ ^[A-Za-z0-9]+(\.[A-Za-z0-9-]+)+$ ]]; then
  echo "BUNDLE_ID is invalid." >&2
  exit 64
fi

if [[ ! "${MINIMUM_SYSTEM_VERSION}" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "MINIMUM_SYSTEM_VERSION is invalid." >&2
  exit 64
fi

if [[ ! -d "${DEVELOPER_DIR}" ]]; then
  echo "Xcode developer directory not found: ${DEVELOPER_DIR}" >&2
  exit 1
fi

if [[ ! -f "${APP_ICON}" ]]; then
  echo "App icon not found: ${APP_ICON}" >&2
  exit 1
fi

if [[ ! -f "${ENTITLEMENTS}" ]]; then
  echo "Entitlements file not found: ${ENTITLEMENTS}" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"
STAGING_ROOT="$(mktemp -d "${OUTPUT_DIR}/.staging.XXXXXX")"
trap 'rm -rf "${STAGING_ROOT}"' EXIT

PAYLOAD_DIR="${STAGING_ROOT}/${ARTIFACT_NAME}"
APP_DIR="${PAYLOAD_DIR}/gazerow.app"

cd "${ROOT_DIR}"
export DEVELOPER_DIR

echo "==> Building gazerow Universal release (arm64 + x86_64)"
swift build -c release --arch arm64 --arch x86_64 --product gazerow

BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
EXECUTABLE_PATH="${BIN_DIR}/gazerow"

if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
  echo "Built executable not found: ${EXECUTABLE_PATH}" >&2
  exit 1
fi

echo "==> Assembling ${APP_DIR}"
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
  <string>${MINIMUM_SYSTEM_VERSION}</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSCameraUsageDescription</key>
  <string>gazerow uses the camera only when you enable experimental gaze focus. Frames stay local and clicks still require keyboard confirmation.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>gazerow asks your browser (Chrome, Safari, and similar) for its open tab count so the window switcher can show it. No tab content is read.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

cat > "${PAYLOAD_DIR}/INSTALL.txt" <<'INSTALL'
gazerow 무료 베타 설치 안내
===========================

이 빌드는 Apple Developer Program 없이 배포되는 무료 베타입니다.
Apple의 Developer ID 서명과 공증을 받지 않았으므로 처음 실행할 때 macOS가 차단합니다.

설치 및 최초 실행
1. gazerow.app을 응용 프로그램(Applications) 폴더로 옮깁니다.
2. gazerow.app을 더블클릭해 한 번 실행을 시도합니다.
3. 시스템 설정 > 개인정보 보호 및 보안 > 보안으로 이동합니다.
4. gazerow에 대해 "확인 없이 열기(Open Anyway)"를 선택하고 다시 실행합니다.
5. 앱 안내에 따라 손쉬운 사용 권한을 허용합니다.

주의
- 출처를 신뢰할 수 있을 때만 보안 예외를 허용하세요.
- 이 앱은 메뉴바에서 실행되며 Dock에는 나타나지 않습니다.
- 실험적 gaze 기능을 직접 켜기 전에는 카메라를 사용하지 않습니다.
- 업데이트된 베타는 ad-hoc 서명이 달라 손쉬운 사용 권한을 다시 요청할 수 있습니다.

Free beta installation
======================

This build is distributed without Apple Developer ID signing or notarization.
macOS blocks it on first launch.

1. Move gazerow.app to Applications.
2. Double-click gazerow.app once.
3. Open System Settings > Privacy & Security > Security.
4. Choose Open Anyway for gazerow, then launch it again.
5. Follow the app guidance to grant Accessibility permission.

Only override macOS security when you trust the source of this ZIP.
INSTALL

echo "==> Applying ad-hoc signature with Hardened Runtime"
codesign \
  --force \
  --options runtime \
  --entitlements "${ENTITLEMENTS}" \
  --sign - \
  --identifier "${BUNDLE_ID}" \
  "${APP_DIR}"

codesign --verify --strict --verbose=2 "${APP_DIR}"

ARCHITECTURES="$(lipo -archs "${APP_DIR}/Contents/MacOS/gazerow")"
if [[ "${ARCHITECTURES}" != *"arm64"* || "${ARCHITECTURES}" != *"x86_64"* ]]; then
  echo "Universal executable validation failed: ${ARCHITECTURES}" >&2
  exit 1
fi

echo "==> Creating ${ZIP_PATH}"
rm -f "${ZIP_PATH}" "${CHECKSUM_PATH}"
/usr/bin/ditto \
  -c \
  -k \
  --sequesterRsrc \
  --keepParent \
  "${PAYLOAD_DIR}" \
  "${ZIP_PATH}"

(
  cd "${OUTPUT_DIR}"
  shasum -a 256 "$(basename "${ZIP_PATH}")" > "$(basename "${CHECKSUM_PATH}")"
)

"${ROOT_DIR}/scripts/verify_beta_release.sh" \
  "${ZIP_PATH}" \
  "${CHECKSUM_PATH}" \
  "${MARKETING_VERSION}" \
  "${BUILD_VERSION}" \
  "${BUNDLE_ID}" \
  "${MINIMUM_SYSTEM_VERSION}"

echo "==> Free beta release ready"
echo "ZIP: ${ZIP_PATH}"
echo "SHA-256: ${CHECKSUM_PATH}"
