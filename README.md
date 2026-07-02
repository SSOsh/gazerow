# GazeRow

macOS 키보드 클릭 유틸리티 (Homerow 스타일). 화면 위의 클릭 가능한 UI 요소를
자동으로 찾아 label을 붙이고, 사용자가 키보드로 focus와 click을 수행하게 한다.

> **현재 상태**: TICKET-001부터 TICKET-006까지 core 구현 완료, TICKET-009 UX/문서 구현.
> 메뉴바 앱 shell + Settings window + Accessibility 권한 UX + target resolver
> + Accessibility scanner + overlay layout/window 기반 + focus engine
> + kill switch + onboarding.
> global hotkey와 실제 click 실행은 아직 없다(TICKET-007+).

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
| 기본 단축키 | Command + Shift + Space (TICKET-005에서 등록) |
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
  Tests/GazeRowTests/
    PermissionManagerTests.swift
    SessionControllerTests.swift
    OnboardingStateTests.swift
    TargetResolverTests.swift
    AccessibilityScannerTests.swift
    OverlayLayoutEngineTests.swift
    LabelGeneratorTests.swift
    FocusEngineTests.swift
    FocusKeyboardCommandMapperTests.swift
  plans/                      # 계획/티켓/결정 문서
```

## 빌드 / 실행

Swift Package Manager 기반. **Xcode toolchain이 필요**하다.

```bash
# Xcode 라이선스 최초 1회 동의 (필요 시)
sudo xcodebuild -license accept

# 빌드 / 실행 (Xcode toolchain 지정)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run
```

> **주의**: `xcode-select`가 Command Line Tools를 가리키면 SwiftPM manifest
> 링크 오류가 발생한다. 위처럼 `DEVELOPER_DIR`로 Xcode toolchain을 지정하거나,
> `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`로 전환한다.

실행하면 Dock 아이콘 없이 메뉴바에 커서 아이콘이 표시된다.
아이콘 클릭 → **Open Settings** / **Quit** 으로 동작을 확인할 수 있다.

```bash
# 테스트 실행
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
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
- [x] 단위 테스트 5건 통과, crash 없이 실행 확인

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

## TICKET-009 완료 기준

- [x] kill switch(`SessionController`): 메뉴바 · Settings에서 세션 즉시 중단/재개
- [x] 첫 실행 Onboarding 시트(`OnboardingState` + `OnboardingView`): 접근 범위 설명 → setup 안내 → non-medical disclaimer
- [x] Known Limitations 열람 시트(`KnownLimitationsView`): 제한사항 / Click Safety / 앱 지원 등급
- [x] 사용자 노출 문구 단일 출처(`AppContent`)로 통합
- [x] Known Limitations 문서화(`plans/gazerow_known_limitations_v1.md`)
- [x] 단위 테스트 9건 통과(Session 5 + Onboarding 4)

## 하지 않는 것 (현재 범위 외)

- 실제 click 실행 (TICKET-007+)
- Camera / Screen Recording 권한 요청, gaze 기능 (Post-MVP)

## 다음 티켓

- **TICKET-007**: AXPress Click Execution and Safety

자세한 계획은 `plans/` 폴더 참조.
