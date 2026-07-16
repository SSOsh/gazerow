# gazerow MVP Plan v2

## 변경 이력
- v2: v1 대비 AI-DLC 관점을 추가. 제품 MVP를 단순 구현 목록이 아니라 문제정의, 데이터 수집, 모델/휴리스틱 선택, 평가셋, 안전 게이트, 피드백 루프, 배포 전 의사결정 기준까지 포함하는 개발 생명주기로 재구성.
- v1: 최초 작성. macOS에서 Homerow 스타일 키보드 클릭 지원과 gaze 기반 창 선택을 결합하는 MVP 범위, 필요 툴, 권한, 구현 순서, 검증 기준을 정의.

## 1. AI-DLC 관점의 목표

gazerow는 일반 macOS 유틸리티이면서 동시에 AI/ML 성격이 들어가는 제품이다. 핵심 AI 성격은 다음 두 가지다.

1. 사용자의 카메라 입력에서 gaze 또는 attention region을 추정한다.
2. macOS Accessibility tree, 화면 좌표, 사용자 입력 이력을 바탕으로 사용자가 의도한 클릭 후보를 ranking한다.

따라서 MVP는 단순히 기능을 구현하는 것으로 끝내면 안 된다. 아래 질문에 답할 수 있어야 한다.

- 이 기능이 실제로 마우스 사용량을 줄이는가?
- gaze가 active window보다 target 선택을 더 잘하는가?
- 잘못된 클릭을 얼마나 자주 유발하는가?
- 어떤 앱에서 Accessibility tree가 충분하고, 어떤 앱에서 부족한가?
- 모델 또는 휴리스틱 개선을 위해 어떤 데이터를 로컬에서 수집해야 하는가?
- 개인정보와 카메라 데이터는 어떻게 다루어야 하는가?

MVP의 최종 산출물은 앱 하나가 아니라 다음 세트다.

- 로컬 실행 가능한 macOS 앱
- 앱별 지원성 평가표
- gaze/target/focus 정확도 측정 결과
- 안전장치가 포함된 interaction design
- 다음 단계로 AI를 넣을지 말지 결정할 수 있는 근거

## 2. AI-DLC 단계 요약

| 단계 | 질문 | 산출물 |
| --- | --- | --- |
| 0. Problem Framing | 어떤 사용자 문제를 푸는가 | 사용자 시나리오, 성공 지표 |
| 1. Baseline | AI 없이도 쓸모 있는가 | Homerow-lite baseline |
| 2. Instrumentation | 무엇을 측정할 것인가 | 로컬 이벤트 로그 schema |
| 3. Data Readiness | 어떤 데이터가 필요한가 | 앱별 AX snapshot, interaction trace |
| 4. Heuristic MVP | 모델 없이 어디까지 가능한가 | active window + AX ranking |
| 5. Gaze Spike | gaze가 target 선택에 도움 되는가 | calibration 결과, 정확도 리포트 |
| 6. Ranking | 어떤 요소가 먼저 focus되어야 하는가 | candidate ranking function |
| 7. Evaluation | 개선을 어떻게 판정할 것인가 | offline/online 평가셋 |
| 8. Safety | 오클릭을 어떻게 막을 것인가 | confirm-first UX, kill switch |
| 9. Privacy | 카메라/화면/AX 데이터를 어떻게 보호할 것인가 | local-only 정책 |
| 10. Release Gate | 공개 배포할 수준인가 | go/no-go checklist |

## 3. 문제 정의

### 사용자 문제

사용자는 마우스나 트랙패드로 화면의 작은 UI 요소를 반복적으로 클릭해야 한다. 키보드 중심 사용자는 이 맥락 전환을 불편하게 느낀다. 기존 단축키는 앱마다 다르고 외우기 어렵다.

### 제안 해결책

화면 위의 클릭 가능한 UI 요소를 자동으로 찾아 label을 붙이고, 사용자가 키보드로 focus와 click을 수행하게 한다. gaze는 사용자가 현재 의도하는 창 또는 영역을 추정해서 후보를 줄이는 데 사용한다.

### 핵심 가설

