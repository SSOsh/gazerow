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
| 3 | 클릭은 AXPress에 의존하며, click action이 없는 요소는 동작하지 않을 수 있다 | 좌표 클릭 대신 AX 액션 우선 |
| 4 | 좌표 클릭 fallback은 기본 off이며 debug에서만 활성화 가능 | 오클릭(mis-click) 위험 최소화 |
| 5 | 모든 클릭은 명시적 키보드 확인이 필요하며 자동 클릭은 없다 | 사용자 통제 우선(SD-006 kill switch 계열 원칙) |
| 6 | gaze/카메라 기능은 Post-MVP이며 이 빌드에서 비활성 | Baseline MVP 범위 분리 |
| 7 | Finder sidebar row는 candidate 수집 확인 후 fixed task 재평가가 필요하다 | TICKET-010 실제 click task에서 sidebar item task fail 후 label map 63개로 증가, `AXOpen` 실행 지원 추가 |
| 8 | VS Code Activity Bar item은 candidate 수집 확인 후 fixed task 재평가가 필요하다 | TICKET-010 실제 click task에서 Activity Bar 이동 task fail 후 label map 29개, Activity Bar `AXRadioButton` 후보 수집 확인 |

## 3. Click Safety (좌표 클릭 fallback)

좌표 기반 클릭 fallback(`CGEventPost`)은 오클릭 위험을 줄이기 위해
**기본 비활성**이다. 클릭은 accessibility의 **AXPress action**을 사용한다.

- kill switch(Session Disable)로 overlay 활성화를 즉시 중단할 수 있다
  (메뉴바 · Settings 양쪽에서 토글).

## 4. App Support Tiers (앱 지원 등급)

TICKET-010 실제 click task 결과 기준이며, 30분 crash-free session과 내부 사용자 평가 전까지는 provisional 상태다.

| 앱 | 등급 |
| --- | --- |
| Finder | Limited: sidebar row candidate 수집 확인, fixed task 재평가 필요 |
| Safari | Evaluation pass |
| Chrome | Evaluation pass |
| VS Code | Limited: Activity Bar candidate 수집 확인, fixed task 재평가 필요 |
| System Settings | Evaluation pass |
| Limited apps | Finder, VS Code |
| Slack | Unverified |
| Notion | Unverified |

- **Evaluation target**: MVP 기준 앱으로 TICKET-010에서 검증 대상.
- **Supported**: TICKET-010에서 task 성공이 확인된 앱.
- **Limited**: 동작하지만 후보/클릭에 제약이 있는 앱.
- **Unverified**: 아직 검증하지 않은 앱.

## 5. 표시 경로

| 콘텐츠 | 노출 위치 |
| --- | --- |
| Non-Medical Disclaimer | Onboarding 시트 |
| Setup steps | Onboarding 시트 |
| Known Limitations / Click Safety / App Support | Settings → **Known Limitations…** 시트 |

---

@author suho.do
@since 2026-07-02
