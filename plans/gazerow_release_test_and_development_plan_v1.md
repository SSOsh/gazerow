# GazeRow Release Test and Development Plan v1

## 변경 이력
- v1: 릴리즈 전 결함 발견을 위한 자동/수동 테스트 목록과 Post-MVP 개발 후보를 통합 정리.
- v2: 2026-07-03 Claude 자동/정적/smoke 테스트 실행 결과를 반영. 현재 기준 상태를 실측값으로 갱신하고, 핵심 5개 앱 overlay smoke 결과를 기록. System Settings smoke bundle id 오기(`com.apple.SystemSettings` → `com.apple.systempreferences`)를 수정.

## 1. 목적

이 문서는 GazeRow 릴리즈 전까지 결함을 최대한 빨리 발견하기 위한 테스트 목록을 정리한다.

범위:

- Codex가 실행하거나 반복 확인할 수 있는 자동화/반자동 테스트
- 사용자가 실제 macOS 환경에서 확인해야 하는 수동 테스트
- 테스트 중 발견해야 할 기존 결함 유형과 기록 기준
- 릴리즈 이후 또는 Post-MVP로 발전시킬 수 있는 개발 후보

비범위:

- 테스트 결과를 지어내는 것
- gaze/camera 기능을 MVP 릴리즈 필수 조건으로 올리는 것
- 외부 배포용 signing/notarization을 이미 완료된 것으로 간주하는 것

## 2. 현재 기준 상태

최신 확인 결과 (2026-07-03 Claude 실행):

| 항목 | 결과 |
| --- | --- |
| 기준 일시 | 2026-07-03 (v2 재검증) |
| 기준 위치 | `/Users/suho/Github/gazerow` |
| Freeze 검증 | `scripts/verify_mvp_freeze.sh` pass |
| Build | pass |
| Unit tests | 335 tests / 0 failures |
| Test 5회 반복 | 5회 모두 335 / 0, flaky 없음 |
| Excluded permission/framework grep | pass |
| 정적 검증(fallback/secure field/debug/raw text/author) | pass |
| 로컬 `.app` 번들 생성 | pass (adhoc 서명, arm64) |

핵심 5개 앱 overlay smoke 결과 (label map 미출력, click 미실행):

| 앱 | bundle id | 결과 |
| --- | --- | --- |
| Finder | `com.apple.finder` | success, `labels=46` |
| Safari | `com.apple.Safari` | success, `labels=35` |
| Chrome | `com.google.Chrome` | success, `labels=69` |
| VS Code | `com.microsoft.VSCode` | success, `labels=3` (빈 Welcome 화면 기준, 실제 워크스페이스 재측정 권장) |
| System Settings | `com.apple.systempreferences` | success, `labels=64` |

