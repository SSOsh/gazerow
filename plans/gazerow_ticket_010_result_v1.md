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

## 1. 상태

현재 상태: `BLOCKED_PENDING_ACCESSIBILITY_PERMISSION`

자동 사전 검증은 완료했다. 2026-07-02 12:19:56 KST에 로컬 GUI 수동 평가를 착수했지만, 당시 앱 런타임에는 target resolve, scanner, overlay, focus engine, click executor를 end-to-end로 실행하는 activation 진입점이 연결되어 있지 않았다.

이후 1차 runtime wiring으로 메뉴바 activation에서 target resolve, scan, overlay show까지 연결했고, overlay keyboard command를 FocusEngine과 focused label highlight update에 연결했다. focus/label jump interaction log wiring, focused label confirm의 AXPress click execution wiring, risky action second confirm runtime flow, click attempt/completed interaction log wiring도 완료했다.

2026-07-02 12:58:32 KST에 수동 평가 재시도 전 precheck를 수행했지만, 현재 실행 환경에서 Accessibility 권한이 `not granted`로 확인됐다. AX tree scan과 AXPress가 모두 Accessibility 권한에 의존하므로 5개 앱 task 수행은 권한 부여 후 재시도해야 한다.

2026-07-02 19:36:10 KST에 Settings의 Accessibility 섹션에 시스템 권한 요청 프롬프트를 여는 `Request Permission` 버튼을 연결했다. 코드상 권한 요청 동선은 준비됐지만 macOS 보안 권한은 사용자가 직접 승인해야 하므로 현재 수동 평가는 계속 차단 상태다.

2026-07-02 19:42:19 KST에는 Show Overlay 실행 중 target resolve/scan이 Accessibility 권한 부족으로 실패하면 권한 요청 프롬프트와 System Settings Accessibility 패널을 여는 경로를 추가했다. 실제 권한 토글은 OS 보안 설정이므로 사용자 승인 없이는 변경하지 않았다.

2026-07-02 19:45:35 KST에는 `swift run GazeRow -- --request-accessibility` 실행 시 앱 시작 직후 권한 요청 프롬프트와 System Settings Accessibility 패널을 여는 런치 옵션을 추가했다.

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
| Accessibility 권한 | not granted, blocks manual evaluation retry |
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
- Accessibility 권한이 아직 부여되지 않아 TICKET-010 5개 앱 수동 평가는 권한 부여 후 재시도한다.

## 4. 앱별 평가 기록

### Finder

```text
AppSupportReport
  appName: Finder
  bundleIdentifier: com.apple.finder
  appVersion: PENDING_MANUAL_EVALUATION
  macOSVersion: macOS 26.2 (25C56)
  task: sidebar item 클릭
  taskSuccess: PENDING_MANUAL_EVALUATION
  candidateCount: PENDING_MANUAL_EVALUATION
  usefulCandidateCount: PENDING_MANUAL_EVALUATION
  scanDurationMs: PENDING_MANUAL_EVALUATION
  nodesVisited: PENDING_MANUAL_EVALUATION
  labelCount: PENDING_MANUAL_EVALUATION
  labelCollisionCount: PENDING_MANUAL_EVALUATION
  labelOcclusionCount: PENDING_MANUAL_EVALUATION
  overlayReadability: PENDING_MANUAL_EVALUATION
  overlayMisaligned: PENDING_MANUAL_EVALUATION
  focusMoveCount: PENDING_MANUAL_EVALUATION
  labelJumpAttemptCount: PENDING_MANUAL_EVALUATION
  labelJumpSuccessCount: PENDING_MANUAL_EVALUATION
  correctionCount: PENDING_MANUAL_EVALUATION
  abandonedAttemptCount: PENDING_MANUAL_EVALUATION
  mouseBaselineSeconds: PENDING_MANUAL_EVALUATION
  gazerowSeconds: PENDING_MANUAL_EVALUATION
  clickAttemptCount: PENDING_MANUAL_EVALUATION
  clickSuccessCount: PENDING_MANUAL_EVALUATION
  clickMethod: PENDING_MANUAL_EVALUATION
  fallbackRequired: PENDING_MANUAL_EVALUATION
  criticalMisclickCount: PENDING_MANUAL_EVALUATION
  missingImportantElements: PENDING_MANUAL_EVALUATION
  noisyElements: PENDING_MANUAL_EVALUATION
  permissionOrSetupFriction: PENDING_MANUAL_EVALUATION
  notes:
```

### Safari

