# GazeRow

macOS 키보드 클릭 유틸리티 (Homerow 스타일). 화면 위의 클릭 가능한 UI 요소를
자동으로 찾아 label을 붙이고, 사용자가 키보드로 focus와 click을 수행하게 한다.

> **현재 상태**: TICKET-001부터 TICKET-009까지 MVP core/UX 구현 완료.
> 메뉴바 앱 shell + Settings window + Accessibility 권한 UX + target resolver
> + Accessibility scanner + overlay layout/window 기반 + focus engine
> + AXPress click executor + local interaction logging/debug export
> + kill switch + onboarding + known limitations 문서화.
> TICKET-010 사전 검증과 TICKET-011 freeze 준비 산출물은 완료했으며,
> TICKET-010 수동 평가 착수 중 확인된 end-to-end overlay activation/click
> runtime wiring 차단과 Accessibility 권한 차단은 해소했다. 5개 앱
> overlay activation smoke와 5개 앱 실제 click task를 수행했다. 초기 결과는
> Safari/Chrome/System Settings pass, Finder/VS Code fail이었지만,
> candidate coverage, launch-option click result stdout, overlay panel 좌표 변환,
> `--click-overlay-label`, `AXShowDefaultUI` 실행 지원을 보강한 뒤
> Finder/VS Code fixed task 재평가도 pass했다. 30분 crash-free session도
> 통과했다. 내부 사용자 3명 gate는 ED-008에 따라 Post-MVP로 defer했다.

## MVP 포지셔닝

- 로컬 macOS keyboard-click utility
- Baseline MVP는 gaze(카메라) 없이 동작
- gaze는 Post-MVP experimental 기능으로 분리
- 접근성/의료 보조 제품으로 포지셔닝하지 않음

## 기본 결정값

| 항목 | 값 |
| --- | --- |
| 앱 이름 | GazeRow |
| Bundle Identifier | `dev.local.gazerow` |
| 최소 macOS 버전 | macOS 14 |
| 앱 형태 | 메뉴바 앱(`.accessory`) + Settings window |
| overlay 활성화 | Command+Shift+Space 또는 메뉴바 "Show Overlay" 메뉴 |
| UI 기술 | SwiftUI(Settings) + AppKit(status item / lifecycle) |

## 프로젝트 구조

