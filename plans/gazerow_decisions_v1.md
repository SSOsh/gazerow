# GazeRow Decisions v1

## 변경 이력
- v1: `gazerow_mvp_v5.md`, `gazerow_tickets_v1.md`, `gazerow_evaluation_template_v1.md` 기준으로 구현 착수 전 결정값과 미결정 항목을 분리해 기록.
- v2: 외부 내부 사용자 3명 확보 불가로 내부 사용자 평가 gate를 local MVP freeze에서 Post-MVP로 defer하는 결정을 기록(ED-001 Deferred, ED-008 추가).

## 1. 상태 정의

| 상태 | 의미 |
| --- | --- |
| Accepted | 현재 계획에 반영된 결정 |
| Proposed | 권장안은 있으나 사용자 확인이 필요한 결정 |
| TBD | 아직 결정되지 않은 항목 |
| Deferred | MVP 이후로 미룬 결정 |
| Rejected | 명시적으로 하지 않기로 한 결정 |

## 2. Product Decisions

| ID | 항목 | 상태 | 결정값 | 근거/비고 |
| --- | --- | --- | --- | --- |
| PD-001 | 초기 사용자 | Accepted | macOS를 키보드 중심으로 쓰는 개발자 또는 파워유저 | 범용 접근성/의료 보조 제품으로 포지셔닝하지 않음 |
| PD-002 | MVP 포지셔닝 | Accepted | 로컬 macOS keyboard-click utility | 의료/보조공학 수준의 안전성과 인증 범위를 요구하지 않도록 명확히 함 |
| PD-003 | 앱 이름 | TBD | TBD | 메뉴바, bundle id, 권한 안내 문구에 필요 |
| PD-004 | 초기 지원 앱 | Accepted | Finder, Safari, Chrome, VS Code, System Settings | 5개 중 3개 task 성공을 MVP 기준으로 사용 |
| PD-005 | MVP 완료 기준 | Accepted | 초기 5개 앱 중 3개 이상 task 성공, 치명적 오클릭 0건, 내부 사용자 3명 중 2명 이상 기본 흐름 이해 | 기능 성공과 제품성 최소 기준을 함께 봄. 내부 사용자 조건은 ED-008에 따라 local MVP freeze에서 Post-MVP defer |
| PD-006 | Post-MVP 앱 후보 | Deferred | Slack, Discord, Obsidian, Notion | MVP 범위 과확장을 막기 위해 후순위 |
| PD-007 | Gaze 포지셔닝 | Accepted | MVP 필수 기능이 아니라 Post-MVP spike | Baseline이 쓸모 있는지 먼저 검증 |
| PD-008 | App Store 배포 | Rejected for MVP | MVP에서는 하지 않음 | notarization 이전의 로컬/외부 배포 검증이 먼저 |
| PD-009 | 결제/라이선스 | Rejected for MVP | MVP에서는 하지 않음 | 제품성 검증 전 수익화 제외 |

## 3. Technical Decisions

| ID | 항목 | 상태 | 결정값 | 근거/비고 |
| --- | --- | --- | --- | --- |
| TD-001 | 저장소 위치 | TBD | TBD | Swift app 생성 위치 결정 필요 |
| TD-002 | 앱 형태 | Proposed | 메뉴바 앱 + Settings window | 상시 실행 utility에 적합. 최종 확인 필요 |
| TD-003 | UI 기술 | Accepted | SwiftUI + AppKit | Settings는 SwiftUI, overlay/status item/AX integration은 AppKit 사용 |
| TD-004 | 기본 단축키 | Proposed | Command + Shift + Space | 충돌 가능성이 있어 설정 변경 가능해야 함 |
| TD-005 | 최소 macOS 버전 | TBD | TBD | Xcode target, API 사용 가능성, 평가 환경에 영향 |
| TD-006 | target app/window 결정 | Accepted | frontmost app + focused window 기반 | gaze 없이 baseline을 검증하기 위함 |
| TD-007 | clickable 후보 소스 | Accepted | Accessibility tree 우선 | Screen Recording/screenshot fallback은 MVP에서 제외 |
| TD-008 | click 실행 방식 | Accepted | `AXPress` 우선 | 좌표 클릭보다 안전하고 설명 가능 |
| TD-009 | `CGEventPost` fallback | Accepted | 기본 off, debug 또는 앱별 allowlist에서만 사용 | 오클릭 리스크를 낮추기 위함 |
| TD-010 | 실제 클릭 도입 시점 | Accepted | TICKET-007 전까지 실제 클릭 없음 | scanner/overlay/focus 안정화 후 도입 |
| TD-011 | 로그 저장 방식 | Accepted | Info 로그 가능, Interaction 파일 저장은 opt-in | 개인정보 최소화 |
| TD-012 | window title 처리 | Accepted | 원문 저장 금지, session salt hash만 허용 | 장기 식별자화 방지 |
| TD-013 | 텍스트 필드 처리 | Accepted | title/value/help/description은 런타임 조회만, 기본 로그/저장 제외 | 위험 판정과 개인정보 보호 균형 |

## 4. Permission Decisions

| ID | 항목 | 상태 | 결정값 | 근거/비고 |
| --- | --- | --- | --- | --- |
| PR-001 | Accessibility | Accepted | 첫 overlay activation 전 요청/안내 | AX tree 조회와 AXPress에 필요 |
| PR-002 | Input Monitoring | Proposed | 가능하면 지연 요청 | global key capture가 실제로 필요할 때 요청 |
| PR-003 | Camera | Deferred | Post-MVP gaze 기능을 켤 때만 요청 | Baseline MVP에서 불필요 |
| PR-004 | Screen Recording | Rejected for MVP | 요청하지 않음 | screenshot fallback 전까지 제외 |
| PR-005 | 권한 거부 시 동작 | Accepted | 앱 crash 없이 Settings/Help와 권한 안내만 제공 | 사용자가 가능한 기능/불가능한 기능을 알아야 함 |
| PR-006 | 권한 안내 방식 | Accepted | 데이터 접근 범위를 기능 가치보다 먼저 설명 | 신뢰와 개인정보 리스크 완화 |

