#include "local_auth_proxy.h"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <signal.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include <cerrno>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

namespace v2ray_box {
namespace {

bool SetReuseAddr(int fd) {
  int yes = 1;
  return setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes)) == 0;
}

int ListenLocal(int port) {
  const int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return -1;
  }
  SetReuseAddr(fd);
  sockaddr_in addr {};
  addr.sin_family = AF_INET;
  addr.sin_port = htons(static_cast<uint16_t>(port));
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  if (bind(fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) != 0) {
    close(fd);
    return -1;
  }
  if (listen(fd, 128) != 0) {
    close(fd);
    return -1;
  }
  return fd;
}

bool ReadExact(int fd, void* buf, size_t len) {
  auto* p = static_cast<unsigned char*>(buf);
  size_t got = 0;
  while (got < len) {
    const ssize_t n = read(fd, p + got, len - got);
    if (n <= 0) {
      return false;
    }
    got += static_cast<size_t>(n);
  }
  return true;
}

bool WriteExact(int fd, const void* buf, size_t len) {
  const auto* p = static_cast<const unsigned char*>(buf);
  size_t sent = 0;
  while (sent < len) {
    const ssize_t n = write(fd, p + sent, len - sent);
    if (n <= 0) {
      return false;
    }
    sent += static_cast<size_t>(n);
  }
  return true;
}

bool ReadLine(int fd, std::string* out, size_t max_len = 8192) {
  out->clear();
  char ch = 0;
  while (out->size() < max_len) {
    const ssize_t n = read(fd, &ch, 1);
    if (n <= 0) {
      return false;
    }
    out->push_back(ch);
    if (ch == '\n') {
      return true;
    }
  }
  return false;
}

std::string Base64Encode(const std::string& input) {
  static const char* kTable =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  std::string out;
  out.reserve(((input.size() + 2) / 3) * 4);
  size_t i = 0;
  while (i + 2 < input.size()) {
    const unsigned int b0 = static_cast<unsigned char>(input[i]);
    const unsigned int b1 = static_cast<unsigned char>(input[i + 1]);
    const unsigned int b2 = static_cast<unsigned char>(input[i + 2]);
    const unsigned int triple = (b0 << 16) | (b1 << 8) | b2;
    out.push_back(kTable[(triple >> 18) & 0x3F]);
    out.push_back(kTable[(triple >> 12) & 0x3F]);
    out.push_back(kTable[(triple >> 6) & 0x3F]);
    out.push_back(kTable[triple & 0x3F]);
    i += 3;
  }
  if (i < input.size()) {
    const unsigned int b0 = static_cast<unsigned char>(input[i]);
    const unsigned int b1 =
        (i + 1 < input.size()) ? static_cast<unsigned char>(input[i + 1]) : 0;
    const unsigned int triple = (b0 << 16) | (b1 << 8);
    out.push_back(kTable[(triple >> 18) & 0x3F]);
    out.push_back(kTable[(triple >> 12) & 0x3F]);
    if (i + 1 < input.size()) {
      out.push_back(kTable[(triple >> 6) & 0x3F]);
      out.push_back('=');
    } else {
      out.push_back('=');
      out.push_back('=');
    }
  }
  return out;
}

bool ConstantTimeEqual(const std::string& a, const std::string& b) {
  if (a.size() != b.size()) {
    return false;
  }
  unsigned char diff = 0;
  for (size_t i = 0; i < a.size(); ++i) {
    diff |= static_cast<unsigned char>(a[i]) ^ static_cast<unsigned char>(b[i]);
  }
  return diff == 0;
}

int ConnectLoopback(int port) {
  const int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return -1;
  }
  sockaddr_in addr {};
  addr.sin_family = AF_INET;
  addr.sin_port = htons(static_cast<uint16_t>(port));
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  if (connect(fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) != 0) {
    close(fd);
    return -1;
  }
  return fd;
}

bool Socks5HandshakeNoAuth(int fd) {
  const unsigned char greeting[] = {0x05, 0x01, 0x00};
  if (!WriteExact(fd, greeting, sizeof(greeting))) {
    return false;
  }
  unsigned char resp[2];
  if (!ReadExact(fd, resp, 2) || resp[0] != 0x05 || resp[1] != 0x00) {
    return false;
  }
  return true;
}