```text
gazerow/
  Package.swift
  Sources/GazeRow/
    App/
      GazeRowApp.swift      # @main 진입점, Settings scene
      AppDelegate.swift     # AppKit lifecycle, 메뉴바 status item
    UI/
      SettingsView.swift      # Settings window 본문
      OnboardingView.swift    # 첫 실행 안내 시트
      KnownLimitationsView.swift # 제한사항/앱 지원 열람 시트
    Infrastructure/
      AppState.swift          # 앱 메타데이터, MVP 상태, 권한 안내 문구
      AppLogger.swift         # OSLog wrapper (lifecycle / session)
      DebugFeatureVisibility.swift # debug 전용 UI 기본 숨김 정책
      DiagnosticsActionFeedback.swift # diagnostics 수동 액션 결과 표시 상태
      MVPDefaultPolicy.swift   # MVP freeze 기본값 자동 감사
      OverlayActivationShortcut.swift # Command+Shift+Space overlay activation shortcut
      PermissionManager.swift # Accessibility 권한 조회/요청/재확인
      SessionController.swift # kill switch 세션 상태 (메뉴바/Settings 공유)
      OnboardingState.swift   # 첫 실행 완료 여부 (UserDefaults)
      AppContent.swift        # 사용자 노출 정적 콘텐츠 (문구/제한/앱 지원)
    Targeting/
      TargetResolver.swift    # frontmost app + focused window resolve
      TargetModels.swift      # target app/window/context/failure 모델
      AccessibilityTargetClient.swift
      FrontmostApplicationProvider.swift
    Scanning/
      AccessibilityScanner.swift
      AccessibilityClickabilityPolicy.swift
      AccessibilityScanModels.swift
      AccessibilityElementClient.swift
      AXAccessibilityElementClient.swift
    Overlay/
      OverlayWindowController.swift
      OverlayView.swift
      OverlayLayoutEngine.swift
      OverlayCoordinateMapper.swift
      OverlayModels.swift
    Focus/
      LabelGenerator.swift
      FocusEngine.swift
      FocusModels.swift
      FocusKeyboardCommand.swift
    Clicking/
      ClickExecutor.swift
      ClickModels.swift
      ClickRiskClassifier.swift
      ClickExecutionClient.swift
      AXClickExecutionClient.swift
    Logging/
      InteractionEvent.swift
      InteractionLogStore.swift
      WindowTitleHasher.swift
      SessionSalt.swift
      DebugExportManager.swift
      LogDirectory.swift
    Runtime/
      OverlaySessionController.swift # 메뉴바 activation → target resolve → scan → overlay show
      OverlaySessionClickExecutor.swift # focused label confirm → AXPress click execution
      OverlayLaunchReporter.swift # 평가 런치 옵션용 overlay/click stdout reporter
  Tests/GazeRowTests/
    PermissionManagerTests.swift
    SessionControllerTests.swift
    OnboardingStateTests.swift
    TargetResolverTests.swift
    AccessibilityScannerTests.swift
    OverlayLayoutEngineTests.swift
    OverlaySessionClickTargetResolverTests.swift
    OverlaySessionControllerTests.swift
    LabelGeneratorTests.swift
    FocusEngineTests.swift
    FocusKeyboardCommandMapperTests.swift
    ClickExecutorTests.swift
    ClickRiskClassifierTests.swift
    DebugFeatureVisibilityTests.swift
    DiagnosticsActionFeedbackTests.swift
    MVPDefaultPolicyTests.swift
    OverlayActivationShortcutTests.swift
    InteractionLogStoreTests.swift
    WindowTitleHasherTests.swift
    DebugExportManagerTests.swift
  plans/                      # 계획/티켓/결정 문서
  scripts/
    verify_mvp_freeze.sh      # TICKET-011 freeze 사전 검증
    evaluate_overlay_target.sh # Post-MVP 앱 overlay/click 평가 실행
```

## 평가 준비 문서

- `plans/gazerow_evaluation_template_v1.md`: TICKET-010 Baseline Evaluation 기록 양식
- `plans/gazerow_ticket_010_prep_v1.md`: TICKET-010 착수 전 평가 환경/절차 준비 체크리스트
- `plans/gazerow_ticket_010_result_v1.md`: TICKET-010 사전 검증 결과와 수동 평가 기록지
- `plans/gazerow_internal_user_evaluation_v1.md`: TICKET-010 내부 사용자 3명 평가 runbook
- `plans/gazerow_mvp_freeze_package_v1.md`: TICKET-011 MVP freeze package 초안
- `plans/gazerow_distribution_checklist_v1.md`: 외부 배포 전 signing/notarization 체크리스트 초안
- `plans/gazerow_post_mvp_app_evaluation_v1.md`: Post-MVP 앱 확대 검증 절차와 진행 상태

## 진행 상황 요약

| 티켓 | 상태 | 메모 |
| --- | --- | --- |
| TICKET-001 ~ TICKET-009 | Done | MVP core/UX, logging, onboarding, known limitations 구현 |
| TICKET-010 | Done | runtime wiring, 권한 요청 동선, Accessibility 권한 부여, 5개 앱 overlay activation smoke, 실제 click task, 30분 crash-free session, Finder/VS Code fixed task 재평가 완료. 내부 사용자 gate는 Post-MVP defer |
| TICKET-011 | Ready for final freeze | freeze package, default audit, verification script, distribution checklist 준비 완료. 최종 확정은 freeze 검증 재실행과 go/no-go 판정 필요 |
| Post-MVP gaze | Deferred | camera/gaze는 이 빌드에서 비활성 |

## 앱 지원 범위

TICKET-010 실제 click task, Finder/VS Code fixed task 재평가, 30분 crash-free session 결과 기준이다.

