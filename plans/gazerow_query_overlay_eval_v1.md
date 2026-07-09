# GazeRow Query Overlay Evaluation v1

## 변경 이력

- v1: Query Overlay v1 로컬 평가 기록 양식과 최초 실행 기록 추가.

## 1. 평가 방법

```bash
# Element search
scripts/evaluate_query_overlay.sh \
  --target-bundle-id <bundle-id> \
  --query <text> \
  --expect-scope elements

# Window switch
scripts/evaluate_query_overlay.sh \
  --window-query <text> \
  --expect-app <bundle-id>
```

## 2. 고정 평가 매트릭스

| ID | scope | target/query | pass 기준 | 상태 |
| --- | --- | --- | --- | --- |
| E1 | elements | VS Code / explorer | focus success | Not run |
| E2 | elements | VS Code / search | focus success | Not run |
| E3 | elements | Safari / reload | focus success | Not run |
| E4 | elements | Finder / download | focus success | Pass |
| E5 | elements | Chrome / bookmark | focus success | Not run |
| W1 | windows | code | frontmost VS Code | Not run |
| W2 | windows | safari | frontmost Safari | Not run |
| W3 | windows | chrome | frontmost Chrome | Not run |
| W4 | windows | finder | frontmost Finder | Not run |
| W5 | windows | slack | frontmost Slack if installed | Not run |

## 3. 실행 기록

### T019 Unit/Verify Gate — PASS

- date: 2026-07-09
- command: `swift test --filter 'AppLaunchOptionsTests|OverlayLaunchReporterTests|ElementSearchIndexTests|IntentRouterTests|ActionablePromoterTests|WindowSearchIndexTests'`
- result: 61 tests, 0 failures
- scope resolved: parser/reporter/elements/windows unit gate
- notes: 실제 앱별 E/W 매트릭스는 평가 환경에서 `scripts/evaluate_query_overlay.sh`로 반복 실행해 누적한다.

### E4 Finder download — PASS

- date: 2026-07-09
- command: `scripts/evaluate_query_overlay.sh --target-bundle-id com.apple.finder --query download --expect-scope elements --timeout 10`
- query: download
- scope resolved: elements
- match count: 1
- focus: `StarPlayerDownLoads`
- result: `GAZEROW_QUERY_RESULT scope=elements matches=1 match_index=1 focus=StarPlayerDownLoads success=true`
- notes: Finder target bundle launch, overlay success labels=116, query evaluation passed.

## 4. 실패 기록 양식

```markdown
## E3 Safari reload — FAIL

- date: 2026-07-XX
- query: reload
- scope resolved: elements
- match count: 0
- promotion: n/a
- ax notes: toolbar button title empty, only AXDescription
- follow-up: TICKET-020 app-specific weights
```

---

@author suho.do
@since 2026-07-09
