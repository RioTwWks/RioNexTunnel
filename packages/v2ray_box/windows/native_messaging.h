#ifndef V2RAY_BOX_NATIVE_MESSAGING_H_
#define V2RAY_BOX_NATIVE_MESSAGING_H_

#include <map>
#include <string>

namespace v2ray_box {

class NativeMessaging {
 public:
  static std::string NativeHostDirectory();
  static std::string NativeHostBinaryPath();
  static std::string SessionCredentialsPath();
  static std::string ExtensionPingPath();

  static bool InstallHost(const std::string& source_binary_path);
  static bool InstallManifests();
  static bool PublishCredentials(const std::string& host,
                                 int port,
                                 const std::string& username,
                                 const std::string& password);
  static bool ClearCredentials();
  static std::map<std::string, bool> GetBrowserHelperStatus();
};

}  // namespace v2ray_box

#endif  // V2RAY_BOX_NATIVE_MESSAGING_H_
