# GazeRow TICKET-010 Result v1

## 변경 이력
- v1: TICKET-010 Baseline Evaluation Run의 사전 검증 결과와 수동 평가 기록지를 생성.
- v2: 수동 평가 착수 중 현재 빌드에 end-to-end overlay activation/click runtime 진입점이 없어 5개 앱 task를 수행할 수 없음을 기록.
- v3: 메뉴바 activation에서 target resolve, scan, overlay show까지 1차 runtime wiring이 완료됐고, keyboard focus/click wiring이 다음 차단 항목임을 기록.
- v4: overlay keyboard command와 FocusEngine runtime wiring 및 focused label highlight update가 완료됐고, interaction log/click wiring이 다음 차단 항목임을 기록.
- v5: focus/label jump interaction log wiring이 완료됐고, AXPress click execution wiring이 다음 차단 항목임을 기록.
- v6: focused label confirm에서 AXPress click execution까지 runtime wiring이 완료됐고, risky second confirm/click logging이 다음 차단 항목임을 기록.
- v7: risky action second confirm runtime flow가 완료됐고, click attempt/completed logging이 다음 차단 항목임을 기록.
- v8: click attempt/completed interaction log wiring이 완료되어 TICKET-010 수동 평가 재시도 가능 상태로 갱신.
- v9: TICKET-010 재시도 전 권한 precheck에서 Accessibility 권한이 not granted임을 확인하고 평가 차단 상태로 갱신.
- v10: Settings Accessibility 권한 요청 버튼을 연결하고 freeze 검증 통과를 기록. 실제 권한 부여는 여전히 필요.
- v11: Show Overlay 권한 실패 시 Accessibility 요청 프롬프트와 System Settings 이동을 연결하고 freeze 검증 통과를 기록.
- v12: `--request-accessibility` 런치 옵션을 추가하고 freeze 검증 통과를 기록.
- v13: Accessibility 권한 승인 후 5개 앱 overlay activation smoke를 통과했고, click task는 계속 pending으로 기록.
- v14: 5개 앱 실제 click task를 수행해 Safari/Chrome/System Settings pass, Finder/VS Code fail을 기록.
- v15: 30분 crash-free manual session 통과 결과를 기록.
- v16: 내부 사용자 3명 평가 runbook 준비 상태를 기록.
- v17: Finder/VS Code candidate coverage 보강 후 fixed task 재평가 필요 상태를 기록.
- v18: scanner 기본 depth 확장 후 Finder/VS Code label map smoke 개선 결과를 기록.
- v19: Finder sidebar candidate용 `AXOpen` click execution 지원을 기록.
- v20: `AXConfirm` candidate click execution 지원을 기록.
- v21: overlay 표시 시 keyboard input 수신을 위한 app activation 보강을 기록.
- v22: launch-option 평가용 click result stdout 출력을 기록.

## 1. 상태

현재 상태: `CRASH_FREE_SESSION_PASS_PENDING_INTERNAL_USER_EVALUATION`

자동 사전 검증은 완료했다. 2026-07-02 12:19:56 KST에 로컬 GUI 수동 평가를 착수했지만, 당시 앱 런타임에는 target resolve, scanner, overlay, focus engine, click executor를 end-to-end로 실행하는 activation 진입점이 연결되어 있지 않았다.

이후 1차 runtime wiring으로 메뉴바 activation에서 target resolve, scan, overlay show까지 연결했고, overlay keyboard command를 FocusEngine과 focused label highlight update에 연결했다. focus/label jump interaction log wiring, focused label confirm의 AXPress click execution wiring, risky action second confirm runtime flow, click attempt/completed interaction log wiring도 완료했다.

2026-07-02 12:58:32 KST에 수동 평가 재시도 전 precheck를 수행했지만, 현재 실행 환경에서 Accessibility 권한이 `not granted`로 확인됐다. AX tree scan과 AXPress가 모두 Accessibility 권한에 의존하므로 5개 앱 task 수행은 권한 부여 후 재시도해야 한다.

2026-07-02 19:36:10 KST에 Settings의 Accessibility 섹션에 시스템 권한 요청 프롬프트를 여는 `Request Permission` 버튼을 연결했다. 코드상 권한 요청 동선은 준비됐지만 macOS 보안 권한은 사용자가 직접 승인해야 하므로 현재 수동 평가는 계속 차단 상태다.

