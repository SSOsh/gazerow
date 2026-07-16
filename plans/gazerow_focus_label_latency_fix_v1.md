# GazeRow Focus Label Latency Fix v1.2

## 1. 개요

- **목적**: overlay 라벨의 첫 표시 지연과 overlay 직후 첫 라벨 입력이 focus로 보이지 않는 문제를 계측하고 해결한다.
- **대상 사용자**: keyboard로 overlay label jump를 수행하는 macOS 사용자.
- **작성일**: 2026-07-13
- **작성자**: suho.do
- **상태**: 기획중

## 2. 증상 정의

### 2.1 사용자 관찰 증상

- overlay activation 후 라벨이 체감상 늦게 나타난다.
- 라벨이 보인 직후 `F` 같은 bare letter를 누르면 focus highlight가 바뀌지 않는 경우가 있다.
- 조금 기다리거나 다시 입력하면 동작하는 것처럼 보인다.

### 2.2 이번 분석에서 구분할 현상

첫 입력 문제는 아래 세 경우를 분리해서 측정한다.

1. keyDown 자체가 capture되지 않았다.
2. keyDown은 capture됐지만 session이 준비되지 않아 무시되거나 처리가 지연됐다.
3. focus state는 바뀌었지만 overlay 전체 재렌더가 늦어 화면에 늦게 반영됐다.

현재 코드만으로는 세 경우가 사용자에게 모두 동일하게 보인다. 따라서 구현 순서는 계측, 입력 readiness, 렌더 개선 순으로 진행한다.

## 3. 재검토 결과

### 3.1 확인된 구조적 원인

#### A. 첫 paint 이전 메인 액터 동기 작업이 과도하다

`OverlaySessionController.start()`는 다음 작업을 한 번의 `@MainActor` 동기 흐름에서 실행한다.

1. target resolve
2. AX candidate scan
3. layout 생성과 panel render/order front
4. searchable AX tree 재순회
5. 실행 앱/window index 생성
6. `activeSession` 설정과 status 재렌더

영향:

- AX scan은 기본 `maxDepth=28`, `maxNodes=4000`, `timeout=1.5s`까지 실행될 수 있다.
- searchable collector가 같은 AX tree를 다시 순회한다.
- label-only 사용에도 window index를 즉시 만든다.
- `orderFrontRegardless()` 이후 메인 run loop에 제어권이 돌아오기 전까지 실제 첫 화면 합성이 늦어질 수 있다.

#### B. 현재 timing 로그는 사용자가 기다린 전체 시간을 표시하지 않는다

`shownAt`은 `overlayPresenter.show()` 직후 기록되지만 실제 로그는 element/window index 생성 이후 출력된다. 로그의 `totalMs`는 index 생성 시간과 첫 화면 합성 대기 시간을 제외한다.

영향:

- 로그상 `totalMs`가 짧아도 사용자는 더 오래 기다릴 수 있다.
- scan, layout, render, capture ready, session ready, first frame을 분리하지 않아 병목을 판별할 수 없다.

#### C. panel 공개가 keyboard capture 준비보다 먼저다

`OverlayWindowController.show()`는 target/command panel을 `orderFrontRegardless()`로 공개한 뒤 `prepareKeyboardCapture()`를 호출한다.

영향:

- 라벨이 보이기 시작한 시점과 event tap 준비 완료 사이에 입력 공백이 생긴다.
- 이 공백에서 누른 첫 키는 기존 target app으로 전달될 수 있다.
- Input Monitoring 권한 요청도 첫 activation의 critical path에서 실행된다.

#### D. session 준비가 검색 인덱스 생성보다 늦다

`activeSession`은 panel show 후 searchable index와 window index 생성까지 끝난 뒤 설정된다.

영향:

- 이 구간에 AppDelegate monitor로 들어온 command는 `no active session`으로 무시된다.
- event tap command는 `Task { @MainActor ... }`에 대기하므로 메인 액터가 바쁜 동안 focus 반영이 지연된다.

#### E. focus 변경마다 overlay 전체 content view를 재생성한다

`OverlayWindowController.updateStatus()`는 매번 `render()`를 호출하고, `render()`는 target panel과 command bar panel의 `NSHostingView`를 모두 새로 만든다.

영향:

- 첫 `F`가 정상 처리되어도 모든 marker/label SwiftUI view가 다시 구성돼 highlight가 늦게 보일 수 있다.
- 현재 `OverlayView`는 candidate마다 marker와 label을 각각 생성하므로 candidate 수가 많을수록 입력 반응 비용이 커진다.
- command bar만 바뀌는 상태에서도 target overlay 전체가 다시 만들어진다.

#### F. 라벨 배치가 candidate 수 증가에 취약하다

`OverlayLayoutEngine`은 candidate마다 기존 label frame 배열을 다시 만들고 충돌 여부를 선형 검색한다. dense layout에서는 adaptive placer가 여러 위치마다 기존 label 전체를 다시 검사한다.

영향:

- 전체 비용이 candidate 수에 대해 대략 제곱으로 증가한다.
- 현재 layout 성능 회귀를 감지하는 benchmark가 없다.

#### G. scan cache TTL 기준 시점이 scan 시작 시각이다

`CachingScanner`는 wrapped scan 호출 전에 얻은 `now`를 cache의 `storedAt`으로 저장한다.

영향:

- scan이 기본 TTL 0.5초보다 오래 걸리면 scan 완료 직후에도 cache가 이미 만료된 상태가 된다.
- 느린 앱일수록 연속 activation cache 이점을 받지 못한다.

#### H. keyboard routing 정책과 실제 경로가 일치하지 않는다

문서 정책은 bare letter를 label 입력으로 우선하고 `/`, `;`로 query scope를 명시하는 것이다. 그러나 `OverlayKeyboardCommandRouter`는 첫 bare letter를 전달한 뒤 두 번째 bare letter를 자동으로 query 문자열로 전환한다.

또한 입력 경로별 상태 관리가 다르다.

- event tap / `OverlayPanel.keyDown`: stateful `OverlayKeyboardCommandRouter` 사용
- AppDelegate global/local monitor: 매 이벤트마다 새 `FocusKeyboardCommandMapper`를 사용

영향:

- 2글자 이상 label은 event tap 경로에서 두 번째 글자가 query로 바뀌어 완성되지 않을 수 있다.
- event tap fallback에서 local monitor가 panel보다 먼저 이벤트를 소비하면 pinned query 상태가 유지되지 않을 수 있다.
- 같은 키 입력이 capture 경로에 따라 다른 command가 된다.

### 3.2 정정한 가설

