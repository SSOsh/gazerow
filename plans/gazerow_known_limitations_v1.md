# GazeRow — Known Limitations & Support Scope (v1)

> TICKET-009 산출물. 사용자 노출 문구의 단일 출처는 `AppContent.swift`이며,
> 이 문서는 그 내용을 문서화하고 배경/근거를 함께 정리한다.

## 1. 포지셔닝 (Non-Medical Disclaimer)

GazeRow는 키보드 중심 사용자를 위한 **생산성 유틸리티**다.
접근성/보조공학(assistive-technology) 제품이 아니며, 의료·안전이 중요한
용도(medical or safety-critical use)를 의도하지 않는다.

- 이 문구는 첫 실행 Onboarding 시트 하단에 노출된다.
- gaze/카메라 기능은 Post-MVP experimental로 분리되어 이 빌드에서는 비활성.

## 2. Known Limitations (알려진 제한)

| # | 제한 | 배경 |
| --- | --- | --- |
| 1 | 최전면(frontmost) 앱의 focused window만 스캔한다 | 스캔 범위를 좁혀 오탐/성능 문제를 줄이기 위함 |
| 2 | 일부 앱은 accessibility tree가 불완전해 후보가 누락될 수 있다 | AX API가 노출하는 정보에 의존 |
| 3 | 클릭은 `AXPress`, `AXConfirm`, `AXOpen`, `AXShowDefaultUI` 같은 접근성 action에 의존하며, 지원 action이 없는 요소는 동작하지 않을 수 있다 | 좌표 클릭 대신 AX 액션 우선 |
| 4 | 좌표 클릭 fallback은 기본 off이며 debug에서만 활성화 가능 | 오클릭(mis-click) 위험 최소화 |
| 5 | 모든 클릭은 명시적 키보드 확인이 필요하며 자동 클릭은 없다 | 사용자 통제 우선(SD-006 kill switch 계열 원칙) |
| 6 | gaze/카메라 기능은 Post-MVP이며 이 빌드에서 비활성 | Baseline MVP 범위 분리 |
| 7 | Discord는 expanded AX child scanning 이후 앱 UI 후보가 수집되지만 현재 화면 기준 대표 click task 검증이 남아 있다 | 대표 click task pass 전까지 Limited 유지 |
| 8 | Query Overlay element 검색은 AX tree에 노출된 title/value/help/description/role 기반이다 | 앱이 의미 텍스트를 비워두면 검색 0건이 가능 |
| 9 | Query Overlay window scope는 실행 중인 regular app/window만 검색한다 | AX window title이 비어 있거나 앱 activation이 제한되면 전환 실패 가능 |
| 10 | Query Overlay v1은 fuzzy, 초성, 동의어, 결과 리스트를 제공하지 않는다 | 정확/부분 문자열 기반 v1을 먼저 안정화 |

## 3. Click Safety (좌표 클릭 fallback)

좌표 기반 클릭 fallback(`CGEventPost`)은 오클릭 위험을 줄이기 위해
**기본 비활성**이다. 클릭은 accessibility의 **AX action**을 사용한다.

- kill switch(Session Disable)로 overlay 활성화를 즉시 중단할 수 있다
  (메뉴바 · Settings 양쪽에서 토글).

## 4. App Support Tiers (앱 지원 등급)

TICKET-010 실제 click task와 Finder/VS Code fixed task 재평가 결과 기준이다.

| 앱 | 등급 |
| --- | --- |
| Finder | Evaluation pass |
| Safari | Evaluation pass |
| Chrome | Evaluation pass |
| VS Code | Evaluation pass |
| System Settings | Evaluation pass |
| Slack | Evaluation pass |
| Notion | Evaluation pass |
| Discord | Limited: app UI candidates collected; representative click pending |
| Obsidian | Unverified |

- **Evaluation target**: MVP 기준 앱으로 TICKET-010에서 검증 대상.
- **Supported**: TICKET-010에서 task 성공이 확인된 앱.
- **Limited**: 동작하지만 후보/클릭에 제약이 있는 앱.
- **Unsupported**: 평가했지만 현재 후보 수집 또는 대표 task 수행이 불가능한 앱.
- **Unverified**: 아직 검증하지 않은 앱.

## 5. 표시 경로

| 콘텐츠 | 노출 위치 |
| --- | --- |
| Non-Medical Disclaimer | Onboarding 시트 |
| Setup steps | Onboarding 시트 |
| Known Limitations / Click Safety / App Support | Settings → **Known Limitations…** 시트 |

## 6. Query Overlay 추가 제한

Query Overlay는 기존 label overlay 위에 얹힌 보조 입력 경로다. `/`는 element 검색,
`;`는 windows 검색 scope를 고정하며, bare letter는 기존 label 입력을 우선한다.

- Element 검색 결과는 현재 focused window에서 스캔된 AX node와 clickable candidate의
  관계에 의존한다.
- 검색된 node가 직접 클릭 가능하지 않으면 parent/child/spatial promotion으로 가장
  가까운 actionable candidate를 선택한다.
- Window 검색은 앱/창 전환 뒤 frontmost polling을 수행하지만, macOS나 대상 앱이
  activation을 거부하면 실패할 수 있다.
- 앱별 AX 노출 품질 차이 때문에 같은 UI라도 검색어 match 수가 앱/버전에 따라 다를 수 있다.

---

@author suho.do
@since 2026-07-02
