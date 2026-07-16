# 창 이동 후 요소 라벨 표시 수정

> 작성: suho.do · 2026-07-16 · 상태: 완료

## 문제

`windows` scope에서 선택한 창을 활성화한 뒤 `elements` scope로 전환해도
새 창의 라벨이 보이지 않을 수 있다.

## 근본 원인

`WindowActivator`가 대상 앱의 bundle ID가 frontmost인지만 확인한다.
같은 앱의 다른 창으로 이동할 때는 bundle ID가 이미 일치하므로,
선택한 AX 창이 focused/main 창으로 반영되기 전 이전 창을 재스캔하는 race가 발생한다.

## 작업 목록

- [x] 선택 창 준비 상태 polling 회귀 테스트 추가
- [x] frontmost 앱과 focused/main AX 창을 함께 검증하도록 `WindowActivator` 수정
- [x] 관련 단위 테스트와 전체 테스트 통과
- [x] 커밋·push 대상 파일과 검증 결과 확정

## 완료 조건

- 같은 앱의 다른 창으로 이동해도 선택 창이 준비된 뒤에만 재스캔한다.
- AX 창 정보가 없는 앱 단위 entry는 기존 frontmost 정책을 유지한다.
- 타임아웃 시 잘못된 창을 재스캔하지 않고 활성화 실패로 처리한다.