실행한 명령:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/verify_mvp_freeze.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/evaluate_overlay_target.sh --bundle-id com.apple.finder --timeout 8 --min-labels 1 --no-label-map
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/evaluate_overlay_target.sh --bundle-id com.apple.Safari --timeout 8 --min-labels 1 --no-label-map
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/evaluate_overlay_target.sh --bundle-id com.google.Chrome --timeout 8 --min-labels 1 --no-label-map
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/evaluate_overlay_target.sh --bundle-id com.microsoft.VSCode --timeout 10 --min-labels 1 --no-label-map
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/evaluate_overlay_target.sh --bundle-id com.apple.systempreferences --timeout 8 --min-labels 1 --no-label-map
```

현재 문서화된 지원 상태:

| 앱 | 상태 |
| --- | --- |
| Finder | Evaluation pass |
| Safari | Evaluation pass |
| Chrome | Evaluation pass |
| VS Code | Evaluation pass |
| System Settings | Evaluation pass |
| Slack | Evaluation pass |
| Notion | Evaluation pass |
| Discord | Limited, representative click pending |
| Obsidian | Unverified |

## 3. 릴리즈 판단 기준

릴리즈 전 반드시 만족해야 할 최소 조건:

- `scripts/verify_mvp_freeze.sh` 통과
- Accessibility 권한 granted 상태에서 대표 앱 overlay activation 성공
- 좌표 클릭 fallback 기본 off 유지
- critical misclick 0건
- 30분 이상 crash-free 수동 세션 1회 이상
- Settings, Onboarding, Known Limitations가 현재 기능/제한과 일치
- interaction log opt-in 기본 off
- debug export가 수동 액션으로만 생성됨
- 외부 배포를 한다면 signing/notarization/privacy 문서 준비 완료

릴리즈 보류 조건:

- overlay가 표시되지 않거나 frontmost 앱이 아닌 창을 스캔함
- label 위치가 실제 클릭 대상과 반복적으로 어긋남
- fallback off인데 좌표 클릭이 실행됨
- secure/password field가 후보로 표시됨
- raw window title, raw text value가 로그나 export에 저장됨
- 권한 거부/철회 상태에서 crash 또는 무응답 발생
- click 결과가 사용자 의도와 다른 destructive action을 실행함

## 4. Codex가 할 수 있는 테스트

Codex가 주로 담당할 수 있는 테스트는 터미널 기반 자동화, 정적 검증, 안전한 smoke 실행이다.
실제 사용감, 화면 가독성, 오클릭 여부는 사용자의 수동 확인이 필요하다.

### 4.1 기본 빌드/테스트

| 테스트 | 명령 | 발견 가능한 결함 |
| --- | --- | --- |
| Debug build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` | 컴파일 오류, 누락 파일, SwiftPM 설정 오류 |
| 전체 테스트 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | 도메인 로직 회귀, 모델/정책 회귀 |
| Freeze 검증 | `scripts/verify_mvp_freeze.sh` | build/test 실패, 제외 권한/API 참조 유입 |
| Clean build | `rm -rf .build && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` | 캐시 의존 빌드 문제 |
| Test repeat | `for i in {1..5}; do swift test || exit 1; done` | flaky test, 타이밍 의존성 |

### 4.2 테스트 클래스별 확인 범위

| 영역 | 대표 테스트 파일 | 확인하는 결함 |
| --- | --- | --- |
| Permission | `PermissionManagerTests.swift`, `CameraPermissionManagerTests.swift` | 권한 상태 갱신, 권한 없음 안내, camera opt-in 분리 |
| Launch options | `AppLaunchOptionsTests.swift` | 평가 런치 옵션 파싱 오류 |
| Targeting | `TargetResolverTests.swift`, `TargetWindowCandidateSelectorTests.swift`, `RecentNonSelfApplicationProviderTests.swift` | frontmost/focused window 선택 오류 |
| Accessibility scan | `AccessibilityScannerTests.swift`, `AccessibilityRootElementSelectorTests.swift`, `AccessibilityChildAttributeCollectorTests.swift` | 후보 누락, secure field 노출, depth/maxNodes 회귀 |
| Overlay | `OverlayLayoutEngineTests.swift`, `OverlayCoordinateMapperTests.swift`, `OverlayWindowControllerTests.swift`, `OverlayModelsTests.swift` | label 배치, 좌표 변환, overlay 입력 수신 회귀 |
| Focus | `FocusEngineTests.swift`, `FocusKeyboardCommandMapperTests.swift`, `FocusModelsTests.swift`, `LabelGeneratorTests.swift` | focus 이동, label jump, 키 입력 해석 오류 |
| Click | `ClickExecutorTests.swift`, `ClickRiskClassifierTests.swift`, `OverlaySessionClickTargetResolverTests.swift` | AXPress/AXOpen/AXConfirm/AXShowDefaultUI 선택 오류, second confirm 회귀 |
| Runtime | `OverlaySessionControllerTests.swift`, `OverlaySessionStartFailureTests.swift`, `OverlayLaunchReporterTests.swift` | resolve-scan-show-click 흐름 단절 |
| Window control | `WindowControlActionTests.swift`, `WindowControlShortcutTests.swift`, `WindowControlShortcutSetTests.swift`, `WindowControlCommandDispatcherTests.swift` | Control+Option+C/M/Z 해석과 AX 버튼 실행 오류 |
| Logging/privacy | `InteractionEventTests.swift`, `InteractionLogStoreTests.swift`, `WindowTitleHasherTests.swift`, `SessionSaltTests.swift`, `DebugExportManagerTests.swift`, `LogDirectoryTests.swift` | raw title 저장, log/export 생성/삭제, salt/hash 회귀 |
| UX content | `AppContentTests.swift`, `AppLanguageSettingsTests.swift`, `OnboardingStateTests.swift`, `DiagnosticsActionFeedbackTests.swift`, `DebugFeatureVisibilityTests.swift` | 안내 문구/언어/디버그 UI 기본값 회귀 |
| MVP policy | `MVPDefaultPolicyTests.swift` | MVP 제외 기능 기본 off 정책 회귀 |
| Gaze experimental | `GazeCalibration*Tests.swift`, `GazeFocus*Tests.swift`, `GazeActivation*Tests.swift`, `EyeFeatureExtractorTests.swift`, `CameraGazeSettingsTests.swift` | Post-MVP gaze 코드가 기본 off 정책을 깨는지 확인 |