- 첫 bare letter는 `OverlayKeyboardCommandRouter`에서 보류되지 않는다. 첫 `F`는 `.typeLabel("F")`로 반환된다.
- 따라서 “첫 `F` 자체를 primer가 삼킨다”는 설명은 맞지 않는다.
- `activeSession` 지연은 실제 위험이지만 첫 입력 누락의 단일 확정 원인으로 단정할 수 없다.
- event tap 권한 실패도 가능한 분기지만 현재 런타임 로그가 없어 이번 증상의 확정 원인으로 보지 않는다.
- 우선 검증할 가능성이 높은 순서는 `capture 공개 순서`, `session readiness`, `전체 재렌더 지연`, `capture 경로별 routing 불일치`다.

## 4. 목표 구조

### 4.1 activation 단계

```text
resolve target
  -> scan candidates
  -> make layout
  -> create minimal session
  -> prepare keyboard capture
  -> publish panels
  -> first frame
  -> build optional indexes on demand
```

보장 조건:

- 화면에 라벨이 보이는 시점에는 keyboard capture와 minimal session이 모두 준비돼야 한다.
- label jump, Tab, Arrow, Return은 searchable/window index 없이 동작해야 한다.
- query index 생성은 label 입력과 첫 focus render를 막지 않아야 한다.

### 4.2 keyboard routing 단계

모든 capture 경로는 overlay session 생명주기에 속한 하나의 stateful router를 사용한다.

- idle bare letter: 항상 label command
- `/`: elements scope pin
- `;`: windows scope pin
- pinned scope 이후 printable input: query command
- overlay close/reopen: router state reset

### 4.3 rendering 단계

- panel과 hosting view는 session 동안 유지한다.
- focus/status 변경은 observable render state만 갱신한다.
- target overlay와 command bar의 갱신 경로를 분리한다.
- command bar 문구만 바뀌는 경우 target label tree를 재생성하지 않는다.

## 5. 작업 목록

### TICKET-FL-000: 재현 계측과 기준선 확보

- [x] activation ID를 생성해 한 session의 로그를 연결한다.
- [→] `shortcutReceived`, `targetResolved`, `scanCompleted`, `layoutCompleted`, `sessionReady`, `captureReady`, `panelsOrdered`, `firstDisplayPass`, `keyCaptured`, `commandHandled`, `focusStateChanged`, `focusRendered` 시점을 기록한다. `focusRendered`는 TICKET-FL-004의 persistent render state 도입 때 연결한다.
- [ ] 기존 `totalMs`를 `activationToFirstFrameMs`와 `activationToSessionReadyMs`로 분리한다.
- [→] key 로그에는 capture 경로(event tap/panel/local monitor), command 종류, session 유무만 남기고 raw query/window title은 기록하지 않는다. 현재 command 종류와 session 유무를 기록하며, capture 경로는 TICKET-FL-001의 presenter callback 연결 때 추가한다.
- [ ] Finder, Safari, Chrome, VS Code, System Settings에서 cold/warm activation과 첫 `F`를 각 10회 측정한다.
- [ ] 첫 입력 실패를 capture 누락, session 무시, render 지연 중 하나로 분류한다.

### TICKET-FL-001: 화면 공개 전 input readiness 보장

- [x] layout 생성 후 label-only minimal `OverlaySessionState`를 먼저 준비한다.
- [x] keyboard capture를 panel 공개 전에 준비한다.
- [x] event tap 성공 시에만 panel을 공개하거나, fallback key focus가 준비된 직후 공개한다.
- [→] Input Monitoring 권한 확인/요청은 activation critical path 밖의 onboarding/settings로 이동한다. activation 중 요청은 제거했고, settings의 명시적 요청 UI는 후속 UX 티켓에서 추가한다.
- [x] event tap에서 MainActor로 전달한 command의 FIFO 순서를 보장한다.
- [x] 테스트: `captureReady`가 `panelsOrdered`보다 먼저 발생한다.
- [x] 테스트: panel 공개 직후 첫 `F`가 정확히 한 번 처리된다.
- [x] 테스트: 빠른 `F` -> `Return` 순서가 유지된다.

### TICKET-FL-002: label-only fast path와 lazy index

- [x] start 시 searchable collector 호출을 제거한다.
- [x] start 시 `windowSearchIndexProvider()` 호출을 제거한다.
- [x] scan candidates 기반 fallback element index 또는 별도 minimal state로 label click 계약을 유지한다.
- [x] `/` elements scope 최초 진입 시 searchable index를 한 번 준비한다.
- [x] `;` windows scope 최초 진입 시 window index를 한 번 준비한다.
- [x] index 생성 실패/빈 결과는 label session을 닫지 않고 graceful degrade한다.
- [x] rescan 경로에도 같은 fast path를 적용한다.
- [x] 테스트: label-only start/input에서 두 index provider가 호출되지 않는다.
- [x] 테스트: 각 scope 최초 진입에서 해당 provider만 한 번 호출된다.
- [x] 테스트: query 실패 후에도 기존 label focus/click이 유지된다.

### TICKET-FL-003: keyboard router 단일화와 정책 복구

- [x] `pendingLabelPrimer` 기반 두 번째 bare letter 자동 query 전환을 제거한다.
- [x] event tap과 panel fallback이 동일 router 구현/정책을 사용하게 하고, AppDelegate monitor는 overlay 문자 입력 소유권에서 제외한다.
- [x] overlay 활성 중 중복 capture 경로가 같은 keyDown을 두 번 처리하지 않도록 한다.
- [x] close/reopen 시 router와 query state를 함께 초기화한다.
- [x] 테스트: 1글자 label `F`가 모든 capture 경로에서 `.typeLabel("F")`가 된다.
- [x] 테스트: 2글자 label `FA`가 `.typeLabel("F")`, `.typeLabel("A")`로 완성된다.
- [x] 테스트: `/` + `find`, `;` + `code`는 각 pinned query로 유지된다.
- [x] 테스트: event tap 성공/실패 경로의 command sequence가 동일하다.

### TICKET-FL-004: incremental overlay rendering

- [ ] target/command bar의 `NSHostingView`를 show 시 한 번 만들고 session 동안 유지한다.
- [ ] focus, scope, status는 observable render model로 갱신한다.
- [ ] target label tree와 command bar state를 분리해 필요한 panel만 invalidate한다.
- [ ] 동일 status 재설정은 렌더를 생략한다.
- [ ] 테스트: `updateStatus()`가 target/command hosting view identity를 교체하지 않는다.
- [ ] 테스트: focus 변경은 focused label만 바꾸고 layout/label count를 유지한다.
- [ ] 테스트: command bar 전용 변경이 target content view를 교체하지 않는다.

### TICKET-FL-005: scan cache 만료 기준 수정

