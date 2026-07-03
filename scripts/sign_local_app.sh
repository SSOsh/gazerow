#!/usr/bin/env bash
# 로컬 self-signed identity로 GazeRow.app 번들을 재서명한다.
#
# scripts/build_local_app.sh 로 번들을 만든 뒤 실행한다. 인증서는
# scripts/create_local_signing_identity.sh 가 미리 생성해 둔다(없으면 자동 실행).
# identifier를 dev.local.gazerow 로 고정해 재빌드 후에도 동일 Designated Requirement를
# 유지하므로 Accessibility 권한이 살아남는다.
#
# @author suho.do
# @since 2026-07-03
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IDENTITY_NAME="${IDENTITY_NAME:-GazeRow Local Signing}"
APP_DIR="${1:-${APP_DIR:-${ROOT_DIR}/.build/local-app/GazeRow.app}}"
BUNDLE_ID="${BUNDLE_ID:-dev.local.gazerow}"

if [[ ! -d "${APP_DIR}" ]]; then
  echo "App bundle not found: ${APP_DIR}" >&2
  echo "Run scripts/build_local_app.sh first." >&2
  exit 1
fi

if ! security find-certificate -c "${IDENTITY_NAME}" >/dev/null 2>&1; then
  echo "==> Signing identity missing; creating it"
  "${ROOT_DIR}/scripts/create_local_signing_identity.sh"
fi

echo "==> Signing ${APP_DIR} with '${IDENTITY_NAME}'"
codesign --force --deep \
  --sign "${IDENTITY_NAME}" \
  --identifier "${BUNDLE_ID}" \
  "${APP_DIR}"

echo "==> Verifying signature"
codesign -dvvv "${APP_DIR}" 2>&1 | grep -E "Identifier|Signature|Authority|flags" || true

if codesign -dvvv "${APP_DIR}" 2>&1 | grep -q "adhoc"; then
  echo "WARNING: bundle is still adhoc-signed" >&2
  exit 1
fi

echo "==> Signed. Re-grant Accessibility once; it will persist across rebuilds."
