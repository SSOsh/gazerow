# GazeRow Runtime Wiring v1

## 변경 이력
- v1: TICKET-010 수동 평가 차단 해소를 위한 end-to-end overlay session wiring 작업 목록을 정의.
- v2: runtime wiring 완료 후 Accessibility 권한 precheck 차단 상태를 기록.
- v3: Settings Accessibility 권한 요청 버튼 연결과 검증 통과를 기록.
- v4: Show Overlay 권한 실패 시 권한 요청/설정 이동 경로와 검증 통과를 기록.
- v5: `--request-accessibility` 런치 옵션과 검증 통과를 기록.
- v6: target bundle launch option, target window fallback, 5개 앱 overlay activation smoke 통과를 기록.
- v7: label map 평가 옵션과 5개 앱 실제 click task 결과를 기록.
- v8: 30분 crash-free manual session 통과를 기록.

## 1. 목적

TICKET-010 수동 평가를 재시도하려면 현재 개별 구성요소로만 존재하는 target resolve, scan, overlay, focus, click 흐름을 실제 앱 런타임에 연결해야 한다.

## 2. 작업 목록

### Phase 1: Overlay Session Activation
- [x] 1.1 메뉴바 액션에서 target resolve, scan, overlay show까지 연결
- [x] 1.2 activation 실패 사유를 raw title/text 없이 로그로 기록

### Phase 2: Keyboard Focus Wiring
- [x] 2.1 overlay keyboard command를 `FocusEngine`에 연결
- [x] 2.2 focus/label jump 이벤트를 interaction log에 연결

### Phase 3: Click Execution Wiring
- [x] 3.1 focused label confirm을 `AXPress` click execution에 연결
- [x] 3.2 risky action second confirm 흐름을 runtime에 연결
- [x] 3.3 click attempt/completed 이벤트를 interaction log에 연결

### Phase 4: Evaluation Retry
- [x] 4.1 `scripts/verify_mvp_freeze.sh` 재실행
- [x] 4.2 Settings Accessibility 권한 요청 버튼 연결
- [x] 4.3 Show Overlay 권한 실패 시 Accessibility 요청/설정 이동 연결
- [x] 4.4 `--request-accessibility` 런치 옵션 연결
- [x] 4.5 `--show-overlay-on-launch --target-bundle-id` 평가 런치 옵션 연결
- [x] 4.6 target window fallback 연결
- [x] 4.7 TICKET-010 5개 앱 overlay activation smoke
- [x] 4.8 `--print-overlay-label-map` 로컬 평가 옵션 연결
- [x] 4.9 TICKET-010 5개 앱 실제 click task 재시도
  - result: Safari/Chrome/System Settings pass, Finder/VS Code fail
- [x] 4.10 TICKET-010 30분 crash-free session
- [!] 4.11 TICKET-010 내부 사용자 3명 평가
  - blocked: 앱별 click task와 30분 session은 완료됐지만 내부 사용자 3명 평가가 아직 미수행
- [x] 4.12 README, handoff, freeze package 상태 갱신

## 3. 제한

- coordinate fallback은 기본 off를 유지한다.
- Camera와 Screen Recording 권한은 요청하지 않는다.
- 원문 window title, title/value/help/description은 로그나 파일에 저장하지 않는다.
- 실제 click은 keyboard confirm 이후에만 수행한다.

---

@author suho.do
@since 2026-07-02
