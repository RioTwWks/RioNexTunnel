#include "kill_switch.h"

#include <cstdlib>
#include <sstream>

namespace v2ray_box {
namespace {

constexpr const char* kChain = "RIONEX_KS";
constexpr const char* kTable = "rionex_ks";

}  // namespace

KillSwitch& KillSwitch::Instance() {
  static KillSwitch instance;
  return instance;
}

void KillSwitch::SetMode(const std::string& mode) {
  mode_ = mode;
  if (mode_ == "off") {
    Release();
  }
}

std::string KillSwitch::GetMode() const {
  return mode_;
}

bool KillSwitch::ProbeBackend() {
  if (RunCommand("iptables -w -L -n >/dev/null 2>&1")) {
    use_nft_ = false;
    available_ = true;
    return true;
  }
  if (RunCommand("nft list tables >/dev/null 2>&1")) {
    use_nft_ = true;
    available_ = true;
    return true;
  }
  available_ = false;
  last_error_ = "iptables/nftables not available (root or CAP_NET_ADMIN required)";
  return false;
}

bool KillSwitch::RunCommand(const std::string& command) {
  const int code = std::system(command.c_str());
  if (code != 0) {
    last_error_ = "command failed: " + command;
    return false;
  }
  return true;
}

bool KillSwitch::ApplyRules(bool allow_local_proxy, int socks_port) {
  if (!ProbeBackend()) {
    return false;
  }

  Release();

  if (use_nft_) {
    std::ostringstream script;
    script << "nft add table inet " << kTable << " 2>/dev/null || true; "
           << "nft flush table inet " << kTable << " 2>/dev/null || true; "
           << "nft add chain inet " << kTable << " output "
           << "{ type filter hook output priority 0; policy accept; } "
           << "2>/dev/null || true; "
           << "nft flush chain inet " << kTable << " output 2>/dev/null || true; "
           << "nft add rule inet " << kTable << " output oif lo accept "
           << "2>/dev/null || true; "
           << "nft add rule inet " << kTable << " output ip daddr 127.0.0.0/8 accept "
           << "2>/dev/null || true; ";

    if (allow_local_proxy && socks_port > 0) {
      const int http_port = socks_port + 1;
      script << "nft add rule inet " << kTable << " output ip daddr 127.0.0.1 "
             << "tcp dport " << socks_port << " accept 2>/dev/null || true; "
             << "nft add rule inet " << kTable << " output ip daddr 127.0.0.1 "
             << "tcp dport " << http_port << " accept 2>/dev/null || true; ";
    }

    script << "nft add rule inet " << kTable << " output drop 2>/dev/null || true";
    return RunCommand(script.str());
  }

  std::ostringstream script;
  script << "iptables -w -N " << kChain << " 2>/dev/null || true; "
         << "iptables -w -F " << kChain << " 2>/dev/null || true; "
         << "iptables -w -D OUTPUT -j " << kChain << " 2>/dev/null || true; "
         << "iptables -w -I OUTPUT 1 -j " << kChain << " 2>/dev/null || true; "
         << "iptables -w -A " << kChain << " -o lo -j ACCEPT 2>/dev/null || true; "
         << "iptables -w -A " << kChain << " -d 127.0.0.0/8 -j ACCEPT 2>/dev/null || true; ";

  if (allow_local_proxy && socks_port > 0) {
    const int http_port = socks_port + 1;
    script << "iptables -w -A " << kChain << " -d 127.0.0.1 -p tcp --dport "
           << socks_port << " -j ACCEPT 2>/dev/null || true; "
           << "iptables -w -A " << kChain << " -d 127.0.0.1 -p tcp --dport "
           << http_port << " -j ACCEPT 2>/dev/null || true; ";
  }

  script << "iptables -w -A " << kChain << " -j DROP 2>/dev/null || true";
  return RunCommand(script.str());
}

bool KillSwitch::Arm(int socks_port) {
  if (mode_ != "strict") {
    return true;
  }
  socks_port_ = socks_port;
  const bool ok = ApplyRules(true, socks_port);
  armed_ = ok;
  engaged_ = false;
  return ok;
}

bool KillSwitch::Engage() {
  if (mode_ != "strict") {
    return true;
  }
  const bool ok = ApplyRules(false, 0);
  engaged_ = ok;
  armed_ = ok;
  return ok;
}

bool KillSwitch::Disengage() {
  if (!armed_ && !engaged_) {
    return true;
  }
  const bool ok = ApplyRules(true, socks_port_);
  engaged_ = false;
  armed_ = ok;
  return ok;
}

bool KillSwitch::Release() {
  armed_ = false;
  engaged_ = false;

  if (!available_ && !ProbeBackend()) {
    return true;
  }

  if (use_nft_) {
    std::ostringstream script;
    script << "nft delete table inet " << kTable << " 2>/dev/null || true";
    RunCommand(script.str());
    return true;
  }

  std::ostringstream script;
  script << "iptables -w -D OUTPUT -j " << kChain << " 2>/dev/null || true; "
         << "iptables -w -F " << kChain << " 2>/dev/null || true; "
         << "iptables -w -X " << kChain << " 2>/dev/null || true";
  RunCommand(script.str());
  return true;
}

bool KillSwitch::IsArmed() const {
  return armed_;
}

bool KillSwitch::IsEngaged() const {
  return engaged_;
}

bool KillSwitch::IsAvailable() const {
  return available_;
}

std::string KillSwitch::LastError() const {
  return last_error_;
}

}  // namespace v2ray_box