- H1: Accessibility tree만으로도 주요 앱에서 충분한 clickable 후보를 수집할 수 있다.
- H2: label overlay + keyboard focus는 마우스 이동보다 빠른 클릭 경로를 제공한다.
- H3: gaze 기반 window targeting은 active window 방식보다 멀티윈도우 상황에서 target 선택 실패를 줄인다.
- H4: gaze를 직접 클릭에 쓰지 않고 focus priority에만 쓰면 오클릭 리스크를 낮출 수 있다.
- H5: 앱별 예외 처리는 필요하지만, 초기 5개 앱에서는 공통 scanner로 MVP가 가능하다.

## 4. 성공 지표

### 기능 성공 지표

| 지표 | MVP 기준 | 측정 방법 |
| --- | --- | --- |
| Overlay activation success | 95% 이상 | 단축키 입력 대비 overlay 표시율 |
| Candidate extraction success | 테스트 앱 5개 중 3개 이상 | 수동 테스트 매트릭스 |
| Click success | 후보 클릭 중 80% 이상 | 클릭 후 UI 변화 또는 사용자 판정 |
| Focus navigation success | 95% 이상 | Tab/label 입력 처리 로그 |
| Crash-free manual session | 30분 이상 | 수동 사용 |

### AI/gaze 성공 지표

| 지표 | MVP 기준 | 측정 방법 |
| --- | --- | --- |
| Gaze region accuracy | 9개 영역 중 top-1 60% 이상 | calibration 후 scripted test |
| Window targeting accuracy | 2개 창 배치에서 70% 이상 | 사용자가 바라본 창과 선택 창 비교 |
| Initial focus improvement | active-window baseline 대비 개선 | 첫 focus가 의도 요소 근처인지 비교 |
| False click rate | 0에 가깝게 유지 | 클릭은 keyboard confirm으로만 실행 |

### 제품성 지표

| 지표 | MVP 기준 | 측정 방법 |
| --- | --- | --- |
| Time-to-click | 반복 작업에서 mouse 대비 체감 개선 | 간단한 task timing |
| User correction count | 클릭 1회당 focus 이동 3회 이하 | 로그 |
| Permission setup completion | 로컬 개발자 기준 성공 | 수동 체크 |
| Learnability | 5분 안에 기본 흐름 사용 | 자기 테스트 |

## 5. 범위 재정의

### AI-DLC 관점의 MVP

MVP는 두 층으로 나눈다.

Baseline MVP:

- AI/gaze 없이 동작하는 Homerow-lite
- active focused window 기반
- AX scanner
- overlay labels
- focus navigation
- keyboard-confirmed click

AI MVP:

- camera-based gaze spike
- 9-point calibration
- gaze region estimation
- gaze window targeting
- gaze-prioritized initial focus
- 모든 gaze 데이터는 로컬 volatile memory에서만 처리

첫 번째 릴리즈 가능성은 Baseline MVP 기준으로 판단한다. AI MVP는 기능 플래그로 분리한다.

### MVP에서 일부러 하지 않는 것

- gaze만 보고 자동 클릭
- 카메라 프레임 저장
- 화면 녹화 데이터 저장
- 외부 서버 전송
- LLM API 호출
- 사용자별 모델 학습 자동화
- 앱스토어 배포
- 결제/라이선스

## 6. 필요한 툴

### 개발 툴

| 도구 | 필수 여부 | 용도 | 설치/비용 |
| --- | --- | --- | --- |
| Xcode | 필수 | Swift, SwiftUI, AppKit 개발 | 무료 |
| Xcode Command Line Tools | 필수 | git, swift CLI, 빌드 도구 | 무료 |
| Accessibility Inspector | 필수 | AX tree 검사 | Xcode 추가 도구 |
| SF Symbols | 선택 | 설정 UI/icon | 무료 |
| Karabiner-Elements | 선택 | Hyper key 테스트 | 무료 |
| QuickTime Player | 선택 | 사용성 녹화 | macOS 기본 |

### 관측/평가 툴

| 도구 | 필수 여부 | 용도 | 비고 |
| --- | --- | --- | --- |
| OSLog Console | 필수 | 앱 로그 확인 | macOS Console.app |
| Instruments | 선택 | 성능/메모리 측정 | Xcode 포함 |
| Accessibility Inspector | 필수 | 앱별 후보 누락 분석 | Xcode 포함 |
| Numbers/CSV | 선택 | 수동 평가 결과 정리 | CSV면 충분 |

### 나중에 고려할 툴

