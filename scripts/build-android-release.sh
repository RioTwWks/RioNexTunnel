#!/usr/bin/env bash
# Build signed Android release artifacts for CI / local release packaging.
#
# Reads version from RELEASE_TAG (e.g. v0.2.4) or first argument (e.g. 0.2.4).
# Produces split-per-abi APKs, a universal APK, and an App Bundle.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${APP_DIR:-secure_vpn_client}"
RAW_VERSION="${1:-${RELEASE_TAG:-}}"
RAW_VERSION="${RAW_VERSION#v}"
# Drop Flutter build suffix (e.g. 0.2.6+12) before semver parsing.
RAW_VERSION="${RAW_VERSION%%+*}"

if [[ -z "${RAW_VERSION}" ]]; then
  echo "build-android-release.sh: version required (arg or RELEASE_TAG)" >&2
  exit 1
fi

# Use cut so extra semver segments never merge into PATCH (bash read joins leftovers).
MAJOR="$(cut -d. -f1 <<< "${RAW_VERSION}")"
MINOR="$(cut -d. -f2 <<< "${RAW_VERSION}")"
PATCH="$(cut -d. -f3 <<< "${RAW_VERSION}")"
MAJOR="${MAJOR:-0}"
MINOR="${MINOR:-0}"
PATCH="${PATCH:-0}"
BUILD_NUMBER=$(( MAJOR * 10000 + MINOR * 100 + PATCH ))

if (( BUILD_NUMBER < 1 )); then
  BUILD_NUMBER=1
fi

echo "Android release build: versionName=${RAW_VERSION}, versionCode=${BUILD_NUMBER}"

cd "${ROOT_DIR}/${APP_DIR}"
flutter pub get

COMMON_FLAGS=(--release --build-name="${RAW_VERSION}" --build-number="${BUILD_NUMBER}")

flutter build apk "${COMMON_FLAGS[@]}" --split-per-abi
flutter build apk "${COMMON_FLAGS[@]}"
flutter build appbundle "${COMMON_FLAGS[@]}"

APK_DIR="${ROOT_DIR}/${APP_DIR}/build/app/outputs/flutter-apk"
BUILD_TOOLS="$(ls -d "${ANDROID_HOME}/build-tools"/* 2>/dev/null | sort -V | tail -n 1 || true)"

if [[ -n "${BUILD_TOOLS}" && -d "${BUILD_TOOLS}" ]]; then
  for apk in "${APK_DIR}"/*-release.apk; do
    [[ -f "${apk}" ]] || continue
    echo "Verifying ${apk}"
    "${BUILD_TOOLS}/zipalign" -c -v 4 "${apk}"
    "${BUILD_TOOLS}/apksigner" verify --verbose "${apk}"
  done
else
  echo "Warning: Android build-tools not found; skipping APK verification" >&2
fi

echo "Android release artifacts:"
ls -la "${APK_DIR}"/*-release.apk "${ROOT_DIR}/${APP_DIR}/build/app/outputs/bundle/release/"*.aab
