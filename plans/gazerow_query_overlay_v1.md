# gazerow Query Overlay v1

## 변경 이력

- v1: TICKET-012~019 구현 결과와 평가 경로를 저장소 문서로 정리.

## 1. 구현 요약

Query Overlay v1은 기존 label overlay를 유지하면서 검색 기반 focus/activation을
추가한 기능이다.

| 티켓 | 상태 | 요약 |
| --- | --- | --- |
| TICKET-012 | Done | `QueryScope`, `OverlayInteractionStatus`, 2줄 status UI, AppContent 문자열/테스트 |
| TICKET-013 | Done | Query keyboard command, `/` elements primer, `;` windows primer, label-first 정책 |
| TICKET-014 | Done | AX searchable node collector와 `ElementSearchIndex` 연결 |
| TICKET-015 | Done | `ActionablePromoter` parent/children/spatial promotion |
| TICKET-016 | Done | `IntentRouter`와 labels/elements session 통합 |
| TICKET-017 | Done | `WindowSearchIndex`, `WindowActivator`, frontmost polling |
| TICKET-018 | Done | windows scope routing, activation/rescan, label opacity/scope color polish |
| TICKET-019 | Done | 평가 스크립트, 런치 옵션, README/plans/verify 갱신 |

## 2. 사용자 입력 정책

| 입력 | 동작 |
| --- | --- |
| bare letter | 기존 label 입력 우선 |
| `/` | elements scope 고정 |
| `;` | windows scope 고정 |
| printable query | 고정 scope 또는 non-label query에 append |
| `Tab` / `Shift+Tab` | 현재 query scope match 순환 |
| `Return` | elements는 focused candidate click, windows는 selected window activation |
| `Delete` | query buffer 한 글자 삭제 또는 label buffer clear |

## 3. 평가 경로

```bash
# Element search
scripts/evaluate_query_overlay.sh \
  --target-bundle-id com.microsoft.VSCode \
  --query explorer \
  --expect-scope elements

# Window switch
scripts/evaluate_query_overlay.sh \
  --window-query code \
  --expect-app com.microsoft.VSCode
```

앱은 평가용 런치 옵션으로 `--query-type-text`, `--query-text`,
`--query-scope-pin`, `--perform-query-confirm`을 지원한다. stdout에는
`GAZEROW_QUERY_RESULT scope=<scope> matches=<count> focus=<name> success=<bool>`를 출력한다.

## 4. 평가 요약

상세 기록은 `plans/gazerow_query_overlay_eval_v1.md`에 누적한다.

## 5. 후속 후보

- 앱별 AX 노출 품질표와 검색 weight 보정
- fuzzy/초성/동의어 검색
- 검색 결과 리스트 UI
- scanner와 searchable collector의 단일 walk 구조화

---

@author suho.do
@since 2026-07-09
