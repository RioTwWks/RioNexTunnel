#ifndef V2RAY_BOX_DESKTOP_CORE_H_
#define V2RAY_BOX_DESKTOP_CORE_H_

#include <windows.h>

#include <string>

namespace v2ray_box {

class DesktopCore {
 public:
  static DesktopCore& Instance();

  std::string Start(const std::string& engine,
                    const std::string& config_path,
                    const std::string& work_dir);
  /// TUN → local SOCKS (second process for desktop VPN).
  std::string StartSingboxTunBridge(int socks_port, const std::string& socks_user,
                                  const std::string& socks_pass);
  std::string StartXrayTunBridge(int socks_port, const std::string& socks_user,
                                 const std::string& socks_pass);
  void Stop();
  bool IsRunning() const;
  bool IsBridgeRunning() const;
  std::string FindBinary(const std::string& engine) const;
  std::string GetVersion(const std::string& engine) const;

 private:
  DesktopCore() = default;
  HANDLE process_handle_ = nullptr;
  DWORD process_id_ = 0;
  HANDLE bridge_process_handle_ = nullptr;
  std::string bridge_config_basename_;
  std::string engine_;
};

std::string GetHomeDirectory();
std::string GetExecutableDirectory();
std::string GetWorkingDirectory();
std::string JoinPath(const std::string& base, const std::string& leaf);
bool EnsureDirectory(const std::string& path);
bool RemovePathIfExists(const std::string& path);
bool WriteTextFile(const std::string& path, const std::string& content);
bool RemoveFileIfExists(const std::string& path);
bool CopyFileIfMissing(const std::string& src, const std::string& dst);
void EnsureXrayGeoAssets(const std::string& work_dir,
                         const std::string& binary_path);
bool IsValidJson(const std::string& json);

}  // namespace v2ray_box

#endif  // V2RAY_BOX_DESKTOP_CORE_H_
