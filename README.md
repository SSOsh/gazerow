# gazerow

키보드만으로 화면 위 버튼·링크·메뉴를 클릭하는 macOS 유틸리티입니다.
단축키로 overlay를 켜면 클릭 가능한 요소마다 문자 라벨이 붙고, 라벨을 입력해
focus를 맞춘 뒤 키로 확인하면 마우스 없이 클릭됩니다. (Homerow 스타일)

*이 문서의 [영어 버전](README.en.md)도 있습니다.*

- 마우스에 손을 떼지 않고 앱을 조작하고 싶은 키보드 중심 사용자를 위한 도구입니다.
- macOS 손쉬운 사용(Accessibility) 트리를 읽어 동작하며, 모든 데이터는 로컬에만 있습니다.
- 접근성/보조공학 제품이나 의료·안전 필수 용도로 설계된 제품이 아닙니다.

> **개발 진행 중**입니다. 무료 베타 ZIP은 Apple Developer ID 서명과 공증을 받지
> 않았습니다. 출처를 신뢰할 수 있을 때만 아래 보안 예외 절차로 실행하세요.

---

## 무료 베타 설치

무료 베타는 Xcode나 터미널 없이 실행할 수 있는 Universal `gazerow.app`을 포함하며
Apple Silicon과 Intel Mac을 모두 지원합니다.

