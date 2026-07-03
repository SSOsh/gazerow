# GazeRow Post-MVP App Evaluation v1

## 변경 이력
- v1: Slack/Notion 등 Post-MVP 앱 확대 검증을 위한 재사용 실행 스크립트와 작업 목록을 정의.

## 1. 상태

현재 상태: `SLACK_LIMITED_NOTION_PASS`

TICKET-010/TICKET-011 local MVP freeze 기준 앱 5개는 모두 pass했다. Post-MVP에서는 Slack, Notion 등 추가 앱의 overlay label coverage와 click action 실행 가능성을 같은 기준으로 수집한다.

## 2. 작업 목록

### Phase 1: 평가 실행 도구
- [x] 1.1 bundle id 기반 overlay activation 스크립트 추가
- [x] 1.2 optional label click 실행 옵션 추가
- [x] 1.3 timeout, label map 출력 on/off, 실패 exit code 처리
- [x] 1.4 Finder overlay smoke로 스크립트 동작 검증
- [x] 1.5 Finder label click smoke로 click result 검증

### Phase 2: 문서화
- [x] 2.1 README 실행 예시에 평가 스크립트 추가
- [x] 2.2 Post-MVP 평가 계획 문서 작성

### Phase 3: 앱별 평가
- [x] 3.1 Slack overlay label map smoke
- [!] 3.2 Slack representative click task
  - issue: 현재 smoke에서 window-control `AXButton` 후보 3개만 수집되어 대표 앱 UI click task를 안전하게 정할 수 없음.
- [x] 3.3 Notion overlay label map smoke
- [x] 3.4 Notion representative click task
- [x] 3.5 App Support Tier 갱신

## 3. 평가 명령

Overlay visibility/candidate smoke:

```bash
scripts/evaluate_overlay_target.sh --bundle-id <bundle-id>
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
| Slack | `scripts/evaluate_overlay_target.sh --bundle-id com.tinyspeck.slackmacgap --timeout 8` | limited, 3 labels, window-control candidates only |
| Notion | `scripts/evaluate_overlay_target.sh --bundle-id notion.id --timeout 8` | pass, 57 labels |
| Notion | `scripts/evaluate_overlay_target.sh --bundle-id notion.id --click-label AY --timeout 8 --no-label-map` | pass, `AXPress`, safeNavigation, fallback=false |

## 4. 판정 기준

| 항목 | Pass 기준 |
| --- | --- |
| overlay activation | `GAZEROW_OVERLAY_RESULT success labels=N` 출력 |
| representative click | `GAZEROW_OVERLAY_CLICK_RESULT success ... fallback=false` 출력 |
| safety | coordinate fallback 기본 off 유지, critical misclick 0 |
| 미설치 앱 | 평가 불가로 기록하고 등급은 `Unverified` 유지 |

## 5. 다음 작업

Slack은 Limited, Notion은 Evaluation pass로 반영했다. 다음 앱 확대 검증은 Discord(`com.hnc.Discord`) 또는 Obsidian 설치 여부를 확인한 뒤 같은 스크립트로 진행한다.

---

@author suho.do
@since 2026-07-03