### 4.3 정적 검증

| 테스트 | 명령 | 발견 가능한 결함 |
| --- | --- | --- |
| 제외 권한/API 참조 검사 | `grep -REn "ScreenCaptureKit|CGDisplayStream|NSScreenCaptureUsageDescription|NSMicrophoneUsageDescription|NSInputMonitoringUsageDescription" Package.swift Sources/GazeRow` | Screen Recording/Input Monitoring 등 MVP 제외 권한 유입 |
| raw text 저장 의심 문자열 검사 | `rg "title|value|help|description" Sources/GazeRow/Logging Sources/GazeRow/Runtime Sources/GazeRow/Clicking` | 로그/이벤트에 민감 텍스트 저장 가능성 |
| coordinate fallback 기본값 검사 | `rg "coordinate|fallback|CGEventPost" Sources/GazeRow Tests/GazeRowTests` | fallback 기본 off 회귀 |
| secure field 필터 검사 | `rg "secure|password|AXSecureTextField" Sources/GazeRow Tests/GazeRowTests` | 비밀번호 필드 후보 노출 위험 |
| debug UI 기본 숨김 검사 | `rg "DebugFeatureVisibility|debug export|isVisible" Sources/GazeRow Tests/GazeRowTests` | debug 기능 노출 회귀 |
| author 검사 | `rg "@author" .` | author 표기 규칙 위반 |

### 4.4 반자동 overlay smoke

사전 조건:

- Xcode full app 설치
- Accessibility 권한 granted
- 대상 앱 실행 가능
- 평가 중 사용자가 실제 화면 상태를 확인 가능

명령:

```bash
scripts/evaluate_overlay_target.sh --bundle-id com.apple.finder --timeout 8 --min-labels 1 --no-label-map
scripts/evaluate_overlay_target.sh --bundle-id com.apple.Safari --timeout 8 --min-labels 1 --no-label-map
scripts/evaluate_overlay_target.sh --bundle-id com.google.Chrome --timeout 8 --min-labels 1 --no-label-map
scripts/evaluate_overlay_target.sh --bundle-id com.microsoft.VSCode --timeout 10 --min-labels 1 --no-label-map
scripts/evaluate_overlay_target.sh --bundle-id com.apple.systempreferences --timeout 8 --min-labels 1 --no-label-map
```

확인할 결함:

- `GAZEROW_OVERLAY_RESULT failure`
- timeout
- labels가 0 또는 기존 기준보다 급감
- 대상 앱이 아닌 GazeRow/다른 앱이 스캔됨
- overlay가 실제 화면에는 보이지 않음

### 4.5 반자동 click smoke

사용자가 label map을 보고 안전한 label을 지정한 뒤 실행한다.
Codex는 임의 label을 찍지 않는다.

