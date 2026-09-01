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
  } else {
    result->NotImplemented();
  }
}

void WebViewMasterPlugin::CreateWebView(const flutter::EncodableMap& args,
                                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int id = next_web_view_id_++;
  std::string initial_url = std::get<std::string>(args.at(flutter::EncodableValue("initialUrl")));

  auto instance = std::make_unique<WebViewInstance>();
  instance->id = id;
  instance->hwnd = registrar_->GetView()->GetNativeWindow();

  // Initialize WebView2
  CreateCoreWebView2EnvironmentWithOptions(nullptr, nullptr, nullptr,
      Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
          [this, instance_ptr = instance.get(), initial_url, result_ptr = result.release()](HRESULT result, ICoreWebView2Environment* env) -> HRESULT {
            env->CreateCoreWebView2Controller(instance_ptr->hwnd,
                Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                    [this, instance_ptr, initial_url, result_ptr](HRESULT result, ICoreWebView2Controller* controller) -> HRESULT {
                      if (controller != nullptr) {
                        instance_ptr->controller = controller;
                        instance_ptr->controller->get_CoreWebView2(&instance_ptr->webview);
                      }

                      // Resize WebView to fit the window
                      RECT bounds;
                      GetClientRect(instance_ptr->hwnd, &bounds);
                      instance_ptr->controller->put_Bounds(bounds);

                      if (!initial_url.empty()) {
                        instance_ptr->webview->Navigate(
                            Utf16FromUtf8(initial_url).c_str());
                      }

                      // Register callbacks
                      EventRegistrationToken token;
                      instance_ptr->webview->add_NavigationStarting(
                          Callback<ICoreWebView2NavigationStartingEventHandler>(
                              [this, instance_ptr](ICoreWebView2* sender, ICoreWebView2NavigationStartingEventArgs* args) -> HRESULT {
                                LPWSTR uri;
                                args->get_Uri(&uri);
                                std::string suri = Utf8FromUtf16(uri);

                                flutter::EncodableMap callback_args;
                                callback_args[flutter::EncodableValue("webViewId")] = flutter::EncodableValue(instance_ptr->id);
                                callback_args[flutter::EncodableValue("url")] = flutter::EncodableValue(suri);
                                channel_->InvokeMethod("onPageStarted", std::make_unique<flutter::EncodableValue>(callback_args));
                                return S_OK;
                              }).Get(), &token);

                      instance_ptr->webview->add_NavigationCompleted(
                          Callback<ICoreWebView2NavigationCompletedEventHandler>(
                              [this, instance_ptr](ICoreWebView2* sender, ICoreWebView2NavigationCompletedEventArgs* args) -> HRESULT {
                                LPWSTR uri;
                                sender->get_Source(&uri);
                                std::string suri = Utf8FromUtf16(uri);

                                flutter::EncodableMap callback_args;
                                callback_args[flutter::EncodableValue("webViewId")] = flutter::EncodableValue(instance_ptr->id);
                                callback_args[flutter::EncodableValue("url")] = flutter::EncodableValue(suri);
                                channel_->InvokeMethod("onPageFinished", std::make_unique<flutter::EncodableValue>(callback_args));
                                return S_OK;
                              }).Get(), &token);

                      result_ptr->Success(flutter::EncodableValue(instance_ptr->id));
                      delete result_ptr;
                      return S_OK;
                    }).Get());
            return S_OK;
          }).Get());

  web_views_[id] = std::move(instance);
}

WebViewMasterPlugin::WebViewInstance* WebViewMasterPlugin::GetWebView(int id) {
  auto it = web_views_.find(id);
  if (it != web_views_.end()) {
    return it->second.get();
  }
  return nullptr;
}

}  // namespace web_view_master
