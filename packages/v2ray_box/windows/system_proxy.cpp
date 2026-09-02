#include "system_proxy.h"

#include "desktop_core.h"

#include <wininet.h>

#include <fstream>
#include <sstream>
#include <string>

namespace v2ray_box {
namespace {

constexpr const char* kInternetSettingsKey =
    "Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings";

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return L"";
  }
  const int size =
      MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, nullptr, 0);
  if (size <= 0) {
    return L"";
  }
  std::wstring wide(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, wide.data(), size);
  if (!wide.empty() && wide.back() == L'\0') {
    wide.pop_back();
  }
  return wide;
}

std::string BackupPath() {
  return JoinPath(GetWorkingDirectory(), "proxy_backup.env");
}

void WriteBackup(const std::string& content) {
  std::ofstream out(BackupPath(), std::ios::trunc);
  if (!out.is_open()) {
    return;
  }
  out << content;
}

std::string ReadBackup() {
  std::ifstream in(BackupPath());
  if (!in.is_open()) {
    return "";
  }
  std::ostringstream buffer;
  buffer << in.rdbuf();
  return buffer.str();
}

void RemoveBackup() {
  RemoveFileIfExists(BackupPath());
}

void RefreshProxySettings() {
  InternetSetOptionW(nullptr, INTERNET_OPTION_SETTINGS_CHANGED, nullptr, 0);
  InternetSetOptionW(nullptr, INTERNET_OPTION_REFRESH, nullptr, 0);
}

bool ReadDword(HKEY key, const wchar_t* name, DWORD* value) {
  DWORD type = 0;
  DWORD size = sizeof(DWORD);
  return RegQueryValueExW(key, name, nullptr, &type,
                          reinterpret_cast<LPBYTE>(value),
                          &size) == ERROR_SUCCESS &&
         type == REG_DWORD;
}

bool ReadString(HKEY key, const wchar_t* name, std::string* value) {
  wchar_t buffer[1024];
  DWORD type = 0;
  DWORD size = sizeof(buffer);
  if (RegQueryValueExW(key, name, nullptr, &type,
                       reinterpret_cast<LPBYTE>(buffer),
                       &size) != ERROR_SUCCESS ||
      type != REG_SZ) {
    return false;
  }
  const int utf8_size =
      WideCharToMultiByte(CP_UTF8, 0, buffer, -1, nullptr, 0, nullptr, nullptr);
  if (utf8_size <= 0) {
    return false;
  }
  std::string utf8(static_cast<size_t>(utf8_size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, buffer, -1, utf8.data(), utf8_size, nullptr,
                      nullptr);
  if (!utf8.empty() && utf8.back() == '\0') {
    utf8.pop_back();
  }
  *value = utf8;
  return true;
}

void BackupCurrentSettings() {
  HKEY key = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, Utf8ToWide(kInternetSettingsKey).c_str(),
                    0, KEY_READ, &key) != ERROR_SUCCESS) {
    return;
  }

  DWORD proxy_enable = 0;
  std::string proxy_server;
  std::string proxy_override;
  ReadDword(key, L"ProxyEnable", &proxy_enable);
  ReadString(key, L"ProxyServer", &proxy_server);
  ReadString(key, L"ProxyOverride", &proxy_override);
  RegCloseKey(key);

  std::ostringstream backup;
  backup << "proxy_enable=" << proxy_enable << '\n';
  backup << "proxy_server=" << proxy_server << '\n';
  backup << "proxy_override=" << proxy_override << '\n';
  WriteBackup(backup.str());
}

}  // namespace

bool ConfigOptionsSetSystemProxy(const std::string& json) {
  return json.find("\"set-system-proxy\":true") != std::string::npos ||
         json.find("\"set-system-proxy\": true") != std::string::npos;
}

bool SystemProxy::IsSupported() {
  HKEY key = nullptr;
  const bool supported =
      RegOpenKeyExW(HKEY_CURRENT_USER, Utf8ToWide(kInternetSettingsKey).c_str(),
                    0, KEY_READ, &key) == ERROR_SUCCESS;
  if (key != nullptr) {
    RegCloseKey(key);
  }
  return supported;
}