bool Socks5Connect(int fd, const std::string& host, int port) {
  std::vector<unsigned char> req;
  req.push_back(0x05);
  req.push_back(0x01);
  req.push_back(0x00);
  req.push_back(0x03);
  if (host.size() > 255) {
    return false;
  }
  req.push_back(static_cast<unsigned char>(host.size()));
  req.insert(req.end(), host.begin(), host.end());
  req.push_back(static_cast<unsigned char>((port >> 8) & 0xFF));
  req.push_back(static_cast<unsigned char>(port & 0xFF));
  if (!WriteExact(fd, req.data(), req.size())) {
    return false;
  }
  unsigned char hdr[4];
  if (!ReadExact(fd, hdr, 4) || hdr[0] != 0x05 || hdr[1] != 0x00) {
    return false;
  }
  if (hdr[3] == 0x01) {
    unsigned char skip[6];
    return ReadExact(fd, skip, 6);
  }
  if (hdr[3] == 0x03) {
    unsigned char len = 0;
    if (!ReadExact(fd, &len, 1)) {
      return false;
    }
    std::vector<unsigned char> skip(static_cast<size_t>(len) + 2);
    return ReadExact(fd, skip.data(), skip.size());
  }
  if (hdr[3] == 0x04) {
    unsigned char skip[18];
    return ReadExact(fd, skip, 18);
  }
  return false;
}

void RelayBidirectional(int a, int b) {
  while (true) {
    fd_set rfds;
    FD_ZERO(&rfds);
    FD_SET(a, &rfds);
    FD_SET(b, &rfds);
    const int maxfd = a > b ? a : b;
    const int ready = select(maxfd + 1, &rfds, nullptr, nullptr, nullptr);
    if (ready <= 0) {
      break;
    }
    char buf[16384];
    if (FD_ISSET(a, &rfds)) {
      const ssize_t n = read(a, buf, sizeof(buf));
      if (n <= 0 || !WriteExact(b, buf, static_cast<size_t>(n))) {
        break;
      }
    }
    if (FD_ISSET(b, &rfds)) {
      const ssize_t n = read(b, buf, sizeof(buf));
      if (n <= 0 || !WriteExact(a, buf, static_cast<size_t>(n))) {
        break;
      }
    }
  }
}

bool HandleSocksClient(int client,
                       int backend_port,
                       const std::string& username,
                       const std::string& password) {
  unsigned char ver_nmethods[2];
  if (!ReadExact(client, ver_nmethods, 2) || ver_nmethods[0] != 0x05) {
    return false;
  }
  const unsigned char nmethods = ver_nmethods[1];
  std::vector<unsigned char> methods(nmethods);
  if (nmethods > 0 && !ReadExact(client, methods.data(), methods.size())) {
    return false;
  }
  bool offers_user_pass = false;
  for (unsigned char m : methods) {
    if (m == 0x02) {
      offers_user_pass = true;
      break;
    }
  }
  if (!offers_user_pass) {
    const unsigned char reject[] = {0x05, 0xFF};
    WriteExact(client, reject, 2);
    return false;
  }
  const unsigned char accept_auth[] = {0x05, 0x02};
  if (!WriteExact(client, accept_auth, 2)) {
    return false;
  }

  unsigned char auth_ver = 0;
  if (!ReadExact(client, &auth_ver, 1) || auth_ver != 0x01) {
    return false;
  }
  unsigned char ulen = 0;
  if (!ReadExact(client, &ulen, 1)) {
    return false;
  }
  std::string user(ulen, '\0');
  if (ulen > 0 && !ReadExact(client, user.data(), user.size())) {
    return false;
  }
  unsigned char plen = 0;
  if (!ReadExact(client, &plen, 1)) {
    return false;
  }
  std::string pass(plen, '\0');
  if (plen > 0 && !ReadExact(client, pass.data(), pass.size())) {
    return false;
  }
  const bool ok =
      ConstantTimeEqual(user, username) && ConstantTimeEqual(pass, password);
  const unsigned char auth_resp[] = {0x01, static_cast<unsigned char>(ok ? 0x00 : 0x01)};
  if (!WriteExact(client, auth_resp, 2) || !ok) {
    return false;
  }

  unsigned char req_hdr[4];
  if (!ReadExact(client, req_hdr, 4) || req_hdr[0] != 0x05 || req_hdr[1] != 0x01) {
    const unsigned char fail[] = {0x05, 0x07, 0x00, 0x01, 0, 0, 0, 0, 0, 0};
    WriteExact(client, fail, sizeof(fail));
    return false;
  }

  std::string host;
  int port = 0;
  if (req_hdr[3] == 0x01) {
    unsigned char ip[4];
    unsigned char p[2];
    if (!ReadExact(client, ip, 4) || !ReadExact(client, p, 2)) {
      return false;
    }
    char buf[32];
    snprintf(buf, sizeof(buf), "%u.%u.%u.%u", ip[0], ip[1], ip[2], ip[3]);
    host = buf;
    port = (p[0] << 8) | p[1];
  } else if (req_hdr[3] == 0x03) {
    unsigned char len = 0;
    if (!ReadExact(client, &len, 1)) {
      return false;
    }
    host.assign(len, '\0');
    unsigned char p[2];
    if ((len > 0 && !ReadExact(client, host.data(), host.size())) ||
        !ReadExact(client, p, 2)) {
      return false;
    }
    port = (p[0] << 8) | p[1];
  } else {
    const unsigned char fail[] = {0x05, 0x08, 0x00, 0x01, 0, 0, 0, 0, 0, 0};
    WriteExact(client, fail, sizeof(fail));
    return false;
  }

  const int backend = ConnectLoopback(backend_port);
  if (backend < 0 || !Socks5HandshakeNoAuth(backend) ||
      !Socks5Connect(backend, host, port)) {
    const unsigned char fail[] = {0x05, 0x05, 0x00, 0x01, 0, 0, 0, 0, 0, 0};
    WriteExact(client, fail, sizeof(fail));
    if (backend >= 0) {
      close(backend);
    }
    return false;
  }

  const unsigned char success[] = {0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0};
  if (!WriteExact(client, success, sizeof(success))) {
    close(backend);
    return false;
  }
  RelayBidirectional(client, backend);
  close(backend);
  return true;
}