- [ ] cache `storedAt`을 wrapped scan 성공 완료 시각으로 기록한다.
- [ ] scan 소요 시간이 TTL보다 긴 경우에도 완료 직후 재호출은 cache hit가 되게 한다.
- [ ] click/rescan/window identity 변경 시 기존 invalidate 정책을 유지한다.
- [ ] 테스트: 0.8초 scan, TTL 0.5초 조건에서 완료 직후 두 번째 호출은 cache hit다.
- [ ] 테스트: 완료 시각 기준 TTL을 넘으면 재스캔한다.

### TICKET-FL-006: layout/render 대량 후보 성능 개선

- [ ] layout 단계에 `layoutMs`와 candidate count를 기록한다.
- [ ] `placedLabels.map(\.labelFrame)` 반복 생성을 제거한다.
- [ ] 충돌 검사는 spatial bucket/grid index로 제한해 전체 선형 검색을 피한다.
- [ ] dense candidate에서 marker/label view 수와 first render 시간을 측정한다.
- [ ] 50/150/500/1000 candidate benchmark를 추가하되 CI 단위 테스트에는 환경 의존 절대 시간 assertion을 두지 않는다.
- [ ] 기능 테스트로 label ID, 공간 순서, collision/occlusion 정책이 유지되는지 검증한다.

### TICKET-FL-007: AX walk 중복 제거 검토

- [ ] scanner가 이미 읽은 snapshot으로 searchable node index를 함께 만들 수 있는지 설계한다.
- [ ] 단일 walk가 initial scan 시간을 유의미하게 늘리지 않는지 측정한다.
- [ ] 효과가 확인되면 lazy collector를 대체하고 query 최초 진입 지연을 줄인다.
- [ ] candidate 선정, parent/child 관계, AX path 계약의 회귀 테스트를 추가한다.

## 6. 우선순위

1. `TICKET-FL-000`: 원인 분류가 가능한 계측
2. `TICKET-FL-001`: capture/session 준비 후 화면 공개
3. `TICKET-FL-003`: 입력 경로 단일화와 다문자 label 복구
4. `TICKET-FL-002`: label-only fast path
5. `TICKET-FL-004`: focus 렌더 지연 제거
6. `TICKET-FL-005`: warm activation cache 수정
7. `TICKET-FL-006`: 대량 후보 layout/render 개선
8. `TICKET-FL-007`: 단일 AX walk 후속 최적화

`TICKET-FL-001`과 `TICKET-FL-003`은 첫 키 유실 방지, `TICKET-FL-002`와 `TICKET-FL-004`는 첫 표시와 focus 피드백 속도 개선을 담당한다.

## 7. 완료 기준

- panel이 화면에 공개될 때 keyboard capture와 minimal session이 이미 준비돼 있다.
- overlay 직후 첫 bare letter가 모든 capture 경로에서 정확히 한 번 처리된다.
- 1글자/2글자/3글자 label 입력이 query로 오인되지 않는다.
- label-only activation은 searchable/window index build에 막히지 않는다.
- `keyCaptured -> focusStateChanged`와 `focusStateChanged -> focusRendered`를 별도로 측정할 수 있다.
- 150 candidates 기준 post-scan 첫 frame과 focus render의 목표치는 기준선 측정 후 수치로 고정한다.
- 기존 label jump, elements query, window switch, risky second confirm 동작이 유지된다.
- 함수 수정/추가에 대응하는 Given-When-Then 테스트가 함께 추가되고 전체 테스트가 통과한다.

## 8. 검증 명령

```bash
swift test
scripts/evaluate_overlay_target.sh --bundle-id com.apple.finder --timeout 6 --no-label-map
scripts/evaluate_query_overlay.sh --target-bundle-id com.microsoft.VSCode --query explorer --expect-scope elements
scripts/evaluate_query_overlay.sh --window-query code --expect-app com.microsoft.VSCode
```

수동 검증 매트릭스:

| 조건 | 입력 | 기대 결과 |
| --- | --- | --- |
| cold activation | overlay 직후 `F` | 1회 capture, 즉시 focus 표시 |
| warm activation | overlay 직후 `F` | cache hit, 1회 focus 표시 |
| 다문자 label | `F` -> `A` | label `FA` focus |
| 빠른 confirm | `F` -> `Return` | `F` focus 후 해당 candidate confirm |
| elements fallback | `/` -> `find` | elements query 유지 |
| windows fallback | `;` -> `code` | windows query 유지 |
| event tap 실패 | 위 입력 반복 | event tap 성공 경로와 동일 command sequence |

## 9. 보류/주의

- scanner의 maxDepth/maxNodes/timeout 축소는 candidate 누락 위험이 있어 계측 없이 적용하지 않는다.
- AX 작업을 바로 background thread로 이동하지 않는다. Accessibility API 호출과 session state의 actor/thread 계약을 먼저 검증한다.
- pending command queue는 capture/session 준비 후 화면 공개로도 해결되지 않는 경우에만 도입한다.
- first frame 측정은 `orderFrontRegardless()` 반환 시각으로 대체하지 않는다. 실제 다음 run loop/display 완료 지점을 사용한다.
- 현재 관련 Swift 파일에 별도 미커밋 변경이 있으므로 구현 시 해당 변경을 보존하고 함께 작업한다.

## 10. 구현 에이전트 실행 규칙

이 절부터는 다른 구현 에이전트가 추가 설계 없이 작업할 수 있도록 결정을 고정한다.

1. 티켓 순서를 임의로 바꾸지 않는다. 각 티켓의 테스트가 통과한 뒤 다음 티켓으로 이동한다.
2. 한 티켓에서 지정하지 않은 동작이나 UI 문구는 변경하지 않는다.
3. 현재 worktree의 기존 미커밋 변경은 사용자 작업으로 간주하고 되돌리지 않는다.
4. 함수 수정/추가와 같은 티켓에서 테스트를 작성한다.
5. 새 Swift 파일의 문서 주석 `@author`는 반드시 `suho.do`로 작성한다.
6. private 함수가 복잡도 기준을 넘으면 역할별로 분리하되, 이 계획에 없는 기능 변경은 하지 않는다.
7. 성능 개선 전후에 label ID, candidate index, click index 대응이 동일한지 반드시 확인한다.
8. 임시 `>>> [DEBUG]` 로그는 재현 단계에서만 사용하고 티켓 완료 전에 제거한다.
9. 영구 timing 로그에는 raw title, raw query, AX value/help, window title을 남기지 않는다.
10. 구현 중 새로운 원인이 발견되면 임의 수정하지 말고 이 문서의 해당 티켓에 원인과 검증 항목을 먼저 추가한다.

## 11. 파일별 변경 범위