2026-07-02 19:42:19 KST에는 Show Overlay 실행 중 target resolve/scan이 Accessibility 권한 부족으로 실패하면 권한 요청 프롬프트와 System Settings Accessibility 패널을 여는 경로를 추가했다. 실제 권한 토글은 OS 보안 설정이므로 사용자 승인 없이는 변경하지 않았다.

2026-07-02 19:45:35 KST에는 `swift run GazeRow -- --request-accessibility` 실행 시 앱 시작 직후 권한 요청 프롬프트와 System Settings Accessibility 패널을 여는 런치 옵션을 추가했다.

2026-07-02 19:57:41 KST에는 Codex 실행 컨텍스트의 Accessibility 권한 승인 후 `AXIsProcessTrusted()`가 `true`를 반환했다. 이후 `--show-overlay-on-launch --target-bundle-id` 평가 런치 옵션, target window fallback(`AXFocusedWindow` -> `AXMainWindow` -> `AXWindows`), overlay launch reporter를 추가했고 Finder, Safari, Chrome, VS Code, System Settings에서 overlay activation smoke가 모두 통과했다. 이 시점에는 실제 keyboard label jump/confirm click task, 30분 crash-free session, 내부 사용자 3명 평가가 남아 있었다.

2026-07-02 20:20 KST에는 실제 click task를 수행했다. `--print-overlay-label-map` 평가 옵션으로 GazeRow가 부여한 label과 candidate를 확인했고, keyboard label jump 후 Return confirm으로 Safari, Chrome, System Settings task가 성공했다. Finder는 sidebar row가 candidate로 수집되지 않았고, VS Code는 Activity Bar item이 candidate로 수집되지 않아 task 실패로 기록한다. 초기 5개 앱 중 3개 task 성공 기준은 충족했지만, 이 시점에는 30분 crash-free session과 내부 사용자 3명 평가가 아직 남아 있었다.

2026-07-02 20:46:31 KST부터 21:16:31 KST까지 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run GazeRow`로 30분 crash-free session을 수행했다. 1분 간격으로 프로세스 생존을 확인했고 1800초 동안 crash 없이 유지됐다. 세션 종료 시 `SIGINT`로 정상 정리했으며 잔여 `GazeRow` 프로세스는 없었다.

2026-07-02에는 내부 사용자 3명 평가를 직접 대체하지 않고, `gazerow_internal_user_evaluation_v1.md`에 평가 실행 절차와 기록지를 준비했다. 실제 User 1/User 2/User 3 결과가 입력되기 전까지 go/no-go 최종 판정은 보류한다.

2026-07-03 09:53 KST에는 launch-option 평가 중 keyboard confirm click 결과를 `GAZEROW_OVERLAY_CLICK_RESULT`로 stdout에 출력하도록 연결했다. Finder/VS Code fixed task 재평가 시 label map 출력과 함께 실제 click 성공/실패, 실행 방식, risk, fallback 여부를 기록할 수 있다. 이 변경은 재평가 준비이며 Finder/VS Code pass 판정으로 간주하지 않는다.

## 2. 평가 전 체크리스트

| 항목 | 값 |
| --- | --- |
| 평가 일시 | 2026-07-02 12:11:54 KST |
| 평가자 | PENDING_MANUAL_EVALUATION |
| macOS version | macOS 26.2 (25C56) |
| Xcode version | Xcode 26.6 (17F113) |
| GazeRow commit | `76c8555` |
| 빌드 방식 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` |
| build result | pass |
| test result | pass, 95 tests, 0 failures |
| run smoke result | pass, launched and stayed running for 5 seconds before manual interrupt |
| freeze verification result | pass, `scripts/verify_mvp_freeze.sh` |
| Accessibility 권한 | granted for Codex execution context |
| Input Monitoring 권한 | not requested |
| Screen Recording 권한 | not requested |
| Camera 권한 | not requested |
| coordinate fallback | off by default |
| interaction log opt-in | off by default |
| debug export opt-in | manual action only |

## 3. 사전 검증 결과

