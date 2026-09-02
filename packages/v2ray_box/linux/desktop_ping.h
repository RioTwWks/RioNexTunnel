#ifndef V2RAY_BOX_DESKTOP_PING_H_
#define V2RAY_BOX_DESKTOP_PING_H_

#include <string>

namespace v2ray_box {

/// Measures HTTP round-trip latency through a temporary core instance and local
/// SOCKS/mixed inbound (full tunnel path, not raw TCP to the remote host:port).
/// Returns latency in milliseconds, or -1 on failure/timeout.
int MeasureOutboundDelay(const std::string& engine,
                         const std::string& config_json,
                         int socks_port,
                         const std::string& test_url,
                         int timeout_ms);

}  // namespace v2ray_box

#endif  // V2RAY_BOX_DESKTOP_PING_H_