| 도구 | 쓰는 시점 | 이유 |
| --- | --- | --- |
| Create ML | gaze 모델 개선 | 로컬 모델 학습 실험 |
| Core ML Tools | 모델 변환 | 외부 모델을 Core ML로 변환할 때 |
| Sparkle | 외부 배포 업데이트 | notarization 이후 |
| Sentry/Telemetry | 공개 배포 이후 | MVP에서는 개인정보 리스크 때문에 제외 |

## 7. 권한과 개인정보 설계

### 권한

| 권한 | Baseline MVP | AI MVP | 목적 |
| --- | --- | --- | --- |
| Accessibility | 필요 | 필요 | AX tree 조회, AXPress |
| Input Monitoring | 가능하면 지연 | 가능하면 지연 | overlay 중 키 입력 감지 |
| Camera | 불필요 | 필요 | gaze 추정 |
| Screen Recording | 제외 | 제외 | screenshot fallback 전까지 사용하지 않음 |

### 개인정보 원칙

- 카메라 프레임은 저장하지 않는다.
- 카메라 프레임은 외부 전송하지 않는다.
- AX tree snapshot은 기본 저장하지 않는다.
- debug export는 사용자가 명시적으로 누른 경우에만 저장한다.
- debug export에는 앱 이름, role, frame, action 정도만 포함하고 텍스트 값은 마스킹 옵션을 둔다.
- gaze calibration 값은 로컬 UserDefaults 또는 파일에 저장하되 삭제 버튼을 제공한다.

### 로컬 로그 등급

| 등급 | 내용 | 기본 저장 |
| --- | --- | --- |
| Info | 권한 상태, overlay open/close | 가능 |
| Interaction | focus 이동, click attempt | 가능 |
| AX Debug | role/title/frame/actions | 기본 비활성 |
| Camera Debug | landmark/gaze 좌표 | 기본 비활성 |
| Raw Camera | 이미지 프레임 | 저장 금지 |

## 8. 데이터 설계

### 로컬 이벤트 로그

MVP에서 최소한 다음 이벤트를 기록한다.

```text
overlay_opened
  timestamp
  app_bundle_id
  app_name
  window_title_hash
  target_source
  candidate_count
  scan_duration_ms

focus_changed
  timestamp
  from_index
  to_index
  method

label_jump
  timestamp
  typed_label
  matched

click_attempted
  timestamp
  element_role
  action_method
  fallback_used

click_completed
  timestamp
  success_user_marked
```

`window_title_hash`는 원문 제목 저장을 피하기 위해 hash로 둔다.

### AX Snapshot Debug Schema

문제 분석용 export는 수동 버튼으로만 만든다.

```json
{
  "app": "Finder",
  "bundleIdentifier": "com.apple.finder",
  "windowFrame": {"x": 0, "y": 0, "w": 1200, "h": 800},
  "elements": [
    {
      "role": "AXButton",
      "subrole": null,
      "titleMasked": true,
      "frame": {"x": 20, "y": 50, "w": 32, "h": 32},
      "actions": ["AXPress"]
    }
  ]
}
```

### Gaze Evaluation Data

저장해도 되는 값:

- calibration point id
- predicted region id
- confidence
- timestamp
- face detection success/failure
- landmark quality score

저장하지 않을 값:

- raw camera frame
- eye crop image
- 얼굴 이미지

## 9. Baseline Architecture

```text
ShortcutManager
  -> OverlaySessionController
    -> TargetResolver
      -> AccessibilityScanner
        -> ClickableElement[]
    -> LabelGenerator
    -> FocusEngine
    -> OverlayWindowController
    -> ClickExecutor
```

### 핵심 모듈

| 모듈 | 책임 | AI-DLC 관점의 계측 |
| --- | --- | --- |
| ShortcutManager | global hotkey | activation success/failure |
| TargetResolver | active/gaze window 결정 | target_source, fallback reason |
| AccessibilityScanner | AX tree traversal | scan duration, node count, candidate count |
| CandidateFilter | clickable 후보 필터 | filtered reason |
| Ranker | focus 순서 결정 | score breakdown |
| OverlayWindowController | label 표시 | render latency |
| FocusEngine | keyboard focus | correction count |
| ClickExecutor | AXPress/CGEventPost | fallback_used, click method |
| GazeTracker | gaze 추정 | region accuracy, confidence |

## 10. Ranking 설계

MVP에서는 ML 모델을 바로 쓰지 않고 score-based heuristic으로 시작한다.

