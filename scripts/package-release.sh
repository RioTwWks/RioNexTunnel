#!/usr/bin/env bash
# Package flutter build output into release archives (RioGram-style naming).
#
# Usage: ./scripts/package-release.sh <platform> <version> <output_dir>
#   platform: linux | macos | android | ios
#   version:  e.g. 0.2.0 (without v prefix)
#
# Windows packaging is handled by package-release.ps1.
set -euo pipefail

PLATFORM="${1:?platform required}"
VERSION="${2:?version required}"
OUT_DIR="${3:?output dir required}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${APP_DIR:-secure_vpn_client}"
mkdir -p "${ROOT_DIR}/${OUT_DIR}"
OUT_DIR="$(cd "${ROOT_DIR}/${OUT_DIR}" && pwd)"

NAME="RioNexTunnel-${VERSION}"
APP_ROOT="${ROOT_DIR}/${APP_DIR}"

case "${PLATFORM}" in
  linux)
    bundle_dir="${APP_ROOT}/build/linux/x64/release/bundle"
    top_dir="${NAME}-linux-x64"
    if tar --help 2>&1 | grep -q one-top-level; then
      tar --one-top-level="${top_dir}" -czf "${OUT_DIR}/${NAME}-linux-x64.tar.gz" \
        -C "${bundle_dir}" .
    else
      tar -czf "${OUT_DIR}/${NAME}-linux-x64.tar.gz" -C "${bundle_dir}" .
    fi
    ;;
  macos)
    release_dir="${APP_ROOT}/build/macos/Build/Products/Release"
    app_name="$(find "${release_dir}" -maxdepth 1 -name '*.app' -type d -printf '%f\n' | head -n 1)"
    if [[ -z "${app_name}" ]]; then
      echo "package-release.sh: no .app bundle found in ${release_dir}" >&2
      ls -la "${release_dir}" || true
      exit 1
    fi
    macos_arch="$(uname -m)"
    (cd "${release_dir}" && zip -qr "${OUT_DIR}/${NAME}-macos-${macos_arch}.zip" "${app_name}")
    ;;
  android)
    apk_dir="${APP_ROOT}/build/app/outputs/flutter-apk"
    if [[ -f "${apk_dir}/app-arm64-v8a-release.apk" ]]; then
      cp "${apk_dir}/app-arm64-v8a-release.apk" \
        "${OUT_DIR}/${NAME}-android-arm64.apk"
    fi
    if [[ -f "${apk_dir}/app-armeabi-v7a-release.apk" ]]; then
      cp "${apk_dir}/app-armeabi-v7a-release.apk" \
        "${OUT_DIR}/${NAME}-android-armv7.apk"
    fi
    if [[ -f "${apk_dir}/app-release.apk" ]]; then
      cp "${apk_dir}/app-release.apk" \
        "${OUT_DIR}/${NAME}-android-universal.apk"
    fi
    if [[ -f "${APP_ROOT}/build/app/outputs/bundle/release/app-release.aab" ]]; then
      cp "${APP_ROOT}/build/app/outputs/bundle/release/app-release.aab" \
        "${OUT_DIR}/${NAME}-android.aab"
    fi
    ;;
  ios)
    if compgen -G "${APP_ROOT}/build/ios/ipa/"*.ipa > /dev/null; then
      cp "${APP_ROOT}"/build/ios/ipa/*.ipa "${OUT_DIR}/${NAME}-ios.ipa"
    else
      app_path="$(find "${APP_ROOT}/build/ios/iphoneos" -maxdepth 1 -name '*.app' -type d | head -n 1)"
      if [[ -z "${app_path}" ]]; then
        echo "package-release.sh: iOS artifact not found (.ipa or .app)" >&2
        exit 1
      fi
      app_name="$(basename "${app_path}")"
      (cd "${APP_ROOT}/build/ios/iphoneos" && \
        zip -qr "${OUT_DIR}/${NAME}-ios-unsigned.zip" "${app_name}")
    fi
    ;;
  *)
    echo "package-release.sh: unknown platform ${PLATFORM} (windows uses package-release.ps1)" >&2
    exit 1
    ;;
esac

echo "Packaged ${PLATFORM} -> ${OUT_DIR}"