```bash
scripts/evaluate_overlay_target.sh --bundle-id com.apple.finder --click-label <LABEL> --timeout 8 --no-label-map
```

확인할 결함:

- click result failure
- `fallback=true`
- click method가 기대와 다름
- second confirm이 필요한 대상인데 즉시 실행됨
- click 후 overlay가 닫히지 않음

### 4.6 로컬 앱 번들 smoke

SwiftPM 실행과 `.app` 실행은 activation/keyboard focus 조건이 다르므로 별도로 확인한다.

```bash
scripts/build_local_app.sh
open -n .build/local-app/GazeRow.app
```

확인할 결함:

- `.app` bundle 생성 실패
- 메뉴바 아이콘 미표시
- Settings window 열기 실패
- Command+Shift+Space hotkey 미등록
- overlay keyboard input 미수신

### 4.7 문서 일관성 검사

Codex가 비교할 문서:

- `README.md`
- `plans/gazerow_known_limitations_v1.md`
- `plans/gazerow_mvp_freeze_package_v1.md`
- `plans/gazerow_distribution_checklist_v1.md`
- `plans/gazerow_post_mvp_app_evaluation_v1.md`

확인할 결함:

- 지원 앱 등급 불일치
- 테스트 개수/최신 검증 결과 불일치
- MVP 제외 기능이 포함 기능처럼 설명됨
- 권한 사용 설명이 실제 동작과 다름
- Post-MVP 항목이 릴리즈 필수 항목처럼 섞임

## 5. 사용자가 해야 하는 테스트

사용자 수동 테스트는 화면 인지, 실제 macOS 권한, 앱 상태, 오클릭 위험을 확인하는 목적이다.
각 테스트는 가능하면 화면 녹화 없이 체크리스트로 기록하고, 민감 정보가 보이는 앱에서는 label map/export 저장을 피한다.

### 5.1 설치/최초 실행

| 테스트 | 절차 | Pass 기준 |
| --- | --- | --- |
| 최초 실행 | `.app` 실행 또는 `swift run GazeRow` | 메뉴바 아이콘 표시, crash 없음 |
| Settings 열기 | 메뉴바 아이콘 → Open Settings | Settings window 표시 |
| Quit | 메뉴바 아이콘 → Quit | 앱 정상 종료 |
| 재실행 | 종료 후 다시 실행 | 상태 꼬임 없이 실행 |
| Dock 표시 여부 | 실행 중 Dock 확인 | 메뉴바 앱으로 동작, 불필요한 Dock 노출 없음 |
| 다중 실행 | 앱을 두 번 열기 | 중복 메뉴바 아이콘/세션 문제가 없는지 확인 |

### 5.2 Accessibility 권한

| 테스트 | 절차 | Pass 기준 |
| --- | --- | --- |
| 권한 없음 상태 | Accessibility 권한 제거 후 overlay 시도 | 명확한 안내, crash 없음 |
| 권한 요청 | Settings 또는 `--request-accessibility` | System Settings 이동/요청 동선 정상 |
| 권한 부여 후 refresh | 권한 허용 후 Settings 재확인 | granted 표시 |
| 권한 철회 | 실행 중 권한 제거 후 overlay 시도 | 차단 안내, crash 없음 |
| 권한 재부여 | 권한 다시 허용 후 overlay | 정상 복구 |

### 5.3 Onboarding / Settings / Known Limitations

| 테스트 | 절차 | Pass 기준 |
| --- | --- | --- |
| 첫 실행 onboarding | UserDefaults 초기화 후 실행 | Setup steps와 non-medical disclaimer 표시 |
| onboarding 완료 저장 | 완료 후 재실행 | 같은 onboarding이 반복 노출되지 않음 |
| Known Limitations | Settings에서 열기 | 제한사항과 app support tier가 최신 문서와 일치 |
| Shortcuts 안내 | Settings Shortcuts 확인 | Command+Shift+Space, Control+Option+C/M/Z 표시 |
| 언어 설정 | English/Korean 전환 | 주요 문구가 해당 언어로 표시 |
| debug UI 기본값 | Settings 확인 | debug export UI가 기본 숨김 |

