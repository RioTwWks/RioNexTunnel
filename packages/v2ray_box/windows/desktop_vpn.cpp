#include "desktop_vpn.h"

#include "system_proxy.h"

#ifdef _WIN32
#include <windows.h>
#include <sddl.h>
#endif

namespace v2ray_box {
namespace {

bool DesktopVpnActive(const std::string& service_mode,
                      const std::string& config_options_json) {
  return IsVpnServiceMode(service_mode) &&
         ConfigOptionsEnableTun(config_options_json);
}

#ifdef _WIN32
bool IsProcessElevated() {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) {
    return false;
  }
  TOKEN_ELEVATION elevation {};
  DWORD size = 0;
  const BOOL ok = GetTokenInformation(token, TokenElevation, &elevation,
                                      sizeof(elevation), &size);
  CloseHandle(token);
  return ok && elevation.TokenIsElevated;
}
#endif

}  // namespace

bool IsVpnServiceMode(const std::string& service_mode) {
  return service_mode == "vpn";
}

bool ConfigOptionsEnableTun(const std::string& json) {
  if (json.find("\"enable-tun\":false") != std::string::npos ||
      json.find("\"enable-tun\": false") != std::string::npos) {
    return false;
  }
  return true;
}

bool ShouldUseSystemProxy(const std::string& service_mode,
                          const std::string& config_options_json) {
  if (DesktopVpnActive(service_mode, config_options_json)) {
    return false;
  }
  return ConfigOptionsSetSystemProxy(config_options_json);
}

std::string ValidateDesktopVpnStart(const std::string& service_mode,
                                    const std::string& config_options_json,
                                    const std::string& engine,
                                    const std::string& core_binary_path) {
  if (!DesktopVpnActive(service_mode, config_options_json)) {
    return "";
  }
  if (engine == "skadi") {
    return "SkadiCore desktop VPN is not supported. Use sing-box or Xray.";
  }
  if (core_binary_path.empty()) {
    return "Core binary not found. Run scripts/fetch_cores.sh.";
  }
#ifdef _WIN32
  if (!IsProcessElevated()) {
    return "Desktop VPN (TUN) on Windows requires running RioNexTunnel as "
           "Administrator.";
  }
#endif
  return "";
}

}  // namespace v2ray_box
