# gazerow TICKET-001 Spec v1

## 변경 이력
- v1: `gazerow_tickets_v1.md`의 `TICKET-001: Project Shell and App Lifecycle`을 구현 가능한 상세 명세로 확장. 앱 shell 생성 전 결정값, 권장 구조, 완료 기준, 검증 절차를 정의.

## 1. 티켓 요약

TICKET-001은 gazerow의 빈 macOS 앱 shell을 만드는 작업이다.

목표:

- 로컬에서 실행 가능한 Swift macOS app을 만든다.
- AppKit lifecycle과 SwiftUI Settings window를 연결한다.
- 이후 권한 UX, AX resolver, overlay 작업이 들어갈 최소 구조를 만든다.

비목표:

- Accessibility 권한 요청 구현
- AX tree 조회
- overlay 표시
- global hotkey 등록
- 실제 click 실행
- gaze/camera 기능

## 2. 착수 전 결정값

TICKET-001 시작 전에 아래 항목을 확정한다.

| 항목 | 상태 | 권장값 | 비고 |
| --- | --- | --- | --- |
| 앱 이름 | TBD | gazerow | bundle name, menu title, Settings title에 사용 |
| 저장소 위치 | TBD | `/Users/lotte/gitlab/gazerow` | Swift app 생성 위치 |
| 앱 형태 | Proposed | 메뉴바 앱 + Settings window | 상시 실행 utility에 적합 |
| 기본 단축키 | Proposed | Command + Shift + Space | TICKET-005 이후 변경 가능해야 함 |
| 최소 macOS 버전 | TBD | macOS 14 이상 또는 현재 개발 Mac 기준 | Xcode target 결정 필요 |
| Bundle Identifier | TBD | `dev.local.gazerow` 또는 사용자 prefix | 외부 배포 전 변경 가능 |

착수 전 위 항목이 확정되지 않으면 임시값으로 시작할 수 있지만, `gazerow_decisions_v1.md`에 반드시 기록한다.

## 3. 권장 앱 구조

MVP 초기 구조:

```text
gazerow/
  gazerow.xcodeproj
  gazerow/
    App/
      GazeRowApp.swift
      AppDelegate.swift
    UI/
      SettingsView.swift
    Infrastructure/
      AppState.swift
      Logger.swift
    Resources/
      Assets.xcassets
      Info.plist
```

원칙:

- SwiftUI는 Settings와 단순 상태 표시 중심으로 쓴다.
- AppKit은 status item, app lifecycle, 향후 overlay window에 사용한다.
- TICKET-001에서는 `PermissionManager`, `AccessibilityScanner`, `OverlayWindowController`를 만들지 않는다.
- 후속 티켓을 위해 폴더만 과하게 만들지 않는다. 실제 타입이 생길 때 추가한다.

## 4. 구현 항목

### 4.1 App Shell

작업:

- macOS Swift app 생성
- 최소 macOS deployment target 설정
- 앱 이름과 bundle identifier 설정
- 앱 실행 시 기본 window를 자동으로 띄울지 여부 결정

권장:

- 메뉴바 utility를 목표로 하므로 앱 시작 시 큰 main window는 띄우지 않는다.
- Settings window는 사용자가 메뉴에서 열 때 표시한다.

### 4.2 AppDelegate 연결

작업:

- `NSApplicationDelegate` 연결
- app activation policy 결정
- 앱 종료 처리 확인

권장:

- 초기에는 `.regular` 또는 `.accessory` 중 하나를 명확히 선택한다.
- 메뉴바 앱으로 확정하면 status item 중심으로 동작하게 한다.

주의:

- overlay와 global hotkey는 TICKET-005 이후 작업이다.
- TICKET-001에서 입력 이벤트를 가로채지 않는다.

### 4.3 Status Item

작업:

- `NSStatusItem` 생성
- 메뉴 항목 추가
  - Open Settings
  - Quit

완료 기준:

- 메뉴바 아이콘 또는 텍스트가 표시된다.
- Settings를 열 수 있다.
- Quit으로 앱이 종료된다.

### 4.4 Settings Window

작업:

- `SettingsView` 생성
- 앱 이름과 MVP 상태 표시
- 이후 권한 상태가 들어갈 placeholder 영역 추가

TICKET-001에서 표시할 수 있는 최소 정보:

- App name
- Version 또는 build placeholder
- MVP mode: Baseline only
- Gaze: Disabled / Post-MVP

권장 문구:

```text
gazerow is a local macOS keyboard-click utility.
Baseline MVP does not use camera, screen recording, or external telemetry.
```

### 4.5 Logging Foundation

작업:

- 최소 `Logger` wrapper 또는 `OSLog` category 준비
- app lifecycle 로그
  - app launched
  - settings opened
  - app terminated

주의:

- Interaction 로그 파일 저장은 만들지 않는다.
- 개인정보 관련 로그는 TICKET-008에서 별도로 다룬다.

## 5. 완료 기준

TICKET-001은 아래 조건을 만족하면 완료다.

- 앱이 Xcode 또는 CLI에서 build된다.
- 앱이 로컬에서 실행된다.
- status item이 표시된다.
- Settings window를 열 수 있다.
- Quit으로 정상 종료된다.
- 앱 이름, bundle id, 최소 macOS 버전이 기록되어 있다.
- Camera, Screen Recording, Accessibility, Input Monitoring 권한을 요청하지 않는다.
- 실제 click, AX scan, overlay, hotkey 기능이 없다.

## 6. 검증 절차

수동 검증:

| 항목 | 기대 결과 | 결과 |
| --- | --- | --- |
| 앱 실행 | crash 없이 실행 | pass / fail |
| status item 표시 | 메뉴바에 표시 | pass / fail |
| Settings 열기 | Settings window 표시 | pass / fail |
| Quit | 앱 종료 | pass / fail |
| 권한 prompt | 아무 권한도 요청하지 않음 | pass / fail |

CLI 검증:

```text
xcodebuild -scheme gazerow -configuration Debug build
```

실제 scheme 이름은 프로젝트 생성 후 기록한다.

## 7. 산출물

- Swift macOS app project
- App shell
- Status item
- Settings window
- 최소 lifecycle logging
- 결정값 업데이트가 반영된 `gazerow_decisions_v1.md`

## 8. 다음 티켓 연결

TICKET-001 완료 후 바로 이어질 작업:

- `TICKET-002: Permission UX and PermissionManager`

TICKET-002에서 추가할 것:

- Accessibility 권한 상태 표시
- System Settings 이동 버튼
- 권한 재확인 버튼
- 권한 없음 상태의 overlay activation failure UX

TICKET-001에서 하지 말아야 할 것:

- 권한 요청 선점
- AXUIElement 접근
- hotkey/global event tap
- overlay window
- click execution
