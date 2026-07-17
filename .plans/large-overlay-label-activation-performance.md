# 대량 Overlay 라벨 활성화 성능 개선

## 개요

- **목적**: `ZY` 수준(약 675개)의 라벨이 생성되는 화면에서 overlay 활성화가 1~2초 걸리는 문제를 단계별로 줄인다.
- **대상 사용자**: 클릭 가능한 AX 요소가 많은 웹·Electron·복합 UI 앱에서 GazeRow를 사용하는 사용자
- **작성일**: 2026-07-17
- **작성자**: suho.do
- **상태**: 완료

## 요구사항

### 필수 기능 (Must Have)

- [x] 기존 activation trace로 AX scan, layout, first display 구간을 분리해 검증한다.
- [x] AX child-like 속성 조회의 IPC 호출 수를 batch 조회로 줄이되 기존 fallback 동작을 유지한다.
- [x] 대상 창과 교차하지 않는 후보를 label/layout/render 대상에서 제외한다.
- [x] centered 배치에서 불필요한 `O(n²)` 배열 복사와 collision 검사를 제거한다.
- [x] 대량의 비선택 라벨과 target marker를 SwiftUI view subtree보다 가벼운 방식으로 렌더링한다.
- [x] 새 public/internal 함수 또는 동작 변경에는 Given-When-Then 테스트를 추가한다.
- [x] 기존 label 선택, focus, click identity 계약을 유지한다.

### 선택 기능 (Nice to Have)

- [x] 반복 활성화 성능을 위해 AXObserver 기반 cache invalidation 도입 타당성을 검토한다.
- [x] 대량 후보 성능 회귀를 감지하는 benchmark 성격의 테스트를 추가한다.

## 기술 스펙

### AX scan

- `AXUIElementCopyMultipleAttributeValues`를 사용해 child-like 속성을 한 번에 읽는다.
- batch 조회를 지원하지 않거나 전체 호출이 실패하는 앱에서는 기존 속성별 조회로 fallback한다.
- 반환된 child 배열은 기존과 동일하게 중복 제거한다.
- candidate frame은 `TargetContext.window.frame`과 교차하고 양의 크기를 가질 때만 수집한다.

### Layout

- centered 배치는 collision 회피를 수행하지 않으므로 매 iteration의 `placedLabels.map`을 생략한다.
- collision metric은 화면 공간 bucket/spatial index를 사용해 교차 가능성이 있는 기존 frame만 검사한다.
- adaptive 배치의 기존 동작과 순서는 유지한다.

### Rendering

- 초기 focus가 없는 대량 layout은 정적 marker/label을 `Canvas` 기반으로 일괄 렌더링한다.
- focus·입력에 따라 opacity나 style이 달라지는 상태에서도 표시 계약을 유지한다.
- 작은 layout은 기존 SwiftUI view 경로를 유지해 시각적 회귀 위험을 제한한다.

### 성능 검증

- 기존 OSLog phase `scanCompleted`, `layoutCompleted`, `firstDisplayPass`를 기준으로 전후를 비교한다.
- 단위 테스트에서는 675개 이상의 후보로 layout 결과와 완료 시간을 검증하되, 느린 CI 환경을 고려해 과도하게 엄격한 시간 제한은 두지 않는다.

## 작업 목록

### Phase 1: 기준선과 AX 조회

- [x] 1.1 기존 activation trace와 대량 후보 테스트 기준 확인
- [x] 1.2 AX child-like 속성 batch 조회 및 fallback 구현
- [x] 1.3 batch/fallback/중복 제거 테스트

### Phase 2: 후보 수 축소

- [x] 2.1 대상 창 밖 candidate 필터 구현
- [x] 2.2 경계 교차·창 밖·빈 frame 테스트

### Phase 3: Layout 최적화

- [x] 3.1 centered 배치의 불필요한 placed frame 복사 제거
- [x] 3.2 collision metric spatial index 구현
- [x] 3.3 대량 layout 및 adaptive 회귀 테스트

### Phase 4: Rendering 최적화

- [x] 4.1 대량 layout Canvas 렌더링 경로 구현
- [x] 4.2 focus·opacity·소규모 layout 회귀 테스트

### Phase 5: 통합 검증

- [x] 5.1 cache 개선 타당성 검토 및 필요 시 구현
  - 기존 0.5초 cache는 유지한다. AXObserver 없는 TTL 연장은 stale label 위험이 있고, 이번 first activation 병목 개선에는 영향을 주지 않아 별도 후속으로 분리한다.
- [x] 5.2 관련 테스트와 전체 테스트 실행
- [x] 5.3 기획서 완료 상태와 검증 결과 기록

### Phase 6: AX node 통합 조회

- [x] 6.1 snapshot과 children을 함께 반환하는 node inspection 계약 추가
- [x] 6.2 production AX client에서 snapshot·children 단일 batch 조회 구현
- [x] 6.3 scanner 호출 횟수 및 fallback 회귀 테스트

### Phase 7: 변경 감지 cache

- [x] 7.1 AXObserver 기반 UI 변경 감지기 구현
- [x] 7.2 observer 활성 시 cache TTL 연장 및 변경 이벤트 무효화
- [x] 7.3 observer 실패·context 전환·변경 이벤트 테스트

### Phase 8: 렌더 후속 최적화

- [x] 8.1 대량 Canvas 이중 순회와 text resolve 비용 측정
- [x] 8.2 시각적 z-order를 유지할 수 있을 때 단일 렌더 패스 적용
- [x] 8.3 대량 렌더 회귀 테스트 및 전체 성능 검증

## 검증 결과

- AX child batch/fallback 테스트: 9개 통과
- Accessibility scanner 테스트: 23개 통과
- Candidate ordering 및 layout 테스트: 30개 통과
- 대량 Canvas 전략 및 이미지 렌더 테스트: 3개 통과
- 1차 전체 테스트: 687개 통과, 실패 0개
- 2차 전체 테스트: 709개 통과, 실패 0개
- 675개 centered layout 단위 테스트: 약 8ms
- 675개 Canvas 이미지 렌더 단위 테스트: 약 109ms
- 2차 최적화 전 675개 Canvas 5회 평균: 약 77ms
- 단일 Canvas·label별 합성 layer 제거 후 5회 평균: 약 70ms
- 실제 앱 activation p50/p95는 기존 `OverlayActivationTracer`의 `scanCompleted`, `layoutCompleted`, `firstDisplayPass`로 후속 측정한다.

## 비기능 요구사항

- 사용자 입력과 클릭 대상 index 계약을 바꾸지 않는다.
- raw window title, element value 등 민감정보를 성능 로그에 추가하지 않는다.
- timeout 축소만으로 성능 개선을 완료 처리하지 않는다.
- 기존 미커밋 파일을 수정하거나 제거하지 않는다.

## 참고사항

- 현재 scan은 `@MainActor`에서 최대 4,000 node, 1.5초 timeout으로 실행된다.
- 현재 child collector는 최대 11개 child-like 속성을 요소마다 개별 AX IPC로 조회한다.
- 현재 overlay view는 label마다 marker와 text용 SwiftUI subtree를 각각 생성한다.
- 기본 label placement는 centered이며 dense adaptive 전환은 기본적으로 꺼져 있다.
