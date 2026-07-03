# GazeRow MVP Freeze Package v1

## 변경 이력
- v1: TICKET-011 착수 전 freeze package 초안 작성. TICKET-010 수동 평가 결과가 필요한 항목은 명시적으로 보류.
- v2: runtime wiring 완료 후 Accessibility 권한 precheck 차단 상태를 반영.
- v3: Settings Accessibility 권한 요청 버튼 연결과 freeze 검증 통과 상태를 반영.
- v4: Show Overlay 권한 실패 시 권한 요청/설정 이동 경로와 123 tests 검증 결과를 반영.
- v5: `--request-accessibility` 런치 옵션과 125 tests 검증 결과를 반영.
- v6: Accessibility 권한 승인, 5개 앱 overlay activation smoke, 136 tests 검증 결과를 반영.
- v7: 5개 앱 실제 click task 결과(3 pass / 2 fail), known limitations 갱신, 141 tests 검증 결과를 반영.
- v8: 30분 crash-free manual session 통과 결과를 반영.
- v9: 내부 사용자 3명 평가 runbook 준비 상태를 반영.
- v10: Command+Shift+Space overlay activation shortcut 구현과 148 tests 검증 결과를 반영.
- v11: Finder/VS Code candidate coverage 보강, 150 tests 검증 결과, 재평가 필요 상태를 반영.
- v12: scanner 기본 depth 확장, 183 tests 검증 결과, Finder/VS Code label map smoke 개선 결과를 반영.
- v13: Finder sidebar candidate용 `AXOpen` click execution 지원을 반영.
- v14: overlay keyboard input 수신을 위한 app activation 보강과 188 tests 검증 결과를 반영.
- v15: launch-option click result stdout 출력과 191 tests 검증 결과를 반영.
- v16: ED-008에 따라 내부 사용자 gate를 Post-MVP defer로 정리하고 현재 차단 항목을 Finder/VS Code fixed task 재평가로 좁힘.
- v17: local `.app` bundle 생성 스크립트와 191 tests freeze 검증 결과를 반영.
- v18: overlay panel AX/AppKit 좌표 변환, Finder overlay visibility smoke, 193 tests freeze 검증 결과를 반영.
- v19: 좌표 보정 후 VS Code overlay visibility smoke 결과를 반영.
- v20: `--click-overlay-label` 평가 옵션, `AXShowDefaultUI` 실행 지원, Finder/VS Code fixed task pass, 200 tests freeze 검증 결과를 반영.
- v21: 표준 윈도우 컨트롤 고정키(Control+Option+C/M/Z → 닫기/최소화/줌 `AXPress`)와 Settings Shortcuts 안내 노출, 228 tests freeze 검증 결과를 반영.

## 1. 상태

현재 상태: `LOCAL_MVP_FREEZE_GO`

이 문서는 TICKET-011의 local MVP freeze 산출물을 정리한다. freeze package, 기본값 자동 감사, 검증 스크립트, distribution checklist는 준비됐다. 내부 사용자 3명 gate는 ED-008에 따라 Post-MVP로 defer했으며 local MVP freeze 블로커로 두지 않는다. 2026-07-02 수동 평가 착수 결과 당시 빌드에는 end-to-end overlay activation/click runtime wiring이 없어 TICKET-010을 재시도할 수 없었다. 이후 메뉴바 activation에서 target resolve, scan, overlay show까지 1차 wiring을 완료했고, overlay keyboard focus wiring, focus/label jump interaction log wiring, focused label AXPress click wiring, risky action second confirm runtime flow, click attempt/completed interaction log wiring도 연결했다. 2026-07-02 19:57:41 KST에는 Accessibility 권한 승인 후 `AXIsProcessTrusted()`가 true를 반환했고, target bundle launch option과 target window fallback을 추가해 5개 앱 overlay activation smoke를 통과했다. 2026-07-02 20:20 KST 실제 click task는 Safari/Chrome/System Settings pass, Finder/VS Code fail로 3/5 success를 기록했다. 2026-07-02 20:46:31~21:16:31 KST에는 30분 crash-free session도 통과했다. known limitations와 app support tier도 이 결과에 맞춰 갱신했고, 내부 사용자 평가 runbook(`gazerow_internal_user_evaluation_v1.md`)도 준비했다. 이후 Command+Shift+Space overlay activation shortcut, Finder/VS Code candidate coverage, scanner 기본 depth, Finder sidebar candidate용 `AXOpen`, `AXConfirm`, `AXShowDefaultUI` 실행, overlay keyboard input 수신을 위한 app activation, launch-option click result stdout 출력, `--click-overlay-label` 평가 옵션, overlay panel AX/AppKit 좌표 변환을 보강했다. Finder와 VS Code는 좌표 보정 후 전체 화면 캡처 기준 overlay visibility smoke를 통과했고, fixed task 재평가도 Finder `AXShowDefaultUI`, VS Code `AXPress`로 pass했다. `scripts/verify_mvp_freeze.sh`는 200 tests, 0 failures로 통과했다. 이후 표준 윈도우 컨트롤 고정키(Control+Option+C/M/Z → 닫기/최소화/줌 `AXPress`)를 추가하고 Settings Shortcuts 섹션에 overlay/window control 단축키를 SSOT 기반으로 노출했으며, 228 tests로 freeze 검증을 다시 통과했다.