### 5.4 Overlay activation

| 테스트 | 절차 | Pass 기준 |
| --- | --- | --- |
| 메뉴 activation | 대상 앱 전면 → 메뉴바 Show Overlay | overlay 표시 |
| 단축키 activation | Command+Shift+Space | overlay 표시 |
| 반복 activation | 20회 열고 닫기 | crash, stuck window 없음 |
| Esc close | overlay 표시 후 Esc | overlay 닫힘 |
| 앱 전환 직후 activation | 앱 전환 후 즉시 단축키 | 직전/대상 앱 선택이 기대와 일치 |
| session disabled | kill switch off 후 activation | overlay 차단 |
| session re-enable | 다시 enable 후 activation | overlay 복구 |

### 5.5 App별 대표 task

각 앱에서 최소 3회 반복한다.

| 앱 | 테스트 task | Pass 기준 |
| --- | --- | --- |
| Finder | sidebar item 또는 row 실행 | label 표시, keyboard confirm으로 target 이동 |
| Safari | toolbar button 또는 tab overview | UI 반응 확인 |
| Chrome | 주소창 focus | confirm 후 텍스트 입력 가능 |
| VS Code | Activity Bar item 전환 | target view 전환 |
| System Settings | Back button 또는 pane 이동 | pane 이동 또는 상태 변화 |
| Slack | Messages tab 또는 안전한 탭 이동 | `fallback=false` 상태로 UI 전환 |
| Notion | breadcrumb/page 안전 클릭 | 페이지/위치 전환 |
| Discord | 안전한 non-destructive UI 클릭 | representative click pass 여부 결정 |
| Obsidian | 설치 후 sidebar/file 안전 클릭 | Unverified 해소 |

앱별로 기록할 값:

```text
app:
bundleId:
version:
task:
attempt:
labelCount:
taskSuccess:
clickMethod:
fallbackUsed:
criticalMisclickCount:
missingImportantElements:
noisyElements:
overlayMisaligned:
notes:
```

### 5.6 Label/focus 조작

| 테스트 | 절차 | Pass 기준 |
| --- | --- | --- |
| Tab 이동 | overlay에서 Tab 반복 | focus가 순차 이동 |
| Shift+Tab 이동 | 역방향 반복 | focus가 역방향 이동 |
| Arrow 이동 | 위/아래 방향키 | 기대 순서로 이동 |
| label jump 성공 | 보이는 label 입력 | 해당 후보로 focus 이동 |
| label jump 실패 | 없는 label 입력 | crash 없이 miss 처리 |
| label buffer reset | 입력 후 Esc/timeout/다른 명령 | 다음 입력에 잔여 버퍼 없음 |
| Return confirm | focus된 후보에서 Return | click 실행 또는 second confirm |
| second confirm | 위험/unknown 후보에서 Return 두 번 | 첫 번째는 대기, 두 번째 실행 |

### 5.7 Click safety

| 테스트 | 절차 | Pass 기준 |
| --- | --- | --- |
| fallback off | 기본 설정으로 click | 좌표 클릭 fallback 미사용 |
| safe navigation | 일반 버튼/탭 click | 1회 confirm으로 실행 |
| destructive 후보 | 닫기/삭제류 후보 확인 | second confirm 요구 |
| external effect 후보 | 외부 링크/전송류 후보 확인 | second confirm 요구 |
| secure field 제외 | 로그인/비밀번호 화면에서 overlay | password/secure field 후보 없음 |
| 실패 click | action 없는 후보 click | 실패 안내/로그, 오클릭 없음 |
| overlay close after click | click 성공 후 | overlay가 닫힘 |

### 5.8 Window control 단축키