| 검증 | 명령 | 결과 |
| --- | --- | --- |
| git 상태 | `git status --short --branch` | preflight 시작 시 clean, `main...origin/main` |
| build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` | pass |
| test | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | pass, 95 tests, 0 failures |
| run smoke | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run` | pass, launched and stayed running for 5 seconds before manual interrupt |
| freeze verification | `scripts/verify_mvp_freeze.sh` | pass |
| manual evaluation attempt | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run` | pass, app process launched, but no runtime activation path exists for 5-app click tasks |
| permission precheck | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift -e 'import ApplicationServices; print(AXIsProcessTrusted())'` | false |
| runtime wiring focused tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OverlaySessionControllerTests\|OverlaySessionClickTargetResolverTests'` | pass, 24 tests, 0 failures |
| permission request UI focused tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter PermissionManagerTests` | pass, 6 tests, 0 failures |
| freeze verification after permission request UI | `scripts/verify_mvp_freeze.sh` | pass, 120 tests, 0 failures |
| overlay permission recovery focused tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OverlaySessionStartFailureTests\|PermissionManagerTests\|OverlaySessionControllerTests'` | pass, 29 tests, 0 failures |
| freeze verification after overlay permission recovery | `scripts/verify_mvp_freeze.sh` | pass, 123 tests, 0 failures |
| launch option focused tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'AppLaunchOptionsTests\|PermissionManagerTests\|OverlaySessionStartFailureTests'` | pass, 11 tests, 0 failures |
| freeze verification after launch option | `scripts/verify_mvp_freeze.sh` | pass, 125 tests, 0 failures |
| accessibility precheck after approval | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift -e 'import ApplicationServices; print(AXIsProcessTrusted())'` | true |
| target window fallback / launch reporter focused tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'AppLaunchOptionsTests\|BundleIdentifierApplicationProviderTests\|TargetResolverTests\|TargetWindowCandidateSelectorTests\|OverlayLaunchReporterTests'` | pass, 16 tests, 0 failures |
| freeze verification after overlay smoke support | `scripts/verify_mvp_freeze.sh` | pass, 136 tests, 0 failures |
| label map focused tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'AppContentTests\|AppLaunchOptionsTests\|OverlayLaunchReporterTests'` | pass, 14 tests, 0 failures |
| freeze verification after click task docs/support update | `scripts/verify_mvp_freeze.sh` | pass, 141 tests, 0 failures |
| 30min crash-free session | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run GazeRow` with 1-minute process checks | pass, 1800 seconds, 0 crashes |
| freeze verification after 30min session docs | `scripts/verify_mvp_freeze.sh` | pass, 141 tests, 0 failures |
| internal user evaluation runbook | `plans/gazerow_internal_user_evaluation_v1.md` | ready, awaiting User 1/User 2/User 3 results |
| selectable container candidate coverage focused tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'AccessibilityScannerTests\|OverlaySessionClickTargetResolverTests'` | pass, 15 tests, 0 failures |
| freeze verification after candidate coverage update | `scripts/verify_mvp_freeze.sh` | pass, 150 tests, 0 failures |
| scanner depth focused tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'AccessibilityScannerTests\|OverlaySessionClickTargetResolverTests'` | pass, 17 tests, 0 failures |
| VS Code label map smoke after depth update | `.build/arm64-apple-macosx/debug/GazeRow --show-overlay-on-launch --target-bundle-id com.microsoft.VSCode --print-overlay-label-map` | pass, 29 labels, Activity Bar `AXRadioButton` candidates visible |
| freeze verification after scanner depth update | `scripts/verify_mvp_freeze.sh` | pass, 183 tests, 0 failures, MVP-excluded check passed |
| AXOpen click execution focused tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'ClickExecutorTests\|ClickRiskClassifierTests'` | pass, 15 tests, 0 failures |
| freeze verification after AXOpen update | `scripts/verify_mvp_freeze.sh` | pass, 186 tests, 0 failures, MVP-excluded check passed |
| AXConfirm click execution focused tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'ClickExecutorTests'` | pass, 10 tests, 0 failures |
| freeze verification after AXConfirm update | `scripts/verify_mvp_freeze.sh` | pass, 187 tests, 0 failures, MVP-excluded check passed |
| overlay window activation focused tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OverlayWindowControllerTests'` | pass, 1 test, 0 failures |
| freeze verification after overlay activation update | `scripts/verify_mvp_freeze.sh` | pass, 188 tests, 0 failures, MVP-excluded check passed |
| click result reporter focused tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter 'OverlayLaunchReporterTests\|OverlaySessionControllerTests'` | pass, 28 tests, 0 failures |
| full test after click result reporter update | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | pass, 191 tests, 0 failures |
| freeze verification after click result reporter update | `scripts/verify_mvp_freeze.sh` | pass, 191 tests, 0 failures, MVP-excluded check passed |

## 3.1 수동 평가 착수 결과

2026-07-02 12:19:56 KST 기준으로 앱 실행은 성공했다.

확인 내용:

- `GazeRow` 프로세스가 `.build/arm64-apple-macosx/debug/GazeRow`로 실행됨.
- 메뉴바/Settings/권한/세션 UI는 앱 런타임에 연결되어 있음.
- `TargetResolver`, `AccessibilityScanner`, `OverlayWindowController`, `FocusEngine`, `ClickExecutor`는 단위 테스트와 개별 구성요소로 존재하지만, 실제 사용자 activation 경로에서 함께 호출되지 않았음.
- 이후 메뉴바 `Show Overlay` 액션에서 target resolve, scan, overlay show까지 연결됨.

결론:

- 현재 빌드는 overlay 표시, keyboard focus/label jump, focus interaction log, AXPress click execution, risky action second confirm, click attempt/completed interaction log 진입점까지 갖췄다.
- 이전 차단 사유였던 runtime wiring 부재는 해소됐다.
- Accessibility 권한과 5개 앱 overlay activation smoke는 통과했다.
- TICKET-010 5개 앱 실제 click task는 3 pass / 2 fail이다.
- 이후 Finder/VS Code candidate coverage는 selectable role 수집과 scanner 기본 depth 확장으로 개선했다.
- Finder label map은 19개에서 63개로 증가했고 `AXRow` / `AXCell` 후보가 수집된다.
- VS Code label map은 3개에서 29개로 증가했고 Activity Bar `AXRadioButton` 후보가 수집된다.
- Finder sidebar candidate용 `AXOpen` 실행을 지원한다.
- `AXConfirm`으로만 노출되는 candidate 실행도 지원한다.
- overlay 표시 시 app activation과 key window 전환을 보강했다.
- launch-option 평가 중 keyboard confirm click 결과를 `GAZEROW_OVERLAY_CLICK_RESULT`로 stdout에 출력한다.
- Finder sidebar row와 VS Code Activity Bar item fixed task는 보강 후 재평가가 필요하다.

## 3.2 5개 앱 overlay activation smoke

| 앱 | Bundle ID | 결과 | Label count | 명령 |
| --- | --- | --- | ---: | --- |
| Finder | `com.apple.finder` | pass | 63 | `.build/arm64-apple-macosx/debug/GazeRow --show-overlay-on-launch --target-bundle-id com.apple.finder --print-overlay-label-map` |
| Safari | `com.apple.Safari` | pass | 35 | `swift run GazeRow -- --show-overlay-on-launch --target-bundle-id com.apple.Safari` |
| Chrome | `com.google.Chrome` | pass | 46 | `swift run GazeRow -- --show-overlay-on-launch --target-bundle-id com.google.Chrome` |
| VS Code | `com.microsoft.VSCode` | pass | 29 | `.build/arm64-apple-macosx/debug/GazeRow --show-overlay-on-launch --target-bundle-id com.microsoft.VSCode --print-overlay-label-map` |
| System Settings | `com.apple.systempreferences` | pass | 11 | `swift run GazeRow -- --show-overlay-on-launch --target-bundle-id com.apple.systempreferences` |

## 4. 앱별 평가 기록

### Finder

```text
AppSupportReport
  appName: Finder
  bundleIdentifier: com.apple.finder
  appVersion: not measured
  macOSVersion: macOS 26.2 (25C56)
  task: sidebar item 클릭
  taskSuccess: fail
  candidateCount: 19
  usefulCandidateCount: 0
  scanDurationMs: not measured
  nodesVisited: not measured
  labelCount: 19
  labelCollisionCount: not measured
  labelOcclusionCount: not measured
  overlayReadability: not scored
  overlayMisaligned: not scored
  focusMoveCount: 0
  labelJumpAttemptCount: 0
  labelJumpSuccessCount: 0
  correctionCount: 0
  abandonedAttemptCount: 1
  mouseBaselineSeconds: not measured
  gazerowSeconds: not measured
  clickAttemptCount: 0
  clickSuccessCount: 0
  clickMethod: none
  fallbackRequired: no
  criticalMisclickCount: 0
  missingImportantElements: sidebar rows not collected as clickable candidates
  noisyElements: toolbar/window-title candidates only for this task
  permissionOrSetupFriction: none after Accessibility approval
  notes: Overlay activation passed, but Finder sidebar rows were absent from the candidate set, so the fixed sidebar item task could not be attempted safely.