| 앱 | 등급 | Freeze 전 확인 |
| --- | --- | --- |
| Finder | Evaluation pass | sidebar row task pass via `AXShowDefaultUI` |
| Safari | Evaluation pass | Tab Overview toolbar button task pass |
| Chrome | Evaluation pass | address bar focus task pass |
| VS Code | Evaluation pass | Activity Bar item task pass via `AXPress` |
| System Settings | Evaluation pass | toolbar Back button pane navigation task pass |
| Slack | Limited | overlay pass, only window-control candidates collected |
| Notion | Evaluation pass | breadcrumb/page click task pass via `AXPress` |
| Discord | Unsupported | overlay target resolved, but no clickable candidates collected |
| Obsidian | Unverified | app not installed in current evaluation environment |

등급 의미:

- **Evaluation target**: MVP 기준 앱으로 TICKET-010에서 검증 대상.
- **Limited**: 동작하지만 후보/클릭에 제약이 확인된 앱.
- **Unsupported**: 평가했지만 현재 후보 수집 또는 대표 task 수행이 불가능한 앱.
- **Unverified**: 아직 검증하지 않은 앱.

## 빌드 / 실행

Swift Package Manager 기반. **Xcode toolchain이 필요**하다.

```bash
# Xcode 라이선스 최초 1회 동의 (필요 시)
sudo xcodebuild -license accept

# 빌드 / 실행 (Xcode toolchain 지정)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run

# Accessibility 권한 요청/설정 이동을 바로 열고 실행
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run GazeRow -- --request-accessibility

# 특정 앱 overlay activation smoke
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run GazeRow -- --show-overlay-on-launch --target-bundle-id com.apple.finder

# 로컬 평가용 label map 출력
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run GazeRow -- --show-overlay-on-launch --target-bundle-id com.apple.Safari --print-overlay-label-map

# 재사용 가능한 overlay/click 평가 스크립트
scripts/evaluate_overlay_target.sh --bundle-id com.apple.finder
scripts/evaluate_overlay_target.sh --bundle-id com.apple.finder --click-label AA --no-label-map

# 로컬 .app 번들 생성(LaunchServices/activation 재평가용)
scripts/build_local_app.sh
open -n .build/local-app/GazeRow.app
```

> **주의**: `xcode-select`가 Command Line Tools를 가리키면 SwiftPM manifest
> 링크 오류가 발생한다. 위처럼 `DEVELOPER_DIR`로 Xcode toolchain을 지정하거나,
> `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`로 전환한다.

실행하면 Dock 아이콘 없이 메뉴바에 커서 아이콘이 표시된다.
아이콘 클릭 → **Open Settings** / **Quit** 으로 동작을 확인할 수 있다.
Accessibility 권한이 없으면 Settings의 **Request Permission** 또는 위 런치 옵션으로
권한 요청 동선을 열 수 있다.
SwiftPM 바이너리 실행에서 macOS 앱 activation/키 입력 재현이 불안정하면
`scripts/build_local_app.sh`로 `.build/local-app/GazeRow.app`을 만든 뒤 실행한다.

```bash
# 테스트 실행
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# MVP freeze 사전 검증
scripts/verify_mvp_freeze.sh
```

## TICKET-001 완료 기준

- [x] macOS Swift app shell 생성
- [x] AppKit lifecycle 연결 (`.accessory` 모드)
- [x] 메뉴바 status item (Open Settings / Quit)
- [x] Settings window (앱 이름 / 버전 / MVP 상태 / 개인정보 안내)
- [x] lifecycle 로깅 (app launched / settings opened / app terminated)
- [x] 로컬 빌드/실행 검증 (`swift build` 성공, crash 없이 실행 확인)

## TICKET-002 완료 기준

- [x] `PermissionManager` 생성 (조회 / 요청 / 재확인 / System Settings 이동)
- [x] Settings에 Accessibility 권한 상태 표시 (Granted / Not granted 배지)
- [x] 권한 없을 때 activation gate + 안내 문구 (`canActivateOverlay` / `overlayUnavailableReason`)
- [x] Camera / Input Monitoring은 baseline에서 요청하지 않음을 UI에 명시
- [x] 창 표시 / 앱 활성화 시 자동 refresh + Recheck 버튼
- [x] 단위 테스트 6건 통과, crash 없이 실행 확인

