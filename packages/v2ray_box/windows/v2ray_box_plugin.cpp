#include "v2ray_box_plugin.h"

#include <windows.h>

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <VersionHelpers.h>

#include <fstream>
#include <memory>
#include <sstream>
#include <string>
#include <utility>

#include "desktop_core.h"
#include "system_proxy.h"

namespace v2ray_box {
namespace {

std::string g_core_engine = "xray";
std::string g_service_mode = "proxy";
std::string g_config_options = "{}";
std::string g_socks_user;
std::string g_socks_pass;
int g_socks_port = 1080;
std::string g_kill_switch_mode = "off";
bool g_kill_switch_engaged = false;

V2rayBoxPlugin* g_plugin_instance = nullptr;

std::string ActiveConfigPath() {
  return JoinPath(GetWorkingDirectory(), "profiles\\active_config.json");
}

void WipeSensitiveFiles() {
  RemoveFileIfExists(ActiveConfigPath());
  RemoveFileIfExists(
      JoinPath(GetWorkingDirectory(), "singbox_config.json"));
}

void ClearSessionCredentials() {
  g_socks_user.clear();
  g_socks_pass.clear();
  g_socks_port = 1080;
  _putenv_s("SECURE_VPN_SOCKS_USER", "");
  _putenv_s("SECURE_VPN_SOCKS_PASS", "");
  _putenv_s("SECURE_VPN_SOCKS_PORT", "");
}

void ApplySessionCredentials() {
  if (!g_socks_user.empty()) {
    _putenv_s("SECURE_VPN_SOCKS_USER", g_socks_user.c_str());
  }
  if (!g_socks_pass.empty()) {
    _putenv_s("SECURE_VPN_SOCKS_PASS", g_socks_pass.c_str());
  }
  const std::string socks_port = std::to_string(g_socks_port);
  _putenv_s("SECURE_VPN_SOCKS_PORT", socks_port.c_str());
}

flutter::EncodableValue SuccessBool(bool value) {
  return flutter::EncodableValue(value);
}

flutter::EncodableValue SuccessString(const std::string& value) {
  return flutter::EncodableValue(value);
}

void SuccessBoolResult(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
    bool value) {
  result->Success(SuccessBool(value));
}

void SuccessStringResult(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
    const std::string& value) {
  result->Success(SuccessString(value));
}

void ErrorResult(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
    const char* code,
    const std::string& message) {
  result->Error(code, message);
}

const flutter::EncodableMap* GetArgumentMap(
    const flutter::MethodCall<flutter::EncodableValue>& method_call) {
  const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
  return args;
}

std::string GetMapString(const flutter::EncodableMap& map,
                         const char* key) {
  const auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return "";
  }
  if (const auto* value = std::get_if<std::string>(&it->second)) {
    return *value;
  }
  return "";
}

int GetMapInt(const flutter::EncodableMap& map, const char* key) {
  const auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return 0;
  }
  if (const auto* value = std::get_if<int32_t>(&it->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int64_t>(&it->second)) {
    return static_cast<int>(*value);
  }
  return 0;
}

void HandleCredentialsCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "setSessionCredentials") {
    const auto* args = GetArgumentMap(method_call);
    if (args != nullptr) {
      g_socks_user = GetMapString(*args, "username");
      g_socks_pass = GetMapString(*args, "password");
      const int port = GetMapInt(*args, "port");
      if (port > 0) {
        g_socks_port = port;
      }
    }
    ApplySessionCredentials();
    SuccessBoolResult(std::move(result), true);
    return;
  }

  if (method == "clearSessionCredentials") {
    ClearSessionCredentials();
    WipeSensitiveFiles();
    SuccessBoolResult(std::move(result), true);
    return;
  }

  if (method == "getLocalSocksPort") {
    result->Success(flutter::EncodableValue(g_socks_port));
    return;
  }

  result->NotImplemented();
}

std::unique_ptr<flutter::StreamHandler<flutter::EncodableValue>>
MakeNoopStreamHandler() {
  return std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [](const flutter::EncodableValue* arguments,
         std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        return nullptr;
      },
      [](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        return nullptr;
      });
}

}  // namespace