## 2. Freeze 대상

| 항목 | 값 |
| --- | --- |
| 제품명 | GazeRow |
| Bundle Identifier | `dev.local.gazerow` |
| 플랫폼 | macOS 14+ |
| 앱 형태 | 메뉴바 앱(`.accessory`) + Settings window |
| 기준 commit | `76c8555` |
| Toolchain | Xcode 26.6 (17F113) |
| 평가 기준 문서 | `gazerow_ticket_010_result_v1.md` |

## 3. MVP 범위

포함:

- Accessibility 권한 기반 target app/window resolve
- Command+Shift+Space overlay activation shortcut
- 표준 윈도우 컨트롤 고정키(Control+Option+C/M/Z → 닫기/최소화/줌 `AXPress`)
- Settings Shortcuts 섹션의 overlay/window control 단축키 안내
- AX tree scanner와 clickable candidate 수집
- selectable container candidate 수집(`AXRow` / `AXCell` / `AXImage`)
- Finder sidebar candidate용 `AXOpen` click execution
- Finder row candidate용 `AXShowDefaultUI` click execution
- launch-option click result stdout reporting
- launch-option label click evaluation option
- overlay panel AX/AppKit coordinate conversion
- overlay label layout/rendering
- keyboard focus movement와 label jump
- keyboard-confirmed `AXPress` / `AXConfirm` / `AXOpen` / `AXShowDefaultUI` click execution
- risky action second confirm 정책
- kill switch
- first-run onboarding
- known limitations 표시
- opt-in local interaction log
- manual debug export 생성/삭제

제외:

- gaze/camera 기능
- Screen Recording 권한
- 원격 telemetry
- 자동 클릭
- 기본 활성 좌표 클릭 fallback
- 외부 배포용 signing/notarization

## 4. 로컬 Build/Run Guide

사전 조건:

- Xcode full app 설치
- Xcode 라이선스 동의
- Xcode toolchain 사용

명령:

```bash
cd /Users/suho/Github/gazerow
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run

# local .app bundle 생성
scripts/build_local_app.sh
open -n .build/local-app/GazeRow.app

# freeze 사전 검증
scripts/verify_mvp_freeze.sh
```

주의:

- `xcode-select`가 Command Line Tools를 가리켜도 위처럼 `DEVELOPER_DIR`를 지정하면 된다.
- 실행 후 Dock 아이콘 없이 메뉴바 status item이 표시된다.
- SwiftPM 바이너리 실행에서 activation/keyboard focus 재현이 불안정하면 local `.app` bundle로 재평가한다.
- Settings는 메뉴바 아이콘의 **Open Settings**로 연다.
- 권한 요청 동선은 `swift run GazeRow -- --request-accessibility`로 바로 열 수 있다.
- 실제 scanner/overlay 평가에는 Accessibility 권한이 필요하다.

## 5. 기능 플래그/기본값 확인

| 기능 | Freeze 기본값 | 근거 |
| --- | --- | --- |
| Camera/gaze | off / not included | Post-MVP |
| Screen Recording | not requested | MVP 제외 |
| Input Monitoring | not requested | MVP 제외 |
| coordinate click fallback | off | 오클릭 위험 최소화 |
| interaction log file | opt-in off | privacy 기본값 |
| debug export | manual only | 사용자 명시 동작 |
| debug export UI | hidden by default | `DebugFeatureVisibility` |
| automatic click | not supported | keyboard confirm 원칙 |
| second confirm | enabled for risky action | destructive/externalEffect/unknownRisk 안전 정책 |
| automated default audit | pass required | `MVPDefaultPolicy` |
| freeze verification script | pass required | `scripts/verify_mvp_freeze.sh` |

## 6. Privacy / Log 삭제 동선

