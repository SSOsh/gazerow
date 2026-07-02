# GazeRow

macOS 키보드 클릭 유틸리티 (Homerow 스타일). 화면 위의 클릭 가능한 UI 요소를
자동으로 찾아 label을 붙이고, 사용자가 키보드로 focus와 click을 수행하게 한다.

> **현재 상태**: TICKET-002 (Permission UX and PermissionManager) 구현.
> 메뉴바 앱 shell + Settings window + lifecycle 로깅 + Accessibility 권한 상태 UX.
> AX tree 조회, overlay, hotkey, 실제 click은 아직 없다.

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
      SettingsView.swift    # Settings window 본문
    Infrastructure/
      AppState.swift          # 앱 메타데이터, MVP 상태, 권한 안내 문구
      AppLogger.swift         # OSLog wrapper (lifecycle)
      PermissionManager.swift # Accessibility 권한 조회/요청/재확인
  Tests/GazeRowTests/
    PermissionManagerTests.swift
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

## 하지 않는 것 (현재 범위 외)

- AXUIElement 접근, AX tree 조회 (TICKET-003+)
- overlay window, global hotkey / event tap (TICKET-005+)
- 실제 click 실행 (TICKET-007+)
- Camera / Screen Recording 권한 요청, gaze 기능 (Post-MVP)

## 다음 티켓

- **TICKET-003**: Target Resolver (frontmost app + focused window 조회)

자세한 계획은 `plans/` 폴더 참조.