| 파일 | 변경 목적 | 주요 변경 |
| --- | --- | --- |
| `Sources/GazeRow/Runtime/OverlaySessionController.swift` | minimal session 선설정, lazy index, timing 연결 | start/rescan 공통 presentation 흐름, index ensure 함수, optional window index |
| `Sources/GazeRow/Overlay/OverlayWindowController.swift` | capture-before-publish, persistent hosting view | presenter API 분리, capture mode 반환, render state 유지 |
| `Sources/GazeRow/Focus/OverlayKeyboardCommandRouter.swift` | 입력 정책 단일화 | 기존 private router 이동, `pendingLabelPrimer` 제거 |
| `Sources/GazeRow/Focus/FocusKeyboardCommand.swift` | mapper 계약 유지 | 필요한 경우 접근 수준만 조정, label/query 매핑 규칙 변경 금지 |
| `Sources/GazeRow/App/AppDelegate.swift` | 중복 overlay 문자 capture 제거 | global/local monitor의 focus command 선처리 제거 |
| `Sources/GazeRow/Runtime/CachingScanner.swift` | warm activation cache 수정 | scan 성공 완료 시각으로 `storedAt` 기록 |
| `Sources/GazeRow/Overlay/OverlayView.swift` | incremental focus render | target render state 관찰, view identity 유지 |
| `Sources/GazeRow/Overlay/OverlayCommandBarView.swift` | command bar 상태 분리 | command render state 관찰 |
| `Sources/GazeRow/Overlay/OverlayLayoutEngine.swift` | layout allocation/충돌 비용 감소 | placed frame 재사용, collision index 사용 |
| `Sources/GazeRow/Overlay/OverlayLabelPlacer.swift` | indexed collision query | 배열 전체 검색 대신 collision query 주입 |
| `Sources/GazeRow/Infrastructure/AppLogger.swift` | 기존 category 재사용 | 새 민감정보 로그 category 추가 금지 |
| `Tests/GazeRowTests/OverlaySessionControllerTests.swift` | start/lazy index 순서 검증 | presenter/collector/provider spy 보강 |
| `Tests/GazeRowTests/OverlayWindowControllerTests.swift` | capture/render identity 검증 | operation trace, content view identity 테스트 |
| `Tests/GazeRowTests/OverlayKeyboardCommandRouterTests.swift` | router 직접 단위 테스트 | 새 테스트 파일 |
| `Tests/GazeRowTests/CachingScannerTests.swift` | scan 완료 기준 TTL 검증 | 시간 진행 가능한 spy/clock 사용 |
| `Tests/GazeRowTests/OverlayLayoutEngineTests.swift` | layout 의미 보존 | indexed collision 전후 결과 계약 테스트 |

`SearchableNodeCollector.swift`, `WindowSearchIndex.swift`, `IntentRouter.swift`의 검색 점수나 매칭 정책은 이번 범위에서 변경하지 않는다.

## 12. 고정 설계 결정

### 12.1 입력 소유권

overlay 활성 중 문자 입력 소유자는 정확히 하나여야 한다.

| 상태 | 입력 소유자 | AppDelegate monitor 동작 |
| --- | --- | --- |
| event tap 시작 성공 | `OverlayKeyboardEventTap` | overlay 문자 command를 만들지 않음 |
| event tap 시작 실패 | key window인 `OverlayPanel.keyDown` | overlay 문자 command를 만들지 않음 |
| overlay 비활성 | 없음 | activation/gaze/window-control shortcut만 처리 |

구현 지침:

- `AppDelegate.installOverlayActivationShortcut()`의 global/local monitor에서 `Self.focusKeyboardCommand(from:)` 호출 블록을 제거한다.
- `AppDelegate.focusKeyboardCommand(from:)`는 다른 호출자가 없으면 제거한다.
- Carbon overlay activation, gaze activation, window-control shortcut 로직은 유지한다.
- fallback에서는 `applicationActivator()` 후 target panel을 key window로 만든다.
- local monitor가 일반 문자 이벤트를 소비하지 않아 responder chain을 통해 `OverlayPanel.keyDown`에 도달하게 한다.
- event tap과 panel은 각각 session 생성 시 새 `OverlayKeyboardCommandRouter`를 가진다. 한 session에서 두 경로를 동시에 활성화하지 않으므로 공유 mutable router는 만들지 않는다.

### 12.2 router 정책

기존 private `OverlayKeyboardCommandRouter`를 `Sources/GazeRow/Focus/OverlayKeyboardCommandRouter.swift`로 이동하고 internal `struct`로 둔다.

권장 형태:

```swift
struct OverlayKeyboardCommandRouter {
    private let mapper = FocusKeyboardCommandMapper()
    private var queryInput = QueryInputState()

    mutating func command(for input: FocusKeyboardInput) -> FocusKeyboardCommand? {
        guard let command = mapper.command(for: input, queryInput: queryInput) else {
            return nil
        }

        updateState(for: command)
        return command
    }

    mutating func reset() {
        queryInput = QueryInputState()
    }
}
```

`updateState(for:)` 계약:

| command | router state 변경 |
| --- | --- |
| `.typeLabel` | `lastScope = .labels`, query buffer 변경 없음 |
| `.pinScope(scope)` | `pinnedScope = scope`, `lastScope = scope`, buffer 유지 |
| `.appendQuery(text)` | buffer가 비었거나 text가 다문자면 대입, 아니면 append |
| `.deleteQueryCharacter` | buffer가 있으면 마지막 grapheme 제거 |
| `.clearQueryBuffer`, `.clearLabelBuffer`, `.closeOverlay` | `QueryInputState()`로 초기화 |
| `.move`, `.cycleMatch`, `.dryRunConfirm` | query state 변경 없음 |

금지 사항:

- `pendingLabelPrimer`를 다른 이름으로 다시 만들지 않는다.
- idle 상태의 두 번째 bare letter를 자동 query로 바꾸지 않는다.
- query 검색을 시작하려면 반드시 `/` 또는 `;`로 scope가 pin되어야 한다.

### 12.3 presenter API 분리

현재 `OverlaySessionPresenting.show(targetFrame:candidates:...) -> OverlayLayout`은 layout 생성과 화면 공개가 결합돼 minimal session을 먼저 만들 수 없다. 다음 형태로 분리한다.

