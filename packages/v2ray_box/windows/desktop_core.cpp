#include "desktop_core.h"

#include <direct.h>
#include <io.h>
#include <process.h>
#include <shlobj.h>
#include <sys/stat.h>

#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <vector>

namespace v2ray_box {
namespace {

constexpr const char* kXrayName = "xray.exe";
constexpr const char* kSingboxName = "sing-box.exe";

std::string GetEnvVar(const char* name) {
  char* buffer = nullptr;
  size_t length = 0;
  if (_dupenv_s(&buffer, &length, name) != 0 || buffer == nullptr) {
    return "";
  }
  std::string value(buffer);
  free(buffer);
  return value;
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return L"";
  }
  const int size =
      MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, nullptr, 0);
  if (size <= 0) {
    return L"";
  }
  std::wstring wide(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, wide.data(), size);
  if (!wide.empty() && wide.back() == L'\0') {
    wide.pop_back();
  }
  return wide;
}

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return "";
  }
  const int size = WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, nullptr,
                                       0, nullptr, nullptr);
  if (size <= 0) {
    return "";
  }
  std::string utf8(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, utf8.data(), size,
                      nullptr, nullptr);
  if (!utf8.empty() && utf8.back() == '\0') {
    utf8.pop_back();
  }
  return utf8;
}

bool FileExists(const std::string& path) {
  struct _stat st {};
  return _stat(path.c_str(), &st) == 0 && (st.st_mode & _S_IFREG);
}

bool IsExecutable(const std::string& path) {
  return FileExists(path);
}

void AppendUnique(std::vector<std::string>* paths, const std::string& path) {
  if (path.empty()) {
    return;
  }
  for (const auto& existing : *paths) {
    if (existing == path) {
      return;
    }
  }
  paths->push_back(path);
}

std::string ShellQuote(const std::string& value) {
  std::string quoted = "\"";
  for (const char ch : value) {
    if (ch == '"') {
      quoted += "\\\"";
    } else {
      quoted += ch;
    }
  }
  quoted += "\"";
  return quoted;
}

void RunShellCommand(const std::string& command) {
  std::system(command.c_str());
}

void KillOrphanCoreProcesses(const std::string& config_path) {
  const std::string pattern = config_path;
  const std::string cmd =
      "wmic process where \"CommandLine like '%" + pattern +
      "%'\" call terminate >nul 2>&1";
  RunShellCommand(cmd);
  Sleep(200);
}

void KillProcessOnPort(int port) {
  if (port <= 0) {
    return;
  }
  const std::string cmd =
      "for /f \"tokens=5\" %a in ('netstat -ano ^| findstr :" +
      std::to_string(port) +
      " ^| findstr LISTENING') do taskkill /F /PID %a >nul 2>&1";
  RunShellCommand(cmd);
  Sleep(100);
}

std::string ReadPipe(HANDLE pipe) {
  std::string output;
  char buffer[512];
  DWORD bytes = 0;
  while (ReadFile(pipe, buffer, sizeof(buffer), &bytes, nullptr) && bytes > 0) {
    output.append(buffer, bytes);
  }
  return output;
}

std::string TrimOutput(const std::string& value) {
  const auto start = value.find_first_not_of(" \t\n\r");
  if (start == std::string::npos) {
    return "";
  }
  const auto end = value.find_last_not_of(" \t\n\r");
  return value.substr(start, end - start + 1);
}

