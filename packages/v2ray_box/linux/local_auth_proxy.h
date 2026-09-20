#ifndef V2RAY_BOX_LOCAL_AUTH_PROXY_H_
#define V2RAY_BOX_LOCAL_AUTH_PROXY_H_

#include <string>

namespace v2ray_box {

/// Authenticated SOCKS5 + HTTP CONNECT front for SkadiCore's no-auth SOCKS.
///
/// Public ports require session credentials; traffic is relayed to
/// 127.0.0.1:[backend_socks_port] via SOCKS5 no-auth.
class LocalAuthProxy {
 public:
  static LocalAuthProxy& Instance();

  /// Returns empty string on success, otherwise an error message.
  std::string Start(int public_socks_port,
                    int public_http_port,
                    int backend_socks_port,
                    const std::string& username,
                    const std::string& password);
  void Stop();
  bool IsRunning() const;

 private:
  LocalAuthProxy() = default;
  pid_t pid_ = -1;
};

}  // namespace v2ray_box

#endif  // V2RAY_BOX_LOCAL_AUTH_PROXY_H_
