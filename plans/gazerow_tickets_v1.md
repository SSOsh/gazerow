# GazeRow Tickets v1

## 변경 이력
- v1: `gazerow_mvp_v5.md`를 실행 가능한 티켓 단위로 분해. Baseline MVP를 우선 구현 범위로 두고, gaze 관련 작업은 Post-MVP 후보로 분리.

## 1. 공통 원칙

- Baseline MVP는 gaze 없이 동작해야 한다.
- `CGEventPost` fallback은 기본 off다.
- 텍스트 필드는 런타임 조회만 허용하고 기본 로그/저장 대상에서 제외한다.
- Interaction 로그 파일 저장은 사용자 opt-in이다.
- 각 티켓은 완료 기준과 검증 명령 또는 수동 검증 결과를 남긴다.
- MVP는 초기 5개 앱 중 3개 이상에서 task 성공을 목표로 한다.

초기 5개 앱:

- Finder
- Safari
- Chrome
- VS Code
- System Settings

## 2. 결정 필요 항목

구현 착수 전 확정한다.

| 항목 | 결정값 | 비고 |
| --- | --- | --- |
| 앱 이름 | TBD | 메뉴바/권한 안내 문구에 사용 |
| 저장소 위치 | TBD | Swift app 생성 위치 |
| 앱 형태 | TBD | 메뉴바 앱 또는 일반 window 앱 |
| 기본 단축키 | Command + Shift + Space | 충돌 시 변경 가능해야 함 |
| 테스트 macOS 버전 | TBD | 평가표에 기록 |
| 내부 평가자 3명 | TBD | Baseline Evaluation에 필요 |

## 3. MVP 티켓

### TICKET-001: Project Shell and App Lifecycle

목표:

- SwiftUI/AppKit 기반 macOS 앱 shell을 만든다.
- 메뉴바 앱 또는 일반 window 앱 결정을 코드에 반영한다.

작업:

- Swift macOS app 생성
- AppKit lifecycle 연결
- 앱 실행/종료 동작 확인
- 기본 Settings window 뼈대 생성
- 앱 이름, bundle id, 최소 macOS 버전 기록

완료 기준:

- 앱이 로컬에서 실행된다.
- Settings window를 열 수 있다.
- 앱 종료가 정상 동작한다.

검증:

- Xcode 또는 `xcodebuild`로 build 성공
- 앱 실행/종료 수동 확인

의존성:

- 없음

### TICKET-002: Permission UX and PermissionManager

목표:

- Accessibility 권한 상태를 표시하고, 권한 안내 UX를 만든다.

작업:

- `PermissionManager` 생성
- Accessibility 권한 상태 조회
- System Settings 이동 버튼
- 권한 재확인 버튼
- 첫 실행 권한 안내 문구 작성
- Camera/Input Monitoring은 MVP에서 즉시 요청하지 않도록 분리

완료 기준:

- Accessibility 권한 허용/거부 상태가 Settings에 표시된다.
- 권한이 없을 때 overlay activation이 명확한 안내로 실패한다.
- Camera 권한은 MVP baseline 흐름에서 요청하지 않는다.

검증:

- 권한 없음 상태 수동 확인
- 권한 부여 후 상태 갱신 확인
- 권한 거부 시 앱이 crash 없이 동작하는지 확인

의존성:

- TICKET-001

### TICKET-003: Target Resolver

목표:

- 현재 target app/window를 결정한다.

작업:

- `NSWorkspace.frontmostApplication` 기반 frontmost app 조회
- `AXUIElementCreateApplication` 연결
- focused window attribute 조회
- window frame/title 런타임 조회
- 실패 reason enum 정의
- target context debug view 작성

완료 기준:

- Finder, Safari, Chrome, VS Code, System Settings에서 target app/window가 표시된다.
- window 없는 앱 또는 조회 실패에서 graceful fallback이 동작한다.
- window title 원문은 기본 로그에 저장하지 않는다.

검증:

- 5개 앱에서 target app/window 수동 확인
- 권한 없음/조회 실패 케이스 확인

의존성:

- TICKET-002

### TICKET-004: Accessibility Scanner