std::string RunForOutput(const std::string& binary,
                         const std::vector<std::string>& args) {
  SECURITY_ATTRIBUTES sa {};
  sa.nLength = sizeof(sa);
  sa.bInheritHandle = TRUE;

  HANDLE read_pipe = nullptr;
  HANDLE write_pipe = nullptr;
  if (!CreatePipe(&read_pipe, &write_pipe, &sa, 0)) {
    return "";
  }
  SetHandleInformation(read_pipe, HANDLE_FLAG_INHERIT, 0);

  std::wstring command_line = L"\"" + Utf8ToWide(binary) + L"\"";
  for (const auto& arg : args) {
    command_line += L" \"" + Utf8ToWide(arg) + L"\"";
  }

  STARTUPINFOW si {};
  si.cb = sizeof(si);
  si.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
  si.hStdOutput = write_pipe;
  si.hStdError = write_pipe;
  si.wShowWindow = SW_HIDE;

  PROCESS_INFORMATION pi {};
  std::vector<wchar_t> mutable_cmd(command_line.begin(), command_line.end());
  mutable_cmd.push_back(L'\0');

  if (!CreateProcessW(nullptr, mutable_cmd.data(), nullptr, nullptr, TRUE,
                      CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) {
    CloseHandle(write_pipe);
    CloseHandle(read_pipe);
    return "";
  }

  CloseHandle(write_pipe);
  WaitForSingleObject(pi.hProcess, INFINITE);
  const std::string output = TrimOutput(ReadPipe(read_pipe));
  CloseHandle(read_pipe);
  CloseHandle(pi.hThread);
  CloseHandle(pi.hProcess);
  return output;
}

}  // namespace

std::string JoinPath(const std::string& base, const std::string& leaf) {
  if (base.empty()) {
    return leaf;
  }
  if (base.back() == '\\' || base.back() == '/') {
    return base + leaf;
  }
  return base + "\\" + leaf;
}

DesktopCore& DesktopCore::Instance() {
  static DesktopCore instance;
  return instance;
}

std::string GetHomeDirectory() {
  wchar_t* path = nullptr;
  if (SHGetKnownFolderPath(FOLDERID_Profile, 0, nullptr, &path) != S_OK) {
    return "";
  }
  const std::string home = WideToUtf8(path);
  CoTaskMemFree(path);
  return home;
}

std::string GetExecutableDirectory() {
  wchar_t path[MAX_PATH];
  const DWORD len = GetModuleFileNameW(nullptr, path, MAX_PATH);
  if (len == 0 || len >= MAX_PATH) {
    return "";
  }
  std::wstring full(path, len);
  const auto pos = full.find_last_of(L"\\/");
  if (pos == std::wstring::npos) {
    return "";
  }
  return WideToUtf8(full.substr(0, pos));
}

std::string GetWorkingDirectory() {
  wchar_t* path = nullptr;
  if (SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &path) != S_OK) {
    return JoinPath(GetHomeDirectory(), "v2ray_box");
  }
  const std::string local_app_data = WideToUtf8(path);
  CoTaskMemFree(path);
  if (local_app_data.empty()) {
    return JoinPath(GetHomeDirectory(), "v2ray_box");
  }
  return JoinPath(local_app_data, "v2ray_box");
}

bool EnsureDirectory(const std::string& path) {
  if (path.empty()) {
    return false;
  }
  if (_mkdir(path.c_str()) == 0 || errno == EEXIST) {
    return true;
  }

  std::stringstream ss(path);
  std::string part;
  std::string current;
  while (std::getline(ss, part, '\\')) {
    if (part.empty()) {
      continue;
    }
    if (part.find(':') != std::string::npos) {
      current = part;
      continue;
    }
    current = current.empty() ? part : current + "\\" + part;
    if (_mkdir(current.c_str()) != 0 && errno != EEXIST) {
      return false;
    }
  }
  return true;
}

bool RemovePathIfExists(const std::string& path) {
  struct _stat st {};
  if (_stat(path.c_str(), &st) != 0) {
    return true;
  }
  if (st.st_mode & _S_IFDIR) {
    return _rmdir(path.c_str()) == 0;
  }
  return _unlink(path.c_str()) == 0;
}

bool WriteTextFile(const std::string& path, const std::string& content) {
  const auto slash = path.find_last_of("\\/");
  if (slash != std::string::npos) {
    const std::string parent = path.substr(0, slash);
    if (!EnsureDirectory(parent)) {
      return false;
    }
  }
  if (!RemovePathIfExists(path)) {
    return false;
  }

  std::ofstream out(path, std::ios::binary | std::ios::trunc);
  if (!out.is_open()) {
    return false;
  }
  out << content;
  out.flush();
  return out.good();
}

