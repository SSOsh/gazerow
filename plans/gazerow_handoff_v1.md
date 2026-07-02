# GazeRow Handoff v1

## 변경 이력
- v1: 다른 컴퓨터나 새 세션에서 GazeRow 작업을 이어받기 위한 읽기 순서, 현재 상태, 다음 액션, 미결정 항목을 정리.

## 1. 목적

이 문서는 GazeRow 작업을 새 환경에서 이어받을 때 가장 먼저 보는 핸드오프 문서다.

목표:

- 어떤 파일을 어떤 순서로 읽어야 하는지 명확히 한다.
- 현재 결정된 정책과 아직 결정되지 않은 값을 구분한다.
- 다음 작업자가 `TICKET-001` 착수 전 무엇을 확인해야 하는지 알 수 있게 한다.

## 2. 현재 상태

현재는 구현 전 계획 정리 단계다.

완료된 문서:

- `gazerow_mvp_v1.md`부터 `gazerow_mvp_v5.md`
- `gazerow_tickets_v1.md`
- `gazerow_evaluation_template_v1.md`
- `gazerow_decisions_v1.md`

현재 기준 문서:

- 최신 MVP 계획: `gazerow_mvp_v5.md`
- 구현 티켓: `gazerow_tickets_v1.md`
- 결정 로그: `gazerow_decisions_v1.md`
- 평가 양식: `gazerow_evaluation_template_v1.md`

## 3. 읽기 순서

처음 이어받는 경우:

1. `gazerow_handoff_v1.md`
2. `gazerow_decisions_v1.md`
3. `gazerow_tickets_v1.md`
4. `gazerow_mvp_v5.md`

평가 단계에서만 추가로 읽을 파일:

1. `gazerow_evaluation_template_v1.md`

과거 변경 흐름을 확인할 때만 읽을 파일:

1. `gazerow_mvp_v1.md`
2. `gazerow_mvp_v2.md`
3. `gazerow_mvp_v3.md`
4. `gazerow_mvp_v4.md`

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

## 5. 구현 착수 전 반드시 결정할 것

`gazerow_decisions_v1.md`의 Next Decision Checkpoint 기준으로 아래 항목을 확정해야 한다.

| 항목 | 현재 상태 | 필요 이유 |
| --- | --- | --- |
| 앱 이름 | TBD | bundle id, UI, 권한 안내 문구에 필요 |
| 저장소 위치 | TBD | Swift app 생성 위치 필요 |
| 앱 형태 | Proposed: 메뉴바 앱 + Settings window | TICKET-001 구현 방향 |
| 기본 단축키 | Proposed: Command + Shift + Space | ShortcutManager 구현 |
| 최소 macOS 버전 | TBD | Xcode target/API 범위 |

## 6. 바로 다음 작업

추천 순서:

1. `gazerow_decisions_v1.md`에서 TICKET-001 착수 전 결정값 확정
2. Swift app 저장소 생성
3. `TICKET-001: Project Shell and App Lifecycle` 착수
4. `TICKET-002: Permission UX and PermissionManager` 착수
5. `TICKET-003` 완료 후 AX 접근 가능성 중간 판단
6. `TICKET-004` 완료 후 Baseline MVP 가능성 중간 판단

## 7. 작업 중 지켜야 할 제한

- TICKET-007 전까지 실제 클릭을 수행하지 않는다.
- fallback 좌표 클릭은 기본 off를 유지한다.
- Camera 권한은 MVP baseline에서 요청하지 않는다.
- Screen Recording 권한은 MVP에서 요청하지 않는다.
- 원문 window title, title/value/help/description은 기본 로그에 저장하지 않는다.
- gaze 관련 코드는 MVP 빌드에서 비활성 또는 미포함 상태를 유지한다.

## 8. 산출물 위치

모든 GazeRow 계획 문서는 아래 폴더에서 관리한다.

```text
/Users/lotte/gitlab/plans/gazerow/
```

현재 파일 목록:

```text
gazerow_decisions_v1.md
gazerow_evaluation_template_v1.md
gazerow_handoff_v1.md
gazerow_mvp_v1.md
gazerow_mvp_v2.md
gazerow_mvp_v3.md
gazerow_mvp_v4.md
gazerow_mvp_v5.md
gazerow_tickets_v1.md
```

## 9. 다음 문서 후보

필요할 때만 만든다.

- `gazerow_ticket_001_spec_v1.md`: TICKET-001 상세 구현 명세
- `gazerow_permission_copy_v1.md`: 권한 안내 문구 초안
- `gazerow_known_limitations_v1.md`: 사용자 노출 제한사항 초안
- `gazerow_readme_draft_v1.md`: MVP README 초안