// static
void V2rayBoxPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<V2rayBoxPlugin>();
  g_plugin_instance = plugin.get();

  auto method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "v2ray_box",
          &flutter::StandardMethodCodec::GetInstance());
  method_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  auto credentials_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "secure_vpn/credentials",
          &flutter::StandardMethodCodec::GetInstance());
  credentials_channel->SetMethodCallHandler(
      [](const auto& call, auto result) {
        HandleCredentialsCall(call, std::move(result));
      });

  auto status_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "v2ray_box/status",
          &flutter::StandardMethodCodec::GetInstance());
  status_channel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [](const flutter::EncodableValue* arguments,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            if (g_plugin_instance != nullptr) {
              g_plugin_instance->OnStatusListen(std::move(events));
            }
            return nullptr;
          },
          [](const flutter::EncodableValue* arguments)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            if (g_plugin_instance != nullptr) {
              g_plugin_instance->OnStatusCancel();
            }
            return nullptr;
          }));

  auto stats_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "v2ray_box/stats",
          &flutter::StandardMethodCodec::GetInstance());
  stats_channel->SetStreamHandler(MakeNoopStreamHandler());

  auto alerts_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "v2ray_box/alerts",
          &flutter::StandardMethodCodec::GetInstance());
  alerts_channel->SetStreamHandler(MakeNoopStreamHandler());

  auto ping_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "v2ray_box/ping",
          &flutter::StandardMethodCodec::GetInstance());
  ping_channel->SetStreamHandler(MakeNoopStreamHandler());

  auto logs_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "v2ray_box/logs",
          &flutter::StandardMethodCodec::GetInstance());
  logs_channel->SetStreamHandler(MakeNoopStreamHandler());

  registrar->AddPlugin(std::move(plugin));
}

V2rayBoxPlugin::V2rayBoxPlugin() = default;

V2rayBoxPlugin::~V2rayBoxPlugin() {
  SystemProxy::Disable();
  DesktopCore::Instance().Stop();
  ClearSessionCredentials();
  WipeSensitiveFiles();
  if (g_plugin_instance == this) {
    g_plugin_instance = nullptr;
  }
}

void V2rayBoxPlugin::OnStatusListen(
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> events) {
  emit_status_events_ = true;
  status_sink_ = std::move(events);
  EmitStatus(is_running_ ? "Started" : "Stopped");
}

void V2rayBoxPlugin::OnStatusCancel() {
  emit_status_events_ = false;
  status_sink_.reset();
}

void V2rayBoxPlugin::EmitStatus(const std::string& status) {
  if (!emit_status_events_ || status_sink_ == nullptr) {
    return;
  }
  flutter::EncodableMap map;
  map[flutter::EncodableValue("status")] = flutter::EncodableValue(status);
  status_sink_->Success(flutter::EncodableValue(map));
}