```swift
@MainActor
protocol OverlaySessionPresenting {
    func makeLayout(
        targetFrame: CGRect,
        candidates: [ClickableCandidate],
        labels: [String]
    ) -> OverlayLayout

    @discardableResult
    func show(
        layout: OverlayLayout,
        initialStatus: OverlayInteractionStatus,
        onEscape: @escaping () -> Void,
        onKeyboardCommand: @MainActor @escaping (OverlayCapturedKeyboardCommand) -> Void,
        onPresentationEvent: @MainActor @escaping (OverlayPresentationEvent) -> Void
    ) -> OverlayKeyboardCaptureMode

    func close()
    func updateFocus(focusedLabelID: Int?)
    func updateStatus(_ status: OverlayInteractionStatus)
}

enum OverlayKeyboardCaptureMode: Equatable {
    case eventTap
    case panelFallback
}

struct OverlayCapturedKeyboardCommand: Equatable {
    let command: FocusKeyboardCommand
    let captureMode: OverlayKeyboardCaptureMode
}

enum OverlayPresentationEvent: Equatable {
    case captureReady(OverlayKeyboardCaptureMode)
    case panelsOrdered
    case firstDisplayPass
}
```

`OverlayWindowController.makeLayout()`은 기존 `layoutEngine.makeLayout()` 호출만 담당한다.

`OverlayWindowController.show()` 내부 순서:

1. 기존 overlay를 `close()`한다.
2. target/command panel과 persistent render state/hosting view를 만든다.
3. `initialStatus`로 두 panel 내용을 한 번 구성한다.
4. event tap을 생성하고 `start()`한다.
5. 성공하면 capture mode를 `.eventTap`으로 정하고 `onPresentationEvent(.captureReady(.eventTap))`을 호출한 뒤 두 panel을 `orderFrontRegardless()`한다.
6. 실패하면 `applicationActivator()`를 호출하고 아직 숨겨진 target panel에 `makeKey()`를 호출한다. `isKeyWindow == true`면 `onPresentationEvent(.captureReady(.panelFallback))`을 호출한 뒤 두 panel을 공개한다. 숨겨진 상태에서 key window가 되지 않는 AppKit 조건에서는 `makeKeyAndOrderFront(nil)`을 사용하고, 반환 직후 key 상태를 확인해 capture ready를 기록한 뒤 command bar를 공개한다.
7. 두 panel 공개가 끝나면 `onPresentationEvent(.panelsOrdered)`를 호출한다.
8. 두 panel에 `displayIfNeeded()`를 호출한다.
9. 다음 MainActor turn에 panel이 여전히 현재 session의 panel인지 확인한 뒤 `onPresentationEvent(.firstDisplayPass)`를 한 번 호출한다.
10. 선택된 `OverlayKeyboardCaptureMode`를 반환한다.

`firstDisplayPass`는 실제 모니터 합성 완료를 보장하는 이름으로 사용하지 않는다. AppKit display pass 완료를 나타내는 근사 지표다.

fallback에서 `makeKeyAndOrderFront`가 필요한 예외 경로는 key 전환과 target panel 공개가 하나의 AppKit 호출에서 일어난다. 이 경우 `captureReady`는 호출 반환 직후 기록하며, 첫 keyDown은 호출이 끝난 뒤에만 사용자 입력으로 도달한다는 계약을 테스트와 수동 검증으로 확인한다.

keyboard command 전달 규칙:

- event tap은 `OverlayCapturedKeyboardCommand(command: ..., captureMode: .eventTap)`을 전달한다.
- panel fallback은 `OverlayCapturedKeyboardCommand(command: ..., captureMode: .panelFallback)`을 전달한다.
- controller callback은 `keyCaptured`를 기록한 뒤 기존 `handleKeyboardCommand(_:)`에 `command`만 넘긴다.
- capture mode는 로그/테스트용이며 focus engine 동작 분기에 사용하지 않는다.

event tap FIFO 규칙:

- event tap callback 안에서 focus/query/click 처리를 직접 실행하지 않는다. callback timeout을 막기 위해 command를 main queue로 넘기고 즉시 event를 소비한다.
- 현재 key마다 만드는 독립 `Task { @MainActor ... }`는 실행 순서 계약이 없으므로 제거한다.
- event tap은 하나의 serial callback source에서 들어오므로 `DispatchQueue.main.async`에 command envelope를 순서대로 제출한다.
- main queue block 안에서는 `MainActor.assumeIsolated`로 `onKeyboardCommand`를 호출한다.
- event tap context가 stop된 뒤 이미 queue에 들어간 command가 새 session으로 전달되지 않도록 generation UUID를 함께 capture한다. block 실행 시 현재 generation과 다르면 버린다.
- generation은 event tap instance 생성 시 한 번 정하고 재사용하지 않는다.

권장 형태:

```swift
let capturedGeneration = generation
let capturedCommand = OverlayCapturedKeyboardCommand(
    command: command,
    captureMode: .eventTap
)
DispatchQueue.main.async { [weak self] in
    MainActor.assumeIsolated {
        guard self?.generation == capturedGeneration,
              self?.isAcceptingCommands == true else {
            return
        }
        self?.onKeyboardCommand(capturedCommand)
    }
}
```

`stop()`은 event tap을 disable한 뒤 context의 `isAcceptingCommands`를 false로 바꾼다. 새 overlay는 새 event tap/context를 생성한다.

### 12.4 session start 순서

`OverlaySessionController.start()`의 성공 경로를 아래 순서로 고정한다.

```text
lastClickResult reset
-> enabled guard
-> activation trace begin
-> target resolve
-> AX scan
-> non-empty candidates guard
-> presenter.makeLayout
-> snapshot 생성
-> fallback element index 생성
-> OverlaySessionState 생성(windowIndex nil)
-> activeSession 설정
-> initialStatus 계산
-> presenter.show(initialStatus 포함)
-> capture mode/session ready timing 기록
-> success(snapshot) 반환
```

중요:

- `activeSession`은 `presenter.show()` 전에 설정한다.
- `presenter.show()` callback은 active session을 즉시 찾을 수 있어야 한다.
- start 경로에서 `searchableNodeCollector.buildIndex()`와 `windowSearchIndexProvider()`를 호출하지 않는다.
- show 직후 별도의 `Ready` status update를 호출하지 않는다. `initialStatus`에 반영해 초기 전체 재렌더를 없앤다.
- show 실패를 새 failure enum으로 추가하지 않는다. 현재 presenter는 panel 생성 실패를 반환하지 않으며 이번 범위에서 failure surface를 넓히지 않는다.

### 12.5 start/rescan 공통화

`start()`와 `rescanFrontmost(message:)`가 동일 readiness 순서를 사용하도록 아래 private helper를 추가한다.

```swift
private func presentSession(
    context: TargetContext,
    scanResult: AccessibilityScanResult,
    queryInput: QueryInputState,
    message: String?,
    tone: OverlayInteractionStatus.Tone,
    activationID: UUID?
) -> OverlaySessionSnapshot
```

helper 책임:

- layout 생성
- snapshot/minimal state 생성
- `activeSession` 선설정
- initial status 계산
- presenter show
- presenter presentation event를 activation tracer에 연결
- snapshot 반환

helper가 하지 않을 일:

