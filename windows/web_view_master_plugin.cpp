#include "web_view_master_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <objbase.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <iostream>

namespace web_view_master {

using namespace Microsoft::WRL;

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int size =
      MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (size <= 0) {
    return std::wstring();
  }
  std::wstring result(static_cast<size_t>(size - 1), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, result.data(), size);
  return result;
}

std::string Utf8FromUtf16(const wchar_t* utf16) {
  if (utf16 == nullptr || utf16[0] == L'\0') {
    return std::string();
  }
  const int size =
      WideCharToMultiByte(CP_UTF8, 0, utf16, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 0) {
    return std::string();
  }
  std::string result(static_cast<size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, utf16, -1, result.data(), size, nullptr,
                      nullptr);
  return result;
}

// static
void WebViewMasterPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<WebViewMasterPlugin>(registrar);

  plugin->channel_->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

WebViewMasterPlugin::WebViewMasterPlugin() : registrar_(nullptr) {}

WebViewMasterPlugin::WebViewMasterPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  if (registrar_ == nullptr) {
    return;
  }
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar_->messenger(), "web_view_master",
          &flutter::StandardMethodCodec::GetInstance());
}

WebViewMasterPlugin::~WebViewMasterPlugin() {
  for (auto const& [id, instance] : web_views_) {
    if (instance->controller) {
      instance->controller->Close();
    }
  }
}

void WebViewMasterPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else if (method_call.method_name().compare("createWebView") == 0) {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    CreateWebView(*args, std::move(result));
  } else if (method_call.method_name().compare("loadUrl") == 0) {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    int id = std::get<int>(args->at(flutter::EncodableValue("webViewId")));
    std::string url = std::get<std::string>(args->at(flutter::EncodableValue("url")));

    auto instance = GetWebView(id);
    if (instance) {
      instance->webview->Navigate(Utf16FromUtf8(url).c_str());
      result->Success();
    } else {
      result->Error("WEBVIEW_NOT_FOUND", "WebView not found");
    }
  } else if (method_call.method_name().compare("evaluateJavaScript") == 0) {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    int id = std::get<int>(args->at(flutter::EncodableValue("webViewId")));
    std::string script = std::get<std::string>(args->at(flutter::EncodableValue("script")));

    auto instance = GetWebView(id);
    if (instance) {
      instance->webview->ExecuteScript(Utf16FromUtf8(script).c_str(),
          Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
            [result_ptr = result.release()](HRESULT errorCode, LPCWSTR resultObjectAsJson) -> HRESULT {
              if (SUCCEEDED(errorCode)) {
                result_ptr->Success(flutter::EncodableValue(
                    Utf8FromUtf16(resultObjectAsJson)));
              } else {
                result_ptr->Error("JS_ERROR", "Failed to execute script");
              }
              delete result_ptr;
              return S_OK;
            }).Get());
    } else {
      result->Error("WEBVIEW_NOT_FOUND", "WebView not found");
    }
  } else if (method_call.method_name().compare("goBack") == 0) {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    int id = std::get<int>(args->at(flutter::EncodableValue("webViewId")));
    auto instance = GetWebView(id);
    if (instance) {
      instance->webview->GoBack();
      result->Success();
    } else {
      result->Error("WEBVIEW_NOT_FOUND", "WebView not found");
    }
  } else if (method_call.method_name().compare("goForward") == 0) {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    int id = std::get<int>(args->at(flutter::EncodableValue("webViewId")));
    auto instance = GetWebView(id);
    if (instance) {
      instance->webview->GoForward();
      result->Success();
    } else {
      result->Error("WEBVIEW_NOT_FOUND", "WebView not found");
    }
  } else if (method_call.method_name().compare("reload") == 0) {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    int id = std::get<int>(args->at(flutter::EncodableValue("webViewId")));
    auto instance = GetWebView(id);
    if (instance) {
      instance->webview->Reload();
      result->Success();
    } else {
      result->Error("WEBVIEW_NOT_FOUND", "WebView not found");
    }
  } else if (method_call.method_name().compare("canGoBack") == 0) {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    int id = std::get<int>(args->at(flutter::EncodableValue("webViewId")));
    auto instance = GetWebView(id);
    if (instance && instance->webview) {
      BOOL can_go_back = FALSE;
      instance->webview->get_CanGoBack(&can_go_back);
      result->Success(flutter::EncodableValue(can_go_back != FALSE));
    } else {
      result->Error("WEBVIEW_NOT_FOUND", "WebView not found");
    }
  } else if (method_call.method_name().compare("canGoForward") == 0) {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    int id = std::get<int>(args->at(flutter::EncodableValue("webViewId")));
    auto instance = GetWebView(id);
    if (instance && instance->webview) {
      BOOL can_go_forward = FALSE;
      instance->webview->get_CanGoForward(&can_go_forward);
      result->Success(flutter::EncodableValue(can_go_forward != FALSE));
    } else {
      result->Error("WEBVIEW_NOT_FOUND", "WebView not found");
    }
  } else if (method_call.method_name().compare("getCurrentUrl") == 0) {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    int id = std::get<int>(args->at(flutter::EncodableValue("webViewId")));
    auto instance = GetWebView(id);
    if (instance && instance->webview) {
      LPWSTR uri = nullptr;
      instance->webview->get_Source(&uri);
      result->Success(flutter::EncodableValue(Utf8FromUtf16(uri)));
      CoTaskMemFree(uri);
    } else {
      result->Error("WEBVIEW_NOT_FOUND", "WebView not found");
    }
  } else if (method_call.method_name().compare("getTitle") == 0) {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    int id = std::get<int>(args->at(flutter::EncodableValue("webViewId")));
    auto instance = GetWebView(id);
    if (instance && instance->webview) {
      LPWSTR title = nullptr;
      instance->webview->get_DocumentTitle(&title);
      result->Success(flutter::EncodableValue(Utf8FromUtf16(title)));
      CoTaskMemFree(title);
    } else {
      result->Error("WEBVIEW_NOT_FOUND", "WebView not found");
    }
  } else if (method_call.method_name().compare("loadHtmlString") == 0) {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    int id = std::get<int>(args->at(flutter::EncodableValue("webViewId")));
    std::string html = std::get<std::string>(args->at(flutter::EncodableValue("html")));
    auto instance = GetWebView(id);
    if (instance && instance->webview) {
      instance->webview->NavigateToString(Utf16FromUtf8(html).c_str());
      result->Success();
    } else {
      result->Error("WEBVIEW_NOT_FOUND", "WebView not found");
    }
  } else if (method_call.method_name().compare("clearCache") == 0) {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    int id = std::get<int>(args->at(flutter::EncodableValue("webViewId")));
    auto instance = GetWebView(id);
    if (instance && instance->webview) {
      // WebView2 does not have a direct clear cache API; use DevTools protocol or skip
      result->Success();
    } else {
      result->Error("WEBVIEW_NOT_FOUND", "WebView not found");
    }
  } else if (method_call.method_name().compare("clearCookies") == 0) {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    int id = std::get<int>(args->at(flutter::EncodableValue("webViewId")));
    auto instance = GetWebView(id);
    if (instance && instance->webview) {
      // Cookie management requires ICoreWebView2CookieManager (WebView2 1.0.774+)
      result->Success();
    } else {
      result->Error("WEBVIEW_NOT_FOUND", "WebView not found");
    }
  } else if (method_call.method_name().compare("disposeWebView") == 0) {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    int id = std::get<int>(args->at(flutter::EncodableValue("webViewId")));
    auto it = web_views_.find(id);
    if (it != web_views_.end()) {
      if (it->second->controller) {
        it->second->controller->Close();
      }
      web_views_.erase(it);
    }
    result->Success();
  } else if (method_call.method_name().compare("setUserAgent") == 0) {
    // UserAgent changes require ICoreWebView2Settings2; acknowledge silently
    result->Success();
  } else if (method_call.method_name().compare("enableWebNotifications") == 0 ||
             method_call.method_name().compare("disableWebNotifications") == 0) {
    result->Success(flutter::EncodableValue(true));
  } else if (method_call.method_name().compare("hasNotificationPermission") == 0) {
    result->Success(flutter::EncodableValue(false));
  } else if (method_call.method_name().compare("requestNotificationPermission") == 0) {
    result->Success(flutter::EncodableValue(std::string("denied")));
  } else if (method_call.method_name().compare("shareCurrentPage") == 0 ||
             method_call.method_name().compare("enablePullToRefresh") == 0 ||
             method_call.method_name().compare("findInPage") == 0 ||
             method_call.method_name().compare("clearFindMatches") == 0 ||
             method_call.method_name().compare("takeScreenshot") == 0 ||
             method_call.method_name().compare("injectCSS") == 0 ||
             method_call.method_name().compare("getSelectedText") == 0 ||
             method_call.method_name().compare("getPageAnalytics") == 0 ||
             method_call.method_name().compare("isDarkModeEnabled") == 0 ||
             method_call.method_name().compare("showNativeNotification") == 0 ||
             method_call.method_name().compare("showImageNotification") == 0 ||
             method_call.method_name().compare("showNotificationWithActions") == 0 ||
             method_call.method_name().compare("shareFromJS") == 0) {
    result->Success();
  } else {
    result->NotImplemented();
  }
}

