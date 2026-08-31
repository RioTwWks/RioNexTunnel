#!/usr/bin/env bash
# Prepare iOS codesigning from environment variables (CI / local).
#
# Variables:
#   IOS_DISTRIBUTION_CERTIFICATE_BASE64 — Apple Distribution .p12 as base64
#   IOS_DISTRIBUTION_CERTIFICATE_PASSWORD
#   IOS_PROVISIONING_PROFILE_BASE64     — .mobileprovision as base64
#   IOS_DEVELOPMENT_TEAM                — Team ID (10 characters)
#   KEYCHAIN_PASSWORD                   — temporary keychain password
#   IOS_EXPORT_METHOD                   — app-store | ad-hoc | enterprise | development
#
# Without IOS_DISTRIBUTION_CERTIFICATE_BASE64 the script exits successfully and
# Flutter builds with --no-codesign.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="${ROOT_DIR}/secure_vpn_client/ios"

if [[ -z "${IOS_DISTRIBUTION_CERTIFICATE_BASE64:-}" ]]; then
  echo "IOS_DISTRIBUTION_CERTIFICATE_BASE64 is not set — iOS will build unsigned"
  exit 0
fi

: "${IOS_DISTRIBUTION_CERTIFICATE_PASSWORD:?Set IOS_DISTRIBUTION_CERTIFICATE_PASSWORD}"
: "${IOS_PROVISIONING_PROFILE_BASE64:?Set IOS_PROVISIONING_PROFILE_BASE64}"
: "${KEYCHAIN_PASSWORD:?Set KEYCHAIN_PASSWORD}"
: "${IOS_DEVELOPMENT_TEAM:?Set IOS_DEVELOPMENT_TEAM}"

KEYCHAIN_PATH="${RUNNER_TEMP:-/tmp}/rionextunnel-signing.keychain-db"
CERT_PATH="${RUNNER_TEMP:-/tmp}/rionextunnel-distribution.p12"
PROFILE_SRC="${RUNNER_TEMP:-/tmp}/rionextunnel.mobileprovision"
PROFILE_DIR="${HOME}/Library/MobileDevice/Provisioning Profiles"
EXPORT_METHOD="${IOS_EXPORT_METHOD:-app-store}"
BUNDLE_ID="com.example.secureVpnClient"

mkdir -p "${PROFILE_DIR}"
echo "${IOS_DISTRIBUTION_CERTIFICATE_BASE64}" | base64 --decode > "${CERT_PATH}"
echo "${IOS_PROVISIONING_PROFILE_BASE64}" | base64 --decode > "${PROFILE_SRC}"

security create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
security set-keychain-settings -lut 21600 "${KEYCHAIN_PATH}"
security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
security import "${CERT_PATH}" \
  -P "${IOS_DISTRIBUTION_CERTIFICATE_PASSWORD}" \
  -A -t cert -f pkcs12 \
  -k "${KEYCHAIN_PATH}"
security list-keychain -d user -s "${KEYCHAIN_PATH}" login.keychain
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"

PROFILE_PLIST="$(mktemp)"
security cms -D -i "${PROFILE_SRC}" > "${PROFILE_PLIST}"
PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print Name' "${PROFILE_PLIST}")"
PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print UUID' "${PROFILE_PLIST}")"
cp "${PROFILE_SRC}" "${PROFILE_DIR}/${PROFILE_UUID}.mobileprovision"
rm -f "${PROFILE_PLIST}"

cat > "${IOS_DIR}/Flutter/Signing.xcconfig" <<EOF
DEVELOPMENT_TEAM=${IOS_DEVELOPMENT_TEAM}
CODE_SIGN_STYLE=Manual
PROVISIONING_PROFILE_SPECIFIER=${PROFILE_NAME}
CODE_SIGN_IDENTITY=Apple Distribution
EOF

cat > "${IOS_DIR}/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>${EXPORT_METHOD}</string>
  <key>teamID</key>
  <string>${IOS_DEVELOPMENT_TEAM}</string>
  <key>uploadSymbols</key>
  <true/>
  <key>compileBitcode</key>
  <false/>
  <key>signingStyle</key>
  <string>manual</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>${BUNDLE_ID}</key>
    <string>${PROFILE_NAME}</string>
  </dict>
</dict>
</plist>
EOF

echo "iOS signing: keychain, profile \"${PROFILE_NAME}\", ExportOptions.plist (${EXPORT_METHOD})"