bool HttpBasicAuthorized(const std::vector<std::string>& headers,
                         const std::string& expected_b64) {
  const std::string prefix = "proxy-authorization: basic ";
  for (const auto& line : headers) {
    std::string lower = line;
    for (char& c : lower) {
      if (c >= 'A' && c <= 'Z') {
        c = static_cast<char>(c - 'A' + 'a');
      }
    }
    if (lower.rfind(prefix, 0) == 0) {
      std::string token = line.substr(prefix.size());
      while (!token.empty() &&
             (token.back() == '\r' || token.back() == '\n' || token.back() == ' ')) {
        token.pop_back();
      }
      return ConstantTimeEqual(token, expected_b64);
    }
  }
  return false;
}

bool HandleHttpClient(int client,
                      int backend_port,
                      const std::string& expected_b64) {
  std::string request_line;
  if (!ReadLine(client, &request_line)) {
    return false;
  }
  std::vector<std::string> headers;
  while (true) {
    std::string line;
    if (!ReadLine(client, &line)) {
      return false;
    }
    if (line == "\r\n" || line == "\n") {
      break;
    }
    headers.push_back(line);
  }

  if (!HttpBasicAuthorized(headers, expected_b64)) {
    const char* resp =
        "HTTP/1.1 407 Proxy Authentication Required\r\n"
        "Proxy-Authenticate: Basic realm=\"secure-vpn\"\r\n"
        "Content-Length: 0\r\n"
        "Connection: close\r\n\r\n";
    WriteExact(client, resp, strlen(resp));
    return false;
  }

  // CONNECT host:port HTTP/1.x
  std::string method;
  std::string target;
  {
    size_t sp1 = request_line.find(' ');
    size_t sp2 = request_line.find(' ', sp1 == std::string::npos ? 0 : sp1 + 1);
    if (sp1 == std::string::npos || sp2 == std::string::npos) {
      return false;
    }
    method = request_line.substr(0, sp1);
    target = request_line.substr(sp1 + 1, sp2 - sp1 - 1);
  }
  for (char& c : method) {
    if (c >= 'a' && c <= 'z') {
      c = static_cast<char>(c - 'a' + 'A');
    }
  }
  if (method != "CONNECT") {
    const char* resp =
        "HTTP/1.1 501 Not Implemented\r\nContent-Length: 0\r\n"
        "Connection: close\r\n\r\n";
    WriteExact(client, resp, strlen(resp));
    return false;
  }

  std::string host = target;
  int port = 443;
  const auto colon = target.rfind(':');
  if (colon != std::string::npos) {
    host = target.substr(0, colon);
    port = atoi(target.substr(colon + 1).c_str());
  }
  if (host.size() >= 2 && host.front() == '[' && host.back() == ']') {
    host = host.substr(1, host.size() - 2);
  }

  const int backend = ConnectLoopback(backend_port);
  if (backend < 0 || !Socks5HandshakeNoAuth(backend) ||
      !Socks5Connect(backend, host, port)) {
    const char* resp =
        "HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n"
        "Connection: close\r\n\r\n";
    WriteExact(client, resp, strlen(resp));
    if (backend >= 0) {
      close(backend);
    }
    return false;
  }

  const char* ok =
      "HTTP/1.1 200 Connection Established\r\nProxy-Agent: secure-vpn\r\n\r\n";
  if (!WriteExact(client, ok, strlen(ok))) {
    close(backend);
    return false;
  }
  RelayBidirectional(client, backend);
  close(backend);
  return true;
}