bool SystemProxy::Enable(const std::string& host,
                         int port,
                         const std::string& username,
                         const std::string& password) {
  if (!IsSupported() || port <= 0 || host.empty()) {
    return false;
  }

  if (ReadBackup().empty()) {
    BackupCurrentSettings();
  }

  HKEY key = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, Utf8ToWide(kInternetSettingsKey).c_str(),
                    0, KEY_SET_VALUE, &key) != ERROR_SUCCESS) {
    return false;
  }

  const std::string proxy_server = host + ":" + std::to_string(port);
  const DWORD proxy_enable = 1;
  const std::wstring proxy_server_wide = Utf8ToWide(proxy_server);

  RegSetValueExW(key, L"ProxyEnable", 0, REG_DWORD,
                 reinterpret_cast<const BYTE*>(&proxy_enable), sizeof(proxy_enable));
  RegSetValueExW(key, L"ProxyServer", 0, REG_SZ,
                 reinterpret_cast<const BYTE*>(proxy_server_wide.c_str()),
                 static_cast<DWORD>((proxy_server_wide.size() + 1) * sizeof(wchar_t)));

  // Chromium on Windows ignores stored proxy passwords; credentials remain
  // available in the app UI and via the SOCKS inbound on 127.0.0.1:1080.
  (void)username;
  (void)password;

  RegCloseKey(key);
  RefreshProxySettings();
  return true;
}

bool SystemProxy::Disable() {
  if (!IsSupported()) {
    return false;
  }

  const std::string backup = ReadBackup();
  HKEY key = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, Utf8ToWide(kInternetSettingsKey).c_str(),
                    0, KEY_SET_VALUE, &key) != ERROR_SUCCESS) {
    return false;
  }

  if (backup.empty()) {
    const DWORD proxy_enable = 0;
    RegSetValueExW(key, L"ProxyEnable", 0, REG_DWORD,
                   reinterpret_cast<const BYTE*>(&proxy_enable),
                   sizeof(proxy_enable));
    RegCloseKey(key);
    RefreshProxySettings();
    return true;
  }

  DWORD proxy_enable = 0;
  std::string proxy_server;
  std::string proxy_override;

  std::istringstream stream(backup);
  std::string line;
  while (std::getline(stream, line)) {
    const auto pos = line.find('=');
    if (pos == std::string::npos) {
      continue;
    }
    const std::string key_name = line.substr(0, pos);
    const std::string value = line.substr(pos + 1);
    if (key_name == "proxy_enable") {
      proxy_enable = static_cast<DWORD>(std::stoul(value));
    } else if (key_name == "proxy_server") {
      proxy_server = value;
    } else if (key_name == "proxy_override") {
      proxy_override = value;
    }
  }

  RegSetValueExW(key, L"ProxyEnable", 0, REG_DWORD,
                 reinterpret_cast<const BYTE*>(&proxy_enable), sizeof(proxy_enable));

  if (!proxy_server.empty()) {
    const std::wstring proxy_server_wide = Utf8ToWide(proxy_server);
    RegSetValueExW(key, L"ProxyServer", 0, REG_SZ,
                   reinterpret_cast<const BYTE*>(proxy_server_wide.c_str()),
                   static_cast<DWORD>((proxy_server_wide.size() + 1) *
                                      sizeof(wchar_t)));
  }

  if (!proxy_override.empty()) {
    const std::wstring proxy_override_wide = Utf8ToWide(proxy_override);
    RegSetValueExW(key, L"ProxyOverride", 0, REG_SZ,
                   reinterpret_cast<const BYTE*>(proxy_override_wide.c_str()),
                   static_cast<DWORD>((proxy_override_wide.size() + 1) *
                                      sizeof(wchar_t)));
  }

  RegCloseKey(key);
  RefreshProxySettings();
  RemoveBackup();
  return true;
}

}  // namespace v2ray_box
