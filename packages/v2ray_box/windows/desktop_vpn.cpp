#include "desktop_vpn.h"

#include "desktop_core.h"
#include "system_proxy.h"

#ifdef _WIN32
#include <iphlpapi.h>
#include <vector>
#include <windows.h>
#include <sddl.h>
#pragma comment(lib, "iphlpapi.lib")
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

#ifdef _WIN32
namespace {

bool AdapterNameLooksLikeTunnel(const wchar_t* friendly_name) {
  if (friendly_name == nullptr || friendly_name[0] == L'\0') {
    return false;
  }
  if (_wcsnicmp(friendly_name, L"xray", 4) == 0) {
    return true;
  }
  if (_wcsnicmp(friendly_name, L"rio", 3) == 0) {
    return true;
  }
  if (_wcsnicmp(friendly_name, L"tun", 3) == 0) {
    return true;
  }
  return false;
}

bool HasActiveWintunAdapter() {
  ULONG buffer_size = 15000;
  std::vector<BYTE> buffer(buffer_size);
  ULONG result = GetAdaptersAddresses(
      AF_UNSPEC, GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST, nullptr,
      reinterpret_cast<PIP_ADAPTER_ADDRESSES>(buffer.data()), &buffer_size);
  if (result == ERROR_BUFFER_OVERFLOW) {
    buffer.resize(buffer_size);
    result = GetAdaptersAddresses(
        AF_UNSPEC, GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST, nullptr,
        reinterpret_cast<PIP_ADAPTER_ADDRESSES>(buffer.data()), &buffer_size);
  }
  if (result != NO_ERROR) {
    return false;
  }

  for (auto* adapter =
           reinterpret_cast<PIP_ADAPTER_ADDRESSES>(buffer.data());
       adapter != nullptr; adapter = adapter->Next) {
    if (adapter->OperStatus != IfOperStatusUp) {
      continue;
    }
    if (adapter->Description != nullptr &&
        StrStrIW(adapter->Description, L"Wintun") != nullptr) {
      return true;
    }
    if (AdapterNameLooksLikeTunnel(adapter->FriendlyName)) {
      return true;
    }
  }
  return false;
}

}  // namespace
#endif

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

#ifdef _WIN32
bool WaitForWindowsTunReady(int timeout_ms) {
  if (timeout_ms <= 0) {
    return HasActiveWintunAdapter();
  }
  const ULONGLONG deadline =
      GetTickCount64() + static_cast<ULONGLONG>(timeout_ms);
  while (GetTickCount64() < deadline) {
    if (!DesktopCore::Instance().IsRunning()) {
      return false;
    }
    if (!DesktopCore::Instance().IsBridgeRunning()) {
      return false;
    }
    if (HasActiveWintunAdapter()) {
      return true;
    }
    Sleep(200);
  }
  return HasActiveWintunAdapter();
}
#endif

}  // namespace v2ray_box