- target resolve
- scanner 호출/invalidate
- searchable/window index 생성
- click 실행

`start()`는 `queryInput: QueryInputState()`, `message: "Ready"`, `tone: .neutral`을 전달한다.

window activation 후 rescan은 기존 동작을 유지하기 위해 `queryInput: QueryInputState(lastScope: .elements)`, 기존 success message, `.success`를 전달한다.

controller는 initializer로 받은 `activationTracer`를 property로 보관한다. `presentSession`의 `activationID`가 nil이면 timing event를 기록하지 않는다. rescan을 별도 activation으로 측정할 경우 rescan 진입점에서 새 ID를 만들고 전달한다.

### 12.6 lazy index state

`OverlaySessionState`를 다음 의미로 변경한다.

```swift
struct OverlaySessionState: Equatable {
    let snapshot: OverlaySessionSnapshot
    var focusEngine: FocusEngine
    var queryInput: QueryInputState = QueryInputState()
    var elementIndex: ElementSearchIndex
    var didAttemptSearchableIndexBuild = false
    var elementMatches: [SearchMatch] = []
    var elementMatchIndex = 0
    var windowIndex: WindowSearchIndex?
    var windowMatches: [WindowMatch] = []
    var windowMatchIndex = 0
    var pendingSecondConfirm: PendingSecondConfirm?
}
```

fallback element index는 현재 `buildElementIndex`의 candidates mapping 부분을 별도 함수로 분리한다.

```swift
private func makeFallbackElementIndex(
    scanResult: AccessibilityScanResult
) -> ElementSearchIndex
```

searchable index 준비 함수:

```swift
private func ensureSearchableElementIndexIfNeeded(
    session: inout OverlaySessionState
)
```

계약:

- `didAttemptSearchableIndexBuild == true`면 반환한다.
- 호출 즉시 flag를 true로 바꿔 빈 결과에서도 반복 AX walk를 막는다.
- collector가 nil이면 fallback을 유지한다.
- collector 결과가 비어 있으면 fallback을 유지한다.
- 결과가 있으면 `elementIndex`를 교체한다.

window index 준비 함수:

```swift
private func ensureWindowIndexIfNeeded(
    session: inout OverlaySessionState
)
```

계약:

- `windowIndex == nil`이면 provider를 호출해 저장한다.
- 기존 index가 `isStale()`이면 provider를 다시 호출한다.
- 비어 있는 index도 non-nil로 저장해 같은 session에서 provider를 반복 호출하지 않는다.

호출 지점:

| command/경로 | ensure 호출 |
| --- | --- |
| `.typeLabel`, `.move`, label `.dryRunConfirm` | 없음 |
| `.pinScope(.elements)` | searchable element ensure |
| `.pinScope(.windows)` | window ensure |
| `.appendQuery` + effective scope elements | searchable element ensure |
| `.appendQuery` + effective scope windows | window ensure |
| window `.cycleMatch`, window `.dryRunConfirm` | window ensure |

`applyQueryResolution()`에서 optional window index는 `WindowSearchIndex(entries: [])`를 local fallback으로 사용한다. local fallback을 session에 저장하지 않는다. windows scope 경로에서는 호출 전에 반드시 `ensureWindowIndexIfNeeded()`가 실행돼야 한다.

`activateFocusedWindow()`는 optional window index를 guard하고, nil이면 기존 `Window not found` failure status를 사용한다.

### 12.7 timing 계측 모델

새 파일을 추가한다.

`Sources/GazeRow/Runtime/OverlayActivationTrace.swift`

```swift
enum OverlayActivationPhase: String, Equatable {
    case shortcutReceived
    case targetResolved
    case scanCompleted
    case layoutCompleted
    case sessionReady
    case captureReady
    case panelsOrdered
    case firstDisplayPass
    case keyCaptured
    case commandHandled
    case focusStateChanged
    case focusRendered
}

@MainActor
protocol OverlayActivationTracing {
    func begin() -> UUID
    func mark(
        _ phase: OverlayActivationPhase,
        activationID: UUID,
        metadata: OverlayActivationTraceMetadata
    )
}
```

`OverlayActivationTraceMetadata`는 다음 값만 optional로 가진다.

- `nodesVisited: Int?`
- `candidateCount: Int?`
- `captureMode: OverlayKeyboardCaptureMode?`
- `commandKind: String?`
- `hasActiveSession: Bool?`

금지 필드:

- query text
- label text
- AX title/value/help
- app/window title

기본 구현은 기존 `AppLogger.overlay` 또는 `AppLogger.interaction`에 activation UUID, phase, 시작 대비 elapsed ms를 기록한다. elapsed 계산은 monotonic clock 사용이 이상적이지만 기존 주입 패턴을 크게 바꾸지 않기 위해 v1.2에서는 `dateProvider`를 사용해도 된다. 시스템 시각 역행 시 elapsed는 0으로 clamp한다.

테스트에서는 `SpyOverlayActivationTracer`가 `(phase, metadata)` 배열을 저장한다.

필수 phase 순서 assertion:

```text
targetResolved
< scanCompleted
< layoutCompleted
< sessionReady
< captureReady
< panelsOrdered
< firstDisplayPass
```

`firstDisplayPass`는 async이므로 expectation으로 검증한다.

### 12.8 persistent render state

새 파일을 추가한다.

`Sources/GazeRow/Overlay/OverlayRenderState.swift`

```swift
@MainActor
final class OverlayTargetRenderState: ObservableObject {
    @Published private(set) var focusedLabelID: Int?
    @Published private(set) var activeScope: QueryScope
    let layout: OverlayLayout
    let appearance: OverlayAppearance

    func update(focusedLabelID: Int?, activeScope: QueryScope)
}

@MainActor
final class OverlayCommandRenderState: ObservableObject {
    @Published private(set) var status: OverlayInteractionStatus

    func update(status: OverlayInteractionStatus)
}
```

두 `update` 함수는 새 값이 기존 값과 같으면 publish하지 않는다.

`OverlayWindowController`가 session 동안 유지할 property:

```swift
private var targetRenderState: OverlayTargetRenderState?
private var commandRenderState: OverlayCommandRenderState?
private var targetHostingView: NSHostingView<OverlayView>?
private var commandHostingView: NSHostingView<OverlayCommandBarPanelView>?
```

`OverlayView`는 `@ObservedObject var renderState: OverlayTargetRenderState`를 받아 layout/focus/scope/appearance를 읽는다.

`OverlayCommandBarPanelView`는 기존 layout과 language 외에 `@ObservedObject var renderState: OverlayCommandRenderState`를 받는다. command bar panel frame은 preview/message 표시 여부가 바뀔 때만 다시 계산한다.

`OverlayWindowController.updateStatus()` 순서:

