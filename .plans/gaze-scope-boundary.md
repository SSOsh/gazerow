# Gaze × Scope 선택 경계 개선 기획서

> 작성: suho.do · 2026-07-12 · 상태: 초안(분석 완료, 방향 미확정)

## 1. 배경 / 문제 정의

시선(gaze)으로 overlay를 조작할 때 `labels` / `elements` / `windows` 세 scope 중
무엇이 선택되는지에 대한 **결정 규칙과 사용자 피드백이 모호**하다.

핵심 증상:

- 시선으로 대상을 겨냥하는 순간 "지금 라벨을 고르는 중인지, 요소인지, 창인지"가 불분명하다.
- 타이핑(query)으로는 scope가 자동 전환되는데, gaze는 이 규칙을 전혀 타지 않아
  두 입력 모달리티의 scope 상태가 어긋난다.

이 문서는 **결정 규칙(scope resolution)** 관점에서 모호함의 원인을 코드 근거로 규명하고,
개선 방향을 옵션별로 정리한다. 구현 착수 전 방향 확정을 위한 기획 문서다.

## 2. 현재 아키텍처

### 2.1 두 개의 gaze 경로 — 둘 다 labels 전용

| 경로 | 진입 | 처리 | 대상 |
|------|------|------|------|
| one-shot | `AppDelegate.handleGazeCaptureResult` → `focusNearestLabel(to:)` | 단축키 1회 캡처 | labels only |
| runtime(continuous) | `GazeFocusRuntimeController.focusOverlay(point)` 클로저 | 프레임 스트림 | labels only |

두 경로 모두 최종적으로 `FocusEngine.focusNearest(to:)`로 수렴한다
(`FocusEngine.swift:125`, `OverlaySessionController.swift:262`).
`focusNearest`는 `items`(= `layout.labels`)에서만 최근접을 찾으며 **scope 파라미터가 없다.**

```
gaze point ──▶ focusNearestLabel(to:) ──▶ FocusEngine.focusNearest(to:)
                                              └─ GazeFocusController.nearestItem(in: items)   // labels only
```

- `FocusEngine`은 `layout.labels`로만 `FocusItem` 배열을 구성한다 (`FocusEngine.swift:23`).
- 근접도는 프레임 중심까지의 유클리드 거리이며, 선택 임계값
  `maximumActivationDistance`가 이미 존재한다 (`GazeFocusController.swift`).

### 2.2 query scope 결정 트리 — gaze와 분리

`IntentRouter.chooseScope(...)`가 **텍스트 buffer**만으로 scope를 판정한다
(`IntentRouter.swift:96`). 실제 평가 순서:

1. `pinnedScope`가 있으면 그대로 반환 (사용자가 `/`·`;`로 고정).
2. `isPotentialLabel`(1~2자 ASCII 문자) **그리고** label prefix 매치 존재 → `.labels`.
3. `bestSearchScope`: element/window 검색 매치 중 승자
   (`IntentRouter.swift:129`)
   - element만 매치 → `.elements`, window만 매치 → `.windows`
   - 둘 다 매치 → `lastScope == .windows`면 windows, 아니면 **score 높은 쪽**.
4. `buffer.count >= 2 || 한글 포함 || 공백 포함` → `.elements`.
5. fallback: `lastScope`(단, windows면 elements로 강등).

scope 전환 키: `/` → `pinScope(.elements)`, `;` → `pinScope(.windows)`
(`FocusKeyboardCommand.swift:78`).

### 2.3 windows scope엔 공간 좌표가 없다

`windowResolution`은 `highlightFrame = nil`, `focusTargetCandidateIndex = nil`을
반환한다 (`IntentRouter.swift:193`). 즉 windows는 화면 위 겨냥 타겟이 없다.

## 3. 결정 규칙 심층 분석 — 경계 모호의 5대 원인

### 원인 1. 1~2자 ASCII의 이중성 (label ↔ element prefix 충돌)
규칙 2가 규칙 3·4보다 우선한다. 같은 "AB" 입력이라도 **label "AB" 존재 여부에 따라**
scope가 labels ↔ elements로 홱 뒤집힌다. 사용자가 "About"을 찾으려 "AB"를 쳐도
동일 라벨이 있으면 element 검색으로 못 넘어간다. → **입력이 같아도 결과가 예측 불가.**

### 원인 2. score 경합의 진동 (규칙 3)
element·window가 동시 매치일 때 최고 score 비교로 결정한다
(`IntentRouter.swift:150`). score가 비슷하면 한 글자 차이로 scope가 뒤집힌다.
게다가 `lastScope == .windows`일 때만 windows 우선이라 **히스테리시스가 비대칭**이다.

### 원인 3. buffer 길이 임계값의 계단 효과 (규칙 2 → 4)
1글자는 labels 후보(규칙 2), 2글자는 elements(규칙 4)로 떨어질 수 있다.
타이핑 도중 1→2글자로 넘어가는 순간 scope가 labels→elements로 점프한다.
"라벨 고르는 중이었는데 갑자기 요소 검색으로 바뀌는" 체감.

### 원인 4. gaze가 결정 트리를 아예 우회 (가장 큰 원인)
gaze focus는 `chooseScope`를 거치지 않고 **무조건 labels items의 nearest**로 간다.
사용자가 `;`로 windows를 pin한 상태에서 gaze를 쓰면 → gaze는 labels로 이동하는데
상태바는 windows를 가리킨다. **모달리티 간 scope 불일치**가 발생한다.