목표:

- target window의 clickable candidate를 수집한다.

작업:

- AX children traversal
- role/subrole/title/value/help/frame/actions 런타임 조회
- max depth, max nodes, timeout 적용
- clickable role/action 필터
- duplicate 제거
- secure field 제외
- candidate count, scan duration 기록

완료 기준:

- 5개 앱에서 candidate count와 scan duration을 얻는다.
- 텍스트 필드는 기본 로그/저장 대상에서 제외된다.
- scan timeout이 앱 freeze로 이어지지 않는다.

검증:

- 5개 앱 candidate count 기록
- scan duration 기록
- 누락/과잉 후보 수동 메모

의존성:

- TICKET-003

### TICKET-005: Overlay Window and Coordinate Mapping

목표:

- target window 위에 label overlay를 표시한다.

작업:

- borderless `NSWindow` 또는 `NSPanel` 구현
- transparent overlay 구성
- screen coordinate mapping
- target window boundary rendering
- label rendering
- collision mitigation v1
- Retina/external display 여부 기록

완료 기준:

- label이 실제 요소 근처에 표시된다.
- multi-window 상황에서 target window에만 표시된다.
- Esc로 overlay를 닫을 수 있다.
- label collision, label count, overlay occlusion을 기록할 수 있다.

검증:

- 5개 앱에서 overlay 위치 수동 확인
- Retina/external display 환경 여부 기록
- overlay open/close 반복 테스트

의존성:

- TICKET-004

### TICKET-006: Label Generation and Focus Engine

목표:

- keyboard로 candidate focus와 label jump를 수행한다.

작업:

- label generator 구현
- focus indicator 구현
- Tab/Shift-Tab 처리
- Arrow Up/Down 처리
- label typing buffer
- label jump match/miss 기록
- Return click 연결 전 dry-run

완료 기준:

- focus 이동이 candidate list 기준으로 동작한다.
- label typing으로 target candidate에 jump할 수 있다.
- focus 이동과 label jump 성공/실패가 기록된다.

검증:

- 5개 앱에서 focus 이동 수동 확인
- label jump 성공/실패 로그 확인
- overlay open/close 안정성 확인

의존성:

- TICKET-005

### TICKET-007: AXPress Click Execution and Safety

목표:

- keyboard-confirmed click을 `AXPress` 중심으로 수행한다.

작업:

- action list 확인
- `AXPress` 실행
- `AXPress` 실패 reason 기록
- `CGEventPost` fallback hook은 만들되 기본 off 유지
- action risk class 분류
- destructive/externalEffect/unknownRisk second confirm
- password/secure field 후보 제외
- click 후 overlay close

완료 기준:

- fallback off 상태에서 5개 앱 task를 수행할 수 있다.
- 치명적 오클릭 0건을 목표로 검증한다.
- 위험 class는 로그에 class만 남기고 원문 텍스트는 저장하지 않는다.

검증:

- 5개 앱 task 수동 수행
- click method별 성공률 기록
- fallback off 안전성 확인
- fallback on debug 테스트는 별도 기록

의존성:

- TICKET-006

### TICKET-008: Local Logging and Debug Export

목표:

- MVP 평가에 필요한 최소 로그와 debug export를 만든다.

작업:

- Info 로그: 권한 상태, overlay open/close
- Interaction 로그: focus 이동, click attempt, click completed
- session salt 기반 `window_title_hash`
- Interaction 파일 저장 opt-in
- AX debug export 수동 생성
- debug export 삭제 버튼
- 로그 삭제 버튼

완료 기준:

- 기본 상태에서 raw camera, raw title, text value가 저장되지 않는다.
- Interaction 파일 저장은 opt-in일 때만 가능하다.
- 사용자가 로그/export를 삭제할 수 있다.

검증:

- 기본 로그 파일 내용 확인
- opt-in 전/후 저장 동작 확인
- 삭제 버튼 수동 확인

의존성:

- TICKET-002
- TICKET-004
- TICKET-007

### TICKET-009: First-Run UX and Known Limitations

목표:

