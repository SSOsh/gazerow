# gazerow 브랜드명 복원

> 작성: suho.do · 2026-07-16 · 상태: 완료

## 목표

사용자에게 노출되는 제품명과 앱 번들명을 소문자 `gazerow`로 통일한다.

## 호환성 원칙

- Swift 모듈·타입·소스 경로(`GazeRow`)는 대규모 rename 회귀를 막기 위해 유지한다.
- 기존 UserDefaults key, notification name, Application Support 디렉터리는 설정·데이터 유실을 막기 위해 유지한다.
- SwiftPM 실행 제품과 `.app` 번들·실행 파일명은 `gazerow`로 변경한다.

## 작업 목록

- [x] README 및 계획 문서 브랜드명 통일
- [x] 앱 UI·안내·디버그 내보내기 표시명 통일
- [x] SwiftPM 실행 제품과 로컬·배포 앱 번들명 변경
- [x] 브랜드 회귀 테스트 및 전체 검증

## 완료 조건

- README의 제목·명령·후원 표시가 `gazerow`다.
- 생성된 앱이 `gazerow.app/Contents/MacOS/gazerow`로 실행된다.
- Info.plist의 번들·표시 이름이 `gazerow`다.
- 메뉴, Settings, 권한 안내에 구 브랜드명이 노출되지 않는다.
