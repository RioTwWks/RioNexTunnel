#!/usr/bin/env bash
# CI helper: start xray with authenticated local SOCKS, run security_probe.sh, tear down.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORES_DIR="${ROOT_DIR}/secure_vpn_client/linux/runner/resources"
XRAY_BIN="${CORES_DIR}/xray"
PROBE="${ROOT_DIR}/scripts/security_probe.sh"
PORT="${SOCKS_PORT:-1080}"
USER="ci_probe_user_$$"
PASS="$(openssl rand -hex 12)"
CONFIG="$(mktemp --suffix=.json)"
PID=""

cleanup() {
  if [[ -n "${PID}" ]] && kill -0 "${PID}" 2>/dev/null; then
    kill "${PID}" 2>/dev/null || true
    wait "${PID}" 2>/dev/null || true
  fi
  rm -f "${CONFIG}"
}
trap cleanup EXIT

if [[ ! -x "${XRAY_BIN}" ]]; then
  echo "xray binary missing at ${XRAY_BIN}; run ./scripts/fetch_cores.sh first"
  exit 1
fi

cat >"${CONFIG}" <<EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "tag": "secure-socks-in",
    "listen": "127.0.0.1",
    "port": ${PORT},
    "protocol": "socks",
    "settings": {
      "auth": "password",
      "accounts": [{"user": "${USER}", "pass": "${PASS}"}]
    }
  }],
  "outbounds": [{"protocol": "freedom", "tag": "direct"}]
}
EOF

"${XRAY_BIN}" run -c "${CONFIG}" &
PID=$!

for _ in $(seq 1 30); do
  if curl --max-time 1 --socks5 "${USER}:${PASS}@127.0.0.1:${PORT}" \
    https://www.gstatic.com/generate_204 >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "${PID}" 2>/dev/null; then
    echo "xray exited before SOCKS became ready"
    exit 1
  fi
  sleep 0.5
done

SOCKS_HOST=127.0.0.1 SOCKS_PORT="${PORT}" SOCKS_USER="${USER}" SOCKS_PASS="${PASS}" \
  TARGET_URL=https://www.gstatic.com/generate_204 \
  bash "${PROBE}"

echo "CI security probe passed"
