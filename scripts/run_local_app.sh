#!/usr/bin/env bash
# 로컬 GazeRow.app을 빌드하고 단일 인스턴스로 실행한다.
#
# @author suho.do
# @since 2026-07-16
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${APP_DIR:-${ROOT_DIR}/.build/local-app/GazeRow.app}"
REPLACE_RUNNING=false

if [[ "${1:-}" == "--replace-running" ]]; then
  REPLACE_RUNNING=true
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--replace-running]" >&2
  exit 64
fi

RUNNING_PROCESSES="$(
  ps -axo pid=,command= \
    | awk '$0 ~ /\/GazeRow\.app\/Contents\/MacOS\/GazeRow([[:space:]]|$)/ { print }'
)"

if [[ -n "${RUNNING_PROCESSES}" && "${REPLACE_RUNNING}" != true ]]; then
  echo "GazeRow is already running:" >&2
  echo "${RUNNING_PROCESSES}" >&2
  echo "Quit it first, or rerun with --replace-running." >&2
  exit 2
fi

if [[ -n "${RUNNING_PROCESSES}" ]]; then
  RUNNING_PIDS="$(echo "${RUNNING_PROCESSES}" | awk '{ print $1 }')"
  echo "==> Requesting existing GazeRow processes to terminate"
  for process_identifier in ${RUNNING_PIDS}; do
    kill -TERM "${process_identifier}"
  done

  for _ in $(seq 1 50); do
    has_running_process=false
    for process_identifier in ${RUNNING_PIDS}; do
      if kill -0 "${process_identifier}" 2>/dev/null; then
        has_running_process=true
        break
      fi
    done

    if [[ "${has_running_process}" == false ]]; then
      break
    fi
    sleep 0.1
  done

  for process_identifier in ${RUNNING_PIDS}; do
    if kill -0 "${process_identifier}" 2>/dev/null; then
      echo "GazeRow did not terminate cleanly (pid=${process_identifier})." >&2
      exit 3
    fi
  done
fi

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
APP_DIR="${APP_DIR}" \
  "${ROOT_DIR}/scripts/build_local_app.sh"

echo "==> Opening ${APP_DIR}"
open "${APP_DIR}"
