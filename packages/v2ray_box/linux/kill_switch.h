#ifndef V2RAY_BOX_KILL_SWITCH_H_
#define V2RAY_BOX_KILL_SWITCH_H_

#include <string>

namespace v2ray_box {

class KillSwitch {
 public:
  static KillSwitch& Instance();

  void SetMode(const std::string& mode);
  std::string GetMode() const;

  bool Arm(int socks_port);
  bool Engage();
  bool Disengage();
  bool Release();

  bool IsArmed() const;
  bool IsEngaged() const;
  bool IsAvailable() const;
  std::string LastError() const;

 private:
  KillSwitch() = default;

  bool ApplyRules(bool allow_local_proxy, int socks_port);
  bool RunCommand(const std::string& command);
  bool ProbeBackend();

  std::string mode_ = "off";
  bool armed_ = false;
  bool engaged_ = false;
  bool available_ = false;
  bool use_nft_ = false;
  int socks_port_ = 1080;
  std::string last_error_;
};

}  // namespace v2ray_box

#endif