```text
AppSupportReport
  appName: Safari
  bundleIdentifier: com.apple.Safari
  appVersion: PENDING_MANUAL_EVALUATION
  macOSVersion: macOS 26.2 (25C56)
  task: toolbar button 클릭
  taskSuccess: PENDING_MANUAL_EVALUATION
  candidateCount: PENDING_MANUAL_EVALUATION
  usefulCandidateCount: PENDING_MANUAL_EVALUATION
  scanDurationMs: PENDING_MANUAL_EVALUATION
  nodesVisited: PENDING_MANUAL_EVALUATION
  labelCount: PENDING_MANUAL_EVALUATION
  labelCollisionCount: PENDING_MANUAL_EVALUATION
  labelOcclusionCount: PENDING_MANUAL_EVALUATION
  overlayReadability: PENDING_MANUAL_EVALUATION
  overlayMisaligned: PENDING_MANUAL_EVALUATION
  focusMoveCount: PENDING_MANUAL_EVALUATION
  labelJumpAttemptCount: PENDING_MANUAL_EVALUATION
  labelJumpSuccessCount: PENDING_MANUAL_EVALUATION
  correctionCount: PENDING_MANUAL_EVALUATION
  abandonedAttemptCount: PENDING_MANUAL_EVALUATION
  mouseBaselineSeconds: PENDING_MANUAL_EVALUATION
  gazerowSeconds: PENDING_MANUAL_EVALUATION
  clickAttemptCount: PENDING_MANUAL_EVALUATION
  clickSuccessCount: PENDING_MANUAL_EVALUATION
  clickMethod: PENDING_MANUAL_EVALUATION
  fallbackRequired: PENDING_MANUAL_EVALUATION
  criticalMisclickCount: PENDING_MANUAL_EVALUATION
  missingImportantElements: PENDING_MANUAL_EVALUATION
  noisyElements: PENDING_MANUAL_EVALUATION
  permissionOrSetupFriction: PENDING_MANUAL_EVALUATION
  notes:
```

### Chrome

```text
AppSupportReport
  appName: Chrome
  bundleIdentifier: com.google.Chrome
  appVersion: PENDING_MANUAL_EVALUATION
  macOSVersion: macOS 26.2 (25C56)
  task: 주소창 focus
  taskSuccess: PENDING_MANUAL_EVALUATION
  candidateCount: PENDING_MANUAL_EVALUATION
  usefulCandidateCount: PENDING_MANUAL_EVALUATION
  scanDurationMs: PENDING_MANUAL_EVALUATION
  nodesVisited: PENDING_MANUAL_EVALUATION
  labelCount: PENDING_MANUAL_EVALUATION
  labelCollisionCount: PENDING_MANUAL_EVALUATION
  labelOcclusionCount: PENDING_MANUAL_EVALUATION
  overlayReadability: PENDING_MANUAL_EVALUATION
  overlayMisaligned: PENDING_MANUAL_EVALUATION
  focusMoveCount: PENDING_MANUAL_EVALUATION
  labelJumpAttemptCount: PENDING_MANUAL_EVALUATION
  labelJumpSuccessCount: PENDING_MANUAL_EVALUATION
  correctionCount: PENDING_MANUAL_EVALUATION
  abandonedAttemptCount: PENDING_MANUAL_EVALUATION
  mouseBaselineSeconds: PENDING_MANUAL_EVALUATION
  gazerowSeconds: PENDING_MANUAL_EVALUATION
  clickAttemptCount: PENDING_MANUAL_EVALUATION
  clickSuccessCount: PENDING_MANUAL_EVALUATION
  clickMethod: PENDING_MANUAL_EVALUATION
  fallbackRequired: PENDING_MANUAL_EVALUATION
  criticalMisclickCount: PENDING_MANUAL_EVALUATION
  missingImportantElements: PENDING_MANUAL_EVALUATION
  noisyElements: PENDING_MANUAL_EVALUATION
  permissionOrSetupFriction: PENDING_MANUAL_EVALUATION
  notes:
```

### VS Code

```text
AppSupportReport
  appName: VS Code
  bundleIdentifier: com.microsoft.VSCode
  appVersion: PENDING_MANUAL_EVALUATION
  macOSVersion: macOS 26.2 (25C56)
  task: Activity Bar item 이동
  taskSuccess: PENDING_MANUAL_EVALUATION
  candidateCount: PENDING_MANUAL_EVALUATION
  usefulCandidateCount: PENDING_MANUAL_EVALUATION
  scanDurationMs: PENDING_MANUAL_EVALUATION
  nodesVisited: PENDING_MANUAL_EVALUATION
  labelCount: PENDING_MANUAL_EVALUATION
  labelCollisionCount: PENDING_MANUAL_EVALUATION
  labelOcclusionCount: PENDING_MANUAL_EVALUATION
  overlayReadability: PENDING_MANUAL_EVALUATION
  overlayMisaligned: PENDING_MANUAL_EVALUATION
  focusMoveCount: PENDING_MANUAL_EVALUATION
  labelJumpAttemptCount: PENDING_MANUAL_EVALUATION
  labelJumpSuccessCount: PENDING_MANUAL_EVALUATION
  correctionCount: PENDING_MANUAL_EVALUATION
  abandonedAttemptCount: PENDING_MANUAL_EVALUATION
  mouseBaselineSeconds: PENDING_MANUAL_EVALUATION
  gazerowSeconds: PENDING_MANUAL_EVALUATION
  clickAttemptCount: PENDING_MANUAL_EVALUATION
  clickSuccessCount: PENDING_MANUAL_EVALUATION
  clickMethod: PENDING_MANUAL_EVALUATION
  fallbackRequired: PENDING_MANUAL_EVALUATION
  criticalMisclickCount: PENDING_MANUAL_EVALUATION
  missingImportantElements: PENDING_MANUAL_EVALUATION
  noisyElements: PENDING_MANUAL_EVALUATION
  permissionOrSetupFriction: PENDING_MANUAL_EVALUATION
  notes:
```