1. `currentLayout`, 두 render state가 없으면 반환한다.
2. `currentStatus == status`면 반환한다.
3. `currentStatus`를 새 status로 저장한다.
4. focused label ID와 active scope가 바뀐 경우에만 target render state를 update한다.
5. command render state를 update한다.
6. command bar layout variant가 바뀐 경우에만 panel frame을 변경한다.
7. `contentView`를 새 `NSHostingView`로 교체하지 않는다.

테스트 관찰용 internal computed property를 추가한다.

```swift
var targetContentViewIdentity: ObjectIdentifier? { ... }
var commandContentViewIdentity: ObjectIdentifier? { ... }
```

production 동작에는 사용하지 않는다.

`close()`는 panel뿐 아니라 두 render state와 두 hosting view를 nil로 정리한다.

### 12.9 cache timestamp 수정

`CachingScanner.scan(context:)`의 시간 사용을 다음처럼 바꾼다.

```swift
let lookupAt = dateProvider()
if let cachedScan, cachedScan.key == key,
   lookupAt.timeIntervalSince(cachedScan.storedAt) <= timeToLive {
    return .success(cachedScan.result)
}

let result = wrapped.scan(context: context)
switch result {
case .success(let scanResult):
    cachedScan = CachedScan(
        key: key,
        result: scanResult,
        storedAt: dateProvider()
    )
case .failure:
    cachedScan = nil
}
```

기존 경계 조건 `<= timeToLive`, 실패 미캐시, invalidate 동작은 유지한다.

### 12.10 layout collision index

FL-006은 두 단계로 구현한다.

1단계는 allocation 제거다.

- `placedLabels.map(\.labelFrame)`를 loop마다 만들지 않는다.
- `placedFrames: [CGRect]`를 별도로 유지하고 label 확정 시 append한다.
- 이 단계에서 충돌 결과와 배치 결과가 기존 테스트와 완전히 같아야 한다.

2단계는 spatial index다.

새 internal 타입:

```swift
struct LabelCollisionIndex {
    init(cellSize: CGSize)
    mutating func insert(_ frame: CGRect)
    func intersects(_ frame: CGRect) -> Bool
}
```

구현 규칙:

- frame이 걸치는 모든 grid cell key를 계산한다.
- cell별 `[CGRect]`를 저장한다.
- query 시 걸치는 cell의 frame만 검사한다.
- 동일 frame이 여러 cell에 있어도 `intersects` 결과는 boolean이므로 중복 count 문제는 없다.
- `collisionCount`는 최종 label frame이 기존 frame 하나 이상과 겹치면 candidate당 1만 증가하는 기존 의미를 유지한다.
- cell size 기본값은 최대 label size와 spacing을 합친 크기로 정한다. 숫자를 하드코딩하지 않는다.

`OverlayLabelPlacer.place()`는 `[CGRect]` 대신 collision closure를 받는다.

```swift
func place(
    over candidateFrame: CGRect,
    in bounds: CGRect,
    collides: (CGRect) -> Bool
) -> CGRect
```

placer의 corner 우선순위, shift 방향, shift step, centered fallback은 변경하지 않는다.

## 13. 티켓별 상세 구현 절차

### 13.1 FL-000 계측

수정 순서:

1. `OverlayActivationTrace.swift`와 테스트 spy를 추가한다.
2. controller initializer에 tracer dependency를 기본 구현과 함께 추가한다.
3. start 주요 phase를 기록한다.
4. presenter의 display callback으로 async phase를 연결한다.
5. keyboard event tap context와 panel keyDown에서 capture mode/command kind를 기록할 수 있게 callback 경계를 연결한다.
6. 기존 timing log는 새 phase log가 동등 정보를 제공한 뒤 제거하거나 `legacy` 표기 없이 교체한다.

완료 테스트:

- `test_start_성공은_activationPhase를_순서대로_기록한다`
- `test_start_scan실패는_scanCompleted이후_phase를_기록하지않는다`
- `test_keyboardCommand는_raw문자없이_commandKind만_기록한다`

### 13.2 FL-001 readiness

수정 순서:

1. presenter protocol을 `makeLayout`/`show(layout:)`로 분리한다.
2. `StubOverlayPresenter`를 새 protocol에 맞추고 `operationTrace` 배열을 추가한다.
3. controller가 active session을 show 전에 설정하도록 start를 변경한다.
4. presenter가 capture 준비 후 panel을 공개하도록 순서를 변경한다.
5. rescan도 `presentSession` helper를 사용하게 한다.

`operationTrace` 값 예:

```swift
enum PresenterOperation: Equatable {
    case makeLayout
    case show
    case captureStarted
    case panelsOrdered
}
```

완료 테스트:

- `test_start_성공은_session을_준비한뒤_presenterShow를_호출한다`
- `test_show_eventTap성공은_capture후_panel을_공개한다`
- `test_show_eventTap실패는_keyPanel준비후_commandPanel을_공개한다`
- `test_show직후_keyboardCallback은_첫F를_한번처리한다`
- `test_rescan도_show전에_activeSession을_교체한다`

첫 test는 presenter `show()` 안에서 주입된 closure로 `sut.activeSession != nil`을 관찰하게 만들면 된다.

### 13.3 FL-003 router/input ownership

수정 순서:

1. router를 새 Focus 파일로 이동한다.
2. `pendingLabelPrimer`를 제거하고 명시 scope 정책을 구현한다.
3. router 직접 테스트를 먼저 통과시킨다.
4. AppDelegate monitor의 overlay 문자 command 변환을 제거한다.
5. event tap context와 panel fallback 테스트가 같은 command sequence를 내는지 검증한다.

필수 router 테스트:

- `test_idle_F는_typeLabel을_반환한다`
- `test_idle_FA는_두개의_typeLabel을_반환한다`
- `test_elementsPin후_find는_appendQuery를_반환한다`
- `test_windowsPin후_code는_appendQuery를_반환한다`
- `test_clear후_bareLetter는_다시_typeLabel이다`
- `test_close후_routerReset상태를_유지한다`
- `test_한글물리키_F는_typeLabel_F를_반환한다`

event tap async command 테스트는 XCTest expectation을 사용하고 `F`, `Return` 두 이벤트가 입력 순서대로 수신되는지 확인한다.

### 13.4 FL-002 lazy index

수정 순서:

1. `OverlaySessionState.windowIndex`를 optional로 바꾸고 컴파일 오류가 나는 모든 사용처를 명시적으로 처리한다.
2. fallback element index 함수를 분리한다.
3. ensure 함수 두 개를 추가한다.
4. command switch에서 scope별 ensure 호출을 연결한다.
5. start와 rescan의 eager provider 호출을 제거한다.
6. 기존 element/window query 테스트를 provider call count assertion과 함께 수정한다.

