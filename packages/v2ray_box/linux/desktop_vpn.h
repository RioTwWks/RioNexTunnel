#ifndef V2RAY_BOX_DESKTOP_VPN_H_
#define V2RAY_BOX_DESKTOP_VPN_H_

#include <string>

namespace v2ray_box {

bool IsVpnServiceMode(const std::string& service_mode);

bool ConfigOptionsEnableTun(const std::string& config_options_json);

bool ShouldUseSystemProxy(const std::string& service_mode,
                          const std::string& config_options_json);

// Empty string means prerequisites are satisfied.
std::string ValidateDesktopVpnStart(const std::string& service_mode,
                                    const std::string& config_options_json,
                                    const std::string& engine,
                                    const std::string& core_binary_path);

}  // namespace v2ray_box

#endif  // V2RAY_BOX_DESKTOP_VPN_H_
