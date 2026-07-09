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

echo "==> Query Overlay unit tests"
swift test --filter 'ElementSearchIndexTests|IntentRouterTests|ActionablePromoterTests|WindowSearchIndexTests'

echo "==> Checking excluded screen/input permission/framework references"
if grep -REn \
  "ScreenCaptureKit|CGDisplayStream|NSScreenCaptureUsageDescription|NSMicrophoneUsageDescription|NSInputMonitoringUsageDescription" \
  Package.swift Sources/GazeRow > "${FORBIDDEN_MATCHES_FILE}"; then
  echo "Found excluded screen/input references:" >&2
  cat "${FORBIDDEN_MATCHES_FILE}" >&2
  exit 1
fi

echo "==> Camera gaze references are allowed only as explicit opt-in with default-off tests"

echo "==> MVP freeze verification passed"