```

### Safari

```text
AppSupportReport
  appName: Safari
  bundleIdentifier: com.apple.Safari
  appVersion: not measured
  macOSVersion: macOS 26.2 (25C56)
  task: toolbar button 클릭
  taskSuccess: pass
  candidateCount: 35
  usefulCandidateCount: 1
  scanDurationMs: not measured
  nodesVisited: not measured
  labelCount: 35
  labelCollisionCount: not measured
  labelOcclusionCount: not measured
  overlayReadability: 4
  overlayMisaligned: no
  focusMoveCount: 0
  labelJumpAttemptCount: 1
  labelJumpSuccessCount: 1
  correctionCount: 0
  abandonedAttemptCount: 0
  mouseBaselineSeconds: not measured
  gazerowSeconds: not measured
  clickAttemptCount: 1
  clickSuccessCount: 1
  clickMethod: AXPress
  fallbackRequired: no
  criticalMisclickCount: 0
  missingImportantElements: none for selected toolbar task
  noisyElements: start page content candidates also labeled
  permissionOrSetupFriction: none after Accessibility approval
  notes: Label BF targeted the Tab Overview toolbar button. Keyboard label jump plus Return opened tab overview.
```

### Chrome

```text
AppSupportReport
  appName: Chrome
  bundleIdentifier: com.google.Chrome
  appVersion: not measured
  macOSVersion: macOS 26.2 (25C56)
  task: 주소창 focus
  taskSuccess: pass
  candidateCount: 46
  usefulCandidateCount: 1
  scanDurationMs: not measured
  nodesVisited: not measured
  labelCount: 46
  labelCollisionCount: not measured
  labelOcclusionCount: not measured
  overlayReadability: 4
  overlayMisaligned: no
  focusMoveCount: 0
  labelJumpAttemptCount: 1
  labelJumpSuccessCount: 1
  correctionCount: 0
  abandonedAttemptCount: 0
  mouseBaselineSeconds: not measured
  gazerowSeconds: not measured
  clickAttemptCount: 2
  clickSuccessCount: 1
  clickMethod: AXPress
  fallbackRequired: no
  criticalMisclickCount: 0
  missingImportantElements: none for address bar task
  noisyElements: bookmarks and tab controls also labeled
  permissionOrSetupFriction: none after Accessibility approval
  notes: Label AE targeted the address/search field. Because the target was classified as unknownRisk, two Return confirms were used. Address bar text became selected/focused without navigation.
