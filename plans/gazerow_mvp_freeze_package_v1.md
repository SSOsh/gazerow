# GazeRow MVP Freeze Package v1

## 변경 이력
- v1: TICKET-011 착수 전 freeze package 초안 작성. TICKET-010 수동 평가 결과가 필요한 항목은 명시적으로 보류.

## 1. 상태

현재 상태: `DRAFT_PREP_COMPLETE_BLOCKED_PENDING_FOCUS_CLICK_WIRING_AND_TICKET_010`

이 문서는 TICKET-011의 준비 가능한 산출물을 정리한다. freeze package 초안, 기본값 자동 감사, 검증 스크립트, distribution checklist는 준비됐지만, TICKET-010 Baseline Evaluation Run의 실제 앱별 결과와 go/no-go 판정이 없으므로 MVP freeze 완료로 간주하지 않는다. 2026-07-02 수동 평가 착수 결과 당시 빌드에는 end-to-end overlay activation/click runtime wiring이 없어 TICKET-010을 재시도할 수 없었다. 이후 메뉴바 activation에서 target resolve, scan, overlay show까지 1차 wiring을 완료했으며, focus/click wiring이 남아 있다.

## 2. Freeze 대상

| 항목 | 값 |
| --- | --- |
| 제품명 | GazeRow |
| Bundle Identifier | `dev.local.gazerow` |
| 플랫폼 | macOS 14+ |
| 앱 형태 | 메뉴바 앱(`.accessory`) + Settings window |
| 기준 commit | `ae06d01` |
| Toolchain | Xcode 26.6 (17F113) |
| 평가 기준 문서 | `gazerow_ticket_010_result_v1.md` |

## 3. MVP 범위

포함:

- Accessibility 권한 기반 target app/window resolve
- AX tree scanner와 clickable candidate 수집
- overlay label layout/rendering
- keyboard focus movement와 label jump
- keyboard-confirmed `AXPress` click execution
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

# freeze 사전 검증
scripts/verify_mvp_freeze.sh
```

주의:

- `xcode-select`가 Command Line Tools를 가리켜도 위처럼 `DEVELOPER_DIR`를 지정하면 된다.
- 실행 후 Dock 아이콘 없이 메뉴바 status item이 표시된다.
- Settings는 메뉴바 아이콘의 **Open Settings**로 연다.
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

TICKET-010 결과가 들어오기 전까지 아래 표는 provisional 상태다.

| 앱 | 현재 등급 | Freeze 전 필요한 확인 |
| --- | --- | --- |
| Finder | Evaluation target | sidebar item task success |
| Safari | Evaluation target | toolbar button task success |
| Chrome | Evaluation target | address bar focus task success |
| VS Code | Evaluation target | Activity Bar task success |
| System Settings | Evaluation target | button/toggle task success |
| Limited apps | None confirmed yet | TICKET-010 결과 후 갱신 |
| Slack | Unverified | Post-MVP 검증 |
| Notion | Unverified | Post-MVP 검증 |

Freeze package 확정 시 `gazerow_known_limitations_v1.md`의 App Support Tiers를 TICKET-010 결과와 일치시킨다.

## 8. TICKET-010 연결

Freeze 진행 조건:

- [ ] 초기 5개 앱 중 3개 이상에서 task success
- [ ] fallback off 상태에서 critical misclick count 0
- [ ] 30분 수동 세션 crash 없음
- [ ] 내부 사용자 3명 중 2명 이상이 3분 안에 기본 흐름 이해
- [ ] 내부 사용자 3명 중 2명 이상이 계속 쓸 가치 있음으로 평가
- [ ] abandoned attempt count가 task당 1회 이하

현재 차단:

- keyboard focus/click runtime wiring 미완료
- `gazerow_ticket_010_result_v1.md`의 앱별 `PENDING_MANUAL_EVALUATION` 값 미기입
- 내부 사용자 3명 평가 미완료
- go/no-go 판정 미작성

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
Decision: PENDING_TICKET_010
Reason: 실제 앱별 평가와 내부 사용자 평가가 필요하며, 현재 빌드는 5개 앱 task를 완료할 focus/click runtime path가 없다.
Required fixes before freeze: focus/click runtime wiring 구현 후 TICKET-010 재시도
Known limitations to update: TBD after TICKET-010
Next ticket: implement focus/click runtime wiring, rerun TICKET-010 manual evaluation, then finalize TICKET-011
```

---

@author suho.do
@since 2026-07-02
