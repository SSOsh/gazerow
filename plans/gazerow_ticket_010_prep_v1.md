# gazerow TICKET-010 Prep v1

## 변경 이력
- v1: TICKET-010 Baseline Evaluation Run 착수 전, 평가 환경과 절차를 준비하기 위한 체크리스트를 분리.
- v2: 내부 사용자 3명 평가 runbook 준비 상태를 반영.

## 1. 목적

`TICKET-010`은 실제 앱을 실행해 5개 앱에서 수동 평가를 수행하는 티켓이다.
이 문서는 구현 티켓이 아니라 평가 실행 전에 필요한 준비 항목을 정리한다.

`TICKET-008` 완료 후 평가자가 바로 실행할 수 있도록 환경, 절차, 기록 양식을 정리한다.

## 2. TICKET-010 착수 전 필요 조건

| 조건 | 상태 | 비고 |
| --- | --- | --- |
| TICKET-001~TICKET-007 core 구현 | done | README 기준 |
| TICKET-008 Local Logging and Debug Export | done | interaction log/export core |
| TICKET-009 First-Run UX and Known Limitations | done | README 기준 |
| 평가 템플릿 | done | `gazerow_evaluation_template_v1.md` |
| 평가자 3명 확보 | TBD | ED-001, `gazerow_internal_user_evaluation_v1.md` 기준으로 실행 |
| 평가 macOS version 확정 | TBD | ED-001 checkpoint |
| Xcode toolchain 정상화 | done | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 통과 |

## 3. 평가 환경 준비

### 필수

- Xcode full app 설치
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` 성공
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` 성공
- Accessibility 권한 부여
- Finder, Safari, Chrome, VS Code, System Settings 설치/실행 가능
- coordinate fallback off 확인
- Camera/Screen Recording 권한 미요청 확인

### 권장

- Console.app에서 gazerow OSLog 확인 준비
- 평가 화면 녹화가 필요하면 개인정보 검토 후 별도 동의
- Numbers/CSV로 집계표 복사 준비

## 4. 평가 진행 순서

1. commit hash와 macOS version 기록
2. gazerow 실행
3. 첫 실행 onboarding과 권한 안내 확인
4. 5개 앱을 하나씩 열어 고정 task 수행
5. 앱마다 mouse/trackpad baseline time 측정
6. 앱마다 gazerow time-to-click 측정
7. correction count와 abandoned attempt count 기록
8. overlay collision/occlusion/readability 기록
9. click method와 fallback 필요 여부 기록
10. 30분 crash-free manual session 수행
11. go/no-go 기준에 따라 결론 작성

## 5. TICKET-008과의 접점

TICKET-010 평가 중 아래 TICKET-008 로그/export 항목을 실제 값으로 채운다.

- interaction log opt-in 여부
- focus_changed event 수
- label_jump matched/missed count
- click_attempted / click_completed count
- session salt 기반 `window_title_hash` 사용 여부
- debug export 삭제 동선 확인
- raw title/text value 저장 여부 확인

## 6. 지금 하지 않는 것

- TICKET-010 실제 go/no-go 판정
- TICKET-011 freeze package 작성
- gaze/camera 관련 평가

## 7. 완료 기준

- `gazerow_evaluation_template_v1.md`가 존재한다.
- `gazerow_internal_user_evaluation_v1.md`가 존재한다.
- 5개 앱별 고정 task가 명시되어 있다.
- go/no-go 조건이 한 문서에서 확인 가능하다.
- TICKET-008 완료 후 어떤 로그 값을 채울지 명시되어 있다.

---

@author suho.do
@since 2026-07-02