| 테스트 | 절차 | Pass 기준 |
| --- | --- | --- |
| Close | 대상 앱 창 전면 → Control+Option+C | focused window close button AXPress |
| Minimize | Control+Option+M | focused window minimize |
| Zoom | Control+Option+Z | focused window zoom |
| 권한 없음 | 권한 제거 후 단축키 | crash 없이 실패 |
| 창 없음 | window 없는 앱 전면에서 단축키 | crash 없이 실패 |
| 반복 입력 | 같은 단축키 10회 | stuck state 없음 |
| 충돌 확인 | 시스템/앱 단축키와 충돌 여부 확인 | 문서화 또는 변경 필요로 기록 |

### 5.9 Overlay 시각 품질

| 테스트 | 절차 | Pass 기준 |
| --- | --- | --- |
| label readability | 밝은/어두운 UI에서 확인 | label 읽기 가능 |
| collision | label이 밀집된 화면 확인 | 중요한 label이 겹치지 않음 |
| occlusion | 버튼 위 label 위치 확인 | 대상 자체를 과도하게 가리지 않음 |
| misalignment | label 중심과 실제 후보 비교 | 명확한 위치 오차 없음 |
| small controls | 작은 toolbar/icon button | label 표시/선택 가능 |
| large lists | Finder/Notion/Slack list | 후보 과다/누락 기록 |
| scrolling view | 스크롤 가능한 목록 | 보이는 후보만 합리적으로 표시 |

### 5.10 디스플레이/공간 조건

| 테스트 | 절차 | Pass 기준 |
| --- | --- | --- |
| Retina internal display | MacBook 내장 화면 | 좌표/label 정상 |
| external display | 외장 모니터에서 실행 | 좌표 변환 정상 |
| display above/below | 보조 모니터를 위/아래 배치 | overlay 위치 정상 |
| display left/right | 보조 모니터 좌/우 배치 | overlay 위치 정상 |
| Spaces 전환 | 다른 Space에서 앱 전면 | target/overlay 정상 |
| full screen app | 전체 화면 앱 | 가능 범위 문서화, crash 없음 |
| Stage Manager | 켜고 overlay | 오작동 여부 기록 |
| Mission Control 직후 | 전환 직후 activation | stuck overlay 없음 |

### 5.11 Privacy/log/export

| 테스트 | 절차 | Pass 기준 |
| --- | --- | --- |
| log 기본 off | fresh run Settings 확인 | opt-in off |
| log opt-in on | opt-in 후 overlay/click 수행 | JSONL 생성 |
| log 내용 검사 | 생성 파일 열기 | raw title/text value 없음 |
| log 삭제 | Settings delete logs | 파일 삭제/상태 피드백 |
| debug export 생성 | debug UI 노출 후 manual export | 수동 액션으로만 zip/export 생성 |
| debug export 내용 | export 열기 | 민감 원문 없음 |
| debug export 삭제 | delete export | 파일 삭제/상태 피드백 |
| salt/hash | 같은 세션/다른 세션 비교 | 원문 없이 hash만 저장 |

### 5.12 성능/안정성

| 테스트 | 절차 | Pass 기준 |
| --- | --- | --- |
| 30분 crash-free | 실제 작업 중 30분 실행 | crash 없음 |
| overlay 반복 | 100회 open/close | memory/CPU 급증 없음 |
| scan duration | label map 출력으로 앱별 scan 시간 기록 | 체감 지연 허용 범위 |
| large AX tree | VS Code/Discord/Slack에서 실행 | timeout 없이 반환 |
| app launch/quit churn | 대상 앱 종료/재실행 반복 | graceful failure/recovery |
| sleep/wake | Mac sleep 후 wake | hotkey/메뉴바 정상 |
| network 없는 상태 | Slack/Notion 등 offline | crash 없음, 가능한 실패 안내 |

### 5.13 패키징/배포 수동 테스트

외부 배포를 한다면 필수다.

