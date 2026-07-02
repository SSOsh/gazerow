#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
FORBIDDEN_MATCHES_FILE="$(mktemp)"

cleanup() {
  rm -f "${FORBIDDEN_MATCHES_FILE}"
}
trap cleanup EXIT

cd "${ROOT_DIR}"
export DEVELOPER_DIR

if [[ ! -d "${DEVELOPER_DIR}" ]]; then
  echo "Xcode developer directory not found: ${DEVELOPER_DIR}" >&2
  exit 1
fi

echo "==> Using DEVELOPER_DIR=${DEVELOPER_DIR}"
echo "==> Building GazeRow"
swift build

echo "==> Running tests"
swift test

echo "==> Checking MVP-excluded permission/framework references"
if grep -REn \
  "AVCapture|ScreenCaptureKit|CGDisplayStream|NSCameraUsageDescription|NSScreenCaptureUsageDescription|NSMicrophoneUsageDescription|NSInputMonitoringUsageDescription" \
  Package.swift Sources/GazeRow > "${FORBIDDEN_MATCHES_FILE}"; then
  echo "Found MVP-excluded camera/screen/input references:" >&2
  cat "${FORBIDDEN_MATCHES_FILE}" >&2
  exit 1
fi

echo "==> MVP freeze verification passed"