```

### VS Code

```text
AppSupportReport
  appName: VS Code
  bundleIdentifier: com.microsoft.VSCode
  appVersion: not measured
  macOSVersion: macOS 26.2 (25C56)
  task: Activity Bar item 이동
  taskSuccess: fail
  candidateCount: 3
  usefulCandidateCount: 0
  scanDurationMs: not measured
  nodesVisited: not measured
  labelCount: 3
  labelCollisionCount: not measured
  labelOcclusionCount: not measured
  overlayReadability: not scored
  overlayMisaligned: not scored
  focusMoveCount: 0
  labelJumpAttemptCount: 0
  labelJumpSuccessCount: 0
  correctionCount: 0
  abandonedAttemptCount: 1
  mouseBaselineSeconds: not measured
  gazerowSeconds: not measured
  clickAttemptCount: 0
  clickSuccessCount: 0
  clickMethod: none
  fallbackRequired: no
  criticalMisclickCount: 0
  missingImportantElements: Activity Bar items not collected as clickable candidates
  noisyElements: only window controls were labeled
  permissionOrSetupFriction: none after Accessibility approval
  notes: Label map contained only window control buttons, so the Activity Bar item task could not be attempted safely.
```

### System Settings

```text
AppSupportReport
  appName: System Settings
  bundleIdentifier: com.apple.SystemSettings
  appVersion: not measured
  macOSVersion: macOS 26.2 (25C56)
  task: button/toggle focus 및 실행
  taskSuccess: pass
  candidateCount: 13
  usefulCandidateCount: 1
  scanDurationMs: not measured
  nodesVisited: not measured
  labelCount: 13
  labelCollisionCount: not measured
  labelOcclusionCount: not measured
  overlayReadability: 4
  overlayMisaligned: no
  focusMoveCount: 0
  labelJumpAttemptCount: 1
  labelJumpSuccessCount: 1
  correctionCount: 0
  abandonedAttemptCount: 0
  mouseBaselineSeconds: not measured
  gazerowSeconds: not measured
  clickAttemptCount: 2
  clickSuccessCount: 1
  clickMethod: AXPress
  fallbackRequired: no
  criticalMisclickCount: 0
  missingImportantElements: none for selected pane navigation task
  noisyElements: security toggles were labeled but intentionally avoided
  permissionOrSetupFriction: none after Accessibility approval
  notes: Label H targeted the toolbar Back button. Two Return confirms moved from Screen & System Audio Recording back to Accessibility without changing any toggle.