void V2rayBoxPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "getPlatformVersion") {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    SuccessStringResult(std::move(result), version_stream.str());
    return;
  }

  if (method == "setup") {
    const std::string work_dir = GetWorkingDirectory();
    if (!EnsureDirectory(work_dir) ||
        !EnsureDirectory(JoinPath(work_dir, "profiles"))) {
      ErrorResult(std::move(result), "SETUP_ERROR",
                  "Failed to create working directories");
      return;
    }
    const std::string xray_binary = DesktopCore::Instance().FindBinary("xray");
    if (!xray_binary.empty()) {
      EnsureXrayGeoAssets(work_dir, xray_binary);
    }
    SuccessStringResult(std::move(result), "");
    return;
  }

  if (method == "change_config_options") {
    if (const auto* options = std::get_if<std::string>(method_call.arguments())) {
      g_config_options = *options;
    }
    SuccessBoolResult(std::move(result), true);
    return;
  }

  if (method == "set_core_engine") {
    if (const auto* engine = std::get_if<std::string>(method_call.arguments())) {
      g_core_engine = *engine;
    }
    SuccessBoolResult(std::move(result), true);
    return;
  }

  if (method == "get_core_engine") {
    SuccessStringResult(std::move(result), g_core_engine);
    return;
  }

  if (method == "set_service_mode") {
    if (const auto* mode = std::get_if<std::string>(method_call.arguments())) {
      g_service_mode = *mode;
    }
    SuccessBoolResult(std::move(result), true);
    return;
  }

  if (method == "get_service_mode") {
    SuccessStringResult(std::move(result), g_service_mode);
    return;
  }

  if (method == "check_vpn_permission" || method == "request_vpn_permission") {
    SuccessBoolResult(std::move(result), true);
    return;
  }

  if (method == "set_notification_stop_button_text" ||
      method == "set_notification_title" || method == "set_notification_icon" ||
      method == "set_quick_connect_button_text" ||
      method == "update_quick_connect" || method == "sync_quick_settings_tile" ||
      method == "consume_pending_quick_connect" ||
      method == "consume_pending_tile_action" || method == "set_debug_mode" ||
      method == "set_locale" || method == "set_ping_test_url" ||
      method == "set_per_app_proxy_mode" || method == "set_per_app_proxy_list") {
    SuccessBoolResult(std::move(result), true);
    return;
  }

  if (method == "get_debug_mode") {
    SuccessBoolResult(std::move(result), false);
    return;
  }

  if (method == "get_per_app_proxy_mode") {
    SuccessStringResult(std::move(result), "off");
    return;
  }

  if (method == "get_per_app_proxy_list") {
    result->Success(flutter::EncodableValue(flutter::EncodableList()));
    return;
  }

  if (method == "parse_config") {
    SuccessStringResult(std::move(result), "");
    return;
  }

  if (method == "generate_config") {
    ErrorResult(std::move(result), "NOT_SUPPORTED",
                "generate_config is not supported on Windows. Use subscription JSON.");
    return;
  }

  if (method == "check_config_json") {
    const auto* json = std::get_if<std::string>(method_call.arguments());
    const std::string config = json != nullptr ? *json : "";
    if (IsValidJson(config)) {
      SuccessStringResult(std::move(result), "");
    } else {
      ErrorResult(std::move(result), "INVALID_CONFIG", "Invalid JSON format");
    }
    return;
  }

  if (method == "start_with_json") {
    const auto* args = GetArgumentMap(method_call);
    if (args == nullptr) {
      ErrorResult(std::move(result), "INVALID_ARGS", "Missing config parameter");
      return;
    }

    const std::string config_json = GetMapString(*args, "config");
    if (!IsValidJson(config_json)) {
      ErrorResult(std::move(result), "INVALID_CONFIG", "Config validation failed");
      return;
    }

    EmitStatus("Starting");
    const std::string profiles_dir =
        JoinPath(GetWorkingDirectory(), "profiles");
    const std::string path = JoinPath(profiles_dir, "active_config.json");
    if (!EnsureDirectory(profiles_dir)) {
      EmitStatus("Stopped");
      ErrorResult(std::move(result), "START_ERROR",
                  "Failed to create profiles directory");
      return;
    }
    if (!WriteTextFile(path, config_json)) {
      EmitStatus("Stopped");
      ErrorResult(std::move(result), "START_ERROR",
                  "Failed to write config file: " + path);
      return;
    }

    const std::string socks_username = GetMapString(*args, "socksUsername");
    const std::string socks_password = GetMapString(*args, "socksPassword");
    const int socks_port = GetMapInt(*args, "socksPort");
    if (!socks_username.empty()) {
      g_socks_user = socks_username;
    }
    if (!socks_password.empty()) {
      g_socks_pass = socks_password;
    }
    if (socks_port > 0) {
      g_socks_port = socks_port;
    }
    ApplySessionCredentials();

    const std::string start_error = DesktopCore::Instance().Start(
        g_core_engine, path, GetWorkingDirectory());
    if (start_error.empty()) {
      is_running_ = true;
      if (ConfigOptionsSetSystemProxy(g_config_options) && !g_socks_user.empty()) {
        const int http_port = g_socks_port + 1;
        SystemProxy::Enable("127.0.0.1", http_port, g_socks_user, g_socks_pass);
      }
      EmitStatus("Started");
      SuccessBoolResult(std::move(result), true);
      return;
    }

    is_running_ = false;
    WipeSensitiveFiles();
    EmitStatus("Stopped");
    ErrorResult(std::move(result), "START_ERROR", start_error);
    return;
  }

  if (method == "get_browser_helper_status") {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("native_host_installed")] =
        flutter::EncodableValue(false);
    map[flutter::EncodableValue("chrome_manifest_installed")] =
        flutter::EncodableValue(false);
    map[flutter::EncodableValue("firefox_manifest_installed")] =
        flutter::EncodableValue(false);
    result->Success(flutter::EncodableValue(map));
    return;
  }

  if (method == "set_kill_switch_mode") {
    if (const auto* mode = std::get_if<std::string>(method_call.arguments())) {
      g_kill_switch_mode = *mode;
      if (g_kill_switch_mode == "off") {
        g_kill_switch_engaged = false;
      }
    }
    SuccessBoolResult(std::move(result), true);
    return;
  }

  if (method == "arm_kill_switch") {
    SuccessBoolResult(std::move(result), g_kill_switch_mode == "strict");
    return;
  }

  if (method == "engage_kill_switch") {
    SystemProxy::Disable();
    DesktopCore::Instance().Stop();
    is_running_ = false;
    g_kill_switch_engaged = true;
    EmitStatus("Stopped");
    SuccessBoolResult(std::move(result), true);
    return;
  }

  if (method == "disengage_kill_switch") {
    g_kill_switch_engaged = false;
    SuccessBoolResult(std::move(result), true);
    return;
  }

  if (method == "release_kill_switch") {
    g_kill_switch_engaged = false;
    SuccessBoolResult(std::move(result), true);
    return;
  }

  if (method == "get_kill_switch_status") {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("mode")] =
        flutter::EncodableValue(g_kill_switch_mode);
    map[flutter::EncodableValue("armed")] =
        flutter::EncodableValue(g_kill_switch_mode == "strict");
    map[flutter::EncodableValue("engaged")] =
        flutter::EncodableValue(g_kill_switch_engaged);
    map[flutter::EncodableValue("available")] = flutter::EncodableValue(false);
    map[flutter::EncodableValue("backend")] =
        flutter::EncodableValue("proxy_fallback");
    result->Success(flutter::EncodableValue(map));
    return;
  }

  if (method == "is_core_running") {
    SuccessBoolResult(std::move(result),
                      DesktopCore::Instance().IsRunning() &&
                          !g_kill_switch_engaged);
    return;
  }

  if (method == "stop") {
    EmitStatus("Stopping");
    SystemProxy::Disable();
    DesktopCore::Instance().Stop();
    is_running_ = false;
    ClearSessionCredentials();
    WipeSensitiveFiles();
    EmitStatus("Stopped");
    SuccessBoolResult(std::move(result), true);
    return;
  }

  if (method == "get_core_info") {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("engine")] = flutter::EncodableValue(g_core_engine);
    map[flutter::EncodableValue("version")] = flutter::EncodableValue(
        DesktopCore::Instance().GetVersion(g_core_engine));
    const bool xray_ok = !DesktopCore::Instance().FindBinary("xray").empty();
    const bool singbox_ok =
        !DesktopCore::Instance().FindBinary("singbox").empty();
    map[flutter::EncodableValue("xray_available")] =
        flutter::EncodableValue(xray_ok);
    map[flutter::EncodableValue("singbox_available")] =
        flutter::EncodableValue(singbox_ok);
    result->Success(flutter::EncodableValue(map));
    return;
  }

  if (method == "get_logs") {
    result->Success(flutter::EncodableValue(flutter::EncodableList()));
    return;
  }

  if (method == "get_active_config") {
    std::ifstream in(ActiveConfigPath());
    std::ostringstream buffer;
    if (in.is_open()) {
      buffer << in.rdbuf();
    }
    SuccessStringResult(std::move(result), buffer.str());
    return;
  }

  if (method == "get_total_traffic") {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("upload")] = flutter::EncodableValue(0);
    map[flutter::EncodableValue("download")] = flutter::EncodableValue(0);
    result->Success(flutter::EncodableValue(map));
    return;
  }

  if (method == "reset_total_traffic" || method == "clear_logs") {
    SuccessBoolResult(std::move(result), true);
    return;
  }

  if (method == "url_test" || method == "url_test_all" || method == "start" ||
      method == "restart") {
    ErrorResult(std::move(result), "NOT_SUPPORTED",
                "Method not supported on Windows desktop");
    return;
  }

  result->NotImplemented();
}

}  // namespace v2ray_box
