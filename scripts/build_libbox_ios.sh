#!/usr/bin/env bash
# Build Libbox.xcframework for iOS from official sing-box source (gomobile).
#
# Required on macOS with Xcode. Installs the framework into:
#   packages/v2ray_box/ios/Frameworks/Libbox.xcframework
#   secure_vpn_client/ios/Frameworks/Libbox.xcframework
#
# Env:
#   SINGBOX_VERSION — sing-box release tag without "v" (default: 1.14.0)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SINGBOX_VERSION="${SINGBOX_VERSION:-1.14.0}"
PLUGIN_FW="${ROOT_DIR}/packages/v2ray_box/ios/Frameworks/Libbox.xcframework"
APP_FW="${ROOT_DIR}/secure_vpn_client/ios/Frameworks/Libbox.xcframework"
WORK_DIR="$(mktemp -d)"
GOMOBILE_VERSION="v0.1.12"

cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

if [[ -d "${PLUGIN_FW}" ]] && [[ -f "${PLUGIN_FW}/Info.plist" ]]; then
  echo "Libbox.xcframework already present at ${PLUGIN_FW}"
  exit 0
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Libbox.xcframework build requires macOS (Xcode + gomobile)" >&2
  exit 1
fi

echo "Building Libbox.xcframework for iOS (sing-box v${SINGBOX_VERSION})..."

export GOTOOLCHAIN="${GOTOOLCHAIN:-auto}"
go install "github.com/sagernet/gomobile/cmd/gomobile@${GOMOBILE_VERSION}"
go install "github.com/sagernet/gomobile/cmd/gobind@${GOMOBILE_VERSION}"
export PATH="${HOME}/go/bin:${PATH}"
gomobile init

git clone --depth 1 --branch "v${SINGBOX_VERSION}" \
  https://github.com/SagerNet/sing-box.git "${WORK_DIR}/sing-box"
cd "${WORK_DIR}/sing-box"

go run ./cmd/internal/build_libbox -target apple -platform ios

if [[ ! -d "Libbox.xcframework" ]]; then
  echo "Libbox.xcframework was not produced by build_libbox" >&2
  exit 1
fi

# gomobile may emit macOS-style Versions/A layouts; iOS requires shallow frameworks.
for framework in Libbox.xcframework/ios-*/Libbox.framework; do
  if [[ -d "${framework}/Versions/A" ]]; then
    shallow="${framework}.shallow"
    rm -rf "${shallow}"
    ditto "${framework}/Versions/A" "${shallow}"
    rm -rf "${framework}"
    mv "${shallow}" "${framework}"
  fi
done

mkdir -p "$(dirname "${PLUGIN_FW}")" "$(dirname "${APP_FW}")"
rm -rf "${PLUGIN_FW}" "${APP_FW}"
cp -R Libbox.xcframework "${PLUGIN_FW}"
cp -R Libbox.xcframework "${APP_FW}"

echo "Installed Libbox.xcframework:"
echo "  ${PLUGIN_FW}"
echo "  ${APP_FW}"
