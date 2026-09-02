#include "desktop_ping.h"

#include "desktop_core.h"

#include <arpa/inet.h>
#include <cerrno>
#include <fcntl.h>
#include <netinet/in.h>
#include <signal.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>

#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

namespace v2ray_box {
namespace {

constexpr int kMinTimeoutMs = 1000;
constexpr int kMaxTimeoutMs = 60000;
constexpr int kCoreReadyWaitMs = 5000;

bool TcpConnect(const std::string& host, int port, int timeout_ms) {
  if (port <= 0 || port > 65535) {
    return false;
  }

  const int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return false;
  }

  sockaddr_in addr {};
  addr.sin_family = AF_INET;
  addr.sin_port = htons(static_cast<uint16_t>(port));
  if (inet_pton(AF_INET, host.c_str(), &addr.sin_addr) != 1) {
    close(fd);
    return false;
  }

  const int flags = fcntl(fd, F_GETFL, 0);
  if (flags >= 0) {
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);
  }

  const int connect_result = connect(fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr));
  if (connect_result == 0) {
    close(fd);
    return true;
  }
  if (errno != EINPROGRESS) {
    close(fd);
    return false;
  }

  fd_set write_set;
  FD_ZERO(&write_set);
  FD_SET(fd, &write_set);
  timeval tv {};
  tv.tv_sec = timeout_ms / 1000;
  tv.tv_usec = (timeout_ms % 1000) * 1000;

  const int select_result = select(fd + 1, nullptr, &write_set, nullptr, &tv);
  if (select_result <= 0) {
    close(fd);
    return false;
  }

  int so_error = 0;
  socklen_t len = sizeof(so_error);
  getsockopt(fd, SOL_SOCKET, SO_ERROR, &so_error, &len);
  close(fd);
  return so_error == 0;
}

bool WaitForPort(const std::string& host, int port, int timeout_ms) {
  const auto deadline =
      std::chrono::steady_clock::now() + std::chrono::milliseconds(timeout_ms);
  while (std::chrono::steady_clock::now() < deadline) {
    if (TcpConnect(host, port, 200)) {
      return true;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
  }
  return false;
}

std::string ShellQuote(const std::string& value) {
  std::string quoted = "'";
  for (const char ch : value) {
    if (ch == '\'') {
      quoted += "'\\''";
    } else {
      quoted += ch;
    }
  }
  quoted += "'";
  return quoted;
}

std::string RunShellCapture(const std::string& command) {
  const std::string full = command + " 2>/dev/null";
  FILE* pipe = popen(full.c_str(), "r");
  if (pipe == nullptr) {
    return "";
  }
  std::string output;
  char buffer[256];
  while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
    output += buffer;
  }
  pclose(pipe);
  return output;
}

bool CurlAvailable() {
  const std::string out = RunShellCapture("command -v curl");
  return !out.empty();
}

int MeasureWithCurl(int socks_port, const std::string& url, int timeout_ms) {
  if (!CurlAvailable()) {
    return -1;
  }

  const int timeout_sec = (timeout_ms + 999) / 1000;
  const std::string proxy =
      "socks5h://127.0.0.1:" + std::to_string(socks_port);
  const std::string cmd =
      "curl -sS -o /dev/null --max-time " + std::to_string(timeout_sec) +
      " -x " + ShellQuote(proxy) + " -w '%{time_total}' " + ShellQuote(url);

  const std::string output = RunShellCapture(cmd);
  if (output.empty()) {
    return -1;
  }

  try {
    const double seconds = std::stod(output);
    if (seconds <= 0.0) {
      return -1;
    }
    const int ms = static_cast<int>(seconds * 1000.0);
    return ms > 0 ? ms : -1;
  } catch (...) {
    return -1;
  }
}

struct PingProcess {
  pid_t pid = -1;
  std::string config_path;
};

