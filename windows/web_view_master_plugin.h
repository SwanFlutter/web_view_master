#ifndef FLUTTER_PLUGIN_WEB_VIEW_MASTER_PLUGIN_H_
#define FLUTTER_PLUGIN_WEB_VIEW_MASTER_PLUGIN_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <WebView2.h>
#include <wrl.h>

#include <map>
#include <memory>
#include <string>
#include <vector>

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
    Microsoft::WRL::ComPtr<ICoreWebView2Environment> environment;
    HWND hwnd = nullptr;
    int id = 0;
    // Last bounds requested from Dart, in physical pixels.
    RECT bounds = {0, 0, 0, 0};
    bool has_bounds = false;
    // Dart-controlled visibility: the native WebView2 window always paints on
    // top of the Flutter surface, so it has to be hidden whenever the Flutter
    // route that owns it is covered by a dialog or another page.
    bool visible = true;
    // When false, target="_blank" / window.open() URLs are loaded in this same
    // WebView instead of a popup window.
    bool support_multiple_windows = false;
    // Cancel navigations to URI schemes WebView2 would otherwise hand off to
    // the OS shell (which is what makes a link jump to the default browser).
    bool block_external_schemes = true;
    // Progress currently reported to Dart, to avoid duplicate events.
    int progress = 0;
  };

  // How the JSON returned by ExecuteScript should be handed back to Dart.
  enum class ScriptResult {
    kRawJson,          // as-is, matching Android's evaluateJavascript
    kUnquotedString,   // JSON string literal decoded to a plain string
    kBoolean,          // "true"/"false" decoded to a Dart bool
  };

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::map<int, std::unique_ptr<WebViewInstance>> web_views_;
  int next_web_view_id_ = 1;

  void CreateWebView(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  // Second half of CreateWebView, run once the WebView2 environment exists.
  void FinishWebViewCreation(
      int id, HWND host, const std::string& initial_url,
      const std::string& header_block, const std::string& user_agent,
      bool enable_javascript, bool enable_dom_storage,
      std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  // Takes the settings by value: the arguments map does not outlive the
  // asynchronous WebView2 environment/controller creation callbacks.
  void ApplySettings(WebViewInstance* instance, bool enable_javascript,
                     bool enable_dom_storage, const std::string& user_agent);
  void RegisterEventHandlers(WebViewInstance* instance);
  // Asks Dart what to do with a popup and applies the answer. Unlike
  // NavigationStarting, NewWindowRequested supports a deferral, so the Dart
  // decision here is honoured exactly.
  void HandleNewWindowRequest(
      int id, const std::string& url, bool user_initiated,
      Microsoft::WRL::ComPtr<ICoreWebView2NewWindowRequestedEventArgs> args,
      Microsoft::WRL::ComPtr<ICoreWebView2Deferral> deferral);
  void ApplyBounds(WebViewInstance* instance);
  void RunScript(
      WebViewInstance* instance, const std::string& script,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
      ScriptResult kind = ScriptResult::kRawJson);
  void SendEvent(const std::string& method, int id, flutter::EncodableMap args);
  // Asks Dart for a NavigationDecision. WebView2 cannot defer
  // NavigationStarting, so a "prevent" that arrives after the load already
  // began is honoured best-effort by stopping it.
  void AskNavigationDecision(const std::string& method, int id,
                             flutter::EncodableMap args);
  void SendProgress(WebViewInstance* instance, int progress);
  void SendError(int id, const std::string& url, int error_code,
                 const std::string& description);
  WebViewInstance* GetWebView(int id);
};

}  // namespace web_view_master

#endif  // FLUTTER_PLUGIN_WEB_VIEW_MASTER_PLUGIN_H_
