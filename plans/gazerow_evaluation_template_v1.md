# GazeRow Baseline Evaluation Template v1

## 변경 이력
- v1: TICKET-010 착수 전 평가자가 동일한 기준으로 Baseline MVP를 측정할 수 있도록 수동 평가 양식, 앱별 task, go/no-go 판정 기준을 정의.

## 1. 목적

이 문서는 `TICKET-010: Baseline Evaluation Run`에서 사용하는 평가 기록 양식이다.

목표:

- 초기 5개 앱에서 같은 task를 반복 측정한다.
- mouse/trackpad baseline과 GazeRow 흐름을 같은 기준으로 비교한다.
- overlay 품질, click 안전성, setup friction을 분리해서 기록한다.
- go/no-go 결론을 주관 느낌이 아니라 정해진 기준으로 남긴다.

비목표:

- gaze 기능 평가
- 공개 배포 품질 인증
- 성능 benchmark 자동화
- 외부 telemetry 수집

## 2. 평가 전 체크리스트

| 항목 | 값 |
| --- | --- |
| 평가 일시 | TBD |
| 평가자 | TBD |
| macOS version | TBD |
| GazeRow commit | TBD |
| 빌드 방식 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` |
| Accessibility 권한 | granted / not granted |
| Input Monitoring 권한 | requested / not requested |
| Screen Recording 권한 | not requested |
| Camera 권한 | not requested |
| coordinate fallback | off |
| interaction log opt-in | on / off |
| debug export opt-in | on / off |

평가 전 조건:

- coordinate fallback은 기본 off로 둔다.
- Camera와 Screen Recording 권한은 요청하지 않는다.
- 원문 window title, title/value/help/description 저장 여부를 확인한다.
- fallback on debug 테스트는 기본 평가와 분리해서 기록한다.

## 3. 평가 앱과 고정 Task

| 앱 | Bundle ID | Task | 성공 기준 |
| --- | --- | --- | --- |
| Finder | `com.apple.finder` | sidebar item 클릭 | label 표시 후 keyboard confirm으로 target folder/sidebar 이동 |
| Safari | `com.apple.Safari` | toolbar button 클릭 | AXPress 또는 안전한 keyboard-confirmed 흐름으로 UI 반응 확인 |
| Chrome | `com.google.Chrome` | 주소창 focus | keyboard confirm 후 텍스트 입력 가능 상태 |
| VS Code | `com.microsoft.VSCode` | Activity Bar item 이동 | target view 전환 |
| System Settings | `com.apple.systempreferences` | button/toggle focus 및 실행 | 상태 변화 또는 target pane 이동 |

## 4. 앱별 평가 기록

아래 블록을 앱마다 복사해서 작성한다.

```text
AppSupportReport
  appName:
  bundleIdentifier:
  appVersion:
  macOSVersion:
  task:
  taskSuccess: pass / fail
  candidateCount:
  usefulCandidateCount:
  scanDurationMs:
  nodesVisited:
  labelCount:
  labelCollisionCount:
  labelOcclusionCount:
  overlayReadability: 1 / 2 / 3 / 4 / 5
  overlayMisaligned: yes / no
  focusMoveCount:
  labelJumpAttemptCount:
  labelJumpSuccessCount:
  correctionCount:
  abandonedAttemptCount:
  mouseBaselineSeconds:
  gazerowSeconds:
  clickAttemptCount:
  clickSuccessCount:
  clickMethod: AXPress / fallback / none
  fallbackRequired: yes / no
  criticalMisclickCount:
  missingImportantElements:
  noisyElements:
  permissionOrSetupFriction:
  notes:
```

## 5. 평가자별 요약

| 평가자 | 3분 안에 기본 흐름 이해 | 계속 쓸 가치 있음 | 주요 friction |
| --- | --- | --- | --- |
| User 1 | yes / no | yes / no | TBD |
| User 2 | yes / no | yes / no | TBD |
| User 3 | yes / no | yes / no | TBD |

## 6. 집계 표

| 앱 | Task success | Candidate count | Useful candidates | Click success | Correction count | Abandoned attempts | Critical misclick |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Finder | pass / fail | TBD | TBD | TBD | TBD | TBD | TBD |
| Safari | pass / fail | TBD | TBD | TBD | TBD | TBD | TBD |
| Chrome | pass / fail | TBD | TBD | TBD | TBD | TBD | TBD |
| VS Code | pass / fail | TBD | TBD | TBD | TBD | TBD | TBD |
| System Settings | pass / fail | TBD | TBD | TBD | TBD | TBD | TBD |

## 7. Overlay 품질 집계

| 앱 | Label count | Collision count | Occlusion count | Readability 1-5 | Misaligned |
| --- | ---: | ---: | ---: | ---: | --- |
| Finder | TBD | TBD | TBD | TBD | yes / no |
| Safari | TBD | TBD | TBD | TBD | yes / no |
| Chrome | TBD | TBD | TBD | TBD | yes / no |
| VS Code | TBD | TBD | TBD | TBD | yes / no |
| System Settings | TBD | TBD | TBD | TBD | yes / no |

## 8. Safety 결과

| 항목 | 결과 |
| --- | --- |
| coordinate fallback off 유지 | pass / fail |
| critical misclick count | TBD |
| destructive/externalEffect/unknownRisk second confirm | pass / fail |
| secure/password field 후보 제외 | pass / fail |
| click history/file 저장에 원문 title 없음 | pass / fail |

## 9. Go/No-Go 판정

Go 조건:

- 초기 5개 앱 중 3개 이상에서 task 성공
- fallback off 상태에서 치명적 오클릭 0건
- 30분 수동 세션 crash 없음
- 내부 사용자 3명 중 2명 이상이 3분 안에 기본 흐름 이해
- 내부 사용자 3명 중 2명 이상이 계속 쓸 가치 있음으로 평가
- abandoned attempt count가 task당 1회 이하

판정:

```text
Decision: GO / NO-GO / CONDITIONAL-GO
Reason:
Required fixes before freeze:
Known limitations to document:
Next ticket:
```

## 10. 후속 액션

평가 후 반드시 남길 것:

- 앱별 지원성 표 업데이트
- known limitations와 실제 실패 케이스 연결
- TICKET-011 MVP Freeze Package 착수 가능 여부
- gaze spike로 넘어갈 가치가 있는지의 근거

---

@author suho.do
@since 2026-07-02
