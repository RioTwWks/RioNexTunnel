#include "desktop_vpn.h"

#include "system_proxy.h"

#include <cstdio>
#include <memory>
#include <unistd.h>

namespace v2ray_box {
namespace {

bool BinaryHasCapNetAdmin(const std::string& binary_path) {
  if (binary_path.empty()) {
    return false;
  }
  std::string command = "getcap \"";
  for (const char ch : binary_path) {
    if (ch == '"') {
      command += '\\';
    }
    command += ch;
  }
  command += "\" 2>/dev/null";
  std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(command.c_str(), "r"),
                                                pclose);
  if (!pipe) {
    return false;
  }
  char buffer[512];
  std::string output;
  while (fgets(buffer, sizeof(buffer), pipe.get()) != nullptr) {
    output += buffer;
  }
  return output.find("cap_net_admin") != std::string::npos;
}

bool DesktopVpnActive(const std::string& service_mode,
                      const std::string& config_options_json) {
  return IsVpnServiceMode(service_mode) &&
         ConfigOptionsEnableTun(config_options_json);
}

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
  if (geteuid() == 0) {
    return "";
  }
  if (BinaryHasCapNetAdmin(core_binary_path)) {
    return "";
  }
  return "Desktop VPN (TUN) needs CAP_NET_ADMIN on the core binary. "
         "Example: sudo setcap cap_net_admin+ep \"" +
         core_binary_path + "\"";
}

}  // namespace v2ray_box
