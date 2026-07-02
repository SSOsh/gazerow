# GazeRow Handoff v1

## 변경 이력
- v1: 다른 컴퓨터나 새 세션에서 GazeRow 작업을 이어받기 위한 읽기 순서, 현재 상태, 다음 액션, 미결정 항목을 정리.

## 1. 목적

이 문서는 GazeRow 작업을 새 환경에서 이어받을 때 가장 먼저 보는 핸드오프 문서다.

목표:

- 어떤 파일을 어떤 순서로 읽어야 하는지 명확히 한다.
- 현재 구현된 MVP 범위와 아직 남은 평가 작업을 구분한다.
- 다음 작업자가 `TICKET-010` 평가를 바로 준비할 수 있게 한다.

## 2. 현재 상태

현재는 TICKET-001부터 TICKET-009까지 구현됐고, TICKET-010 사전 검증과 TICKET-011 freeze 준비 산출물이 완료된 상태다.
TICKET-010 수동 평가 착수 결과 당시 빌드에 end-to-end overlay activation/click runtime wiring이 없어 5개 앱 task를 수행할 수 없음이 확인됐다. 이후 메뉴바 activation에서 target resolve, scan, overlay show까지 1차 wiring을 완료했고, overlay keyboard command를 FocusEngine 및 focused label highlight update에 연결했다. focus/label jump interaction log wiring, focused label AXPress click wiring, risky action second confirm runtime flow, click attempt/completed interaction log wiring도 완료했다.

2026-07-02 12:58:32 KST precheck에서 현재 실행 환경의 Accessibility 권한이 `not granted`로 확인됐다. 2026-07-02 19:36:10 KST에는 Settings Accessibility 섹션의 `Request Permission` 버튼을 연결했고, 2026-07-02 19:42:19 KST에는 Show Overlay 권한 실패 시 권한 요청 프롬프트와 System Settings 이동을 연결했다. 2026-07-02 19:45:35 KST에는 `--request-accessibility` 런치 옵션을 추가했다. 2026-07-02 19:57:41 KST에는 Accessibility 권한이 승인되어 `AXIsProcessTrusted()`가 `true`를 반환했다. 이후 target bundle launch option과 target window fallback을 추가해 Finder, Safari, Chrome, VS Code, System Settings overlay activation smoke를 통과했다. TICKET-010의 실제 click task, 30분 crash-free session, 내부 사용자 3명 평가와 go/no-go 판정은 아직 남아 있다.

완료된 구현/문서:

- Swift Package 기반 macOS 메뉴바 앱 shell
- Accessibility 권한 UX, target resolver, scanner, overlay, focus engine
- AXPress click executor와 안전 정책
- local interaction logging/debug export core
- debug export UI 기본 숨김 정책
- diagnostics 삭제/생성 액션 상태 피드백
- MVP freeze 기본값 자동 감사
- MVP freeze 사전 검증 스크립트
- runtime overlay session 1차 wiring(menu activation, target resolve, scan, overlay show)
- runtime keyboard focus wiring(FocusEngine, label jump, focused label highlight)
- runtime focus/label jump interaction log wiring
- runtime focused label AXPress click wiring
- runtime risky action second confirm flow
- runtime click attempt/completed interaction log wiring
- Settings Accessibility 권한 요청 버튼
- Show Overlay 권한 실패 시 Accessibility 요청/설정 이동
- `--request-accessibility` 런치 옵션
- `--show-overlay-on-launch --target-bundle-id` 평가 런치 옵션
- target window fallback(`AXFocusedWindow` -> `AXMainWindow` -> `AXWindows`)
- 5개 앱 overlay activation smoke
- TICKET-011 freeze package / distribution checklist 초안
- first-run onboarding, known limitations, kill switch
- `gazerow_tickets_v1.md`
- `gazerow_evaluation_template_v1.md`
- `gazerow_decisions_v1.md`
- `gazerow_distribution_checklist_v1.md`
- `gazerow_known_limitations_v1.md`
- `gazerow_ticket_010_prep_v1.md`
- `gazerow_ticket_010_result_v1.md`
- `gazerow_mvp_freeze_package_v1.md`

현재 기준 문서:

- 최신 MVP 계획: `gazerow_mvp_v2.md`
- 구현 티켓: `gazerow_tickets_v1.md`
- 결정 로그: `gazerow_decisions_v1.md`
- 평가 양식: `gazerow_evaluation_template_v1.md`

## 3. 읽기 순서