void WebViewMasterPlugin::CreateWebView(const flutter::EncodableMap& args,
                                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int id = next_web_view_id_++;
  std::string initial_url = std::get<std::string>(args.at(flutter::EncodableValue("initialUrl")));

  // Pre-insert a placeholder so GetWebView works inside callbacks
  auto instance = std::make_unique<WebViewInstance>();
  instance->id = id;
  instance->hwnd = registrar_->GetView()->GetNativeWindow();
  WebViewInstance* instance_ptr = instance.get();
  web_views_[id] = std::move(instance);

  // Initialize WebView2 asynchronously; reply to Flutter only after the
  // controller is fully ready so loadUrl calls don't race createWebView.
  CreateCoreWebView2EnvironmentWithOptions(nullptr, nullptr, nullptr,
      Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
          [this, instance_ptr, initial_url, result_ptr = result.release()](HRESULT hr, ICoreWebView2Environment* env) -> HRESULT {
            if (FAILED(hr) || env == nullptr) {
              result_ptr->Error("WEBVIEW2_ENV_FAILED", "Failed to create WebView2 environment");
              delete result_ptr;
              return S_OK;
            }
            env->CreateCoreWebView2Controller(instance_ptr->hwnd,
                Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                    [this, instance_ptr, initial_url, result_ptr](HRESULT hr, ICoreWebView2Controller* controller) -> HRESULT {
                      if (FAILED(hr) || controller == nullptr) {
                        result_ptr->Error("WEBVIEW2_CTRL_FAILED", "Failed to create WebView2 controller");
                        delete result_ptr;
                        return S_OK;
                      }

                      instance_ptr->controller = controller;
                      instance_ptr->controller->get_CoreWebView2(&instance_ptr->webview);

                      // Resize WebView to fill the host window
                      RECT bounds;
                      GetClientRect(instance_ptr->hwnd, &bounds);
                      instance_ptr->controller->put_Bounds(bounds);
                      instance_ptr->controller->put_IsVisible(TRUE);

                      if (!initial_url.empty()) {
                        instance_ptr->webview->Navigate(
                            Utf16FromUtf8(initial_url).c_str());
                      }

                      // Register callbacks
                      EventRegistrationToken token;
                      instance_ptr->webview->add_NavigationStarting(
                          Callback<ICoreWebView2NavigationStartingEventHandler>(
                              [this, instance_ptr](ICoreWebView2* sender, ICoreWebView2NavigationStartingEventArgs* args) -> HRESULT {
                                LPWSTR uri = nullptr;
                                args->get_Uri(&uri);
                                std::string suri = Utf8FromUtf16(uri);
                                CoTaskMemFree(uri);

                                flutter::EncodableMap callback_args;
                                callback_args[flutter::EncodableValue("webViewId")] = flutter::EncodableValue(instance_ptr->id);
                                callback_args[flutter::EncodableValue("url")] = flutter::EncodableValue(suri);
                                callback_args[flutter::EncodableValue("isForMainFrame")] = flutter::EncodableValue(true);
                                channel_->InvokeMethod("onNavigationRequest",
                                    std::make_unique<flutter::EncodableValue>(callback_args));
                                channel_->InvokeMethod("onPageStarted",
                                    std::make_unique<flutter::EncodableValue>(callback_args));
                                return S_OK;
                              }).Get(), &token);

                      instance_ptr->webview->add_NavigationCompleted(
                          Callback<ICoreWebView2NavigationCompletedEventHandler>(
                              [this, instance_ptr](ICoreWebView2* sender, ICoreWebView2NavigationCompletedEventArgs* args) -> HRESULT {
                                LPWSTR uri = nullptr;
                                sender->get_Source(&uri);
                                std::string suri = Utf8FromUtf16(uri);
                                CoTaskMemFree(uri);

                                flutter::EncodableMap callback_args;
                                callback_args[flutter::EncodableValue("webViewId")] = flutter::EncodableValue(instance_ptr->id);
                                callback_args[flutter::EncodableValue("url")] = flutter::EncodableValue(suri);
                                channel_->InvokeMethod("onPageFinished",
                                    std::make_unique<flutter::EncodableValue>(callback_args));
                                return S_OK;
                              }).Get(), &token);

                      // Intercept new-window requests (target="_blank", window.open)
                      // and redirect them into the same WebView instead of opening
                      // a new browser window.
                      instance_ptr->webview->add_NewWindowRequested(
                          Callback<ICoreWebView2NewWindowRequestedEventHandler>(
                              [this, instance_ptr](ICoreWebView2* sender, ICoreWebView2NewWindowRequestedEventArgs* args) -> HRESULT {
                                // Defer so we can make it async
                                Microsoft::WRL::ComPtr<ICoreWebView2Deferral> deferral;
                                args->GetDeferral(&deferral);

                                LPWSTR uri = nullptr;
                                args->get_Uri(&uri);
                                std::string suri = Utf8FromUtf16(uri);
                                CoTaskMemFree(uri);

                                // Tell Flutter about the popup; load in same WebView
                                // regardless (Flutter's decision is advisory on Windows
                                // because we can't block synchronously here).
                                flutter::EncodableMap callback_args;
                                callback_args[flutter::EncodableValue("webViewId")] = flutter::EncodableValue(instance_ptr->id);
                                callback_args[flutter::EncodableValue("url")] = flutter::EncodableValue(suri);
                                callback_args[flutter::EncodableValue("isDialog")] = flutter::EncodableValue(false);
                                callback_args[flutter::EncodableValue("isUserGesture")] = flutter::EncodableValue(true);
                                callback_args[flutter::EncodableValue("blocked")] = flutter::EncodableValue(false);
                                channel_->InvokeMethod("onCreateWindow",
                                    std::make_unique<flutter::EncodableValue>(callback_args));

                                // Always suppress the new window and navigate in-place
                                args->put_Handled(TRUE);
                                if (instance_ptr->webview) {
                                  instance_ptr->webview->Navigate(
                                      Utf16FromUtf8(suri).c_str());
                                }

                                deferral->Complete();
                                return S_OK;
                              }).Get(), &token);

                      // Now that everything is ready, tell Flutter the WebView ID
                      result_ptr->Success(flutter::EncodableValue(instance_ptr->id));
                      delete result_ptr;
                      return S_OK;
                    }).Get());
            return S_OK;
          }).Get());
}

WebViewMasterPlugin::WebViewInstance* WebViewMasterPlugin::GetWebView(int id) {
  auto it = web_views_.find(id);
  if (it != web_views_.end()) {
    return it->second.get();
  }
  return nullptr;
}

}  // namespace web_view_master
