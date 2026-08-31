#!/usr/bin/env bash
# Prepare Android release signing from environment variables (CI / local).
#
# Variables:
#   ANDROID_KEYSTORE_BASE64   — keystore (.jks) as base64
#   ANDROID_KEYSTORE_PASSWORD — keystore password
#   ANDROID_KEY_PASSWORD      — key password (defaults to store password)
#   ANDROID_KEY_ALIAS         — key alias (e.g. rionextunnel)
#
# Without ANDROID_KEYSTORE_BASE64 the script exits successfully and Gradle
# falls back to debug signing (local dev / CI without secrets).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="${ROOT_DIR}/secure_vpn_client/android"
KEYSTORE_PATH="${ANDROID_DIR}/app/rionextunnel-release.jks"
KEY_PROPERTIES="${ANDROID_DIR}/key.properties"

if [[ -z "${ANDROID_KEYSTORE_BASE64:-}" ]]; then
  echo "ANDROID_KEYSTORE_BASE64 is not set — release build will use debug signing"
  exit 0
fi

: "${ANDROID_KEYSTORE_PASSWORD:?Set ANDROID_KEYSTORE_PASSWORD}"
: "${ANDROID_KEY_ALIAS:?Set ANDROID_KEY_ALIAS}"

KEY_PASSWORD="${ANDROID_KEY_PASSWORD:-${ANDROID_KEYSTORE_PASSWORD}}"

echo "${ANDROID_KEYSTORE_BASE64}" | base64 --decode > "${KEYSTORE_PATH}"

cat > "${KEY_PROPERTIES}" <<EOF
storePassword=${ANDROID_KEYSTORE_PASSWORD}
keyPassword=${KEY_PASSWORD}
keyAlias=${ANDROID_KEY_ALIAS}
storeFile=${KEYSTORE_PATH}
EOF

echo "Android signing: key.properties and keystore prepared"