bool RemoveFileIfExists(const std::string& path) {
  if (!FileExists(path)) {
    return true;
  }
  return _unlink(path.c_str()) == 0;
}

bool CopyFileIfMissing(const std::string& src, const std::string& dst) {
  if (!FileExists(src) || FileExists(dst)) {
    return FileExists(dst);
  }

  std::ifstream in(src, std::ios::binary);
  std::ofstream out(dst, std::ios::binary | std::ios::trunc);
  if (!in.is_open() || !out.is_open()) {
    return false;
  }
  out << in.rdbuf();
  return out.good();
}

void EnsureXrayGeoAssets(const std::string& work_dir,
                         const std::string& binary_path) {
  const std::string asset_dir = JoinPath(work_dir, "assets");
  EnsureDirectory(asset_dir);

  const auto slash = binary_path.find_last_of("\\/");
  const std::string binary_dir =
      slash == std::string::npos ? "" : binary_path.substr(0, slash);

  const char* geo_files[] = {"geoip.dat", "geosite.dat"};
  for (const char* geo_file : geo_files) {
    const std::string dst = JoinPath(asset_dir, geo_file);
    if (FileExists(dst)) {
      continue;
    }

    std::vector<std::string> candidates;
    AppendUnique(&candidates, JoinPath(binary_dir, geo_file));
    AppendUnique(&candidates,
                 JoinPath(binary_dir, std::string("resources\\") + geo_file));

    const std::string core_dir = GetEnvVar("V2RAY_BOX_CORE_DIR");
    if (!core_dir.empty()) {
      AppendUnique(&candidates, JoinPath(core_dir, geo_file));
    }

    for (const auto& candidate : candidates) {
      if (CopyFileIfMissing(candidate, dst)) {
        break;
      }
    }
  }
}

bool IsValidJson(const std::string& json) {
  if (json.empty()) {
    return false;
  }
  const char first = json.front();
  return first == '{' || first == '[';
}

std::string DesktopCore::FindBinary(const std::string& engine) const {
  const bool singbox = engine == "singbox";
  const char* binary_name = singbox ? kSingboxName : kXrayName;
  const std::string env_override =
      singbox ? GetEnvVar("V2RAY_BOX_SINGBOX_PATH") : GetEnvVar("V2RAY_BOX_XRAY_PATH");

  std::vector<std::string> candidates;
  if (!env_override.empty()) {
    AppendUnique(&candidates, env_override);
  }

  const std::string core_dir = GetEnvVar("V2RAY_BOX_CORE_DIR");
  if (!core_dir.empty()) {
    AppendUnique(&candidates, JoinPath(core_dir, binary_name));
  }

  const std::string exe_dir = GetExecutableDirectory();
  AppendUnique(&candidates, JoinPath(exe_dir, binary_name));
  AppendUnique(&candidates,
               JoinPath(exe_dir, std::string("resources\\") + binary_name));
  AppendUnique(&candidates,
               JoinPath(exe_dir, std::string("..\\resources\\") + binary_name));

  const std::string work_dir = GetWorkingDirectory();
  AppendUnique(&candidates,
               JoinPath(work_dir, std::string("cores\\") + binary_name));

  for (const auto& candidate : candidates) {
    if (IsExecutable(candidate)) {
      return candidate;
    }
  }
  return "";
}

std::string DesktopCore::GetVersion(const std::string& engine) const {
  const std::string binary = FindBinary(engine);
  if (binary.empty()) {
    return "";
  }
  return RunForOutput(binary, {"version"});
}