- 사용자가 권한, 지원 범위, 위험 한계를 이해할 수 있게 한다.

작업:

- 첫 실행 안내 화면
- Accessibility 권한 설명
- MVP가 접근성/의료 보조 제품이 아니라는 문구
- known limitations 작성
- fallback 좌표 클릭 기본 비활성 안내
- 지원 앱/제한 앱/미확인 앱 구분
- 메뉴바 kill switch

완료 기준:

- 첫 실행부터 첫 클릭까지 setup path가 문서화된다.
- 권한이 없어도 사용자가 다음 행동을 알 수 있다.
- 지원 한계가 README 또는 Settings에 표시된다.

검증:

- 신규 사용자 흐름 수동 확인
- 권한 거부/허용 path 확인

의존성:

- TICKET-002
- TICKET-005

### TICKET-010: Baseline Evaluation Run

목표:

- Baseline MVP go/no-go 판단에 필요한 평가를 수행한다.

작업:

- 내부 사용자 3명 평가 준비
- 5개 앱 task 수행
- mouse/trackpad baseline time 측정
- GazeRow time-to-click 측정
- correction count 기록
- abandoned attempt count 기록
- overlay readability 피드백 기록
- permission/setup friction 기록
- 앱별 지원성 표 작성

완료 기준:

- 초기 5개 앱 중 3개 이상에서 task 성공
- fallback off 상태에서 치명적 오클릭 0건
- 30분 수동 세션 crash 없음
- 내부 사용자 3명 중 2명 이상이 3분 안에 기본 흐름 이해
- 내부 사용자 3명 중 2명 이상이 계속 쓸 가치 있음으로 평가
- abandoned attempt count가 task당 1회 이하

검증:

- `gazerow_evaluation_template_v1.md` 기반 결과 기록
- go/no-go 결론 작성

의존성:

- TICKET-001부터 TICKET-009까지

### TICKET-011: MVP Freeze Package

목표:

- 로컬 MVP를 반복 실행 가능한 상태로 정리한다.

작업:

- MVP README
- local build/run guide
- known limitations 정리
- 기능 플래그 기본값 확인
- debug 기능 숨김
- privacy/log 삭제 동선 확인
- code signing/notarization 체크리스트 초안 작성

완료 기준:

- 로컬에서 반복 실행 가능하다.
- 기본 기능은 gaze 없이도 쓸 수 있다.
- gaze 코드는 비활성 또는 미포함이다.
- README에 지원 앱/제한 앱/미확인 앱이 구분되어 있다.

검증:

- clean build 확인
- README 절차대로 실행 확인
- 평가 결과와 known limitations 연결 확인

의존성:

- TICKET-010

## 4. Post-MVP 티켓 후보

### POST-001: Gaze Spike

목표:

- gaze가 active-window baseline보다 target selection에 도움이 되는지 검증한다.

작업:

- camera permission
- AVCaptureSession
- Vision face landmark
- 9-point calibration
- gaze region classifier
- confidence/failure reason 기록

완료 기준:

- 9-region top-1 accuracy 기록
- 2-window targeting 실패율이 active-window baseline 대비 감소하는지 판단
- camera permission UX가 감당 가능한지 평가

### POST-002: Gaze Ranking Integration

목표:

- gaze를 자동 클릭이 아니라 initial focus/ranking 보조 신호로만 통합한다.

작업:

- gaze smoothing
- gaze point 아래 window hit test
- gaze confidence fallback
- gaze-prioritized ranker
- correction count 비교

완료 기준:

- 동일 task에서 initial focus correction count 감소
- gaze 실패 시 active window fallback
- false click risk 증가 없음

## 5. 티켓 진행 순서

1. TICKET-001
2. TICKET-002
3. TICKET-003
4. TICKET-004
5. TICKET-005
6. TICKET-006
7. TICKET-007
8. TICKET-008
9. TICKET-009
10. TICKET-010
11. TICKET-011

TICKET-003까지 완료되면 AX 접근 가능성이 드러난다. TICKET-004까지 완료되면 MVP 가능성이 크게 드러난다. TICKET-007 전까지는 실제 클릭을 수행하지 않는다.
