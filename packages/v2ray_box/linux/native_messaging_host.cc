// Standalone Chrome/Firefox native messaging host (stdio JSON protocol).
#include "desktop_core.h"
#include "native_messaging.h"

#include <sys/stat.h>
#include <unistd.h>

#include <chrono>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace {
constexpr uint32_t kMaxMessageSize = 1024 * 1024;

bool ReadExact(std::istream& in, char* buffer, size_t size) {
  in.read(buffer, static_cast<std::streamsize>(size));
  return static_cast<size_t>(in.gcount()) == size;
}

bool WriteExact(const std::string& payload) {
  const uint32_t length = static_cast<uint32_t>(payload.size());
  std::cout.write(reinterpret_cast<const char*>(&length), sizeof(length));
  std::cout.write(payload.data(), static_cast<std::streamsize>(payload.size()));
  std::cout.flush();
  return std::cout.good();
}

std::string ReadMessage() {
  uint32_t length = 0;
  if (!ReadExact(std::cin,
                 reinterpret_cast<char*>(&length),
                 sizeof(length))) {
    return "";
  }
  if (length == 0 || length > kMaxMessageSize) {
    return "";
  }
  std::vector<char> buffer(length);
  if (!ReadExact(std::cin, buffer.data(), length)) {
    return "";
  }
  return std::string(buffer.begin(), buffer.end());
}

void WritePingTimestamp() {
  const auto now = std::chrono::system_clock::now().time_since_epoch();
  const int64_t now_sec =
      std::chrono::duration_cast<std::chrono::seconds>(now).count();
  std::ofstream out(v2ray_box::NativeMessaging::ExtensionPingPath(),
                    std::ios::trunc);
  if (out.is_open()) {
    out << now_sec;
    chmod(v2ray_box::NativeMessaging::ExtensionPingPath().c_str(), 0600);
  }
}

std::string ReadSessionPayload() {
  std::ifstream in(v2ray_box::NativeMessaging::SessionCredentialsPath());
  if (!in.is_open()) {
    return R"({"type":"clear"})";
  }
  std::ostringstream buffer;
  buffer << in.rdbuf();
  const std::string content = buffer.str();
  if (content.empty()) {
    return R"({"type":"clear"})";
  }
  return content;
}

void HandleMessage(const std::string& message) {
  if (message.find("\"type\"") == std::string::npos) {
    return;
  }
  WritePingTimestamp();
  WriteExact(ReadSessionPayload());
}

}  // namespace

int main() {
  std::ios::sync_with_stdio(false);
  std::cin.tie(nullptr);

  while (true) {
    const std::string message = ReadMessage();
    if (message.empty()) {
      break;
    }
    HandleMessage(message);
  }
  return 0;
}
