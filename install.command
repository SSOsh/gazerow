#!/usr/bin/env bash
# gazerow를 최신 소스로 빌드해 /Applications에 설치하고 실행한다.
# Finder에서 더블클릭하면 터미널이 열리며 그대로 실행된다.
#
# @author suho.do
# @since 2026-07-18
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${INSTALL_DIR:-/Applications/gazerow.app}" "${ROOT_DIR}/scripts/run_local_app.sh" --replace-running

echo
echo "설치가 끝났습니다. 앞으로는 Spotlight(⌘+Space)에서 'gazerow'를 검색하거나"
echo "응용 프로그램(Applications) 폴더에서 gazerow.app을 실행하면 됩니다."
read -rp "아무 키나 누르면 창이 닫힙니다..." _
