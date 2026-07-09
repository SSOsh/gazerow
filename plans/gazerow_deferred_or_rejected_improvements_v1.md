# GazeRow Deferred or Rejected Improvements v1

## 목적

첨부 문서 전체를 코드와 대조한 뒤, 이번 개선 범위에서 제외한 항목을 기록한다.
제외 기준은 현재 코드 상태에서 회귀 위험이 크거나, 사전 수동 조사 없이 구현하면 오동작 가능성이 높은 경우다.

## 이번 턴에서 제외한 항목

| 항목 | 결정 | 이유 |
| --- | --- | --- |
| Query Overlay 전체 세션 통합(TICKET-012~018 일괄) | Deferred | 키보드 입력, label scope, element search, window activation이 모두 얽혀 기존 label click 경로를 크게 바꾼다. 순수 검색 코어부터 추가하고 후속 티켓에서 단계적으로 연결하는 편이 안전하다. |
| 첫 글자 label/query 충돌 정책 확정 | Deferred | `prefixFree` 상태에서 bare letter를 query로 볼지 label로 볼지 제품 UX 결정이 필요하다. 잘못 고르면 기존 파워유저 라벨 입력이 회귀한다. |
| KakaoTalk composer heuristic | Deferred | Accessibility Inspector로 실제 role/subrole/frame을 확인하지 않은 상태에서 `AXGroup`/`AXWebArea`를 후보로 승격하면 밀집 UI에서 오클릭 가능성이 높다. |
| Electron/카카오톡 scan preset 상향 | Deferred | `maxNodes=5000`, `timeout=2s`는 Slack/KakaoTalk에는 유리하지만 모든 세션에 잘못 적용되면 overlay activation latency가 악화된다. bundle id 확인과 context-aware scanner 설계 후 적용한다. |
| Window activation scope(TICKET-017~018) | Deferred | activate 후 frontmost polling 없이 고정 sleep으로 재스캔하면 이전 앱을 스캔할 수 있다. 설계 문서의 GAP-009 보강이 먼저 필요하다. |
| 메뉴바 fuzzy, 초성, 동의어, 결과 리스트 | Deferred | v1 제외/Post-v1 항목이다. Query Overlay 기본 경로가 안정화된 뒤 검색 품질 개선으로 진행한다. |
| 무료 zip 배포 스크립트 추가 | Deferred | 기능 개선보다 배포 작업에 가깝고, 현재 요청의 Query Overlay/앱 한계 개선과 직접 관련이 낮다. release packaging 단계에서 별도 검증과 함께 추가한다. |
| `AXWebArea` clickable 후보화 | Rejected for now | 웹뷰 전체를 클릭 후보로 만들면 target이 너무 커지고 의도하지 않은 클릭 위험이 높다. 앱별 inspector 결과와 2차 확인/휴리스틱이 갖춰진 뒤 재검토한다. |

## 이번 턴에서 진행한 항목

| 항목 | 상태 | 이유 |
| --- | --- | --- |
| focus 없는 confirm 실패 UI 표시 | Done | 기존 경로는 로그와 `lastClickResult`만 남기고 status/observer 갱신이 없어 사용자가 실패를 알기 어렵다. 회귀 표면이 작고 테스트로 고정 가능하다. |
| `ElementSearchIndex` 순수 검색 코어 | Done | 세션에 연결하지 않는 독립 타입이라 기존 overlay 동작을 바꾸지 않는다. TICKET-014의 scoring/filter/sort 기반을 테스트와 함께 마련한다. |

## 다음 권장 순서

1. TICKET-012 query status model/UI를 label-only 하위 호환으로 추가한다.
2. TICKET-013 keyboard command는 첫 글자 충돌 정책을 결정한 뒤 구현한다.
3. TICKET-014 collector를 추가하되 scanner와 이중 AX walk가 생기지 않도록 `OverlayScanBundle` 방향을 먼저 설계한다.
4. TICKET-015 promoter는 `axPath`보다 `parentID` 기반으로 spec을 보정한 뒤 구현한다.

@author suho.do
@since 2026-07-09
