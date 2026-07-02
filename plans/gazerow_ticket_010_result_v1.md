# GazeRow TICKET-010 Result v1

## 변경 이력
- v1: TICKET-010 Baseline Evaluation Run의 사전 검증 결과와 수동 평가 기록지를 생성.

## 1. 상태

현재 상태: `IN_PROGRESS`

자동 사전 검증은 완료했다. 실제 5개 앱 task 수행, 내부 사용자 3명 평가, 30분 crash-free 세션은 로컬 GUI에서 수동 진행이 필요하다.

## 2. 평가 전 체크리스트

| 항목 | 값 |
| --- | --- |
| 평가 일시 | 2026-07-02 11:29:23 KST |
| 평가자 | PENDING_MANUAL_EVALUATION |
| macOS version | macOS 26.2 (25C56) |
| Xcode version | Xcode 26.6 (17F113) |
| GazeRow commit | `6a7333c` |
| 빌드 방식 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` |
| build result | pass |
| test result | pass, 76 tests, 0 failures |
| run smoke result | pass, launched and stayed running for 5 seconds before manual interrupt |
| Accessibility 권한 | PENDING_MANUAL_EVALUATION |
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
| test | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | pass, 76 tests, 0 failures |
| run smoke | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run` | pass, launched and stayed running for 5 seconds before manual interrupt |

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
Reason: 5개 앱 task, 30분 crash-free 세션, 내부 사용자 3명 평가가 아직 필요하다.
Required fixes before freeze: TBD
Known limitations to document: TBD
Next ticket: TICKET-011, TICKET-010 결과가 GO 또는 CONDITIONAL-GO일 때만 착수
```

## 8. 남은 수동 작업

- [ ] `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run`으로 앱 실행
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
