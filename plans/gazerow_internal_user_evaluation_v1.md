# GazeRow Internal User Evaluation v1

## 변경 이력
- v1: TICKET-010 내부 사용자 3명 평가를 실행하기 위한 진행 절차와 기록지를 작성.
- v2: 외부 내부 사용자 3명 확보 불가로 평가를 Post-MVP로 defer(ED-008). 결과를 지어내지 않고 gate defer 상태로 기록. 평가자 확보 시 이 runbook으로 재개.

## 1. 목적

이 문서는 Post-MVP로 defer된 내부 사용자 3명 평가를 수행하기 위한 runbook이다.

이미 충족한 조건:

- 5개 앱 실제 click task: 3 pass / 2 fail
- critical misclick: 0건
- 30분 crash-free session: pass, 1800초
- known limitations/app support tier 갱신

Post-MVP 재개 시 필요한 조건:

- 내부 사용자 3명 중 2명 이상이 3분 안에 기본 흐름 이해
- 내부 사용자 3명 중 2명 이상이 계속 쓸 가치 있음으로 평가

## 2. 평가자 조건

평가자는 macOS를 일상적으로 쓰는 내부 사용자 3명으로 한다.

권장 조건:

- 키보드 단축키나 메뉴바 앱 사용에 익숙한 사용자
- Finder, Safari 또는 Chrome 사용 경험이 있는 사용자
- GazeRow 구현 내용을 직접 작성하지 않은 사용자

평가자가 3명 미만이면 이 runbook의 결과를 pass로 기록하지 않는다.

## 3. 평가 전 준비

평가 진행자는 아래 상태를 먼저 확인한다.

```bash
cd /Users/suho/Github/gazerow
git status --short --branch
scripts/verify_mvp_freeze.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run GazeRow
```

확인해야 할 UI:

- 메뉴바에 GazeRow 아이콘이 표시된다.
- 메뉴바 아이콘에서 `Show Overlay`를 실행할 수 있다.
- Settings에서 Accessibility 권한 상태가 granted로 표시된다.
- Known Limitations에서 Finder와 VS Code가 Limited로 표시된다.

## 4. 사용자에게 줄 설명

평가자는 아래 설명만 읽어준다.

```text
GazeRow는 키보드로 화면의 클릭 가능한 항목을 선택하는 macOS 메뉴바 앱입니다.
메뉴바 아이콘에서 Show Overlay를 누르면 화면 위에 label이 뜹니다.
원하는 label 문자를 입력하고 Return으로 실행합니다.
일부 위험하거나 애매한 대상은 Return을 한 번 더 요구할 수 있습니다.
테스트 중 자동 클릭은 없고, 모든 클릭은 사용자가 키보드로 확인해야 합니다.
```

평가 중 알려주면 안 되는 것:

- 어떤 앱이 pass/fail인지
- 어떤 label을 누르면 되는지
- Finder/VS Code의 known limitation을 먼저 설명하는 것

## 5. 3분 이해도 평가

각 평가자에게 아래 순서로 3분을 준다.

1. GazeRow 메뉴바 아이콘을 찾는다.
2. `Show Overlay`를 실행한다.
3. label을 보고 키보드로 focus 또는 label jump를 시도한다.
4. Return으로 confirm을 시도한다.
5. 실패하거나 막히는 지점을 말로 설명한다.

기록 기준:

- `understoodIn3Min = yes`: 3분 안에 overlay 실행, label 입력, Return confirm 개념을 설명할 수 있음
- `understoodIn3Min = no`: 3분 안에 위 흐름을 설명하지 못하거나 진행자가 핵심 조작을 대신 안내해야 함

## 6. 계속 쓸 가치 평가

3분 이해도 평가 후 아래 질문을 묻는다.

```text
현재 제한사항이 있다는 전제에서, 이 앱이 키보드 중심 작업에 계속 써볼 가치가 있습니까?
yes / no로 답하고, 이유를 한 문장으로 말해주세요.
```

기록 기준:

- `worthContinuing = yes`: 제한사항을 감안해도 다시 써볼 의사가 있음
- `worthContinuing = no`: 현재 상태에서는 다시 쓸 의사가 없음

## 7. 평가 기록지

| 평가자 | 평가 시각 | understoodIn3Min | worthContinuing | 주요 friction | 한 줄 코멘트 |
| --- | --- | --- | --- | --- | --- |
| User 1 | TBD | TBD | TBD | TBD | TBD |
| User 2 | TBD | TBD | TBD | TBD | TBD |
| User 3 | TBD | TBD | TBD | TBD | TBD |

## 8. 판정 계산

```text
understoodIn3MinYesCount:
worthContinuingYesCount:

passesUnderstandingGate: understoodIn3MinYesCount >= 2
passesValueGate: worthContinuingYesCount >= 2
```

두 gate가 모두 true이면 TICKET-010의 내부 사용자 조건은 pass다.

## 9. 결과 반영 위치

평가 후 반드시 아래 문서를 갱신한다.

- `plans/gazerow_ticket_010_result_v1.md`
  - 평가자별 요약 추가
  - Go/No-Go 판정 갱신
  - 남은 수동 작업 체크 갱신
- `plans/gazerow_mvp_freeze_package_v1.md`
  - 내부 사용자 평가 조건 체크 갱신
  - TICKET-011 최종 decision 갱신
- `README.md`
  - TICKET-010/TICKET-011 진행 상태 갱신
- `plans/gazerow_handoff_v1.md`
  - 다음 작업 갱신

## 10. 현재 상태

```text
Status: DEFERRED_POST_MVP
Reason: 외부 내부 사용자 3명을 확보하지 못했고, 평가 결과를 지어내지 않기로 함(ED-008).
Decision: local MVP freeze에서는 내부 사용자 gate를 Post-MVP로 defer한다.
Resume condition: 평가자 3명 확보 시 이 runbook의 Section 3~8 절차로 재개.
Minimum pass condition (재개 시): at least 2 yes for understoodIn3Min and at least 2 yes for worthContinuing
```

---

@author suho.do
@since 2026-07-02