void StopPingProcess(PingProcess& process) {
  if (process.pid <= 0) {
    RemoveFileIfExists(process.config_path);
    process.config_path.clear();
    return;
  }

  kill(process.pid, SIGTERM);
  int status = 0;
  for (int i = 0; i < 20; ++i) {
    const pid_t result = waitpid(process.pid, &status, WNOHANG);
    if (result == process.pid) {
      process.pid = -1;
      RemoveFileIfExists(process.config_path);
      process.config_path.clear();
      return;
    }
    usleep(100000);
  }

  kill(process.pid, SIGKILL);
  waitpid(process.pid, &status, 0);
  process.pid = -1;
  RemoveFileIfExists(process.config_path);
  process.config_path.clear();
}

PingProcess StartPingCore(const std::string& engine,
                          const std::string& config_path,
                          const std::string& work_dir,
                          const std::string& binary_path) {
  PingProcess process;
  process.config_path = config_path;

  int stderr_pipe[2];
  if (pipe(stderr_pipe) != 0) {
    return process;
  }

  const pid_t pid = fork();
  if (pid < 0) {
    close(stderr_pipe[0]);
    close(stderr_pipe[1]);
    return process;
  }

  if (pid == 0) {
    close(stderr_pipe[0]);
    dup2(stderr_pipe[1], STDERR_FILENO);
    close(stderr_pipe[1]);

    if (chdir(work_dir.c_str()) != 0) {
      _exit(126);
    }

    const std::string asset_dir = JoinPath(work_dir, "assets");
    EnsureDirectory(asset_dir);
    if (engine != "singbox") {
      EnsureXrayGeoAssets(work_dir, binary_path);
    }
    setenv("XRAY_LOCATION_ASSET", asset_dir.c_str(), 1);

    if (engine == "singbox") {
      const char* argv[] = {binary_path.c_str(), "run", "-c", config_path.c_str(),
                            "-D", work_dir.c_str(), nullptr};
      execv(binary_path.c_str(), const_cast<char* const*>(argv));
    } else {
      const char* argv[] = {binary_path.c_str(), "run", "-c", config_path.c_str(),
                            nullptr};
      execv(binary_path.c_str(), const_cast<char* const*>(argv));
    }
    _exit(127);
  }

  close(stderr_pipe[1]);
  usleep(300000);
  int status = 0;
  const pid_t early = waitpid(pid, &status, WNOHANG);
  if (early == pid) {
    close(stderr_pipe[0]);
    return process;
  }

  close(stderr_pipe[0]);
  process.pid = pid;
  return process;
}

}  // namespace

int MeasureOutboundDelay(const std::string& engine,
                         const std::string& config_json,
                         int socks_port,
                         const std::string& test_url,
                         int timeout_ms) {
  if (!IsValidJson(config_json) || socks_port <= 0 || socks_port > 65535) {
    return -1;
  }

  const int effective_timeout = std::max(kMinTimeoutMs,
                                         std::min(timeout_ms, kMaxTimeoutMs));
  const std::string url =
      test_url.empty() ? "https://www.gstatic.com/generate_204" : test_url;

  const std::string normalized_engine = engine == "singbox" ? "singbox" : "xray";
  const std::string binary =
      DesktopCore::Instance().FindBinary(normalized_engine);
  if (binary.empty()) {
    return -1;
  }

  const std::string work_dir = GetWorkingDirectory();
  EnsureDirectory(work_dir);
  const std::string ping_dir = JoinPath(work_dir, "ping");
  EnsureDirectory(ping_dir);

  const std::string config_path =
      JoinPath(ping_dir, "ping_" + std::to_string(getpid()) + "_" +
                             std::to_string(socks_port) + ".json");
  if (!WriteTextFile(config_path, config_json)) {
    return -1;
  }

  PingProcess process = StartPingCore(normalized_engine, config_path, work_dir,
                                      binary);
  if (process.pid <= 0) {
    RemoveFileIfExists(config_path);
    return -1;
  }

  if (!WaitForPort("127.0.0.1", socks_port, kCoreReadyWaitMs)) {
    StopPingProcess(process);
    return -1;
  }

  const int latency = MeasureWithCurl(socks_port, url, effective_timeout);
  StopPingProcess(process);
  return latency;
}

}  // namespace v2ray_box