std::string DesktopCore::Start(const std::string& engine,
                               const std::string& config_path,
                               const std::string& work_dir) {
  Stop();
  KillOrphanCoreProcesses(config_path);

  int socks_port = 1080;
  const std::string port_env = GetEnvVar("SECURE_VPN_SOCKS_PORT");
  if (!port_env.empty()) {
    socks_port = std::atoi(port_env.c_str());
  }
  if (socks_port <= 0) {
    socks_port = 1080;
  }
  KillProcessOnPort(socks_port);
  KillProcessOnPort(socks_port + 1);

  const std::string binary = FindBinary(engine);
  if (binary.empty()) {
    return "Core binary not found. Run scripts/fetch_cores.sh and ensure "
           "windows/runner/resources contains xray.exe and sing-box.exe.";
  }

  SECURITY_ATTRIBUTES sa {};
  sa.nLength = sizeof(sa);
  sa.bInheritHandle = TRUE;

  HANDLE read_pipe = nullptr;
  HANDLE write_pipe = nullptr;
  if (!CreatePipe(&read_pipe, &write_pipe, &sa, 0)) {
    return "Failed to create stderr pipe";
  }
  SetHandleInformation(read_pipe, HANDLE_FLAG_INHERIT, 0);

  const std::string user = GetEnvVar("SECURE_VPN_SOCKS_USER");
  if (!user.empty()) {
    _putenv_s("SECURE_VPN_SOCKS_USER", user.c_str());
  }
  const std::string pass = GetEnvVar("SECURE_VPN_SOCKS_PASS");
  if (!pass.empty()) {
    _putenv_s("SECURE_VPN_SOCKS_PASS", pass.c_str());
  }

  const std::string asset_dir = JoinPath(work_dir, "assets");
  EnsureDirectory(asset_dir);
  if (engine != "singbox") {
    EnsureXrayGeoAssets(work_dir, binary);
  }
  _putenv_s("XRAY_LOCATION_ASSET", asset_dir.c_str());

  std::wstring command_line = L"\"" + Utf8ToWide(binary) + L"\" run -c \"" +
                              Utf8ToWide(config_path) + L"\"";
  if (engine == "singbox") {
    command_line += L" -D \"" + Utf8ToWide(work_dir) + L"\"";
  }

  STARTUPINFOW si {};
  si.cb = sizeof(si);
  si.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
  si.hStdError = write_pipe;
  si.wShowWindow = SW_HIDE;

  PROCESS_INFORMATION pi {};
  std::vector<wchar_t> mutable_cmd(command_line.begin(), command_line.end());
  mutable_cmd.push_back(L'\0');

  const std::wstring work_dir_wide = Utf8ToWide(work_dir);
  if (!CreateProcessW(nullptr, mutable_cmd.data(), nullptr, nullptr, TRUE,
                      CREATE_NO_WINDOW, nullptr,
                      work_dir_wide.empty() ? nullptr : work_dir_wide.c_str(),
                      &si, &pi)) {
    CloseHandle(write_pipe);
    CloseHandle(read_pipe);
    return "Failed to start core process";
  }

  CloseHandle(write_pipe);
  Sleep(500);

  DWORD exit_code = STILL_ACTIVE;
  if (GetExitCodeProcess(pi.hProcess, &exit_code) && exit_code != STILL_ACTIVE) {
    const std::string stderr_output = TrimOutput(ReadPipe(read_pipe));
    CloseHandle(read_pipe);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    process_handle_ = nullptr;
    process_id_ = 0;
    engine_.clear();
    if (!stderr_output.empty()) {
      return stderr_output;
    }
    return "Core process exited during startup";
  }

  CloseHandle(read_pipe);
  process_handle_ = pi.hProcess;
  process_id_ = pi.dwProcessId;
  engine_ = engine;
  CloseHandle(pi.hThread);
  return "";
}

void DesktopCore::Stop() {
  if (process_handle_ == nullptr) {
    return;
  }

  TerminateProcess(process_handle_, 0);
  WaitForSingleObject(process_handle_, 5000);
  CloseHandle(process_handle_);
  process_handle_ = nullptr;
  process_id_ = 0;
  engine_.clear();
}

bool DesktopCore::IsRunning() const {
  if (process_handle_ == nullptr) {
    return false;
  }
  DWORD exit_code = STILL_ACTIVE;
  if (!GetExitCodeProcess(process_handle_, &exit_code)) {
    return false;
  }
  return exit_code == STILL_ACTIVE;
}

}  // namespace v2ray_box
