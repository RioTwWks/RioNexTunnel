#include "native_messaging.h"

#include "desktop_core.h"
#include "native_messaging_config.h"

#include <shlobj.h>
#include <windows.h>

#include <chrono>
#include <cstdint>
#include <fstream>
#include <map>
#include <sstream>
#include <vector>

namespace v2ray_box {
namespace {

constexpr int kExtensionPingMaxAgeSeconds = 120;

bool FileExists(const std::string& path) {
  const DWORD attrs = GetFileAttributesA(path.c_str());
  return attrs != INVALID_FILE_ATTRIBUTES &&
         (attrs & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

bool IsExecutable(const std::string& path) { return FileExists(path); }

std::string JsonEscape(const std::string& value) {
  std::string escaped;
  for (const char ch : value) {
    switch (ch) {
      case '\\': escaped += "\\\\"; break;
      case '"': escaped += "\\\""; break;
      case '\n': escaped += "\\n"; break;
      case '\r': escaped += "\\r"; break;
      case '\t': escaped += "\\t"; break;
      default: escaped += ch; break;
    }
  }
  return escaped;
}

std::string JsonEscapePath(const std::string& path) {
  std::string escaped;
  for (const char ch : path) escaped += (ch == '\\') ? "\\\\" : std::string(1, ch);
  return escaped;
}

bool WritePrivateFile(const std::string& path, const std::string& content) {
  std::ofstream out(path, std::ios::trunc | std::ios::binary);
  if (!out.is_open()) return false;
  out << content;
  return out.good();
}

bool CopyBinary(const std::string& source, const std::string& destination) {
  return CopyFileA(source.c_str(), destination.c_str(), FALSE) && FileExists(destination);
}

std::string ManifestDirectory() {
  return JoinPath(NativeMessaging::NativeHostDirectory(), "manifests");
}

std::string ChromeManifestFilePath() {
  return JoinPath(ManifestDirectory(), std::string(kNativeMessagingHostName) + "_chrome.json");
}

std::string EdgeManifestFilePath() {
  return JoinPath(ManifestDirectory(), std::string(kNativeMessagingHostName) + "_edge.json");
}

std::string FirefoxManifestFilePath() {
  wchar_t* app_data = nullptr;
  if (SHGetKnownFolderPath(FOLDERID_RoamingAppData, 0, nullptr, &app_data) != S_OK) return "";
  std::wstring wide(app_data);
  CoTaskMemFree(app_data);
  char narrow[MAX_PATH];
  if (WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, narrow, MAX_PATH, nullptr, nullptr) <= 0) return "";
  return JoinPath(JoinPath(JoinPath(narrow, "Mozilla"), "native-messaging-hosts"),
                  std::string(kNativeMessagingHostName) + ".json");
}

bool WriteNativeManifest(const std::string& path, const std::string& host_path, bool firefox) {
  if (!EnsureDirectory(NativeMessaging::NativeHostDirectory()) || !EnsureDirectory(ManifestDirectory())) return false;
  const auto slash = path.find_last_of("\\/");
  if (slash != std::string::npos && !EnsureDirectory(path.substr(0, slash))) return false;
  std::ostringstream json;
  json << "{\n  \"name\": \"" << kNativeMessagingHostName << "\",\n";
  json << "  \"description\": \"RioNexTunnel proxy auth bridge\",\n";
  json << "  \"path\": \"" << JsonEscapePath(host_path) << "\",\n  \"type\": \"stdio\"\n";
  if (firefox) json << "  ,\"allowed_extensions\": [ \"" << kFirefoxExtensionId << "\" ]\n";
  else json << "  ,\"allowed_origins\": [ \"chrome-extension://" << kChromeExtensionId << "/\" ]\n";
  json << "}\n";
  return WritePrivateFile(path, json.str());
}

bool SetRegistryManifestPath(const char* key_path, const std::string& manifest_path) {
  HKEY key = nullptr;
  if (RegCreateKeyExA(HKEY_CURRENT_USER, key_path, 0, nullptr, REG_OPTION_NON_VOLATILE,
                      KEY_WRITE, nullptr, &key, nullptr) != ERROR_SUCCESS || !key) return false;
  const LONG set_result = RegSetValueExA(key, nullptr, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(manifest_path.c_str()),
      static_cast<DWORD>(manifest_path.size() + 1));
  RegCloseKey(key);
  return set_result == ERROR_SUCCESS;
}

bool RegistryManifestInstalled(const char* key_path) {
  HKEY key = nullptr;
  if (RegOpenKeyExA(HKEY_CURRENT_USER, key_path, 0, KEY_READ, &key) != ERROR_SUCCESS) return false;
  char buffer[MAX_PATH];
  DWORD buffer_size = sizeof(buffer), type = 0;
  const LONG query_result = RegQueryValueExA(key, nullptr, nullptr, &type,
      reinterpret_cast<LPBYTE>(buffer), &buffer_size);
  RegCloseKey(key);
  return query_result == ERROR_SUCCESS && type == REG_SZ && FileExists(std::string(buffer));
}

std::string FindBundledNativeHostBinary() {
  const std::string candidate = JoinPath(GetExecutableDirectory(), "secure_vpn_native_host.exe");
  return IsExecutable(candidate) ? candidate : "";
}

int64_t ReadPingTimestamp() {
  std::ifstream in(NativeMessaging::ExtensionPingPath());
  if (!in.is_open()) return 0;
  int64_t value = 0; in >> value; return value;
}

}  // namespace

std::string NativeMessaging::NativeHostDirectory() { return JoinPath(GetWorkingDirectory(), "native_host"); }
std::string NativeMessaging::NativeHostBinaryPath() { return JoinPath(NativeHostDirectory(), "secure_vpn_native_host.exe"); }
std::string NativeMessaging::SessionCredentialsPath() { return JoinPath(NativeHostDirectory(), "session.json"); }
std::string NativeMessaging::ExtensionPingPath() { return JoinPath(NativeHostDirectory(), "extension_ping"); }

bool NativeMessaging::InstallHost(const std::string& source_binary_path) {
  const std::string source = source_binary_path.empty() ? FindBundledNativeHostBinary() : source_binary_path;
  if (source.empty() || !EnsureDirectory(NativeHostDirectory())) return false;
  return CopyBinary(source, NativeHostBinaryPath());
}

bool NativeMessaging::InstallManifests() {
  const std::string host_path = NativeHostBinaryPath();
  if (!IsExecutable(host_path)) return false;
  bool ok = true;
  const std::string chrome_manifest = ChromeManifestFilePath();
  const std::string edge_manifest = EdgeManifestFilePath();
  const std::string firefox_manifest = FirefoxManifestFilePath();
  if (!chrome_manifest.empty()) {
    ok = WriteNativeManifest(chrome_manifest, host_path, false) && ok;
    ok = SetRegistryManifestPath(("Software\\Google\\Chrome\\NativeMessagingHosts\\" + std::string(kNativeMessagingHostName)).c_str(), chrome_manifest) && ok;
  }
  if (!edge_manifest.empty()) {
    ok = WriteNativeManifest(edge_manifest, host_path, false) && ok;
    ok = SetRegistryManifestPath(("Software\\Microsoft\\Edge\\NativeMessagingHosts\\" + std::string(kNativeMessagingHostName)).c_str(), edge_manifest) && ok;
  }
  if (!firefox_manifest.empty()) ok = WriteNativeManifest(firefox_manifest, host_path, true) && ok;
  return ok;
}

bool NativeMessaging::PublishCredentials(const std::string& host, int port,
    const std::string& username, const std::string& password) {
  if (!EnsureDirectory(NativeHostDirectory())) return false;
  std::ostringstream json;
  json << "{\n  \"type\": \"credentials\",\n  \"host\": \"" << JsonEscape(host) << "\",\n";
  json << "  \"port\": " << port << ",\n  \"username\": \"" << JsonEscape(username) << "\",\n";
  json << "  \"password\": \"" << JsonEscape(password) << "\"\n}\n";
  return WritePrivateFile(SessionCredentialsPath(), json.str());
}

bool NativeMessaging::ClearCredentials() {
  RemoveFileIfExists(SessionCredentialsPath());
  RemoveFileIfExists(ExtensionPingPath());
  return true;
}

std::map<std::string, bool> NativeMessaging::GetBrowserHelperStatus() {
  std::map<std::string, bool> status;
  status["hostInstalled"] = IsExecutable(NativeHostBinaryPath());
  const bool chrome_manifest = RegistryManifestInstalled(("Software\\Google\\Chrome\\NativeMessagingHosts\\" + std::string(kNativeMessagingHostName)).c_str());
  const bool edge_manifest = RegistryManifestInstalled(("Software\\Microsoft\\Edge\\NativeMessagingHosts\\" + std::string(kNativeMessagingHostName)).c_str());
  const std::string firefox_path = FirefoxManifestFilePath();
  const bool firefox_manifest = !firefox_path.empty() && FileExists(firefox_path);
  status["manifestInstalled"] = chrome_manifest || edge_manifest || firefox_manifest;
  status["chromeManifestInstalled"] = chrome_manifest;
  status["chromiumManifestInstalled"] = edge_manifest;
  status["firefoxManifestInstalled"] = firefox_manifest;
  status["credentialsActive"] = FileExists(SessionCredentialsPath());
  const int64_t ping_ts = ReadPingTimestamp();
  const int64_t now_sec = std::chrono::duration_cast<std::chrono::seconds>(
      std::chrono::system_clock::now().time_since_epoch()).count();
  status["extensionConnected"] = ping_ts > 0 && (now_sec - ping_ts) <= kExtensionPingMaxAgeSeconds;
  status["ready"] = status["hostInstalled"] && status["manifestInstalled"] &&
                    status["extensionConnected"] && status["credentialsActive"];
  return status;
}

}  // namespace v2ray_box