## TICKET-003 완료 기준

- [x] `TargetResolver` 생성 (frontmost app + focused window 기반)
- [x] `NSWorkspace.frontmostApplication` provider 분리
- [x] `AXUIElementCreateApplication` 기반 focused window 조회 client 추가
- [x] window frame/title 런타임 조회
- [x] 권한 없음 / window 없음 / frame 없음 / invalid frame 실패 reason 분리
- [x] `TargetContextDebugView` 추가
- [x] `TargetResolverTests`로 성공/실패 경로 검증

## TICKET-004 완료 기준

- [x] `AccessibilityScanner` 생성
- [x] AX children traversal abstraction과 production AX client 추가
- [x] role/subrole/title/value/help/frame/actions runtime snapshot 모델 추가
- [x] max depth / max nodes / timeout 설정 추가
- [x] clickable role/action 필터
- [x] duplicate 제거
- [x] secure field 및 frame 없는 요소 제외
- [x] candidate count / scan duration / node count / child read failure 계측
- [x] `AccessibilityScannerTests`로 필터, 제한, 실패 경로 검증

## TICKET-005 완료 기준

- [x] `OverlayWindowController` 추가 (transparent borderless `NSPanel`)
- [x] `OverlayView` 추가 (target boundary + label rendering)
- [x] screen coordinate → target-local coordinate mapping
- [x] label layout engine 추가
- [x] collision mitigation v1
- [x] label count / collision count / occlusion count / display scale 기록
- [x] Retina 여부 판단용 display info 모델 추가
- [x] `OverlayLayoutEngineTests`로 좌표 변환, label 생성, bounds clamp, collision, occlusion 검증

## TICKET-006 완료 기준

- [x] `LabelGenerator` 추가
- [x] 26개 초과 후보에서 prefix 충돌 없는 고정 길이 label 생성
- [x] `FocusEngine` 추가
- [x] Tab / Shift-Tab 순환 focus 이동
- [x] Arrow Up / Arrow Down 기반 수직 focus 이동
- [x] overlay keyboard input → focus command mapper 추가
- [x] label typing buffer 유지 / 초기화
- [x] label jump match / miss 이벤트 반환
- [x] Return click 연결 전 dry-run confirm 이벤트 반환
- [x] `OverlayView` focused label indicator 추가
- [x] `LabelGeneratorTests`, `FocusEngineTests`, `FocusKeyboardCommandMapperTests`로 label/focus/keyboard/dry-run 검증

## TICKET-007 완료 기준

- [x] `ClickExecutor` 추가
- [x] `AXPress` 우선 실행
- [x] `AXPress` 실패 reason 반환
- [x] 좌표 클릭 fallback hook 추가
- [x] 좌표 클릭 fallback 기본 off 유지
- [x] `ClickRiskClassifier` 추가
- [x] destructive / externalEffect / unknownRisk second confirm 요구
- [x] secure field는 scanner 단계에서 제외 유지
- [x] 위험 class만 결과에 남기고 원문 title은 저장하지 않음
- [x] `AXClickExecutionClient` 추가
- [x] `ClickExecutorTests`, `ClickRiskClassifierTests`로 안전 정책 검증

## TICKET-008 완료 기준

- [x] local interaction event 모델 추가
- [x] interaction 파일 저장 opt-in 기본 off 유지
- [x] focus/click 이벤트 JSON Lines 기록 구조 추가
- [x] session salt 기반 `windowTitleHash` 생성
- [x] raw window title / text value 미저장 정책 반영
- [x] debug export 수동 생성/삭제 관리자 추가
- [x] interaction 로그 삭제 동작 추가
- [x] `InteractionLogStoreTests`, `WindowTitleHasherTests`, `DebugExportManagerTests`로 opt-in/삭제/민감정보 제외 검증

## TICKET-009 완료 기준

