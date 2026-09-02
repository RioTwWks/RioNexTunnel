#ifndef FLUTTER_PLUGIN_V2RAY_BOX_PLUGIN_H_
#define FLUTTER_PLUGIN_V2RAY_BOX_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace v2ray_box {

class V2rayBoxPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  V2rayBoxPlugin();

  virtual ~V2rayBoxPlugin();

  V2rayBoxPlugin(const V2rayBoxPlugin&) = delete;
  V2rayBoxPlugin& operator=(const V2rayBoxPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void EmitStatus(const std::string& status);

  void OnStatusListen(
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> events);
  void OnStatusCancel();

 private:
  bool is_running_ = false;
  bool emit_status_events_ = false;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> status_sink_;
};

}  // namespace v2ray_box

#endif  // FLUTTER_PLUGIN_V2RAY_BOX_PLUGIN_H_
