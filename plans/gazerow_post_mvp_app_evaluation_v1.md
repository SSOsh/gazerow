# gazerow Post-MVP App Evaluation v1

## 변경 이력
- v1: Slack/Notion 등 Post-MVP 앱 확대 검증을 위한 재사용 실행 스크립트와 작업 목록을 정의.
- v2: Discord 재검증 결과를 `no_candidates`에서 window-control-only Limited로 갱신하고 no-candidates 진단 stdout을 추가.
- v3: AX child attribute 스캔 확장 후 Slack 43 labels, Discord 6 labels로 갱신. Slack representative click pass, Discord는 click 검증 전까지 Limited 유지.

## 1. 상태

현재 상태: `SLACK_PASS_DISCORD_CLICK_PENDING`

TICKET-010/TICKET-011 local MVP freeze 기준 앱 5개는 모두 pass했다. Post-MVP에서는 Slack, Notion 등 추가 앱의 overlay label coverage와 click action 실행 가능성을 같은 기준으로 수집한다.

## 2. 작업 목록

### Phase 1: 평가 실행 도구
- [x] 1.1 bundle id 기반 overlay activation 스크립트 추가
- [x] 1.2 optional label click 실행 옵션 추가
- [x] 1.3 timeout, label map 출력 on/off, 실패 exit code 처리
- [x] 1.6 minimum label count assertion 옵션 추가
- [x] 1.4 Finder overlay smoke로 스크립트 동작 검증
- [x] 1.5 Finder label click smoke로 click result 검증

### Phase 2: 문서화
- [x] 2.1 README 실행 예시에 평가 스크립트 추가
- [x] 2.2 Post-MVP 평가 계획 문서 작성

### Phase 3: 앱별 평가
- [x] 3.1 Slack overlay label map smoke
- [x] 3.2 Slack representative click task
  - result: `BI` Messages tab click pass, `axPress`, risk=stateChange, fallback=false.
- [x] 3.3 Notion overlay label map smoke
- [x] 3.4 Notion representative click task
- [x] 3.5 App Support Tier 갱신
- [!] 3.6 Discord overlay label map smoke
  - issue: expanded AX child scanning 및 image candidate filtering 이후 6 labels까지 수집되지만 현재 화면이 로그인/계정 추가 상태라 대표 click task를 아직 확정하지 않음.
- [x] 3.7 Obsidian 설치 여부 확인
  - result: 현재 평가 환경에서 Obsidian 미설치.

## 3. 평가 명령

Overlay visibility/candidate smoke:

```bash
scripts/evaluate_overlay_target.sh --bundle-id <bundle-id>
scripts/evaluate_overlay_target.sh --bundle-id <bundle-id> --min-labels <COUNT>
```

Label click task:

```bash
scripts/evaluate_overlay_target.sh --bundle-id <bundle-id> --click-label <LABEL> --no-label-map
```

검증된 스크립트 smoke:

| 앱 | 명령 | 결과 |
| --- | --- | --- |
| Finder | `scripts/evaluate_overlay_target.sh --bundle-id com.apple.finder --timeout 6 --no-label-map` | pass, 84 labels |
| Finder | `scripts/evaluate_overlay_target.sh --bundle-id com.apple.finder --click-label AA --timeout 6 --no-label-map` | pass, `AXShowDefaultUI`, safeNavigation, fallback=false |
| Slack | `scripts/evaluate_overlay_target.sh --bundle-id com.tinyspeck.slackmacgap --timeout 10 --min-labels 40` | pass, 43 labels after expanded AX child scanning and image candidate filtering |
| Slack | `scripts/evaluate_overlay_target.sh --bundle-id com.tinyspeck.slackmacgap --click-label BI --timeout 10 --min-labels 40 --no-label-map` | pass, `axPress`, risk=stateChange, fallback=false |
| Notion | `scripts/evaluate_overlay_target.sh --bundle-id notion.id --timeout 8` | pass, 57 labels |
| Notion | `scripts/evaluate_overlay_target.sh --bundle-id notion.id --click-label AY --timeout 8 --no-label-map` | pass, `AXPress`, safeNavigation, fallback=false |
| Discord | `scripts/evaluate_overlay_target.sh --bundle-id com.hnc.Discord --timeout 10 --min-labels 6` | limited, 6 labels after expanded AX child scanning and image candidate filtering; representative click pending |
| Discord retry | `scripts/evaluate_overlay_target.sh --bundle-id com.hnc.Discord --timeout 10` | previous run returned `no_candidates`; current retry should be interpreted against current app state |
| Obsidian | `mdfind 'kMDItemCFBundleIdentifier == "md.obsidian"'` | unverified, not installed |

## 4. 판정 기준

| 항목 | Pass 기준 |
| --- | --- |
| overlay activation | `GAZEROW_OVERLAY_RESULT success labels=N` 출력 |
| representative click | `GAZEROW_OVERLAY_CLICK_RESULT success ... fallback=false` 출력 |
| safety | coordinate fallback 기본 off 유지, critical misclick 0 |
| 미설치 앱 | 평가 불가로 기록하고 등급은 `Unverified` 유지 |

## 5. 다음 작업

Slack은 representative click까지 pass했다. Discord는 app UI candidate 수집까지 개선됐지만 representative click 검증 전이라 Limited로 유지한다. Notion은 Evaluation pass, Obsidian은 Unverified다. 다음 작업은 Discord에서 안전한 대표 click label을 확정해 `--click-label` 평가를 실행하거나, Obsidian 설치 환경에서 같은 스크립트로 평가를 재개하는 것이다.

---

@author suho.do
@since 2026-07-03
