#!/usr/bin/env bash
# 무료 베타 ZIP의 체크섬, 앱 구조, 버전, ad-hoc 서명과 Universal 아키텍처를 검증한다.
#
# @author suho.do
# @since 2026-07-17
set -euo pipefail

if [[ $# -ne 6 ]]; then
  echo "Usage: $0 <zip> <sha256> <marketing-version> <build-version> <bundle-id> <minimum-macos>" >&2
  exit 64
fi

ZIP_PATH="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
CHECKSUM_PATH="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
MARKETING_VERSION="$3"
BUILD_VERSION="$4"
BUNDLE_ID="$5"
MINIMUM_SYSTEM_VERSION="$6"
ARTIFACT_NAME="$(basename "${ZIP_PATH}" .zip)"

if [[ ! -f "${ZIP_PATH}" ]]; then
  echo "ZIP not found: ${ZIP_PATH}" >&2
  exit 1
fi

if [[ ! -f "${CHECKSUM_PATH}" ]]; then
  echo "Checksum not found: ${CHECKSUM_PATH}" >&2
  exit 1
fi

echo "==> Verifying SHA-256"
(
  cd "$(dirname "${ZIP_PATH}")"
  shasum -a 256 -c "$(basename "${CHECKSUM_PATH}")"
)

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT

echo "==> Extracting beta ZIP"
/usr/bin/ditto -x -k "${ZIP_PATH}" "${TEMP_DIR}"

PAYLOAD_DIR="${TEMP_DIR}/${ARTIFACT_NAME}"
APP_DIR="${PAYLOAD_DIR}/gazerow.app"
INFO_PLIST="${APP_DIR}/Contents/Info.plist"
EXECUTABLE="${APP_DIR}/Contents/MacOS/gazerow"
INSTALL_GUIDE="${PAYLOAD_DIR}/INSTALL.txt"

for required_path in "${APP_DIR}" "${INFO_PLIST}" "${EXECUTABLE}" "${INSTALL_GUIDE}"; do
  if [[ ! -e "${required_path}" ]]; then
    echo "Required payload item missing: ${required_path}" >&2
    exit 1
  fi
done

ACTUAL_MARKETING_VERSION="$(plutil -extract CFBundleShortVersionString raw "${INFO_PLIST}")"
ACTUAL_BUILD_VERSION="$(plutil -extract CFBundleVersion raw "${INFO_PLIST}")"
ACTUAL_BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "${INFO_PLIST}")"
ACTUAL_MINIMUM_SYSTEM_VERSION="$(plutil -extract LSMinimumSystemVersion raw "${INFO_PLIST}")"

if [[ "${ACTUAL_MARKETING_VERSION}" != "${MARKETING_VERSION}" ]]; then
  echo "Marketing version mismatch: ${ACTUAL_MARKETING_VERSION}" >&2
  exit 1
fi

if [[ "${ACTUAL_BUILD_VERSION}" != "${BUILD_VERSION}" ]]; then
  echo "Build version mismatch: ${ACTUAL_BUILD_VERSION}" >&2
  exit 1
fi

if [[ "${ACTUAL_BUNDLE_ID}" != "${BUNDLE_ID}" ]]; then
  echo "Unexpected bundle identifier: ${ACTUAL_BUNDLE_ID}" >&2
  exit 1
fi

if [[ "${ACTUAL_MINIMUM_SYSTEM_VERSION}" != "${MINIMUM_SYSTEM_VERSION}" ]]; then
  echo "Minimum macOS version mismatch: ${ACTUAL_MINIMUM_SYSTEM_VERSION}" >&2
  exit 1
fi

ARCHITECTURES="$(lipo -archs "${EXECUTABLE}")"
if [[ "${ARCHITECTURES}" != *"arm64"* || "${ARCHITECTURES}" != *"x86_64"* ]]; then
  echo "Universal executable validation failed: ${ARCHITECTURES}" >&2
  exit 1
fi

codesign --verify --strict --verbose=2 "${APP_DIR}"

SIGNATURE_DETAILS="$(codesign -dvv "${APP_DIR}" 2>&1)"
if [[ "${SIGNATURE_DETAILS}" != *"Signature=adhoc"* ]]; then
  echo "Expected an ad-hoc signature for the free beta." >&2
  exit 1
fi

if ! rg -q "Open Anyway|확인 없이 열기" "${INSTALL_GUIDE}"; then
  echo "First-launch security guidance is missing." >&2
  exit 1
fi

echo "==> Beta ZIP verification passed"
echo "Bundle: ${ACTUAL_BUNDLE_ID}"
echo "Version: ${ACTUAL_MARKETING_VERSION} (${ACTUAL_BUILD_VERSION})"
echo "Architectures: ${ARCHITECTURES}"
echo "Signature: ad-hoc (not notarized)"
