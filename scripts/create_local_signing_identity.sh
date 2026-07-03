#!/usr/bin/env bash
# 로컬 개발용 self-signed code signing 인증서를 생성해 login keychain에 저장한다.
#
# adhoc 서명은 CDHash 기반이라 재빌드마다 TCC(Accessibility) 권한이 무효화된다.
# 안정적인 self-signed identity로 서명하면 TCC가 인증서 기반 Designated Requirement로
# 앱을 식별하므로, 재빌드 후 같은 인증서로 재서명하면 권한이 유지된다.
#
# 멱등: 동일 이름 인증서가 이미 있으면 아무 것도 하지 않는다.
#
# @author suho.do
# @since 2026-07-03
set -euo pipefail

IDENTITY_NAME="${IDENTITY_NAME:-GazeRow Local Signing}"
KEYCHAIN="${KEYCHAIN:-${HOME}/Library/Keychains/login.keychain-db}"
P12_PASSWORD="${P12_PASSWORD:-gazerow}"

if security find-certificate -c "${IDENTITY_NAME}" "${KEYCHAIN}" >/dev/null 2>&1; then
  echo "==> Signing identity already exists: ${IDENTITY_NAME}"
  exit 0
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

CONFIG="${WORK_DIR}/openssl.cnf"
cat > "${CONFIG}" <<EOF
[ req ]
distinguished_name = dn
x509_extensions = codesign_ext
prompt = no
[ dn ]
CN = ${IDENTITY_NAME}
[ codesign_ext ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

echo "==> Generating self-signed code signing certificate"
openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "${WORK_DIR}/key.pem" \
  -out "${WORK_DIR}/cert.pem" \
  -config "${CONFIG}" >/dev/null 2>&1

# macOS `security`는 OpenSSL 3.x 기본(AES-256/PBKDF2) PKCS12를 읽지 못하므로
# -legacy(RC2/3DES + SHA1 MAC) 형식으로 export 한다.
openssl pkcs12 -export -legacy \
  -inkey "${WORK_DIR}/key.pem" \
  -in "${WORK_DIR}/cert.pem" \
  -out "${WORK_DIR}/identity.p12" \
  -name "${IDENTITY_NAME}" \
  -passout "pass:${P12_PASSWORD}" >/dev/null 2>&1

echo "==> Importing identity into keychain: ${KEYCHAIN}"
security import "${WORK_DIR}/identity.p12" \
  -k "${KEYCHAIN}" \
  -P "${P12_PASSWORD}" \
  -T /usr/bin/codesign \
  -T /usr/bin/security >/dev/null

# codesign이 서명할 때 키체인 접근 프롬프트가 반복되지 않도록 partition list를 설정한다.
# 실패해도 서명은 가능(첫 서명 시 1회 프롬프트가 뜰 수 있음)하므로 무시한다.
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s -k "" "${KEYCHAIN}" >/dev/null 2>&1 || \
  echo "    (set-key-partition-list skipped; codesign may prompt once)"

echo "==> Done. Identity ready: ${IDENTITY_NAME}"