| 항목 | 상태 |
| --- | --- |
| raw window title 저장 | 금지. `windowTitleHash`만 사용 |
| raw text value 저장 | 금지 |
| interaction log 저장 | opt-in일 때만 JSON Lines로 저장 |
| interaction log 삭제 | Settings의 delete logs 동선과 `InteractionLogStore.deleteAll()` |
| debug export 생성 | Settings의 manual export 동선과 `DebugExportManager.createExport()` |
| debug export 삭제 | Settings의 delete export 동선과 `DebugExportManager.deleteAll()` |
| 삭제/생성 결과 표시 | `DiagnosticsActionFeedback`으로 민감정보 없는 상태 문구 표시 |

Freeze 전 확인:

- [ ] Settings에서 interaction log opt-in 기본 off 확인
- [x] Settings에서 debug export UI 기본 숨김 확인
- [x] diagnostics 삭제/생성 액션의 상태 피드백 표시
- [x] `MVPDefaultPolicy`로 자동 확인 가능한 freeze 기본값 테스트
- [x] `scripts/verify_mvp_freeze.sh`로 build/test/제외 권한 문자열 검증
- [ ] interaction log 생성 후 삭제 확인
- [ ] debug export 생성 후 삭제 확인
- [ ] 생성 파일에 raw title/text value가 없는지 확인

## 7. 지원 앱/제한 앱/미확인 앱

TICKET-010 실제 click task, Finder/VS Code fixed task 재평가, 30분 crash-free session 결과 기준이다.

| 앱 | 현재 등급 | Freeze 전 필요한 확인 |
| --- | --- | --- |
| Finder | Evaluation pass | sidebar row task pass via `AXShowDefaultUI` |
| Safari | Evaluation pass | toolbar button task pass |
| Chrome | Evaluation pass | address bar focus task pass |
| VS Code | Evaluation pass | Activity Bar item task pass via `AXPress` |
| System Settings | Evaluation pass | pane navigation task pass |
| Slack | Evaluation pass | Post-MVP Messages tab click pass via `AXPress`, fallback=false |
| Notion | Evaluation pass | Post-MVP breadcrumb/page click task pass |
| Discord | Limited | Post-MVP smoke에서 6 labels; representative click pending |
| Obsidian | Unverified | 현재 평가 환경에 미설치 |

`gazerow_known_limitations_v1.md`의 App Support Tiers는 TICKET-010 결과와 일치한다.

## 8. TICKET-010 연결

Freeze 진행 조건:

- [x] 초기 5개 앱 중 3개 이상에서 task success
- [x] fallback off 상태에서 critical misclick count 0
- [x] 30분 수동 세션 crash 없음
- [x] 내부 사용자 3명 gate는 Post-MVP로 defer(ED-008)
- [x] abandoned attempt count가 task당 1회 이하

현재 차단:

- 없음. Post-MVP 내부 사용자 평가와 추가 앱 검증은 freeze 블로커가 아니다.

## 9. Code Signing / Notarization 체크리스트 초안

현재는 로컬 MVP이므로 signing/notarization을 freeze 완료 조건으로 두지 않는다.

상세 초안은 `gazerow_distribution_checklist_v1.md`에 둔다.

외부 배포 전 필요한 항목:

- [ ] Apple Developer Program 계정 확인
- [ ] Developer ID Application 인증서 준비
- [ ] hardened runtime 설정
- [ ] app sandbox 필요 여부 검토
- [ ] Accessibility 권한 안내 문구 재검토
- [ ] notarization pipeline 작성
- [ ] updater 포함 여부 결정
- [ ] privacy policy 문서 작성

## 10. Freeze 판정

```text
Decision: GO_FOR_LOCAL_MVP_FREEZE
Reason: 5개 평가 앱 모두 task success, critical misclick 0건, 30분 crash-free session, freeze verification을 충족했다. 내부 사용자 gate는 ED-008에 따라 Post-MVP로 defer했다.
Required fixes before freeze: none for local MVP
Known limitations to update: none for evaluated MVP apps
Next ticket: Discord representative click 검증, Obsidian 설치 환경 검증, 또는 내부 사용자 3명 평가 재개
```

Latest verification:

- 2026-07-03 11:05 KST `scripts/verify_mvp_freeze.sh` pass
- Build pass, 207 tests / 0 failures, MVP-excluded permission/framework reference check pass
- Post-MVP scanner changes verified separately with Slack 43-label smoke + `BI` click pass and Discord 6-label smoke
- 2026-07-03 v2 재검증(Claude): `scripts/verify_mvp_freeze.sh` pass, build pass, 335 tests / 0 failures (5회 반복 안정), excluded screen/input 참조 검사 pass. 핵심 5개 앱 overlay smoke success(Finder 46 / Safari 35 / Chrome 69 / VS Code 3 / System Settings 64, bundle id `com.apple.systempreferences`)

---

@author suho.do
@since 2026-07-02