## 5. Safety Decisions

| ID | 항목 | 상태 | 결정값 | 근거/비고 |
| --- | --- | --- | --- | --- |
| SD-001 | gaze-only click | Rejected | 하지 않음 | 오클릭 리스크가 큼 |
| SD-002 | keyboard confirm | Accepted | 모든 click은 명시적 key confirm 필요 | 자동 클릭 금지 |
| SD-003 | 위험도 분류 | Accepted | safeNavigation, stateChange, destructive, externalEffect, unknownRisk | 단순 keyword보다 안전 정책이 명확함 |
| SD-004 | second confirm 대상 | Accepted | destructive, externalEffect, unknownRisk | 위험도 불확실 시 보수적으로 처리 |
| SD-005 | secure field | Accepted | 후보에서 제외 | 민감 입력 영역 보호 |
| SD-006 | kill switch | Accepted | 메뉴바에 제공 | overlay/입력 처리 즉시 중단 경로 |
| SD-007 | click history | Accepted | 최근 10개는 세션 메모리만, 파일 저장은 debug opt-in | 복구 가능성과 개인정보 보호 균형 |
| SD-008 | undo 자동화 | Rejected | 자동화하지 않음 | 앱마다 semantics가 달라 위험 |

## 6. Evaluation Decisions

| ID | 항목 | 상태 | 결정값 | 근거/비고 |
| --- | --- | --- | --- | --- |
| ED-001 | 내부 평가자 수 | Deferred | 3명 (Post-MVP) | 외부 내부 사용자 확보 불가로 local MVP freeze에서는 평가를 Post-MVP로 defer. ED-008 참조 |
| ED-002 | 평가 앱 | Accepted | Finder, Safari, Chrome, VS Code, System Settings | MVP 기준 앱 |
| ED-003 | task 성공 기준 | Accepted | 앱별 고정 task 성공 | 주관 평가만으로 판단하지 않기 위함 |
| ED-004 | mouse baseline | Accepted | 동일 task를 mouse/trackpad와 GazeRow로 각각 측정 | 속도보다 흐름 유지 가치까지 판단 |
| ED-005 | overlay 품질 | Accepted | collision, label count, occlusion, readability, scaling 기록 | click success와 별도 평가 |
| ED-006 | abandoned attempt | Accepted | task당 1회 이하 목표 | 사용자가 포기하는 흐름을 제품성 실패로 봄 |
| ED-007 | go/no-go 양식 | Accepted | `gazerow_evaluation_template_v1.md` 사용 | 평가 결과를 일관되게 기록 |
| ED-008 | 내부 사용자 gate 처리 | Accepted | 외부 평가자 확보 불가 시 local MVP freeze에서 내부 사용자 3명 gate를 Post-MVP defer | 평가 결과를 지어내지 않기 위함. gate는 Post-MVP에서 재개. PD-005 완료 기준 중 내부 사용자 조건은 이 결정으로 유예 |

## 7. Release Decisions

| ID | 항목 | 상태 | 결정값 | 근거/비고 |
| --- | --- | --- | --- | --- |
| RD-001 | 로컬 MVP | Accepted | 우선 로컬 반복 실행 가능 상태로 freeze | 공개 배포 전 품질 확인 |
| RD-002 | 외부 배포 | Deferred | Gate C 통과 후 검토 | 권한/오클릭/문서화 기준 필요 |
| RD-003 | Developer ID signing | Deferred | 공개 배포 전 확인 | Gate C 항목 |
| RD-004 | notarization | Deferred | 공개 배포 전 성공 필요 | Gatekeeper 경고 방지 |
| RD-005 | updater | Rejected for MVP | Sparkle 등 updater는 MVP 외부 | 보안 검토 필요 |
| RD-006 | telemetry | Rejected for MVP | 외부 전송 telemetry 없음 | 개인정보 리스크 완화 |

## 8. Open Questions

구현 착수 전 답해야 하는 질문:

1. 앱 이름은 무엇으로 할 것인가?
2. Swift app 저장소 위치는 어디로 할 것인가?
3. 앱 형태를 메뉴바 앱으로 확정할 것인가?
4. 기본 단축키 `Command + Shift + Space`를 그대로 쓸 것인가?
5. 최소 macOS 버전은 무엇으로 둘 것인가?
6. 내부 평가자 3명을 확보할 수 있는가?
7. 초기 외부 배포를 목표로 할 것인가, 로컬 도구로만 유지할 것인가?
8. TICKET-001 완료 후 바로 TICKET-002로 갈 것인가, README/문구 초안을 먼저 만들 것인가?

## 9. Next Decision Checkpoint

TICKET-001 착수 전 반드시 확정:

- PD-003 앱 이름
- TD-001 저장소 위치
- TD-002 앱 형태
- TD-004 기본 단축키
- TD-005 최소 macOS 버전

TICKET-010 착수 전 반드시 확정:

- ED-001 내부 평가자 3명
- 평가 환경 macOS 버전
- mouse/trackpad baseline 측정 방식

Gate C 검토 전 반드시 확정:

- RD-002 외부 배포 여부
- RD-003 Developer ID signing
- RD-004 notarization