### System Settings

```text
AppSupportReport
  appName: System Settings
  bundleIdentifier: com.apple.SystemSettings
  appVersion: PENDING_MANUAL_EVALUATION
  macOSVersion: macOS 26.2 (25C56)
  task: button/toggle focus 및 실행
  taskSuccess: PENDING_MANUAL_EVALUATION
  candidateCount: PENDING_MANUAL_EVALUATION
  usefulCandidateCount: PENDING_MANUAL_EVALUATION
  scanDurationMs: PENDING_MANUAL_EVALUATION
  nodesVisited: PENDING_MANUAL_EVALUATION
  labelCount: PENDING_MANUAL_EVALUATION
  labelCollisionCount: PENDING_MANUAL_EVALUATION
  labelOcclusionCount: PENDING_MANUAL_EVALUATION
  overlayReadability: PENDING_MANUAL_EVALUATION
  overlayMisaligned: PENDING_MANUAL_EVALUATION
  focusMoveCount: PENDING_MANUAL_EVALUATION
  labelJumpAttemptCount: PENDING_MANUAL_EVALUATION
  labelJumpSuccessCount: PENDING_MANUAL_EVALUATION
  correctionCount: PENDING_MANUAL_EVALUATION
  abandonedAttemptCount: PENDING_MANUAL_EVALUATION
  mouseBaselineSeconds: PENDING_MANUAL_EVALUATION
  gazerowSeconds: PENDING_MANUAL_EVALUATION
  clickAttemptCount: PENDING_MANUAL_EVALUATION
  clickSuccessCount: PENDING_MANUAL_EVALUATION
  clickMethod: PENDING_MANUAL_EVALUATION
  fallbackRequired: PENDING_MANUAL_EVALUATION
  criticalMisclickCount: PENDING_MANUAL_EVALUATION
  missingImportantElements: PENDING_MANUAL_EVALUATION
  noisyElements: PENDING_MANUAL_EVALUATION
  permissionOrSetupFriction: PENDING_MANUAL_EVALUATION
  notes:
```

## 5. 집계 표

| 앱 | Task success | Candidate count | Useful candidates | Click success | Correction count | Abandoned attempts | Critical misclick |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Finder | PENDING | TBD | TBD | TBD | TBD | TBD | TBD |
| Safari | PENDING | TBD | TBD | TBD | TBD | TBD | TBD |
| Chrome | PENDING | TBD | TBD | TBD | TBD | TBD | TBD |
| VS Code | PENDING | TBD | TBD | TBD | TBD | TBD | TBD |
| System Settings | PENDING | TBD | TBD | TBD | TBD | TBD | TBD |

현재 값은 앱별 실패값이 아니라 평가 미실행값이다. runtime activation/wiring 구현 전에는 앱별 pass/fail을 판정하지 않는다.

## 6. Safety 결과

| 항목 | 결과 |
| --- | --- |
| coordinate fallback off 유지 | pass by code/config default, manual confirmation pending |
| critical misclick count | PENDING_MANUAL_EVALUATION |
| destructive/externalEffect/unknownRisk second confirm | pass by unit test |
| secure/password field 후보 제외 | pass by unit test |
| click history/file 저장에 원문 title 없음 | pass by unit test |

## 7. Go/No-Go 판정

```text
Decision: BLOCKED_PENDING_ACCESSIBILITY_PERMISSION
Reason: runtime wiring 차단은 해소됐지만 현재 실행 환경에서 Accessibility 권한이 부여되지 않았다.
Required fixes before freeze: TBD after manual evaluation retry
Known limitations to document: TICKET-010 재시도 후 확정
Next ticket: Accessibility 권한 부여 후 TICKET-010 5개 앱 수동 평가 재시도. TICKET-011 최종 확정은 그 이후에만 가능
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
- [!] Accessibility 권한 부여와 Settings/onboarding 확인
  - blocked: 2026-07-02 12:58:32 KST precheck에서 `AXIsProcessTrusted()`가 false 반환
- [ ] Finder task 수행
- [ ] Safari task 수행
- [ ] Chrome task 수행
- [ ] VS Code task 수행
- [ ] System Settings task 수행
- [ ] 30분 crash-free manual session 기록
- [ ] 내부 사용자 3명 평가 기록
- [ ] go/no-go 결론 작성

---

@author suho.do
@since 2026-07-02
