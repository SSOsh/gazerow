#!/usr/bin/env bash
set -euo pipefail

# Query Overlay 로컬 평가 스크립트.
#
# @author suho.do
# @since 2026-07-09

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-10}"
TARGET_BUNDLE_ID=""
QUERY=""
WINDOW_QUERY=""
EXPECT_SCOPE=""
EXPECT_APP=""
LOG_FILE=""
GAZEROW_PID=""

usage() {
  cat <<'USAGE'
Usage:
  scripts/evaluate_query_overlay.sh --target-bundle-id <bundle-id> --query <text> --expect-scope elements
  scripts/evaluate_query_overlay.sh --window-query <text> --expect-app <bundle-id>

Examples:
  scripts/evaluate_query_overlay.sh --target-bundle-id com.microsoft.VSCode --query explorer --expect-scope elements
  scripts/evaluate_query_overlay.sh --window-query code --expect-app com.microsoft.VSCode

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

frontmost_bundle_id() {
  osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true' 2>/dev/null || true
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-bundle-id)
      TARGET_BUNDLE_ID="${2:-}"
      shift 2
      ;;
    --query)
      QUERY="${2:-}"
      shift 2
      ;;
    --window-query)
      WINDOW_QUERY="${2:-}"
      shift 2
      ;;
    --expect-scope)
      EXPECT_SCOPE="${2:-}"
      shift 2
      ;;
    --expect-app)
      EXPECT_APP="${2:-}"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SECONDS="${2:-}"
      shift 2
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

if [[ -n "${QUERY}" && -n "${WINDOW_QUERY}" ]]; then
  echo "Use either --query or --window-query, not both." >&2
  exit 2
fi

if [[ -n "${QUERY}" ]]; then
  EXPECT_SCOPE="${EXPECT_SCOPE:-elements}"
  if [[ -z "${TARGET_BUNDLE_ID}" ]]; then
    echo "--target-bundle-id is required with --query." >&2
    exit 2
  fi
fi

if [[ -n "${WINDOW_QUERY}" ]]; then
  EXPECT_SCOPE="windows"
  if [[ -z "${EXPECT_APP}" ]]; then
    echo "--expect-app is required with --window-query." >&2
    exit 2
  fi
fi

if [[ -z "${QUERY}" && -z "${WINDOW_QUERY}" ]]; then
  echo "Either --query or --window-query is required." >&2
  usage >&2
  exit 2
fi

if [[ "${EXPECT_SCOPE}" != "elements" && "${EXPECT_SCOPE}" != "windows" ]]; then
  echo "--expect-scope must be elements or windows: ${EXPECT_SCOPE}" >&2
  exit 2
fi

if ! [[ "${TIMEOUT_SECONDS}" =~ ^[0-9]+$ ]] || [[ "${TIMEOUT_SECONDS}" -lt 1 ]]; then
  echo "--timeout must be a positive integer: ${TIMEOUT_SECONDS}" >&2
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

QUERY_TEXT="${QUERY:-${WINDOW_QUERY}}"
ARGS=(
  "--show-overlay-on-launch"
  "--query-type-text"
  "--query-text" "${QUERY_TEXT}"
  "--query-scope-pin" "${EXPECT_SCOPE}"
)

if [[ -n "${TARGET_BUNDLE_ID}" ]]; then
  ARGS+=("--target-bundle-id" "${TARGET_BUNDLE_ID}")
fi

if [[ -n "${WINDOW_QUERY}" ]]; then
  ARGS+=("--perform-query-confirm")
fi

LOG_FILE="$(mktemp -t gazerow_query_eval.XXXXXX.log)"

echo "==> Running query overlay evaluation"
echo "query=${QUERY_TEXT}"
echo "expect_scope=${EXPECT_SCOPE}"
if [[ -n "${TARGET_BUNDLE_ID}" ]]; then
  echo "target_bundle_id=${TARGET_BUNDLE_ID}"
fi
if [[ -n "${EXPECT_APP}" ]]; then
  echo "expect_app=${EXPECT_APP}"
fi
echo "log_file=${LOG_FILE}"

"${EXECUTABLE_PATH}" "${ARGS[@]}" >"${LOG_FILE}" 2>&1 &
GAZEROW_PID="$!"

deadline=$((SECONDS + TIMEOUT_SECONDS))
frontmost_matched=0
while [[ "${SECONDS}" -lt "${deadline}" ]]; do
  if [[ -n "${EXPECT_APP}" && "$(frontmost_bundle_id)" == "${EXPECT_APP}" ]]; then
    frontmost_matched=1
  fi

  if grep -q '^GAZEROW_QUERY_RESULT ' "${LOG_FILE}"; then
    if [[ -z "${EXPECT_APP}" || "${frontmost_matched}" -eq 1 ]]; then
      break
    fi
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

if ! grep -q '^GAZEROW_QUERY_RESULT ' "${LOG_FILE}"; then
  echo "Query overlay evaluation did not report a query result before timeout." >&2
  exit 1
fi

if ! grep -q "^GAZEROW_QUERY_RESULT .*scope=${EXPECT_SCOPE} " "${LOG_FILE}"; then
  echo "Query overlay evaluation did not resolve expected scope: ${EXPECT_SCOPE}" >&2
  exit 1
fi

if ! grep -q '^GAZEROW_QUERY_RESULT .*success=true' "${LOG_FILE}"; then
  echo "Query overlay evaluation did not report success=true." >&2
  exit 1
fi

if [[ -n "${EXPECT_APP}" && "${frontmost_matched}" -ne 1 ]]; then
  echo "Window query did not activate expected frontmost app: ${EXPECT_APP}" >&2
  echo "frontmost_bundle_id=$(frontmost_bundle_id)" >&2
  exit 1
fi

echo "==> Query overlay evaluation passed"