- [x] kill switch(`SessionController`): 메뉴바 · Settings에서 세션 즉시 중단/재개
- [x] 첫 실행 Onboarding 시트(`OnboardingState` + `OnboardingView`): 접근 범위 설명 → setup 안내 → non-medical disclaimer
- [x] Known Limitations 열람 시트(`KnownLimitationsView`): 제한사항 / Click Safety / 앱 지원 등급
- [x] 사용자 노출 문구 단일 출처(`AppContent`)로 통합
- [x] Known Limitations 문서화(`plans/gazerow_known_limitations_v1.md`)
- [x] 단위 테스트 9건 통과(Session 5 + Onboarding 4)

## TICKET-010 진행 상태

- [x] 평가 템플릿 작성
- [x] 평가 준비 체크리스트 작성
- [x] build/test/run smoke 사전 검증 기록
- [x] freeze verification script 통과 기록
- [x] 수동 평가 착수: 현재 빌드에서 runtime activation/click wiring 부재 확인
- [x] 메뉴바 activation에서 target resolve / scan / overlay show 연결
- [x] activation 실패 사유 sanitized log code 기록
- [x] overlay keyboard focus / label jump wiring
- [x] overlay 표시 시 keyboard input 수신을 위한 app activation 보강
- [x] focus / label jump interaction log wiring
- [x] focused label AXPress click wiring
- [x] risky action second confirm runtime flow
- [x] click attempt/completed interaction log wiring
- [x] Settings Accessibility 권한 요청 버튼 연결
- [x] Show Overlay 권한 실패 시 Accessibility 요청/설정 이동 연결
- [x] Command+Shift+Space overlay activation shortcut 연결
- [x] Finder / VS Code candidate coverage 보강 및 label map smoke 확인
- [x] Finder sidebar candidate용 `AXOpen` click execution 지원
- [x] `AXConfirm` candidate click execution 지원
- [x] `AXShowDefaultUI` candidate click execution 지원
- [x] launch-option 평가용 click result stdout 출력
- [x] `--click-overlay-label` 평가 옵션 연결
- [x] `--request-accessibility` 런치 옵션 연결
- [x] overlay panel AX/AppKit 좌표 변환 및 Finder/VS Code 표시 smoke
- [x] Accessibility 권한 부여와 Settings/onboarding 확인
- [x] 5개 앱 overlay activation smoke
- [x] Finder / Safari / Chrome / VS Code / System Settings 실제 click task 수동 평가
  - result: Safari / Chrome / System Settings pass, Finder / VS Code fail
- [x] Finder / VS Code fixed task 재평가
  - result: Finder pass via `AXShowDefaultUI`, VS Code pass via `AXPress`
- [x] 30분 crash-free manual session 기록
  - result: 2026-07-02 20:46:31~21:16:31 KST, 1800초 crash 없이 유지
- [x] 내부 사용자 3명 평가 runbook 작성
- [x] 내부 사용자 gate Post-MVP defer 결정 반영(ED-008)
- [x] go/no-go 판정

## TICKET-011 준비 상태

- [x] MVP freeze package 초안 작성
- [x] local build/run guide 정리
- [x] 기능 플래그/기본값 자동 감사(`MVPDefaultPolicy`)
- [x] MVP freeze 사전 검증 스크립트(`scripts/verify_mvp_freeze.sh`)
- [x] debug export UI 기본 숨김
- [x] diagnostics 삭제/생성 액션 피드백
- [x] app support tier provisional 정리
- [x] distribution signing/notarization checklist 초안
- [x] TICKET-010 결과 기반 known limitations/app support 갱신
- [x] MVP freeze 최종 go/no-go 확정

## 하지 않는 것 (현재 범위 외)

- Post-MVP 내부 사용자 3명 평가
- Post-MVP 앱 확대 검증 추가(Obsidian 설치 환경, Discord candidate 개선 등)
- Camera / Screen Recording 권한 요청, gaze 기능 (Post-MVP)

## 다음 티켓

- **Post-MVP**: Discord candidate 개선, Obsidian 설치 환경 검증, 내부 사용자 3명 평가 재개
- 이후 **TICKET-011**: MVP Freeze Package 최종 확정

자세한 계획은 `plans/` 폴더 참조.