처음 이어받는 경우:

1. `README.md`
2. `gazerow_handoff_v1.md`
3. `gazerow_tickets_v1.md`
4. `gazerow_decisions_v1.md`
5. `gazerow_mvp_v2.md`

평가 단계에서만 추가로 읽을 파일:

1. `gazerow_evaluation_template_v1.md`
2. `gazerow_ticket_010_prep_v1.md`
3. `gazerow_known_limitations_v1.md`
4. `gazerow_ticket_010_result_v1.md`
5. `gazerow_mvp_freeze_package_v1.md`
6. `gazerow_distribution_checklist_v1.md`

## 4. 핵심 결정 요약

Accepted:

- Baseline MVP는 gaze 없이 동작해야 한다.
- 초기 사용자는 macOS 키보드 중심 개발자 또는 파워유저다.
- MVP는 범용 접근성/의료 보조 제품으로 포지셔닝하지 않는다.
- 초기 앱은 Finder, Safari, Chrome, VS Code, System Settings다.
- MVP 성공 기준은 초기 5개 앱 중 3개 이상 task 성공이다.
- 모든 click은 keyboard confirm이 필요하다.
- `AXPress`를 우선 사용한다.
- `CGEventPost` fallback은 기본 off다.
- Camera, Screen Recording, telemetry는 MVP에서 제외한다.
- Interaction 로그 파일 저장은 사용자 opt-in이다.
- 텍스트 필드는 런타임 조회만 하고 기본 로그/저장 대상에서 제외한다.

Deferred:

- gaze tracking
- gaze ranking integration
- 외부 배포
- Developer ID signing
- notarization
- updater

## 5. 평가 전 반드시 확인할 것

| 항목 | 현재 상태 | 필요 이유 |
| --- | --- | --- |
| Xcode toolchain | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`로 검증 | SwiftPM AppKit build/test |
| Runtime activation/wiring | 완료 | TICKET-010 5개 앱 task 수행 전제 |
| 권한 요청 UX | 완료 | Settings `Request Permission`, Show Overlay 권한 실패 경로, `--request-accessibility` 런치 옵션 |
| Accessibility 권한 | granted | scanner/overlay 대상 조회와 AXPress 실행 |
| 5개 앱 overlay activation smoke | 완료 | Finder 19, Safari 35, Chrome 46, VS Code 3, System Settings 11 labels |
| 평가자 3명 | TBD | TICKET-010 완료 조건 |
| 평가 macOS version | TBD | 평가표 필수 기록 |
| 초기 5개 앱 실행 가능 여부 | TBD | Finder/Safari/Chrome/VS Code/System Settings task |

## 6. 바로 다음 작업

추천 순서:

1. Finder, Safari, Chrome, VS Code, System Settings 순서로 실제 click task 수행
2. `gazerow_ticket_010_result_v1.md`에 평가 결과 기록
3. 30분 crash-free manual session 기록
4. 내부 사용자 3명 평가 기록
5. go/no-go 결론 작성
6. TICKET-011 freeze package와 known limitations/app support tiers 최종 갱신

## 7. 작업 중 지켜야 할 제한

- 실제 클릭은 keyboard confirm 이후에만 수행한다.
- fallback 좌표 클릭은 기본 off를 유지한다.
- Camera 권한은 MVP baseline에서 요청하지 않는다.
- Screen Recording 권한은 MVP에서 요청하지 않는다.
- 원문 window title, title/value/help/description은 기본 로그에 저장하지 않는다.
- gaze 관련 코드는 MVP 빌드에서 비활성 또는 미포함 상태를 유지한다.

## 8. 산출물 위치

모든 GazeRow 계획 문서는 아래 폴더에서 관리한다.

```text
/Users/suho/Github/gazerow/plans/
```

현재 파일 목록:

```text
gazerow_decisions_v1.md
gazerow_distribution_checklist_v1.md
gazerow_evaluation_template_v1.md
gazerow_handoff_v1.md
gazerow_known_limitations_v1.md
gazerow_mvp_freeze_package_v1.md
gazerow_mvp_v2.md
gazerow_ticket_001_spec_v1.md
gazerow_ticket_010_prep_v1.md
gazerow_ticket_010_result_v1.md
gazerow_tickets_v1.md
```

검증 스크립트:

```text
scripts/verify_mvp_freeze.sh
```

## 9. 다음 문서 후보

필요할 때만 만든다.

- `gazerow_mvp_freeze_package_v1.md`: TICKET-011 freeze package