1. [GitHub Releases](https://github.com/SSOsh/gazerow/releases)에서
   `gazerow-*-macos-universal.zip`을 내려받아 압축을 풉니다.
2. `gazerow.app`을 **응용 프로그램(Applications)** 폴더로 옮깁니다.
3. 앱을 더블클릭해 한 번 실행을 시도합니다. 미확인 개발자 경고로 실행이 차단됩니다.
4. **시스템 설정 → 개인정보 보호 및 보안 → 보안**에서 gazerow의
   **확인 없이 열기(Open Anyway)**를 선택합니다.
5. gazerow를 다시 실행하고 앱 안내에 따라 **손쉬운 사용 권한**을 허용합니다.

> Apple 공증을 받지 않은 무료 베타이므로 macOS의 경고는 정상입니다. ZIP과 함께
> 제공되는 `.sha256` 파일로 무결성을 확인할 수 있습니다. 새 베타의 ad-hoc 서명이
> 달라지면 손쉬운 사용 권한을 다시 허용해야 할 수 있습니다.

```bash
# 선택 사항: ZIP과 .sha256 파일을 같은 폴더에 둔 뒤 무결성 확인
shasum -a 256 -c gazerow-0.1.0-beta.1-macos-universal.zip.sha256
```

---

## 빠른 시작

1. **앱 실행** — 실행하면 Dock 아이콘 없이 메뉴바에 gazerow 키보드 격자 아이콘이 나타납니다.
2. **권한 허용** — 첫 실행 안내(또는 Settings)에서 **손쉬운 사용 권한**을 허용하고
   **다시 확인**을 누릅니다. 이 권한이 있어야 overlay와 클릭이 동작합니다.
3. **Overlay 열기** — 조작하려는 앱을 맨 앞에 둔 상태에서 `Command+Shift+Space`를 누릅니다.
4. **라벨 입력** — 클릭할 요소 위의 문자 라벨을 그대로 입력합니다.
5. **확인 클릭** — `Return`을 누르면 focus된 요소가 클릭됩니다.

> 카메라·시선 추적은 필요 없습니다. gaze 기능은 실험 기능이며 기본적으로 꺼져 있습니다.

---

## 사용 방법

### Overlay 활성화

| 동작 | 단축키 |
| --- | --- |
| Overlay 표시 (기본) | `Command+Shift+Space` |
| Overlay 표시 (보조) | `Control+Option+Command+Space` |
| 메뉴바에서 표시 | 메뉴바 아이콘 → **Show Overlay** |

### Overlay 안에서 조작

Overlay를 열면 실행 가능한 요소마다 문자 라벨(A, B, … AA, AB …)이 붙습니다.

| 하고 싶은 것 | 키 |
| --- | --- |
| 요소에 focus 맞추기 | 라벨 문자 입력 (예: `F`, `AB`) |
| focus한 요소 클릭 | `Return` |
| 요소 검색 / 창 전환 | `/` / `;` |
| 다음 / 이전 후보로 이동 | `Tab` / `Shift+Tab` |
| 위 / 아래 후보로 이동 | `↑` / `↓` |
| 입력한 라벨 문자 지우기 | `Delete` |
| 클릭하지 않고 닫기 | `Esc` |

키보드 레이아웃은 자동으로 처리됩니다. 별도 변환 설정이나 영문 전환은 필요하지 않습니다.

### Query Overlay

Overlay를 연 뒤 `/`를 누르면 요소 검색, `;`를 누르면 창 검색으로 scope가 고정됩니다.
하단 status bar의 `Windows` / `Elements` / `Labels` 칩을 클릭해도 같은 scope로 전환할 수 있습니다.
검색어를 입력하면 현재 match 수와 focus 대상이 status에 표시됩니다.
`Tab` / `Shift+Tab`으로 검색 결과를 순환하고 `Delete`로 검색어를 지웁니다.
요소 scope에서 `Return`은 focus된 요소를 클릭하고, 창 scope에서 `Return`은 선택한 앱/창으로 전환합니다.
매칭 결과가 없으면 기존 label focus를 비워 `Return`이 이전 label을 실행하지 않습니다.
bare letter 입력은 기존 라벨 선택을 우선하므로 기존 라벨 조작 흐름은 유지됩니다.

### 창 컨트롤 단축키

맨 앞 창의 표준 title-bar 버튼(닫기·최소화·확대/축소)을 키보드로 누릅니다.
gazerow에 손쉬운 사용 권한이 있을 때만 동작합니다.

| 동작 | 단축키 |
| --- | --- |
| 창 닫기 | `Control+Option+C` |
| 창 최소화 | `Control+Option+M` |
| 창 확대/축소 | `Control+Option+Z` |

### 즉시 중지 (Kill Switch)

메뉴바 아이콘이나 Settings에서 세션을 **비활성화**하면 overlay 활성화가 즉시 멈춥니다.
다시 **활성화**하면 재개됩니다.

---

## 클릭 안전 정책

- **자동 클릭은 없습니다.** 모든 클릭은 `Return` 키로 명시 확인해야 실행됩니다.
- 삭제·외부 영향·위험도 불명 같은 위험한 동작은 **한 번 더 확인**을 요구합니다.
- 클릭은 접근성 action(`AXPress`, `AXConfirm`, `AXOpen`, `AXShowDefaultUI`)을 사용합니다.
- 오클릭 위험을 줄이기 위해 **좌표 기반 클릭 fallback은 기본적으로 꺼져** 있습니다.
- 비밀번호 등 secure field는 스캔 단계에서 후보에서 제외됩니다.

---

## 개인정보

- 모든 처리는 **로컬**에서 이뤄지며 네트워크로 전송하지 않습니다.
- Interaction 로그 저장은 **기본 꺼짐(opt-in)**입니다. 켜더라도 최소한의 focus/click
  이벤트만 저장하고, 창 제목은 **세션별 hash로만** 저장합니다. 원문 제목·텍스트 값은
  절대 저장하지 않습니다.
- baseline에서는 **카메라·입력 모니터링 권한을 요청하지 않습니다.**
- Debug Export는 문제 해결용 진단 snapshot을 일반 텍스트로 저장하며, 원본 창 제목이나
  텍스트 값은 포함하지 않습니다.

---

## 앱 지원 범위

| 앱 | 지원 등급 |
| --- | --- |
| Finder | 지원됨 |
| Safari | 지원됨 |
| Chrome | 지원됨 |
| VS Code | 지원됨 |
| System Settings | 지원됨 |
| Slack | 지원됨 |
| Notion | 지원됨 |
| Discord | 제한적 지원 (후보는 보이나 대표 클릭 검증 미완료) |
| Obsidian | 미확인 (평가 환경에 미설치) |

**등급 의미**

- **지원됨**: 실제 클릭 task 검증을 통과한 앱.
- **제한적 지원**: 동작하지만 후보 수집이나 클릭에 제약이 있는 앱.
- **미확인**: 아직 검증하지 않은 앱.

---

## 알려진 제한사항

- 맨 앞 앱의 focused window만 스캔합니다.
- 일부 앱은 접근성 트리를 불완전하게 노출해 일부 후보가 빠질 수 있습니다.
- 지원되는 접근성 action이 없는 요소는 클릭되지 않을 수 있습니다.
- 좌표 기반 클릭 fallback은 기본 꺼짐이며, 명시 확인된 overlay 클릭 경로에서만
  제한적으로 사용합니다.

---

## 요구 사항 / 설치

| 항목 | 값 |
| --- | --- |
| 최소 macOS 버전 | macOS 14 |
| 앱 형태 | 메뉴바 앱 + Settings window |
| 필요 권한 | 손쉬운 사용(Accessibility) |
| 언어 | 한국어 / English |

베타 ZIP 사용에는 Xcode가 필요하지 않습니다. 소스에서 직접 빌드할 때는 Swift
Package Manager 기반으로 **Xcode 15 이상(Swift 5.9 이상) toolchain**이 필요합니다.
macOS 14와 SwiftUI Observation API를 사용하므로 Xcode 14 이하는 지원 대상이 아닙니다.

```bash
# Xcode 라이선스 최초 1회 동의 (필요 시)
sudo xcodebuild -license accept

# 빌드 / 실행 (Xcode toolchain 지정)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run

# 손쉬운 사용 권한 요청/설정 화면을 바로 열고 실행
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run gazerow -- --request-accessibility

# 로컬 .app 번들 생성 후 단일 인스턴스로 실행 (키 입력/activation이 더 안정적)
scripts/run_local_app.sh

# 실행 중인 기존 gazerow를 정상 종료한 뒤 새 빌드로 교체
scripts/run_local_app.sh --replace-running

# 무료 Universal 베타 ZIP과 SHA-256 체크섬 생성
scripts/package_beta_release.sh
```

> **주의**: 여러 Xcode 버전이 설치되어 있으면 위처럼 `DEVELOPER_DIR`로 원하는
> Xcode toolchain을 지정하세요. 로컬 `.app` 번들 생성/서명 흐름은 전체 Xcode
> 설치를 기준으로 검증합니다. `open -n`은 중복 인스턴스를 강제로 만들기 때문에
> 사용하지 마세요.

터미널 명령이 낯설다면 저장소 루트의 `install.command`를 Finder에서 더블클릭하세요.
최신 소스로 빌드해 `/Applications/gazerow.app`으로 설치하고 바로 실행까지 해줍니다.
설치 후에는 Spotlight(⌘+Space)에서 "gazerow"를 검색하거나 응용 프로그램(Applications)
폴더에서 실행할 수 있습니다.

실행 후 메뉴바 키보드 격자 아이콘을 클릭하면 **Open Settings** / **Quit** 등으로 동작을
확인할 수 있습니다. 권한이 없으면 Settings의 **권한 요청** 버튼이나 위 런치 옵션으로
권한 동선을 열 수 있습니다.

---

## 후원

gazerow가 작업 흐름에 도움이 됐다면 메뉴바의 **Support gazerow**에서 개발을 응원해
주세요. 후원 안내에서 **계좌번호 복사**를 누르면 카카오뱅크 `3333-26-7184989`가
클립보드에 복사됩니다.

---

## 개발자 문서

빌드/테스트, 프로젝트 구조, 티켓 진행 내역 등 구현 세부 내용은 `plans/` 폴더를 참고하세요.

```bash
# 테스트 실행
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
