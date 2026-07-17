#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-8}"
PRINT_LABEL_MAP=1
BUNDLE_ID=""
CLICK_LABEL=""
MIN_LABELS=""
LOG_FILE=""
GAZEROW_PID=""

usage() {
  cat <<'USAGE'
Usage:
  scripts/evaluate_overlay_target.sh --bundle-id <bundle-id> [--click-label <label>] [--timeout <seconds>] [--min-labels <count>] [--no-label-map]

Examples:
  scripts/evaluate_overlay_target.sh --bundle-id com.apple.finder
  scripts/evaluate_overlay_target.sh --bundle-id com.apple.finder --click-label AA
  scripts/evaluate_overlay_target.sh --bundle-id com.microsoft.VSCode --click-label AO --timeout 10 --min-labels 20

Environment:
  DEVELOPER_DIR      Xcode developer directory. Defaults to /Applications/Xcode.app/Contents/Developer.
  TIMEOUT_SECONDS   Default timeout when --timeout is omitted.
USAGE
}

cleanup() {
  if [[ -n "${GAZEROW_PID}" ]] && kill -0 "${GAZEROW_PID}" 2>/dev/null; then
    kill -INT "${GAZEROW_PID}" 2>/dev/null || true
    sleep 0.2
    kill -TERM "${GAZEROW_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle-id)
      BUNDLE_ID="${2:-}"
      shift 2
      ;;
    --click-label)
      CLICK_LABEL="${2:-}"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SECONDS="${2:-}"
      shift 2
      ;;
    --min-labels)
      MIN_LABELS="${2:-}"
      shift 2
      ;;
    --no-label-map)
      PRINT_LABEL_MAP=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${BUNDLE_ID}" ]]; then
  echo "--bundle-id is required." >&2
  usage >&2
  exit 2
fi

if [[ -n "${CLICK_LABEL}" && ! "${CLICK_LABEL}" =~ ^[A-Za-z]+$ ]]; then
  echo "--click-label must contain letters only: ${CLICK_LABEL}" >&2
  exit 2
fi

if ! [[ "${TIMEOUT_SECONDS}" =~ ^[0-9]+$ ]] || [[ "${TIMEOUT_SECONDS}" -lt 1 ]]; then
  echo "--timeout must be a positive integer: ${TIMEOUT_SECONDS}" >&2
  exit 2
fi

if [[ -n "${MIN_LABELS}" ]] && { ! [[ "${MIN_LABELS}" =~ ^[0-9]+$ ]] || [[ "${MIN_LABELS}" -lt 1 ]]; }; then
  echo "--min-labels must be a positive integer: ${MIN_LABELS}" >&2
  exit 2
fi

cd "${ROOT_DIR}"
export DEVELOPER_DIR

if [[ ! -d "${DEVELOPER_DIR}" ]]; then
  echo "Xcode developer directory not found: ${DEVELOPER_DIR}" >&2
  exit 1
fi

echo "==> Building gazerow"
swift build --product gazerow >/dev/null

BIN_DIR="$(swift build --show-bin-path)"
EXECUTABLE_PATH="${BIN_DIR}/gazerow"

if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
  echo "Built executable not found: ${EXECUTABLE_PATH}" >&2
  exit 1
fi

ARGS=(
  "--show-overlay-on-launch"
  "--target-bundle-id" "${BUNDLE_ID}"
)

if [[ "${PRINT_LABEL_MAP}" -eq 1 ]]; then
  ARGS+=("--print-overlay-label-map")
fi

if [[ -n "${CLICK_LABEL}" ]]; then
  ARGS+=("--click-overlay-label" "${CLICK_LABEL}")
fi

LOG_FILE="$(mktemp -t gazerow_overlay_eval.XXXXXX.log)"

echo "==> Running overlay evaluation"
echo "bundle_id=${BUNDLE_ID}"
if [[ -n "${CLICK_LABEL}" ]]; then
  echo "click_label=$(printf '%s' "${CLICK_LABEL}" | tr '[:lower:]' '[:upper:]')"
fi
if [[ -n "${MIN_LABELS}" ]]; then
  echo "min_labels=${MIN_LABELS}"
fi
echo "log_file=${LOG_FILE}"

"${EXECUTABLE_PATH}" "${ARGS[@]}" >"${LOG_FILE}" 2>&1 &
GAZEROW_PID="$!"

deadline=$((SECONDS + TIMEOUT_SECONDS))
while [[ "${SECONDS}" -lt "${deadline}" ]]; do
  if [[ -n "${CLICK_LABEL}" ]]; then
    grep -q '^GAZEROW_OVERLAY_CLICK_RESULT ' "${LOG_FILE}" && break
  else
    grep -q '^GAZEROW_OVERLAY_RESULT success ' "${LOG_FILE}" && break
    grep -q '^GAZEROW_OVERLAY_RESULT failure ' "${LOG_FILE}" && break
  fi

  if ! kill -0 "${GAZEROW_PID}" 2>/dev/null; then
    break
  fi

  sleep 0.2
done

cleanup
wait "${GAZEROW_PID}" 2>/dev/null || true
GAZEROW_PID=""

cat "${LOG_FILE}"

if grep -q '^GAZEROW_OVERLAY_RESULT failure ' "${LOG_FILE}"; then
  exit 1
fi

if ! grep -q '^GAZEROW_OVERLAY_RESULT success ' "${LOG_FILE}"; then
  echo "Overlay evaluation did not complete before timeout." >&2
  exit 1
fi

if [[ -n "${MIN_LABELS}" ]]; then
  labels_count="$(
    sed -n 's/^GAZEROW_OVERLAY_RESULT success labels=\([0-9][0-9]*\)$/\1/p' "${LOG_FILE}" | tail -n 1
  )"

  if [[ -z "${labels_count}" ]]; then
    echo "Overlay evaluation did not report a label count." >&2
    exit 1
  fi

  if [[ "${labels_count}" -lt "${MIN_LABELS}" ]]; then
    echo "Overlay evaluation reported ${labels_count} labels, below --min-labels ${MIN_LABELS}." >&2
    exit 1
  fi
fi

if [[ -n "${CLICK_LABEL}" ]] && ! grep -q '^GAZEROW_OVERLAY_CLICK_RESULT success ' "${LOG_FILE}"; then
  echo "Overlay click evaluation did not report success." >&2
  exit 1
fi

echo "==> Overlay evaluation passed"
