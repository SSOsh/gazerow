# gazerow Distribution Checklist v1

## 변경 이력
- v2: Apple Developer Program 없이 배포하는 Universal ZIP 베타 흐름과 검증 상태를 추가.
- v1: TICKET-011 freeze package의 code signing/notarization 체크리스트를 별도 문서로 구체화.

## 1. 목적

이 문서는 gazerow를 로컬 MVP 밖으로 배포하기 전에 필요한 signing, notarization, privacy 문서 준비 항목을 정리한다.

현재 TICKET-011 로컬 MVP freeze의 완료 조건은 아니다. TICKET-010 결과가 GO 또는 CONDITIONAL-GO가 된 뒤 외부 배포를 검토할 때 사용한다.

## 2. 현재 적용 범위

현재 상태: `FREE_BETA_PACKAGING_READY`

무료 베타에서는 아래 항목을 제공한다.

- arm64 + x86_64 Universal `gazerow.app`
- ad-hoc signature + Hardened Runtime
- 버전이 포함된 ZIP과 SHA-256 체크섬
- 한·영 최초 실행 및 `Open Anyway` 안내
- ZIP 구조, 버전, bundle identifier, 아키텍처, 서명 자동 검증

무료 베타에서는 아래 항목을 하지 않는다.

- Developer ID signing
- notarization
- auto update
- telemetry/privacy policy 게시

생성 명령:

```bash
scripts/package_beta_release.sh
```

기본 산출물:

```text
.build/beta-release/gazerow-0.1.0-beta.1-macos-universal.zip
.build/beta-release/gazerow-0.1.0-beta.1-macos-universal.zip.sha256
```

## 3. Signing 체크리스트

| 항목 | 상태 | 메모 |
| --- | --- | --- |
| Apple Developer Program 계정 | Deferred | 무료 베타에는 사용하지 않음 |
| Team ID | TBD | signing 설정에 필요 |
| Developer ID Application 인증서 | TBD | App Store 외 배포 시 필요 |
| Bundle Identifier 확정 | Beta 완료 | `io.github.ssosh.gazerow` |
| Version/Build number 정책 | Beta 완료 | 기본 `0.1.0 (1)`, 환경변수로 주입 |
| Hardened Runtime | Beta 완료 | ad-hoc signature에도 적용 |
| Entitlements 파일 | Beta 완료 | 실험적 camera entitlement만 포함 |
| Sandbox 적용 여부 | TBD | AX 권한/메뉴바 앱 제약 검토 필요 |

## 4. Notarization 체크리스트

| 항목 | 상태 | 메모 |
| --- | --- | --- |
| archive/export 방식 결정 | Beta 완료 | SwiftPM Universal build + ZIP |
| `.app` bundle 산출물 생성 | Beta 완료 | `package_beta_release.sh` |
| `codesign --verify` 절차 | Beta 완료 | 패키징 후와 ZIP 재추출 후 검증 |
| `spctl --assess` 절차 | TBD | Gatekeeper 검증 |
| `notarytool submit` 계정 설정 | TBD | App Store Connect API key 또는 Apple ID |
| notarization staple | TBD | `xcrun stapler staple` |
| clean machine smoke test | TBD | 다운로드 후 최초 실행/권한 안내 확인 |

## 5. Privacy / Permission 문서 체크리스트

| 항목 | 상태 | 메모 |
| --- | --- | --- |
| Accessibility 권한 사용 설명 | draft | README/Onboarding 기반 |
| Camera 권한 미사용 설명 | draft | Post-MVP로 분리 |
| Screen Recording 미사용 설명 | draft | MVP 제외 |
| Interaction log opt-in 설명 | draft | raw title/text 미저장 명시 |
| Debug export 설명 | draft | debug UI 기본 숨김 |
| Log/export 삭제 방법 | draft | Settings 동선 |
| Privacy policy | TBD | 외부 배포 전 별도 문서 필요 |

## 6. 배포 전 차단 조건

외부 배포 전 반드시 해결할 항목:

- [ ] TICKET-010 go/no-go 판정 완료
- [ ] TICKET-011 local MVP freeze 완료
- [ ] Bundle Identifier를 local placeholder에서 실제 identifier로 변경
- [ ] 권한 안내 문구 법무/제품 관점 검토
- [ ] crash/reporting/telemetry 사용 여부 결정
- [ ] updater 포함 여부 결정
- [ ] signing/notarization 자동화 여부 결정

## 7. 권장 검증 명령 초안

외부 배포용 `.app` 산출물 생성 뒤 아래 검증을 수행한다.

```bash
codesign --verify --deep --strict --verbose=2 gazerow.app
spctl --assess --type execute --verbose=4 gazerow.app
xcrun stapler validate gazerow.app
```

무료 베타 산출 방식은 확정됐다. 정식 배포 전에는 Developer ID signing,
notarization, staple과 clean-machine smoke를 별도로 완료해야 한다.

---

@author suho.do
@since 2026-07-02