| 테스트 | 절차 | Pass 기준 |
| --- | --- | --- |
| local `.app` 생성 | `scripts/build_local_app.sh` | bundle 생성 |
| clean machine 실행 | 새 사용자/다른 Mac에서 실행 | 최초 실행/권한 동선 정상 |
| quarantine 상태 실행 | 다운로드된 파일처럼 실행 | Gatekeeper 동작 확인 |
| code signing | `codesign --verify --deep --strict --verbose=2 GazeRow.app` | pass |
| Gatekeeper | `spctl --assess --type execute --verbose=4 GazeRow.app` | pass |
| notarization staple | `xcrun stapler validate GazeRow.app` | pass |
| version 표시 | 앱/문서/릴리즈 노트 | 버전/빌드 일치 |
| privacy 문서 | 배포 페이지/README | 권한/로그/카메라 미사용 설명 일치 |

## 6. 결함 유형과 기록 기준

Severity:

| 등급 | 의미 | 릴리즈 판단 |
| --- | --- | --- |
| P0 | crash, data/privacy leak, critical misclick, destructive action 오동작 | 즉시 릴리즈 보류 |
| P1 | 핵심 5개 앱의 대표 task 실패, 권한 복구 불가, overlay 좌표 큰 오차 | 릴리즈 보류 또는 조건부 보류 |
| P2 | 특정 앱/화면에서 후보 누락/과다, UX friction, 문서 불일치 | known limitation 또는 fix 후보 |
| P3 | polish, 문구, 낮은 빈도 개선 | Post-MVP backlog |

결함 기록 양식:

```text
id:
severity: P0 / P1 / P2 / P3
foundAt:
tester:
app:
bundleId:
macOSVersion:
displaySetup:
buildCommit:
commandOrSteps:
expected:
actual:
reproRate:
fallbackUsed:
criticalMisclick:
logsOrOutput:
privacySensitiveDataIncluded: yes / no
workaround:
releaseDecision:
owner:
nextAction:
```

기존 결함을 의심해야 하는 신호:

- label count가 과거보다 크게 줄어듦
- 특정 앱에서 window-control-only 후보만 나옴
- overlay가 보이지만 키보드 입력을 받지 않음
- 후보는 보이는데 click result가 failure
- click method가 `fallback`으로 표시됨
- second confirm 없이 위험 후보가 실행됨
- Settings 문구와 실제 단축키/권한 상태가 다름
- debug/export/log가 기본 노출되거나 자동 생성됨
- 앱 전환 직후 GazeRow 자신을 스캔함
- 외장 모니터에서 label이 상하 반전 또는 다른 화면에 표시됨

## 7. 릴리즈 전 테스트 순서

권장 순서:

1. 코드 변경 직후: `swift test`
2. 릴리즈 후보 생성 직후: `scripts/verify_mvp_freeze.sh`
3. 권한 granted 상태 확인
4. Finder overlay smoke
5. 핵심 5개 앱 overlay smoke
6. 핵심 5개 앱 representative click task
7. Settings/Onboarding/Known Limitations 수동 확인
8. log/export privacy 수동 확인
9. 30분 crash-free session
10. `.app` bundle smoke
11. 외부 배포 시 signing/notarization/clean machine smoke

