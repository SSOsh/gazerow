# GazeRow TICKET-010 Result v1

## 변경 이력
- v1: TICKET-010 Baseline Evaluation Run의 사전 검증 결과와 수동 평가 기록지를 생성.
- v2: 수동 평가 착수 중 현재 빌드에 end-to-end overlay activation/click runtime 진입점이 없어 5개 앱 task를 수행할 수 없음을 기록.
- v3: 메뉴바 activation에서 target resolve, scan, overlay show까지 1차 runtime wiring이 완료됐고, keyboard focus/click wiring이 다음 차단 항목임을 기록.
- v4: overlay keyboard command와 FocusEngine runtime wiring 및 focused label highlight update가 완료됐고, interaction log/click wiring이 다음 차단 항목임을 기록.
- v5: focus/label jump interaction log wiring이 완료됐고, AXPress click execution wiring이 다음 차단 항목임을 기록.
- v6: focused label confirm에서 AXPress click execution까지 runtime wiring이 완료됐고, risky second confirm/click logging이 다음 차단 항목임을 기록.
- v7: risky action second confirm runtime flow가 완료됐고, click attempt/completed logging이 다음 차단 항목임을 기록.

## 1. 상태

현재 상태: `BLOCKED_RUNTIME_WIRING_REQUIRED`

자동 사전 검증은 완료했다. 2026-07-02 12:19:56 KST에 로컬 GUI 수동 평가를 착수했지만, 당시 앱 런타임에는 target resolve, scanner, overlay, focus engine, click executor를 end-to-end로 실행하는 activation 진입점이 연결되어 있지 않았다.

이후 1차 runtime wiring으로 메뉴바 activation에서 target resolve, scan, overlay show까지 연결했고, overlay keyboard command를 FocusEngine과 focused label highlight update에 연결했다. focus/label jump interaction log wiring, focused label confirm의 AXPress click execution wiring, risky action second confirm runtime flow도 완료했다. 5개 앱 task 수행, 내부 사용자 3명 평가, 30분 crash-free 세션은 click attempt/completed logging까지 완료한 뒤 재시도해야 한다.

## 2. 평가 전 체크리스트

| 항목 | 값 |
| --- | --- |
| 평가 일시 | 2026-07-02 12:11:54 KST |
| 평가자 | PENDING_MANUAL_EVALUATION |
| macOS version | macOS 26.2 (25C56) |
| Xcode version | Xcode 26.6 (17F113) |
| GazeRow commit | `ae06d01` |
| 빌드 방식 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` |
| build result | pass |
| test result | pass, 95 tests, 0 failures |
| run smoke result | pass, launched and stayed running for 5 seconds before manual interrupt |
| freeze verification result | pass, `scripts/verify_mvp_freeze.sh` |
| Accessibility 권한 | PENDING_RUNTIME_WIRING |
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

## 3.1 수동 평가 착수 결과

2026-07-02 12:19:56 KST 기준으로 앱 실행은 성공했다.

확인 내용:

- `GazeRow` 프로세스가 `.build/arm64-apple-macosx/debug/GazeRow`로 실행됨.
- 메뉴바/Settings/권한/세션 UI는 앱 런타임에 연결되어 있음.
- `TargetResolver`, `AccessibilityScanner`, `OverlayWindowController`, `FocusEngine`, `ClickExecutor`는 단위 테스트와 개별 구성요소로 존재하지만, 실제 사용자 activation 경로에서 함께 호출되지 않았음.
- 이후 메뉴바 `Show Overlay` 액션에서 target resolve, scan, overlay show까지 연결됨.

결론:

- 현재 빌드는 overlay 표시, keyboard focus/label jump, focus interaction log, AXPress click execution, risky action second confirm 진입점까지 갖췄지만, click attempt/completed interaction logging이 아직 없어 TICKET-010 평가 전 계측 조건이 완전하지 않다.
- 이는 앱별 AX 지원성 실패가 아니라 click logging wiring 미완료로 인한 평가 차단이다.
- TICKET-010은 click logging wiring 구현 후 재시도해야 한다.

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
Decision: PENDING_MANUAL_EVALUATION
Reason: 5개 앱 task를 평가할 click interaction logging runtime path가 아직 완전하지 않다.
Required fixes before freeze: click attempt/completed interaction logging
Known limitations to document: TICKET-010 재시도 후 확정
Next ticket: runtime activation/wiring 구현 후 TICKET-010 재시도. TICKET-011 최종 확정은 그 이후에만 가능
```

## 8. 남은 수동 작업

- [x] `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run`으로 앱 실행
- [x] menu activation / target resolve / scan / overlay show wiring 구현
- [x] keyboard focus / label jump wiring 구현
- [x] focus / label jump interaction log wiring 구현
- [x] AXPress click execution wiring 구현
- [x] risky action second confirm runtime flow 구현
- [ ] click attempt/completed interaction log wiring 구현
- [ ] Accessibility 권한 부여와 Settings/onboarding 확인
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