```

## 5. 집계 표

| 앱 | Task success | Candidate count | Useful candidates | Click success | Correction count | Abandoned attempts | Critical misclick |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Finder | fail | 19 | 0 | 0 | 0 | 1 | 0 |
| Safari | pass | 35 | 1 | 1 | 0 | 0 | 0 |
| Chrome | pass | 46 | 1 | 1 | 0 | 0 | 0 |
| VS Code | fail | 3 | 0 | 0 | 0 | 1 | 0 |
| System Settings | pass | 13 | 1 | 1 | 0 | 0 | 0 |

초기 5개 앱 중 3개 앱에서 task success를 기록했다. Finder와 VS Code는 overlay activation은 성공했지만 고정 task target이 candidate로 수집되지 않아 실패로 판정했다. 이후 selectable container candidate coverage와 Finder sidebar candidate용 `AXOpen` 실행을 보강했으므로 Finder/VS Code fixed task는 재평가가 필요하다.

## 6. Safety 결과

| 항목 | 결과 |
| --- | --- |
| coordinate fallback off 유지 | pass by code/config default and manual click tasks |
| critical misclick count | 0 |
| destructive/externalEffect/unknownRisk second confirm | pass by unit test |
| secure/password field 후보 제외 | pass by unit test |
| click history/file 저장에 원문 title 없음 | pass by unit test |

## 7. Go/No-Go 판정

```text
Decision: CONDITIONAL_GO_PENDING_INTERNAL_USERS
Reason: 기존 5개 앱 평가에서 3개 task 성공, critical misclick 0건, 30분 crash-free session은 충족했다. Finder/VS Code candidate coverage를 보강했으므로 fixed task 재평가가 필요하고, 내부 사용자 3명 평가도 아직 필요하다.
Required fixes before freeze: Finder/VS Code fixed task 재평가, 내부 사용자 3명 평가
Known limitations to document: Finder/VS Code는 보강 후 재평가 전까지 Limited 유지
Next ticket: Finder/VS Code 재평가와 내부 사용자 3명 평가 후 TICKET-011 freeze 최종 확정
```

## 8. 남은 수동 작업

- [x] `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run`으로 앱 실행
- [x] menu activation / target resolve / scan / overlay show wiring 구현
- [x] keyboard focus / label jump wiring 구현
- [x] focus / label jump interaction log wiring 구현
- [x] AXPress click execution wiring 구현
- [x] risky action second confirm runtime flow 구현
- [x] click attempt/completed interaction log wiring 구현
- [x] Settings Accessibility 권한 요청 버튼 연결
- [x] Show Overlay 권한 실패 시 Accessibility 요청/설정 이동 연결
- [x] `--request-accessibility` 런치 옵션 연결
- [x] Accessibility 권한 부여와 Settings/onboarding 확인
  - 2026-07-02 19:57:41 KST precheck에서 `AXIsProcessTrusted()`가 true 반환
- [x] 5개 앱 overlay activation smoke
- [x] Finder task 수행
  - result: fail, sidebar row candidate 미수집
- [x] Safari task 수행
  - result: pass, Tab Overview toolbar button opened
- [x] Chrome task 수행
  - result: pass, address bar focused/selected after second confirm
- [x] VS Code task 수행
  - result: fail, Activity Bar item candidate 미수집
- [x] System Settings task 수행
  - result: pass, toolbar Back button moved pane without toggling settings
- [x] 30분 crash-free manual session 기록
  - result: 2026-07-02 20:46:31~21:16:31 KST, 1800초, crash 0건
- [x] 내부 사용자 3명 평가 runbook 작성
- [x] Finder/VS Code candidate coverage 보강
- [x] Finder sidebar candidate용 `AXOpen` click execution 지원
- [x] `AXConfirm` candidate click execution 지원
- [x] overlay keyboard input 수신을 위한 app activation 보강
- [x] launch-option 평가용 click result stdout 출력
- [ ] Finder fixed task 재평가
- [ ] VS Code fixed task 재평가
- [ ] 내부 사용자 3명 평가 기록
- [ ] go/no-go 결론 작성

---

@author suho.do
@since 2026-07-02