void ServeClient(int client,
                 bool http,
                 int backend_port,
                 const std::string& username,
                 const std::string& password,
                 const std::string& expected_b64) {
  if (http) {
    HandleHttpClient(client, backend_port, expected_b64);
  } else {
    HandleSocksClient(client, backend_port, username, password);
  }
  close(client);
}

void RunProxyLoop(int socks_fd,
                  int http_fd,
                  int backend_port,
                  const std::string& username,
                  const std::string& password) {
  const std::string expected_b64 = Base64Encode(username + ":" + password);
  while (true) {
    fd_set rfds;
    FD_ZERO(&rfds);
    FD_SET(socks_fd, &rfds);
    FD_SET(http_fd, &rfds);
    const int maxfd = socks_fd > http_fd ? socks_fd : http_fd;
    const int ready = select(maxfd + 1, &rfds, nullptr, nullptr, nullptr);
    if (ready < 0) {
      if (errno == EINTR) {
        continue;
      }
      break;
    }
    if (FD_ISSET(socks_fd, &rfds)) {
      const int client = accept(socks_fd, nullptr, nullptr);
      if (client >= 0) {
        pid_t child = fork();
        if (child == 0) {
          close(socks_fd);
          close(http_fd);
          ServeClient(client, false, backend_port, username, password,
                      expected_b64);
          _exit(0);
        }
        close(client);
        if (child > 0) {
          // Reap opportunistically.
          int status = 0;
          waitpid(-1, &status, WNOHANG);
        }
      }
    }
    if (FD_ISSET(http_fd, &rfds)) {
      const int client = accept(http_fd, nullptr, nullptr);
      if (client >= 0) {
        pid_t child = fork();
        if (child == 0) {
          close(socks_fd);
          close(http_fd);
          ServeClient(client, true, backend_port, username, password,
                      expected_b64);
          _exit(0);
        }
        close(client);
        if (child > 0) {
          int status = 0;
          waitpid(-1, &status, WNOHANG);
        }
      }
    }
  }
}

}  // namespace

LocalAuthProxy& LocalAuthProxy::Instance() {
  static LocalAuthProxy instance;
  return instance;
}

std::string LocalAuthProxy::Start(int public_socks_port,
                                  int public_http_port,
                                  int backend_socks_port,
                                  const std::string& username,
                                  const std::string& password) {
  Stop();
  if (public_socks_port <= 0 || public_http_port <= 0 ||
      backend_socks_port <= 0 || username.empty() || password.empty()) {
    return "Invalid LocalAuthProxy arguments";
  }

  const int socks_fd = ListenLocal(public_socks_port);
  if (socks_fd < 0) {
    return "Failed to bind authenticated SOCKS on 127.0.0.1:" +
           std::to_string(public_socks_port);
  }
  const int http_fd = ListenLocal(public_http_port);
  if (http_fd < 0) {
    close(socks_fd);
    return "Failed to bind authenticated HTTP on 127.0.0.1:" +
           std::to_string(public_http_port);
  }

  const pid_t pid = fork();
  if (pid < 0) {
    close(socks_fd);
    close(http_fd);
    return "Failed to fork LocalAuthProxy";
  }
  if (pid == 0) {
    // Detach from parent session groups lightly.
    RunProxyLoop(socks_fd, http_fd, backend_socks_port, username, password);
    _exit(0);
  }

  close(socks_fd);
  close(http_fd);
  pid_ = pid;
  usleep(100000);
  int status = 0;
  const pid_t waited = waitpid(pid_, &status, WNOHANG);
  if (waited == pid_) {
    pid_ = -1;
    return "LocalAuthProxy exited during startup";
  }
  return "";
}

void LocalAuthProxy::Stop() {
  if (pid_ <= 0) {
    return;
  }
  kill(pid_, SIGTERM);
  int status = 0;
  for (int i = 0; i < 20; ++i) {
    const pid_t result = waitpid(pid_, &status, WNOHANG);
    if (result == pid_) {
      pid_ = -1;
      return;
    }
    usleep(100000);
  }
  kill(pid_, SIGKILL);
  waitpid(pid_, &status, 0);
  pid_ = -1;
}

bool LocalAuthProxy::IsRunning() const {
  return pid_ > 0;
}

}  // namespace v2ray_box