### Baseline Ranking Score

```text
score =
  roleWeight
  + actionWeight
  + visibilityWeight
  + sizePenalty
  + distanceFromWindowCenterPenalty
  + readingOrderWeight
```

### Gaze Ranking Score

```text
score =
  baselineScore
  + gazeDistanceWeight
  + gazeRegionBonus
  + recentUserCorrectionPenalty
```

### Score 설명 가능성

debug mode에서 각 후보에 대해 다음 값을 볼 수 있어야 한다.

- role
- actions
- frame
- baseline score
- gaze distance
- final rank

이 정보가 있어야 나중에 ML로 바꿀 가치가 있는지 판단할 수 있다.

## 11. Evaluation Plan

### Offline Evaluation

앱을 켜지 않고 저장된 AX snapshot만으로 평가한다.

평가 항목:

- candidate recall: 사용자가 클릭 가능하다고 보는 요소가 후보에 포함되는가
- candidate precision: label이 불필요한 장식 요소에 붙지 않는가
- ranking quality: 자주 클릭할 요소가 상위에 오는가
- label collision count: label이 겹치는가

초기에는 수동 golden set으로 충분하다.

```text
fixtures/
  finder_home.json
  safari_toolbar.json
  chrome_toolbar.json
  vscode_sidebar.json
  system_settings_general.json
```

### Online Manual Evaluation

실제 앱에서 정해진 task를 수행한다.

| 앱 | Task | 성공 기준 |
| --- | --- | --- |
| Finder | sidebar item 클릭 | label 표시 후 Enter로 이동 |
| Safari | toolbar button 클릭 | AXPress 또는 fallback 성공 |
| Chrome | 주소창 focus | 텍스트 입력 가능 상태 |
| VS Code | Activity Bar 이동 | target view 전환 |
| System Settings | toggle 또는 button 클릭 | 상태 변화 |

### Gaze Evaluation

9-point calibration 후 다음 평가를 수행한다.

| 테스트 | 기준 |
| --- | --- |
| 9-region classification | top-1 60% 이상 |
| 2-window selection | 70% 이상 |
| gaze drift | 30초 동안 같은 영역 유지 시 큰 이탈 없음 |
| lighting variation | 밝음/어두움에서 failure reason 기록 |

## 12. Safety Design

### 클릭 안전장치

- gaze-only click 금지
- click은 명시적 key confirm 필요
- overlay가 열렸을 때만 click key를 처리
- overlay 밖 일반 키 입력은 가능하면 건드리지 않음
- Esc는 항상 종료
- click fallback은 debug option으로 끌 수 있게 함
- password field나 secure field는 기본 후보에서 제외

### 위험 요소 필터

기본적으로 아래 요소는 label 표시를 보수적으로 처리한다.

- delete
- remove
- clear
- reset
- purchase
- pay
- send
- submit
- confirm
- sign out

MVP에서는 텍스트 의미 분석을 과하게 하지 않고, title/description에 위 키워드가 있으면 warning style 또는 second confirm을 요구한다.

### 오클릭 복구

- 마지막 클릭 요소 정보 표시
- click history 최근 10개 로컬 저장
- undo는 앱마다 다르므로 자동화하지 않음
- 사용자가 Command-Z를 누르기 쉽게 overlay 종료 후 focus를 앱에 돌려줌

## 13. AI 기능 플래그

AI/gaze 기능은 처음부터 분리한다.

| 플래그 | 기본값 | 설명 |
| --- | --- | --- |
| enableGazeTracking | off | 카메라 기반 gaze 추정 |
| enableGazeWindowTargeting | off | gaze 좌표로 창 선택 |
| enableGazeInitialFocus | off | gaze 주변 후보 initial focus |
| enableAXSnapshotExport | off | debug용 AX snapshot export |
| enableClickFallback | on | AXPress 실패 시 CGEventPost |
| enableDangerConfirm | on | 위험 키워드 요소 second confirm |

## 14. 구현 순서 상세

### Sprint 0. 의사결정과 환경

산출물:

- 앱 이름
- 저장소 위치
- 기본 단축키
- 테스트 앱 5개
- 개인정보 원칙

작업:

- Xcode 설치 확인
- Accessibility Inspector 실행 확인
- macOS 버전 기록
- 개발 브랜치 또는 폴더 생성

완료 기준:

- 빈 앱이 실행된다.
- 메뉴바 앱으로 갈지 일반 window 앱으로 갈지 결정된다.

### Sprint 1. Baseline Shell

산출물:

- 메뉴바 앱
- 설정 화면
- 권한 상태 표시
- logging foundation

작업:

- SwiftUI macOS app 생성
- AppKit lifecycle 연결
- NSStatusItem 추가
- Settings window 추가
- PermissionManager 생성
- OSLog wrapper 생성

검증:

- 앱 실행/종료
- Settings 열기
- Accessibility 권한 상태 표시

### Sprint 2. AX Target Resolver

산출물:

- frontmost app resolver
- focused window resolver
- target context debug view

작업:

- NSWorkspace frontmostApplication 조회
- AXUIElementCreateApplication 연결
- focused window attribute 조회
- frame/title 추출
- 실패 reason enum 추가

검증:

- Finder/Safari/Chrome/VS Code/System Settings에서 target app/window 표시
- window 없는 앱에서 graceful fallback

### Sprint 3. AX Scanner

산출물:

- AX traversal
- clickable candidate model
- debug candidate list

작업:

- children traversal
- role/subrole/title/value/help/frame/actions 수집
- max depth, max nodes, timeout 적용
- clickable role/action 필터
- duplicate 제거
- secure field 제외

검증:

- 5개 앱에서 candidate count 기록
- scan duration 기록
- 누락/과잉 후보 수동 메모

### Sprint 4. Overlay

산출물:

- transparent overlay
- label rendering
- focus indicator
- coordinate conversion

작업:

- borderless NSWindow/NSPanel
- screen coordinate mapping
- label generator
- collision mitigation v1
- target window boundary rendering

검증:

- label이 실제 요소 근처에 표시
- multi-window 상황에서 target window만 표시
- Esc close

### Sprint 5. Keyboard Interaction

산출물:

- global activation shortcut
- overlay key handling
- focus engine

작업:

- Command + Shift + Space 등록
- Tab/Shift-Tab 처리
- Arrow Up/Down 처리
- label typing buffer
- Return click 연결 전 dry-run

검증:

- focus 이동 로그
- label jump 성공/실패 로그
- overlay open/close 안정성

### Sprint 6. Click Execution

산출물:

- AXPress click
- CGEventPost fallback
- click result logging

작업:

- action list 확인
- AXPress 실행
- 실패 시 frame center click
- 위험 키워드 second confirm
- click 후 overlay close

검증:

- 5개 앱 task 수행
- click method별 성공률 기록
- fallback 오작동 여부 확인

### Sprint 7. Baseline Evaluation

산출물:

- 수동 평가표
- 앱별 지원성 표
- baseline go/no-go 결정

작업:

- 5개 앱 task 수행
- 후보 recall/precision 주관 평가
- time-to-click 간단 측정
- crash/freeze 여부 기록

완료 기준:

- 3개 앱 이상에서 기본 흐름 성공
- click 오작동이 치명적이지 않음
- 다음 단계 gaze spike로 넘어갈 가치가 있음

### Sprint 8. Gaze Spike

산출물:

- camera permission
- face/eye landmark debug overlay
- 9-point calibration
- gaze region classifier

작업:

- AVCaptureSession 구성
- Vision face landmark 처리
- calibration point UI
- feature extraction
- simple regression 또는 nearest-region mapping
- confidence/failure reason 기록

검증:

- 9-region top-1 accuracy
- 2-window selection accuracy
- 조명/안경/얼굴 각도 failure 기록

### Sprint 9. Gaze Integration

산출물:

- gaze target resolver
- gaze-prioritized ranker
- fallback policy

작업:

- 안정 gaze point smoothing
- gaze point 아래 window hit test
- target_source에 gazeWindow 추가
- gaze confidence 낮으면 active window fallback
- initial focus에 gaze distance 반영

검증:

- 나란히 배치한 두 창 중 바라본 창 선택
- gaze 실패 시 active window fallback
- initial focus correction count 감소 여부 확인

### Sprint 10. MVP Freeze

산출물:

- MVP README
- known limitations
- local build/run guide
- evaluation report

작업:

- 기능 플래그 기본값 정리
- debug 기능 숨김
- 권한 안내 문구 정리
- crash-prone path 방어
- 사용성 녹화 또는 screenshot 수집

완료 기준:

- 로컬에서 반복 실행 가능
- 기본 기능은 gaze 없이도 쓸 수 있음
- gaze는 experimental로 명확히 분리

## 15. 앱별 지원성 분석 항목

각 앱은 다음 기준으로 기록한다.

```text
AppSupportReport
  appName
  bundleIdentifier
  macOSVersion
  appVersion
  candidateCount
  usefulCandidateCount
  missingImportantElements
  noisyElements
  clickSuccessRate
  fallbackRequired
  notes
```

초기 기준 앱:

- Finder
- Safari
- Chrome
- VS Code
- System Settings
- Slack 또는 Discord
- Obsidian 또는 Notion

MVP 완료 기준은 5개 중 3개지만, 데이터 수집은 7개까지 해두는 편이 좋다.

## 16. 실패 케이스 Taxonomy

나중에 개선하려면 실패를 분류해야 한다.

| 코드 | 의미 | 예시 대응 |
| --- | --- | --- |
| AX_NO_PERMISSION | Accessibility 권한 없음 | 권한 안내 |
| AX_NO_WINDOW | focused window 없음 | frontmost app fallback |
| AX_SCAN_TIMEOUT | traversal timeout | depth/node 제한 조정 |
| AX_NO_FRAME | frame 없는 요소 | 제외 또는 parent frame |
| AX_NO_ACTION | click action 없음 | coordinate fallback |
| AX_CLICK_FAILED | AXPress 실패 | CGEventPost fallback |
| OVERLAY_MISALIGNED | label 위치 오류 | coordinate conversion 수정 |
| GAZE_NO_FACE | 얼굴 미검출 | active window fallback |
| GAZE_LOW_CONFIDENCE | gaze confidence 낮음 | gaze priority 비활성 |
| TARGET_WRONG_WINDOW | 잘못된 창 선택 | smoothing/calibration 개선 |

## 17. 의사결정 게이트

### Gate A. Baseline 계속 진행 여부

조건:

- 5개 앱 중 3개 이상에서 clickable 후보가 유용하다.
- overlay 위치가 대체로 맞다.
- keyboard focus/click 흐름이 안정적이다.

통과하면:

- gaze spike 진행

실패하면:

- screenshot/vision fallback 또는 지원 앱 범위 축소 검토

### Gate B. Gaze를 MVP에 포함할지

조건:

- 2-window targeting accuracy 70% 이상
- 사용자가 체감할 정도로 initial focus correction count 감소
- 카메라 권한 UX가 감당 가능

통과하면:

- experimental feature로 포함

실패하면:

- gaze는 research branch로 분리
- MVP는 Homerow-lite로 유지

### Gate C. 공개 배포 여부

조건:

- crash-free session 2시간 이상
- 치명적 오클릭 없음
- 권한 안내 명확
- known limitations 문서화

통과하면:

- Developer Program 가입 여부 검토
- notarization/외부 배포 계획 수립

실패하면:

- 로컬 도구로 유지

## 18. 레퍼런스

| 순위 | 주제 | 레퍼런스 |
| --- | --- | --- |
| 1순위 공식 문서 | Accessibility UI 요소 접근 | https://developer.apple.com/documentation/applicationservices/axuielement |
| 1순위 공식 문서 | 클릭 이벤트 주입 | https://developer.apple.com/documentation/coregraphics/cgeventpost |
| 1순위 공식 문서 | 카메라 권한 및 캡처 | https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media |
| 1순위 공식 문서 | 얼굴/눈 landmark 탐지 | https://developer.apple.com/documentation/vision/vndetectfacelandmarksrequest |
| 3순위 프로젝트 문서 | Homerow interaction model | https://github.com/nchudleigh/homerow#user-guide |

## 19. 바로 다음에 할 일

1. Xcode 설치 상태 확인
2. 앱 저장 위치 결정
3. Baseline MVP부터 만들지, 문서/평가 harness를 먼저 만들지 결정
4. `TICKET-001: 메뉴바 앱과 권한 상태` 구현
5. `TICKET-003: AX scanner`까지 완료되면 실제 가능성이 크게 드러남
6. 그 전까지 gaze 구현은 보류

## 20. 한 줄 전략

먼저 AI 없는 keyboard-click baseline을 만들고, 충분히 쓸모 있다는 것이 확인된 뒤 gaze를 “자동 클릭”이 아니라 “target selection과 ranking 보조 신호”로만 붙인다.