### 원인 5. windows와 gaze는 구조적으로 만날 수 없음
windows scope는 highlightFrame이 없어(원인 2.3) 시선으로 겨냥할 화면 타겟이 없다.
labels/elements는 공간 좌표가 있어 겨냥 가능하지만 windows는 본질적으로 의미 검색이다.
→ 세 scope를 "공간 위(labels·elements)" vs "공간 밖(windows)"으로 나눠 다뤄야 한다.

## 4. 개선 방향 (옵션)

### 방향 A — gaze를 scope-aware로 통합
`focusNearest`가 활성 scope의 대상 집합에서 최근접을 찾도록 확장한다.
elements scope면 `elementIndex.nodes`의 frame에서, labels면 현행대로. windows는 제외.
- 장점: "보는 곳 = 현재 scope 대상 선택"으로 일관.
- 단점: element 후보가 조밀하면 오선택↑. windows 특수 케이스 분리 필요.
- 주요 변경: `FocusEngine.focusNearest`에 대상 집합/scope 주입,
  `OverlaySessionController.focusNearestLabel`가 scope 전달.

### 방향 B — 공간(gaze) vs 의미(검색) 역할 분리 명시화 (현행 유지 + UX 보강)
gaze = 공간 포인터(labels·elements 겨냥), 텍스트 = 의미 검색(elements·windows)으로
규정하고, **상태바·마커에 현재 모달리티/겨냥 대상을 시각적으로 표시**한다.
- 장점: 변경 최소, 회귀 위험 낮음. 지금 체감 모호함의 상당수는 "피드백 부재"가 원인.
- 단점: windows를 시선으로 못 가리키는 한계 유지.
- 주요 변경: OverlayView에 gaze-겨냥 하이라이트, 상태바에 모달리티 뱃지.

### 방향 C — 2단계(coarse→fine) gaze
1단계: 시선으로 창(windows)을 큰 단위로 선택 → 2단계: 그 안에서 labels/elements.
scope가 gaze의 "줌 레벨"이 된다.
- 장점: 세 scope가 자연스러운 계층이 됨.
- 단점: 상호작용 복잡도·구현 비용 큼. windows 화면 좌표 확보 선행 필요.

### 방향 D — 경계 흔들림 완화 (A/B/C와 병행)
결정 규칙·gaze focus의 경계 진동을 잡는 공통 안정화 장치.
- **dwell**: 일정 시간 응시해야 focus 확정.
- **hysteresis**: 현재 focus에 관성 부여 — 새 후보가 임계 margin 이상 더 가까워야 전환.
- **길이/score 경계 완충**: 규칙 2→4 전환, score 경합에 margin·유예 프레임 추가.
- 장점: 원인 2·3의 진동, gaze의 후보 간 튐을 동시에 완화. 기존
  `maximumActivationDistance`와 결이 같음.

## 5. 권장 로드맵

1. **1단계 — 방향 B + D (저비용·저위험)**
   - gaze 활성 시 겨냥 대상 하이라이트 + 상태바 모달리티 표시로 "무엇을 겨냥 중"인지 명확화.
   - dwell/hysteresis로 focus 진동 제거.
   - 결정 트리는 유지하되 원인 2·3에 margin 완충만 추가.
2. **2단계 — 방향 A (기능 확장)**
   - `focusNearest`에 scope 주입 → elements까지 시선 겨냥 확장, windows는 검색 전용 유지.
   - 원인 4(모달리티 불일치) 해소: gaze가 활성 scope를 존중.
3. **3단계(선택) — 방향 C**
   - windows에 화면 좌표를 부여할 수 있으면 coarse→fine 계층 검토.

## 6. 열린 질문 / 다음 결정 포인트

- Q1. "경계가 애매"의 주 통증이 **결정 규칙**인가 **피드백 부재**인가? (사용자: 결정 규칙 쪽으로 추정, 추가 확인 필요)
- Q2. runtime(continuous) gaze를 실제 제품 경로로 살릴 것인가, one-shot만 유지할 것인가?
  (현재 runtime controller는 존재하나 wiring이 확인되지 않음.)
- Q3. windows를 시선 대상으로 포함할 것인가, 검색 전용으로 확정할 것인가? (방향 A vs C 분기)
- Q4. 원인 1(label ↔ element prefix 충돌)을 규칙 우선순위 재설계로 풀 것인가,
  명시적 scope 전환 UX로 회피할 것인가?

## 7. 영향 파일 (예상)

| 파일 | 방향 | 변경 성격 |
|------|------|-----------|
| `Sources/GazeRow/Focus/FocusEngine.swift` | A, D | `focusNearest` scope/hysteresis 확장 |
| `Sources/GazeRow/Gaze/GazeFocusController.swift` | D | dwell/hysteresis, margin |
| `Sources/GazeRow/Query/IntentRouter.swift` | D | 규칙 2·3 경계 완충 |
| `Sources/GazeRow/Runtime/OverlaySessionController.swift` | A, B | scope 전달, 상태 메시지 |
| `Sources/GazeRow/Overlay/OverlayView.swift` | B | gaze 겨냥 하이라이트·모달리티 뱃지 |
| `Tests/GazeRowTests/*` | 전부 | 결정 규칙·gaze 경계 회귀 테스트 |

## 8. 비고

- 모든 gaze 동작은 자동 클릭을 하지 않는다(추정 좌표/포커스 이동만). 이 원칙은 유지한다.
- 구현 착수 시 각 단계는 별도 티켓으로 분리하고, 결정 규칙 변경은 반드시
  한/영 단위 테스트를 동반한다.