릴리즈 직전 재실행해야 하는 최소 세트:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/verify_mvp_freeze.sh
scripts/evaluate_overlay_target.sh --bundle-id com.apple.finder --timeout 8 --min-labels 1 --no-label-map
```

그리고 사용자가 직접 확인:

- Command+Shift+Space overlay activation
- Finder/Safari/Chrome/VS Code/System Settings task 각 1회
- fallback off와 critical misclick 0건
- Settings의 권한/제한/단축키 문구

## 8. 향후 개발 가능한 부분

### 8.1 Release hardening

- 실제 Bundle Identifier 확정
- version/build number 정책 추가
- Developer ID signing 자동화
- notarization 자동화
- clean machine smoke runbook 자동화
- crash report 수집 여부 결정
- opt-in telemetry가 필요한지 제품/개인정보 관점에서 결정
- 릴리즈 노트 템플릿 작성
- privacy policy 작성
- uninstall/delete data 안내 추가

### 8.2 Test automation

- overlay smoke 앱 매트릭스 자동 실행 스크립트 확장
- label count baseline 저장과 회귀 감지
- click smoke를 안전 label registry 기반으로 자동화
- screenshot 기반 overlay 위치 검증
- multi-display 좌표 테스트 fixture 추가
- performance budget 테스트 추가
- flaky test repeat job 추가
- GitHub Actions 또는 로컬 CI 스크립트 추가
- `.app` bundle 생성 후 launch smoke 자동화
- generated debug export privacy scanner 추가

### 8.3 App coverage

- Discord representative click 검증 완료
- Obsidian 설치 환경 검증
- Mail, Calendar, Notes, Reminders, Terminal, iTerm2, Xcode, Figma, Linear 등 자주 쓰는 앱 확장 평가
- 앱별 known limitation catalog 작성
- bundle id별 안전 task registry 작성
- 앱별 min label count baseline 관리
- 앱 업데이트 후 회귀 재평가 루틴 추가

### 8.4 Scanner/targeting

- AX tree depth/maxNodes 앱별 튜닝
- noisy image candidate 필터 개선
- selectable container 후보 ranking 개선
- target window selection heuristic 개선
- window 없는 앱/패널/팝오버 처리 강화
- focused window fallback 우선순위 조정
- scroll view 내부 후보 품질 개선
- candidate confidence score 추가
- missing important element debug view 강화

### 8.5 Overlay/focus UX

- label collision mitigation 개선
- label 가독성 테마 개선
- 고밀도 화면에서 label 그룹핑
- fuzzy label typing 또는 prefix preview
- focus order를 시각적 위치 기준으로 개선
- overlay open/close animation 최소화 검토
- label size/accessibility setting 추가
- 다중 모니터에서 target screen indicator 추가
- overlay가 대상 UI를 가리는 문제 완화

### 8.6 Click safety

- risky action classifier 정교화
- 앱별 destructive role/action 예외 목록
- second confirm UI 피드백 강화
- fallback on debug 모드의 노출/경고 강화
- click 후 결과 검증 heuristic 추가
- 실패 click의 사용자 피드백 개선
- secure field/민감 영역 필터 추가 검증
- accidental repeat key 방지 강화

### 8.7 Shortcuts/window control

- 단축키 커스터마이징
- 단축키 충돌 감지
- global hotkey 등록 실패 안내
- Control+Option+C/M/Z 외 window action 확장
- repeat key/debounce 정책 강화
- 앱별 window button 미지원 fallback 안내

### 8.8 Privacy/diagnostics

- export 내용 schema 문서화
- export 자동 민감정보 검사
- log retention 정책 추가
- one-click data delete 강화
- opt-in 상태를 더 명확히 표시
- privacy mode에서 label map 출력 제한
- support bundle 생성 시 사용자 확인 단계 추가

### 8.9 Gaze Post-MVP

- camera/gaze opt-in UX 완성
- camera permission 안내와 거부/철회 복구
- calibration 품질 기준 정의
- dwell activation threshold 튜닝
- gaze focus와 keyboard confirm 결합
- fatigue/false positive 방지
- camera unavailable 상태 처리
- low light/안경/외장 카메라 조건 평가
- gaze 기능을 기본 off로 유지하는 release gate 추가

### 8.10 Product/documentation

- 초보자용 3분 평가 재개
- 내부 사용자 3명 평가 완료
- onboarding copy 간소화
- known limitations를 앱별로 더 구체화
- troubleshooting 문서 추가
- demo GIF 또는 짧은 사용 영상 추가
- keyboard-only user flow 개선
- feedback/issue template 추가
- 후원/라이선스/배포 페이지 정리

## 9. 다음 실행 제안

가장 가까운 다음 테스트:

1. 핵심 5개 앱 overlay smoke 재실행
2. 핵심 5개 앱 representative click task를 사용자가 화면 보며 재검증
3. Discord representative click 안전 label 확정
4. Obsidian 설치 환경에서 smoke 실행
5. interaction log/export 파일에 민감 원문이 없는지 수동 확인
6. `.app` bundle로 30분 crash-free session 재수행

---

@author suho.do
@since 2026-07-03