collector spy는 struct 대신 call count가 필요한 `@MainActor final class SpySearchableNodeCollector`로 바꾼다.

완료 테스트:

- `test_start는_searchableCollector를_호출하지않는다`
- `test_start는_windowIndexProvider를_호출하지않는다`
- `test_typeLabel은_두Index를_준비하지않는다`
- `test_elementsPin은_searchableCollector를_한번호출한다`
- `test_elementsCollector빈결과는_fallbackIndex를_유지한다`
- `test_windowsPin은_windowProvider를_한번호출한다`
- `test_빈windowIndex도_같은session에서_재생성하지않는다`
- `test_staleWindowIndex는_windowsScope재진입시_갱신한다`
- `test_rescan은_두Index를_eagerBuild하지않는다`

### 13.5 FL-004 rendering

수정 순서:

1. render state 두 타입과 단위 테스트를 추가한다.
2. `OverlayView`를 target render state 기반으로 변경한다.
3. command bar view를 command render state 기반으로 변경한다.
4. controller show에서 hosting view를 한 번 생성해 property에 저장한다.
5. updateStatus에서 상태만 변경한다.
6. close 정리를 보강한다.

완료 테스트:

- `test_targetRenderState_같은값은_publish하지않는다`
- `test_commandRenderState_같은status는_publish하지않는다`
- `test_updateStatus는_targetContentView를_교체하지않는다`
- `test_updateStatus는_commandContentView를_교체하지않는다`
- `test_command전용변경은_targetState를_변경하지않는다`
- `test_focus변경은_targetFocusedLabelID를_갱신한다`
- `test_close는_hostingView와_renderState를_정리한다`

Combine publish count 테스트가 불안정하면 update 함수가 `Bool changed`를 반환하게 만들지 않는다. 최종 state와 content view identity로 검증한다.

### 13.6 FL-005 cache

완료 테스트 추가 방법:

1. `now` 변수를 1000초로 시작한다.
2. spy scanner가 호출될 때 `now += 0.8`하도록 hook을 추가한다.
3. TTL 0.5초로 첫 scan을 호출한다.
4. 시간 추가 없이 같은 context를 다시 호출한다.
5. scan call count가 1인지 확인한다.
6. 이후 `now += 0.51` 후 재호출해 call count가 2인지 확인한다.

테스트 이름:

- `test_scan이_TTL보다오래걸려도_완료직후에는_cacheHit`
- `test_scan완료시각기준_TTL초과면_재스캔`

### 13.7 FL-006 layout

완료 테스트:

- 기존 `OverlayLayoutEngineTests` 전체 통과
- `test_collisionIndex_겹치는frame을_찾는다`
- `test_collisionIndex_멀리떨어진frame은_false`
- `test_collisionIndex_cell경계에걸친frame을_찾는다`
- `test_makeLayout_index적용후_labelID와frame을_유지한다`
- `test_makeLayout_500candidate를_완료한다`는 성능 측정용으로만 두고 절대 ms assertion은 하지 않는다.

benchmark 출력에는 candidate count, layout duration, collision count만 포함한다.

## 14. 회귀 테스트 매트릭스

| 영역 | 정상 | 경계/실패 | 반드시 유지할 계약 |
| --- | --- | --- | --- |
| activation | event tap 성공 | secure input, 권한 없음 | panel은 입력 준비 후 공개 |
| label | 1글자 `F` | 2/3글자 label | bare letter는 query로 전환되지 않음 |
| confirm | `F` 후 Return | 빠른 연속 입력 | 순서 유지, 중복 click 없음 |
| elements | `/` 후 query | collector nil/empty | fallback 유지, overlay 유지 |
| windows | `;` 후 query | empty/stale index | 최초 1회 build, stale만 refresh |
| rendering | focus 변경 | 같은 status 반복 | hosting view identity 유지 |
| cache | 완료 직후 재호출 | TTL 경계/초과 | 완료 시각 기준 |
| layout | sparse/dense | cell 경계/500개 | label/index/click 대응 유지 |
| risky click | 2차 확인 | focus 변경/timeout | 기존 안전 정책 유지 |
| rescan | window activation 성공 | resolve/scan 실패 | readiness 순서와 failure status 유지 |

## 15. 구현 중 확인해야 할 기존 테스트 영향

다음 기존 테스트는 API 변경으로 수정이 예상된다.

- `OverlaySessionControllerTests.test_start_성공하면_resolve_scan_overlayShow를_순서대로_실행`
- `OverlaySessionControllerTests.test_overlayKeyboardCallback은_controller_focus상태를_갱신`
- window query/provider 관련 `OverlaySessionControllerTests`
- `OverlayWindowControllerTests.test_show는_keyboardEventTap이_성공하면_application을_activate하지_않음`
- `OverlayWindowControllerTests.test_show는_keyboardEventTap이_실패하면_application을_activate한다`
- `OverlayWindowControllerTests.test_show는_render시_appearanceProvider를_조회한다`

기존 assertion을 삭제해서 통과시키지 않는다. 새 API의 동일 계약으로 assertion을 옮긴다.

## 16. 단계별 검증 명령

현재 머신은 기본 `xcode-select`가 Command Line Tools를 가리키므로 Xcode toolchain을 명시한다.

```bash
# 빠른 관련 테스트
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter 'GazeRowTests.(OverlayKeyboardCommandRouterTests|OverlayWindowControllerTests|OverlaySessionControllerTests|CachingScannerTests|OverlayLayoutEngineTests)'

# 전체 테스트
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# 실제 앱 평가
scripts/evaluate_overlay_target.sh --bundle-id com.apple.finder --timeout 6 --no-label-map
scripts/evaluate_query_overlay.sh --target-bundle-id com.microsoft.VSCode --query explorer --expect-scope elements
scripts/evaluate_query_overlay.sh --window-query code --expect-app com.microsoft.VSCode
```

각 티켓 완료 후 `git diff --check`를 실행한다. 전체 테스트는 FL-001, FL-003, FL-002, FL-004 완료 시점마다 실행한다.

## 17. 티켓 완료 보고 형식

구현 에이전트는 티켓마다 이 문서의 checkbox를 갱신하고 아래 내용을 보고한다.

```text
완료 티켓: TICKET-FL-XXX
변경 파일: ...
핵심 동작: ...
추가/수정 테스트: ...
테스트 결과: N tests, 0 failures
남은 위험: ...
다음 티켓: TICKET-FL-YYY
```

모든 티켓이 끝나기 전 완료 처리하거나 커밋하지 않는다. 커밋은 사용자의 별도 요청이 있을 때만 수행한다.

---

@author suho.do
@since 2026-07-13
