# gazerow Deferred or Rejected Improvements v1

## 목적

첨부 문서 전체를 코드와 대조한 뒤, 이번 개선 범위에서 제외한 항목을 기록한다.
제외 기준은 현재 코드 상태에서 회귀 위험이 크거나, 사전 수동 조사 없이 구현하면 오동작 가능성이 높은 경우다.

## 이번 턴에서 제외한 항목

| 항목 | 결정 | 이유 |
| --- | --- | --- |
| KakaoTalk composer heuristic | Deferred | Accessibility Inspector로 실제 role/subrole/frame을 확인하지 않은 상태에서 `AXGroup`/`AXWebArea`를 후보로 승격하면 밀집 UI에서 오클릭 가능성이 높다. |
| Electron/카카오톡 scan preset 상향 | Deferred | `maxNodes=5000`, `timeout=2s`는 Slack/KakaoTalk에는 유리하지만 모든 세션에 잘못 적용되면 overlay activation latency가 악화된다. bundle id 확인과 context-aware scanner 설계 후 적용한다. |
| 메뉴바 fuzzy, 초성, 동의어, 결과 리스트 | Deferred | v1 제외/Post-v1 항목이다. Query Overlay 기본 경로가 안정화된 뒤 검색 품질 개선으로 진행한다. |
| 무료 zip 배포 스크립트 추가 | Deferred | 기능 개선보다 배포 작업에 가깝고, 현재 요청의 Query Overlay/앱 한계 개선과 직접 관련이 낮다. release packaging 단계에서 별도 검증과 함께 추가한다. |
| Scanner와 searchable collector의 단일 AX walk 통합 | Deferred | TICKET-014는 collector를 별도 주입으로 연결했다. 기존 scanner 구조를 크게 바꾸면 후보 수집/클릭 회귀 표면이 커져 Post-v1 구조 개선으로 남긴다. |
| 검색 결과 리스트 UI | Deferred | v1 status UI는 현재 match와 count만 표시한다. 리스트 UI는 keyboard focus 모델과 overlay layout 복잡도가 늘어 Post-v1에서 별도 설계한다. |
| 앱별 검색 weight 보정 | Deferred | Safari/Chrome/Finder 등 앱별 AX 노출 차이를 실제 E1~E5/W1~W5 반복 평가로 먼저 수집해야 한다. |
| `AXWebArea` clickable 후보화 | Rejected for now | 웹뷰 전체를 클릭 후보로 만들면 target이 너무 커지고 의도하지 않은 클릭 위험이 높다. 앱별 inspector 결과와 2차 확인/휴리스틱이 갖춰진 뒤 재검토한다. |

## 이번 턴에서 진행한 항목

| 항목 | 상태 | 이유 |
| --- | --- | --- |
| focus 없는 confirm 실패 UI 표시 | Done | 기존 경로는 로그와 `lastClickResult`만 남기고 status/observer 갱신이 없어 사용자가 실패를 알기 어렵다. 회귀 표면이 작고 테스트로 고정 가능하다. |
| `ElementSearchIndex` 순수 검색 코어 | Done | 세션에 연결하지 않는 독립 타입이라 기존 overlay 동작을 바꾸지 않는다. TICKET-014의 scoring/filter/sort 기반을 테스트와 함께 마련한다. |
| Query status model/UI(TICKET-012) | Done | label-only 정보를 보존하면서 query scope/match/action hint를 2줄 status로 표시한다. |
| Query keyboard input(TICKET-013) | Done | bare letter는 label 우선, `/`/`;` primer로 elements/windows query를 명시한다. |
| Searchable node collector(TICKET-014) | Done | AX searchable node를 index로 연결하고 parent/children 관계를 보존한다. |
| Actionable promotion(TICKET-015) | Done | axPath 단독 대신 parentID/childrenIDs와 spatial fallback으로 clickable candidate를 승격한다. |
| Intent routing(TICKET-016) | Done | labels/elements scope를 session에 통합하고 기존 label click, second confirm, axFocus 경로를 유지한다. |
| Window search/activation(TICKET-017) | Done | WindowSearchIndex와 frontmost polling 기반 WindowActivator를 추가했다. |
| Windows scope polish(TICKET-018) | Done | `;` primer, windows activation/rescan, scope color와 label opacity를 반영했다. |
| Evaluation/docs/verify(TICKET-019) | Done | query 평가 스크립트, 런치 옵션, README/plans/verify 통합을 추가했다. |

## 다음 권장 순서

1. `scripts/evaluate_query_overlay.sh`로 E1~E5/W1~W5를 반복 실행해 앱별 실패 패턴을 누적한다.
2. 검색 0건 앱은 AX Inspector로 title/value/help/description 노출 상태를 확인한다.
3. scanner와 searchable collector를 단일 walk/scan bundle로 합치는 구조 개선을 별도 티켓으로 분리한다.
4. fuzzy/초성/동의어/결과 리스트는 기본 query 경로 안정화 이후 Post-v1로 진행한다.

@author suho.do
@since 2026-07-09
