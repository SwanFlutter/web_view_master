#ifndef FLUTTER_PLUGIN_WEB_VIEW_MASTER_PLUGIN_H_
#define FLUTTER_PLUGIN_WEB_VIEW_MASTER_PLUGIN_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <WebView2.h>
#include <wrl.h>

#include <memory>
#include <map>
#include <string>

namespace web_view_master {

class WebViewMasterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  WebViewMasterPlugin();
  explicit WebViewMasterPlugin(flutter::PluginRegistrarWindows* registrar);

  virtual ~WebViewMasterPlugin();

  // Disallow copy and assign.
  WebViewMasterPlugin(const WebViewMasterPlugin&) = delete;
  WebViewMasterPlugin& operator=(const WebViewMasterPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  struct WebViewInstance {
    Microsoft::WRL::ComPtr<ICoreWebView2Controller> controller;
    Microsoft::WRL::ComPtr<ICoreWebView2> webview;
    HWND hwnd;
    int id;
  };

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::map<int, std::unique_ptr<WebViewInstance>> web_views_;
  int next_web_view_id_ = 1;

  void CreateWebView(const flutter::EncodableMap& args,
                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  WebViewInstance* GetWebView(int id);
};

}  // namespace web_view_master

#endif  // FLUTTER_PLUGIN_WEB_VIEW_MASTER_PLUGIN_H_
