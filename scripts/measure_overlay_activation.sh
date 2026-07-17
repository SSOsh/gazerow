#!/usr/bin/env bash
# 대상 앱의 overlay activation timing을 반복 측정한다.
#
# @author suho.do
# @since 2026-07-17
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
TARGET_BUNDLE_ID=""
ITERATIONS=10
TIMEOUT_SECONDS=10
GAZEROW_PID=""

usage() {
  cat <<'USAGE'
Usage:
  scripts/measure_overlay_activation.sh --target-bundle-id <bundle-id> [--iterations <count>] [--timeout <seconds>]

Examples:
  scripts/measure_overlay_activation.sh --target-bundle-id com.google.Chrome
  scripts/measure_overlay_activation.sh --target-bundle-id com.apple.Safari --iterations 10

The target app must already be running and gazerow must have Accessibility permission.
This script only opens the overlay; it does not type, focus, or click a target.
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
    --target-bundle-id)
      TARGET_BUNDLE_ID="${2:-}"
      shift 2
      ;;
    --iterations)
      ITERATIONS="${2:-}"
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

if [[ -z "${TARGET_BUNDLE_ID}" ]]; then
  echo "--target-bundle-id is required." >&2
  usage >&2
  exit 2
fi

if ! [[ "${ITERATIONS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "--iterations must be a positive integer: ${ITERATIONS}" >&2
  exit 2
fi

if ! [[ "${TIMEOUT_SECONDS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "--timeout must be a positive integer: ${TIMEOUT_SECONDS}" >&2
  exit 2
fi

if [[ ! -d "${DEVELOPER_DIR}" ]]; then
  echo "Xcode developer directory not found: ${DEVELOPER_DIR}" >&2
  exit 1
fi

RUNNING_PROCESSES="$(
  ps -axo pid=,command= \
    | awk '$0 ~ /\/(GazeRow|gazerow)\.app\/Contents\/MacOS\/(GazeRow|gazerow)([[:space:]]|$)/ { print }'
)"
if [[ -n "${RUNNING_PROCESSES}" ]]; then
  echo "Quit the running gazerow app before measuring activation timing:" >&2
  echo "${RUNNING_PROCESSES}" >&2
  exit 3
fi

percentile() {
  local percentile="$1"
  shift

  printf '%s\n' "$@" | LC_ALL=C sort -n | awk -v percentile="${percentile}" '
    {
      values[++count] = $1
    }
    END {
      if (count == 0) {
        exit 1
      }
      rank = int((count * percentile) + 0.999999)
      if (rank < 1) {
        rank = 1
      }
      if (rank > count) {
        rank = count
      }
      print values[rank]
    }
  '
}

cd "${ROOT_DIR}"
export DEVELOPER_DIR

echo "==> Building gazerow"
swift build --product gazerow >/dev/null

BIN_DIR="$(swift build --show-bin-path)"
EXECUTABLE_PATH="${BIN_DIR}/gazerow"
if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
  echo "Built executable not found: ${EXECUTABLE_PATH}" >&2
  exit 1
fi

declare -a first_display_times=()

for attempt in $(seq 1 "${ITERATIONS}"); do
  LOG_FILE="$(mktemp -t gazerow_activation_measure.XXXXXX.log)"
  echo "==> Measuring ${TARGET_BUNDLE_ID} (${attempt}/${ITERATIONS})"

  "${EXECUTABLE_PATH}" \
    --show-overlay-on-launch \
    --target-bundle-id "${TARGET_BUNDLE_ID}" \
    --print-overlay-activation-trace >"${LOG_FILE}" 2>&1 &
  GAZEROW_PID="$!"

  deadline=$((SECONDS + TIMEOUT_SECONDS))
  while [[ "${SECONDS}" -lt "${deadline}" ]]; do
    if grep -q '^GAZEROW_OVERLAY_TIMING phase=firstDisplayPass ' "${LOG_FILE}"; then
      break
    fi
    if ! kill -0 "${GAZEROW_PID}" 2>/dev/null; then
      break
    fi
    sleep 0.1
  done

  cleanup
  wait "${GAZEROW_PID}" 2>/dev/null || true
  GAZEROW_PID=""

  grep '^GAZEROW_OVERLAY_' "${LOG_FILE}" || true
  first_display_time="$(awk '
    /^GAZEROW_OVERLAY_TIMING phase=firstDisplayPass / {
      for (field = 1; field <= NF; field++) {
        if ($field ~ /^elapsed_ms=/) {
          sub(/^elapsed_ms=/, "", $field)
          print $field
          exit
        }
      }
    }
  ' "${LOG_FILE}")"
  rm -f "${LOG_FILE}"

  if [[ -z "${first_display_time}" ]]; then
    echo "Overlay timing was not reported before timeout for ${TARGET_BUNDLE_ID}." >&2
    continue
  fi

  first_display_times+=("${first_display_time}")
done

if [[ "${#first_display_times[@]}" -eq 0 ]]; then
  echo "No successful overlay activation timings were collected." >&2
  exit 1
fi

p50="$(percentile 0.50 "${first_display_times[@]}")"
p95="$(percentile 0.95 "${first_display_times[@]}")"

echo "GAZEROW_OVERLAY_TIMING_SUMMARY bundle=${TARGET_BUNDLE_ID} runs=${ITERATIONS} successes=${#first_display_times[@]} first_display_p50_ms=${p50} first_display_p95_ms=${p95}"
