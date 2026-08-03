#include "native_messaging.h"

#include "desktop_core.h"
#include "native_messaging_config.h"

#include <sys/stat.h>
#include <unistd.h>

#include <cerrno>
#include <vector>
#include <chrono>
#include <cstring>
#include <fstream>
#include <map>
#include <sstream>

namespace v2ray_box {
namespace {

constexpr int kExtensionPingMaxAgeSeconds = 120;

bool SetPrivateFileMode(const std::string& path, mode_t mode) {
  return chmod(path.c_str(), mode) == 0;
}

bool WritePrivateFile(const std::string& path, const std::string& content) {
  std::ofstream out(path, std::ios::trunc);
  if (!out.is_open()) {
    return false;
  }
  out << content;
  out.close();
  return SetPrivateFileMode(path, 0600);
}

bool FileExists(const std::string& path) {
  struct stat st {};
  return stat(path.c_str(), &st) == 0;
}

bool IsExecutable(const std::string& path) {
  return access(path.c_str(), X_OK) == 0;
}

std::string JsonEscape(const std::string& value) {
  std::string escaped;
  escaped.reserve(value.size() + 8);
  for (const char ch : value) {
    switch (ch) {
      case '\\':
        escaped += "\\\\";
        break;
      case '"':
        escaped += "\\\"";
        break;
      case '\n':
        escaped += "\\n";
        break;
      case '\r':
        escaped += "\\r";
        break;
      case '\t':
        escaped += "\\t";
        break;
      default:
        escaped += ch;
        break;
    }
  }
  return escaped;
}

std::string ChromeManifestPath() {
  const char* home = std::getenv("HOME");
  if (home == nullptr) {
    return "";
  }
  return std::string(home) +
         "/.config/google-chrome/NativeMessagingHosts/" +
         kNativeMessagingHostName + ".json";
}

std::string ChromiumManifestPath() {
  const char* home = std::getenv("HOME");
  if (home == nullptr) {
    return "";
  }
  return std::string(home) +
         "/.config/chromium/NativeMessagingHosts/" +
         kNativeMessagingHostName + ".json";
}

std::string FirefoxManifestPath() {
  const char* home = std::getenv("HOME");
  if (home == nullptr) {
    return "";
  }
  return std::string(home) + "/.mozilla/native-messaging-hosts/" +
         kNativeMessagingHostName + ".json";
}

bool EnsureParentDirectory(const std::string& path) {
  const auto pos = path.find_last_of('/');
  if (pos == std::string::npos) {
    return false;
  }
  return EnsureDirectory(path.substr(0, pos));
}

bool WriteNativeManifest(const std::string& path,
                         const std::string& host_path,
                         bool firefox) {
  if (!EnsureParentDirectory(path)) {
    return false;
  }

  std::ostringstream json;
  json << "{\n";
  json << "  \"name\": \"" << kNativeMessagingHostName << "\",\n";
  json << "  \"description\": \"Secure VPN proxy auth bridge\",\n";
  json << "  \"path\": \"" << JsonEscape(host_path) << "\",\n";
  json << "  \"type\": \"stdio\"\n";
  if (firefox) {
    json << "  ,\"allowed_extensions\": [ \"" << kFirefoxExtensionId << "\" ]\n";
  } else {
    json << "  ,\"allowed_origins\": [ \"chrome-extension://" << kChromeExtensionId
         << "/\" ]\n";
  }
  json << "}\n";
  return WritePrivateFile(path, json.str());
}

bool CopyBinary(const std::string& source, const std::string& destination) {
  std::ifstream in(source, std::ios::binary);
  if (!in.is_open()) {
    return false;
  }
  std::ofstream out(destination, std::ios::binary | std::ios::trunc);
  if (!out.is_open()) {
    return false;
  }
  out << in.rdbuf();
  out.close();
  return SetPrivateFileMode(destination, 0700);
}

std::string FindBundledNativeHostBinary() {
  const std::string exe_dir = GetExecutableDirectory();
  const std::vector<std::string> candidates = {
      JoinPath(exe_dir, "secure_vpn_native_host"),
      JoinPath(exe_dir, "../lib/secure_vpn_native_host"),
      JoinPath(exe_dir, "lib/secure_vpn_native_host"),
  };
  for (const auto& candidate : candidates) {
    if (IsExecutable(candidate)) {
      return candidate;
    }
  }
  return "";
}

int64_t ReadPingTimestamp() {
  std::ifstream in(NativeMessaging::ExtensionPingPath());
  if (!in.is_open()) {
    return 0;
  }
  int64_t value = 0;
  in >> value;
  return value;
}

}  // namespace

std::string NativeMessaging::NativeHostDirectory() {
  return JoinPath(GetWorkingDirectory(), "native_host");
}

std::string NativeMessaging::NativeHostBinaryPath() {
  return JoinPath(NativeHostDirectory(), "secure_vpn_native_host");
}

std::string NativeMessaging::SessionCredentialsPath() {
  return JoinPath(NativeHostDirectory(), "session.json");
}

std::string NativeMessaging::ExtensionPingPath() {
  return JoinPath(NativeHostDirectory(), "extension_ping");
}

bool NativeMessaging::InstallHost(const std::string& source_binary_path) {
  const std::string source =
      source_binary_path.empty() ? FindBundledNativeHostBinary()
                                 : source_binary_path;
  if (source.empty()) {
    return false;
  }
  if (!EnsureDirectory(NativeHostDirectory())) {
    return false;
  }
  return CopyBinary(source, NativeHostBinaryPath());
}

bool NativeMessaging::InstallManifests() {
  const std::string host_path = NativeHostBinaryPath();
  if (!IsExecutable(host_path)) {
    return false;
  }

  bool ok = true;
  const std::string chrome_path = ChromeManifestPath();
  const std::string chromium_path = ChromiumManifestPath();
  const std::string firefox_path = FirefoxManifestPath();
  if (!chrome_path.empty()) {
    ok = WriteNativeManifest(chrome_path, host_path, false) && ok;
  }
  if (!chromium_path.empty()) {
    ok = WriteNativeManifest(chromium_path, host_path, false) && ok;
  }
  if (!firefox_path.empty()) {
    ok = WriteNativeManifest(firefox_path, host_path, true) && ok;
  }
  return ok;
}

bool NativeMessaging::PublishCredentials(const std::string& host,
                                         int port,
                                         const std::string& username,
                                         const std::string& password) {
  if (!EnsureDirectory(NativeHostDirectory())) {
    return false;
  }

  std::ostringstream json;
  json << "{\n";
  json << "  \"type\": \"credentials\",\n";
  json << "  \"host\": \"" << JsonEscape(host) << "\",\n";
  json << "  \"port\": " << port << ",\n";
  json << "  \"username\": \"" << JsonEscape(username) << "\",\n";
  json << "  \"password\": \"" << JsonEscape(password) << "\"\n";
  json << "}\n";
  return WritePrivateFile(SessionCredentialsPath(), json.str());
}

bool NativeMessaging::ClearCredentials() {
  RemoveFileIfExists(SessionCredentialsPath());
  RemoveFileIfExists(ExtensionPingPath());
  return true;
}

std::map<std::string, bool> NativeMessaging::GetBrowserHelperStatus() {
  std::map<std::string, bool> status;
  const std::string host_path = NativeHostBinaryPath();
  status["hostInstalled"] = IsExecutable(host_path);

  const bool chrome_manifest = FileExists(ChromeManifestPath());
  const bool chromium_manifest = FileExists(ChromiumManifestPath());
  const bool firefox_manifest = FileExists(FirefoxManifestPath());
  status["manifestInstalled"] =
      chrome_manifest || chromium_manifest || firefox_manifest;
  status["chromeManifestInstalled"] = chrome_manifest;
  status["chromiumManifestInstalled"] = chromium_manifest;
  status["firefoxManifestInstalled"] = firefox_manifest;
  status["credentialsActive"] = FileExists(SessionCredentialsPath());

  const int64_t ping_ts = ReadPingTimestamp();
  const auto now = std::chrono::system_clock::now().time_since_epoch();
  const int64_t now_sec =
      std::chrono::duration_cast<std::chrono::seconds>(now).count();
  status["extensionConnected"] =
      ping_ts > 0 && (now_sec - ping_ts) <= kExtensionPingMaxAgeSeconds;

  status["ready"] = status["hostInstalled"] && status["manifestInstalled"] &&
                    status["extensionConnected"] && status["credentialsActive"];
  return status;
}

}  // namespace v2ray_box
