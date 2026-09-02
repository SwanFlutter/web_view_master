#include "web_view_master_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <objbase.h>

// For getPlatformVersion.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/method_result_functions.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

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

namespace {

// Takes ownership of a WebView2-allocated string and returns it as UTF-8.
std::string TakeString(LPWSTR owned) {
  if (owned == nullptr) {
    return std::string();
  }
  std::string result = Utf8FromUtf16(owned);
  CoTaskMemFree(owned);
  return result;
}

int GetInt(const flutter::EncodableMap& args, const char* key,
           int fallback = 0) {
  const auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) return fallback;
  if (const auto* v = std::get_if<int32_t>(&it->second)) return *v;
  if (const auto* v = std::get_if<int64_t>(&it->second)) {
    return static_cast<int>(*v);
  }
  return fallback;
}

std::string GetString(const flutter::EncodableMap& args, const char* key,
                      const std::string& fallback = std::string()) {
  const auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) return fallback;
  if (const auto* v = std::get_if<std::string>(&it->second)) return *v;
  return fallback;
}

bool GetBool(const flutter::EncodableMap& args, const char* key,
             bool fallback) {
  const auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) return fallback;
  if (const auto* v = std::get_if<bool>(&it->second)) return *v;
  return fallback;
}

// Flattens a Dart `Map<String, String>` of headers into the CRLF-separated
// block CreateWebResourceRequest expects.
std::string BuildHeaderBlock(const flutter::EncodableMap& args) {
  std::string block;
  const auto it = args.find(flutter::EncodableValue("headers"));
  if (it == args.end()) return block;
  const auto* headers = std::get_if<flutter::EncodableMap>(&it->second);
  if (headers == nullptr) return block;
  for (const auto& [key, value] : *headers) {
    const auto* name = std::get_if<std::string>(&key);
    const auto* text = std::get_if<std::string>(&value);
    if (name != nullptr && text != nullptr) {
      block += *name + ": " + *text + "\r\n";
    }
  }
  return block;
}

// Navigates with custom request headers when the installed runtime supports
// it, falling back to a plain navigation otherwise.
void NavigateWithHeaders(ICoreWebView2Environment* environment,
                         ICoreWebView2* webview, const std::string& url,
                         const std::string& header_block) {
  if (webview == nullptr || url.empty()) return;
  if (!header_block.empty() && environment != nullptr) {
    ComPtr<ICoreWebView2Environment2> environment2;
    ComPtr<ICoreWebView2_2> webview2;
    ComPtr<ICoreWebView2WebResourceRequest> request;
    if (SUCCEEDED(environment->QueryInterface(IID_PPV_ARGS(&environment2))) &&
        SUCCEEDED(webview->QueryInterface(IID_PPV_ARGS(&webview2))) &&
        SUCCEEDED(environment2->CreateWebResourceRequest(
            Utf16FromUtf8(url).c_str(), L"GET", nullptr,
            Utf16FromUtf8(header_block).c_str(), &request))) {
      webview2->NavigateWithWebResourceRequest(request.Get());
      return;
    }
  }
  webview->Navigate(Utf16FromUtf8(url).c_str());
}

// Schemes WebView2 renders itself. Every *other* scheme (myapp://, tel:,
// mailto:, intent://, bankid:// ...) is silently handed to the OS shell, which
// launches whatever app is registered for it — usually the default browser.
// That hand-off is invisible to Flutter, so it looks like the WebView "lost"
// the link. Detecting it here lets us cancel and report it instead.
bool IsExternalScheme(const std::string& url) {
  const size_t colon = url.find(':');
  if (colon == std::string::npos) return false;  // relative URL
  const size_t slash = url.find('/');
  if (slash != std::string::npos && slash < colon) return false;

  static const char* kInternalSchemes[] = {
      "http", "https",    "file",     "data",        "about",
      "blob", "chrome",   "edge",     "devtools",    "javascript",
      "view-source",      "ms-appx-web", "ms-local-stream",
  };
  for (const char* scheme : kInternalSchemes) {
    if (colon == std::strlen(scheme) &&
        _strnicmp(url.c_str(), scheme, colon) == 0) {
      return false;
    }
  }
  return true;
}

// Maps WebView2 failures onto the error codes the Dart layer already knows
// (see WebViewController._getErrorDescription).
int WebErrorToCode(COREWEBVIEW2_WEB_ERROR_STATUS status) {
  switch (status) {
    case COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_COMMON_NAME_IS_INCORRECT:
    case COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_EXPIRED:
    case COREWEBVIEW2_WEB_ERROR_STATUS_CLIENT_CERTIFICATE_CONTAINS_ERRORS:
    case COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_REVOKED:
    case COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_IS_INVALID:
      return -11;  // Failed SSL handshake
    case COREWEBVIEW2_WEB_ERROR_STATUS_SERVER_UNREACHABLE:
    case COREWEBVIEW2_WEB_ERROR_STATUS_CONNECTION_ABORTED:
    case COREWEBVIEW2_WEB_ERROR_STATUS_CONNECTION_RESET:
    case COREWEBVIEW2_WEB_ERROR_STATUS_DISCONNECTED:
    case COREWEBVIEW2_WEB_ERROR_STATUS_CANNOT_CONNECT:
      return -6;  // Connection failed
    case COREWEBVIEW2_WEB_ERROR_STATUS_TIMEOUT:
      return -8;
    case COREWEBVIEW2_WEB_ERROR_STATUS_ERROR_HTTP_INVALID_SERVER_RESPONSE:
      return -7;  // IO error
    case COREWEBVIEW2_WEB_ERROR_STATUS_HOST_NAME_NOT_RESOLVED:
      return -2;  // Host lookup failed
    case COREWEBVIEW2_WEB_ERROR_STATUS_REDIRECT_FAILED:
      return -9;
    case COREWEBVIEW2_WEB_ERROR_STATUS_VALID_AUTHENTICATION_CREDENTIALS_REQUIRED:
      return -4;
    case COREWEBVIEW2_WEB_ERROR_STATUS_VALID_PROXY_AUTHENTICATION_REQUIRED:
      return -5;
    default:
      return -1;
  }
}

const char* WebErrorToName(COREWEBVIEW2_WEB_ERROR_STATUS status) {
  switch (status) {
    case COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_COMMON_NAME_IS_INCORRECT:
      return "Certificate common name is incorrect";
    case COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_EXPIRED:
      return "Certificate expired";
    case COREWEBVIEW2_WEB_ERROR_STATUS_CLIENT_CERTIFICATE_CONTAINS_ERRORS:
      return "Client certificate contains errors";
    case COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_REVOKED:
      return "Certificate revoked";
    case COREWEBVIEW2_WEB_ERROR_STATUS_CERTIFICATE_IS_INVALID:
      return "Certificate is invalid";
    case COREWEBVIEW2_WEB_ERROR_STATUS_SERVER_UNREACHABLE:
      return "Server unreachable";
    case COREWEBVIEW2_WEB_ERROR_STATUS_TIMEOUT:
      return "Timeout";
    case COREWEBVIEW2_WEB_ERROR_STATUS_ERROR_HTTP_INVALID_SERVER_RESPONSE:
      return "Invalid HTTP server response";
    case COREWEBVIEW2_WEB_ERROR_STATUS_CONNECTION_ABORTED:
      return "Connection aborted";
    case COREWEBVIEW2_WEB_ERROR_STATUS_CONNECTION_RESET:
      return "Connection reset";
    case COREWEBVIEW2_WEB_ERROR_STATUS_DISCONNECTED:
      return "Disconnected";
    case COREWEBVIEW2_WEB_ERROR_STATUS_CANNOT_CONNECT:
      return "Cannot connect";
    case COREWEBVIEW2_WEB_ERROR_STATUS_HOST_NAME_NOT_RESOLVED:
      return "Host name not resolved";
    case COREWEBVIEW2_WEB_ERROR_STATUS_OPERATION_CANCELED:
      return "Operation canceled";
    case COREWEBVIEW2_WEB_ERROR_STATUS_REDIRECT_FAILED:
      return "Redirect failed";
    case COREWEBVIEW2_WEB_ERROR_STATUS_VALID_AUTHENTICATION_CREDENTIALS_REQUIRED:
      return "Authentication required";
    case COREWEBVIEW2_WEB_ERROR_STATUS_VALID_PROXY_AUTHENTICATION_REQUIRED:
      return "Proxy authentication required";
    default:
      return "Unexpected error";
  }
}

std::string Base64Encode(const unsigned char* data, size_t length) {
  static const char kTable[] =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  std::string out;
  out.reserve(((length + 2) / 3) * 4);
  for (size_t i = 0; i < length; i += 3) {
    const unsigned int a = data[i];
    const unsigned int b = (i + 1 < length) ? data[i + 1] : 0u;
    const unsigned int c = (i + 2 < length) ? data[i + 2] : 0u;
    const unsigned int triple = (a << 16) | (b << 8) | c;
    out.push_back(kTable[(triple >> 18) & 0x3F]);
    out.push_back(kTable[(triple >> 12) & 0x3F]);
    out.push_back((i + 1 < length) ? kTable[(triple >> 6) & 0x3F] : '=');
    out.push_back((i + 2 < length) ? kTable[triple & 0x3F] : '=');
  }
  return out;
}

// Wraps a UTF-8 payload as a JavaScript/JSON string literal so it can be
// embedded in a script passed to ExecuteScript.
std::string JsLiteral(const std::string& value) {
  std::string out = "\"";
  for (const char ch : value) {
    switch (ch) {
      case '\\': out += "\\\\"; break;
      case '"':  out += "\\\""; break;
      case '\n': out += "\\n";  break;
      case '\r': out += "\\r";  break;
      case '\t': out += "\\t";  break;
      default:
        if (static_cast<unsigned char>(ch) < 0x20) {
          char buffer[8];
          std::snprintf(buffer, sizeof(buffer), "\\u%04x",
                        static_cast<unsigned char>(ch));
          out += buffer;
        } else {
          out.push_back(ch);
        }
    }
  }
  out += "\"";
  return out;
}

// ExecuteScript hands back a JSON document. Strings arrive quoted; callers that
// want a plain Dart string need the quotes and escapes taken back off.
std::string UnquoteJson(const std::string& json) {
  if (json.size() < 2 || json.front() != '"' || json.back() != '"') {
    return json == "null" ? std::string() : json;
  }
  std::string out;
  out.reserve(json.size() - 2);
  for (size_t i = 1; i + 1 < json.size(); ++i) {
    if (json[i] != '\\' || i + 2 >= json.size()) {
      out.push_back(json[i]);
      continue;
    }
    switch (json[++i]) {
      case 'n': out.push_back('\n'); break;
      case 'r': out.push_back('\r'); break;
      case 't': out.push_back('\t'); break;
      case 'u': {
        if (i + 4 < json.size()) {
          const std::string hex = json.substr(i + 1, 4);
          const wchar_t code =
              static_cast<wchar_t>(std::strtol(hex.c_str(), nullptr, 16));
          const wchar_t buffer[2] = {code, L'\0'};
          out += Utf8FromUtf16(buffer);
          i += 4;
        }
        break;
      }
      default: out.push_back(json[i]); break;
    }
  }
  return out;
}

}  // namespace

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

WebViewMasterPlugin::WebViewMasterPlugin(
    flutter::PluginRegistrarWindows* registrar)
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
      instance->controller->put_IsVisible(FALSE);
      instance->controller->Close();
    }
  }
  web_views_.clear();
}

WebViewMasterPlugin::WebViewInstance* WebViewMasterPlugin::GetWebView(int id) {
  const auto it = web_views_.find(id);
  return it != web_views_.end() ? it->second.get() : nullptr;
}

void WebViewMasterPlugin::SendEvent(const std::string& method, int id,
                                    flutter::EncodableMap args) {
  if (!channel_) return;
  args[flutter::EncodableValue("webViewId")] = flutter::EncodableValue(id);
  channel_->InvokeMethod(method,
                         std::make_unique<flutter::EncodableValue>(args));
}

void WebViewMasterPlugin::AskNavigationDecision(const std::string& method,
                                                int id,
                                                flutter::EncodableMap args) {
  if (!channel_) return;
  args[flutter::EncodableValue("webViewId")] = flutter::EncodableValue(id);
  channel_->InvokeMethod(
      method, std::make_unique<flutter::EncodableValue>(args),
      std::make_unique<flutter::MethodResultFunctions<flutter::EncodableValue>>(
          [this, id](const flutter::EncodableValue* response) {
            bool prevent = false;
            if (response != nullptr) {
              if (const auto* text = std::get_if<std::string>(response)) {
                prevent = *text == "prevent";
              } else if (const auto* allow = std::get_if<bool>(response)) {
                prevent = !*allow;
              }
            }
            if (!prevent) return;
            auto* instance = GetWebView(id);
            if (instance != nullptr && instance->webview) {
              instance->webview->Stop();
            }
          },
          nullptr, nullptr));
}

void WebViewMasterPlugin::SendProgress(WebViewInstance* instance,
                                       int progress) {
  if (instance == nullptr || instance->progress == progress) return;
  instance->progress = progress;
  SendEvent("onProgressChanged", instance->id,
            {{flutter::EncodableValue("progress"),
              flutter::EncodableValue(progress)}});
}

void WebViewMasterPlugin::SendError(int id, const std::string& url,
                                    int error_code,
                                    const std::string& description) {
  SendEvent("onWebResourceError", id,
            {{flutter::EncodableValue("url"), flutter::EncodableValue(url)},
             {flutter::EncodableValue("errorCode"),
              flutter::EncodableValue(error_code)},
             {flutter::EncodableValue("description"),
              flutter::EncodableValue(description)}});
}

void WebViewMasterPlugin::ApplyBounds(WebViewInstance* instance) {
  if (instance == nullptr || !instance->controller) return;
  RECT bounds = instance->bounds;
  if (!instance->has_bounds) {
    // No layout information from Dart yet: fill the host window so the page is
    // at least visible instead of collapsing to a zero-sized rectangle.
    GetClientRect(instance->hwnd, &bounds);
  }
  instance->controller->put_Bounds(bounds);
  instance->controller->put_IsVisible(instance->visible ? TRUE : FALSE);
}

// Runs `script` and completes `result` with what it evaluates to, decoded
// according to `kind`.
void WebViewMasterPlugin::RunScript(
    WebViewInstance* instance, const std::string& script,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
    ScriptResult kind) {
  if (instance == nullptr || !instance->webview) {
    result->Error("WEBVIEW_NOT_FOUND", "WebView not found");
    return;
  }
  // WRL callbacks must be copyable, so the result cannot be moved in as a
  // unique_ptr.
  std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> shared(
      result.release());
  instance->webview->ExecuteScript(
      Utf16FromUtf8(script).c_str(),
      Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
          [shared, kind](HRESULT error_code, LPCWSTR json) -> HRESULT {
            if (FAILED(error_code)) {
              shared->Error("JS_ERROR", "Failed to execute script");
              return S_OK;
            }
            const std::string value = Utf8FromUtf16(json);
            switch (kind) {
              case ScriptResult::kUnquotedString:
                shared->Success(flutter::EncodableValue(UnquoteJson(value)));
                break;
              case ScriptResult::kBoolean:
                shared->Success(flutter::EncodableValue(value == "true"));
                break;
              case ScriptResult::kRawJson:
              default:
                shared->Success(flutter::EncodableValue(value));
                break;
            }
            return S_OK;
          })
          .Get());
}

void WebViewMasterPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
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
    result->Success(flutter::EncodableValue(version_stream.str()));
    return;
  }

  if (method == "hasNotificationPermission") {
    result->Success(flutter::EncodableValue(false));
    return;
  }
  if (method == "requestNotificationPermission") {
    result->Success(flutter::EncodableValue(std::string("denied")));
    return;
  }

  static const flutter::EncodableMap kNoArgs;
  const auto* args_ptr =
      std::get_if<flutter::EncodableMap>(method_call.arguments());
  const flutter::EncodableMap& args = args_ptr ? *args_ptr : kNoArgs;

  if (method == "createWebView") {
    CreateWebView(args, std::move(result));
    return;
  }

  auto* instance = GetWebView(GetInt(args, "webViewId", -1));

  if (method == "disposeWebView") {
    if (instance != nullptr) {
      if (instance->controller) {
        instance->controller->put_IsVisible(FALSE);
        instance->controller->Close();
      }
      web_views_.erase(instance->id);
    }
    result->Success();
    return;
  }

  if (instance == nullptr || !instance->webview) {
    result->Error("WEBVIEW_NOT_FOUND", "WebView not found");
    return;
  }

  if (method == "loadUrl") {
    instance->progress = 0;
    NavigateWithHeaders(instance->environment.Get(), instance->webview.Get(),
                        GetString(args, "url"), BuildHeaderBlock(args));
    result->Success();
    return;
  }

  if (method == "loadHtmlString") {
    instance->progress = 0;
    instance->webview->NavigateToString(
        Utf16FromUtf8(GetString(args, "html")).c_str());
    result->Success();
    return;
  }

  if (method == "goBack") {
    instance->webview->GoBack();
    result->Success();
    return;
  }
  if (method == "goForward") {
    instance->webview->GoForward();
    result->Success();
    return;
  }
  if (method == "reload") {
    instance->progress = 0;
    instance->webview->Reload();
    result->Success();
    return;
  }

  if (method == "canGoBack" || method == "canGoForward") {
    BOOL can_navigate = FALSE;
    if (method == "canGoBack") {
      instance->webview->get_CanGoBack(&can_navigate);
    } else {
      instance->webview->get_CanGoForward(&can_navigate);
    }
    result->Success(flutter::EncodableValue(can_navigate != FALSE));
    return;
  }

  if (method == "getCurrentUrl") {
    LPWSTR uri = nullptr;
    instance->webview->get_Source(&uri);
    result->Success(flutter::EncodableValue(TakeString(uri)));
    return;
  }

  if (method == "getTitle") {
    LPWSTR title = nullptr;
    instance->webview->get_DocumentTitle(&title);
    result->Success(flutter::EncodableValue(TakeString(title)));
    return;
  }

  if (method == "setBounds") {
    instance->bounds = {GetInt(args, "left"), GetInt(args, "top"),
                        GetInt(args, "right"), GetInt(args, "bottom")};
    instance->has_bounds = true;
    ApplyBounds(instance);
    result->Success();
    return;
  }

  if (method == "setVisible") {
    instance->visible = GetBool(args, "visible", true);
    if (instance->controller) {
      instance->controller->put_IsVisible(instance->visible ? TRUE : FALSE);
    }
    result->Success();
    return;
  }

  if (method == "setUserAgent") {
    ComPtr<ICoreWebView2Settings> settings;
    ComPtr<ICoreWebView2Settings2> settings2;
    if (SUCCEEDED(instance->webview->get_Settings(&settings)) &&
        SUCCEEDED(settings.As(&settings2))) {
      settings2->put_UserAgent(
          Utf16FromUtf8(GetString(args, "userAgent")).c_str());
      result->Success();
    } else {
      result->Error("UNSUPPORTED",
                    "Changing the user agent needs WebView2 Runtime 1.0.992+");
    }
    return;
  }

  if (method == "clearCache") {
    // WebView2 has no cache-clearing API at this runtime version, but the
    // DevTools protocol it already speaks does.
    instance->webview->CallDevToolsProtocolMethod(
        L"Network.clearBrowserCache", L"{}", nullptr);
    result->Success();
    return;
  }

  if (method == "clearCookies") {
    ComPtr<ICoreWebView2_2> webview2;
    ComPtr<ICoreWebView2CookieManager> cookies;
    if (SUCCEEDED(instance->webview.As(&webview2)) &&
        SUCCEEDED(webview2->get_CookieManager(&cookies))) {
      cookies->DeleteAllCookies();
    } else {
      instance->webview->CallDevToolsProtocolMethod(
          L"Network.clearBrowserCookies", L"{}", nullptr);
    }
    result->Success();
    return;
  }

  if (method == "evaluateJavaScript") {
    // Raw JSON, so the return value matches Android's evaluateJavascript.
    RunScript(instance, GetString(args, "script"), std::move(result));
    return;
  }

  if (method == "injectCSS") {
    const std::string css = GetString(args, "css");
    RunScript(instance,
              "(function(){var s=document.createElement('style');"
              "s.type='text/css';s.appendChild("
              "document.createTextNode(" + JsLiteral(css) + "));"
              "(document.head||document.documentElement).appendChild(s);"
              "return true;})()",
              std::move(result));
    return;
  }

  if (method == "getSelectedText") {
    RunScript(instance, "String(window.getSelection())", std::move(result),
              ScriptResult::kUnquotedString);
    return;
  }

  if (method == "isDarkModeEnabled") {
    RunScript(instance,
              "(function(){try{return window.matchMedia("
              "'(prefers-color-scheme: dark)').matches;}"
              "catch(e){return false;}})()",
              std::move(result), ScriptResult::kBoolean);
    return;
  }

  if (method == "getPageAnalytics") {
    // Returned as a JSON document; the Dart side decodes it.
    RunScript(instance,
              "JSON.stringify({url:location.href,title:document.title,"
              "domain:location.hostname,protocol:location.protocol,"
              "linkCount:document.getElementsByTagName('a').length,"
              "imageCount:document.getElementsByTagName('img').length,"
              "scriptCount:document.getElementsByTagName('script').length,"
              "formCount:document.getElementsByTagName('form').length,"
              "textLength:(document.body?document.body.innerText.length:0),"
              "readyState:document.readyState,"
              "referrer:document.referrer,"
              "userAgent:navigator.userAgent,"
              "cookieEnabled:navigator.cookieEnabled,"
              "language:navigator.language,"
              "viewportWidth:window.innerWidth,"
              "viewportHeight:window.innerHeight})",
              std::move(result));
    return;
  }

  if (method == "findInPage") {
    // WebView2 1.0.1264 exposes no Find API, so matches are painted with the
    // CSS Custom Highlight API rather than by rewriting the DOM.
    static const char kFindScript[] = R"JS((function(q){try{
if(!window.CSS||!CSS.highlights||typeof Highlight!=='function')return 'unsupported';
CSS.highlights.delete('wvmfind');
if(!q||!document.body)return 'No matches found';
var st=document.getElementById('wvm-find-style');
if(!st){st=document.createElement('style');st.id='wvm-find-style';
st.textContent='::highlight(wvmfind){background-color:#ffd54f;color:#000}';
(document.head||document.documentElement).appendChild(st);}
var needle=q.toLowerCase(),ranges=[],walker=document.createTreeWalker(
document.body,NodeFilter.SHOW_TEXT,{acceptNode:function(n){
var p=n.parentNode?n.parentNode.nodeName:'';
if(p==='SCRIPT'||p==='STYLE'||p==='NOSCRIPT')return NodeFilter.FILTER_REJECT;
return n.nodeValue&&n.nodeValue.trim()?NodeFilter.FILTER_ACCEPT
:NodeFilter.FILTER_REJECT;}});
for(var n;(n=walker.nextNode());){var hay=n.nodeValue.toLowerCase();
for(var i=hay.indexOf(needle);i!==-1;i=hay.indexOf(needle,i+needle.length)){
var r=document.createRange();r.setStart(n,i);r.setEnd(n,i+needle.length);
ranges.push(r);}}
if(!ranges.length)return 'No matches found';
CSS.highlights.set('wvmfind',new Highlight(...ranges));
var host=ranges[0].startContainer.parentElement;
if(host)host.scrollIntoView({block:'center'});
return 'Found '+ranges.length+' matches';}catch(e){return 'error: '+e}}))JS";
    RunScript(instance,
              std::string(kFindScript) + "(" +
                  JsLiteral(GetString(args, "searchText")) + ")",
              std::move(result), ScriptResult::kUnquotedString);
    return;
  }

  if (method == "clearFindMatches") {
    RunScript(instance,
              "(function(){try{if(window.CSS&&CSS.highlights)"
              "CSS.highlights.delete('wvmfind');}catch(e){}return true;})()",
              std::move(result));
    return;
  }

  if (method == "takeScreenshot") {
    ComPtr<IStream> stream;
    if (FAILED(CreateStreamOnHGlobal(nullptr, TRUE, &stream))) {
      result->Error("SCREENSHOT_FAILED", "Could not allocate an image buffer");
      return;
    }
    std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> shared(
        result.release());
    instance->webview->CapturePreview(
        COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT_PNG, stream.Get(),
        Callback<ICoreWebView2CapturePreviewCompletedHandler>(
            [shared, stream](HRESULT error_code) -> HRESULT {
              HGLOBAL global = nullptr;
              STATSTG stat = {};
              if (FAILED(error_code) ||
                  FAILED(stream->Stat(&stat, STATFLAG_NONAME)) ||
                  FAILED(GetHGlobalFromStream(stream.Get(), &global)) ||
                  global == nullptr) {
                shared->Error("SCREENSHOT_FAILED",
                              "Could not capture the page");
                return S_OK;
              }
              const size_t allocated = static_cast<size_t>(GlobalSize(global));
              size_t size = static_cast<size_t>(stat.cbSize.QuadPart);
              if (size > allocated) size = allocated;
              auto* bytes = static_cast<unsigned char*>(GlobalLock(global));
              if (bytes == nullptr) {
                shared->Error("SCREENSHOT_FAILED",
                              "Could not read the captured image");
                return S_OK;
              }
              const std::string encoded = Base64Encode(bytes, size);
              GlobalUnlock(global);
              shared->Success(flutter::EncodableValue(encoded));
              return S_OK;
            })
            .Get());
    return;
  }

  if (method == "enableWebNotifications" ||
      method == "disableWebNotifications") {
    // WebView2 1.0.1264 exposes no notification-permission API.
    result->Success(flutter::EncodableValue(false));
    return;
  }

  if (method == "shareCurrentPage") {
    // Win32 has no share sheet, so the URL goes to the clipboard instead.
    LPWSTR uri = nullptr;
    instance->webview->get_Source(&uri);
    const std::wstring url = Utf16FromUtf8(TakeString(uri));
    if (!url.empty() && OpenClipboard(instance->hwnd)) {
      EmptyClipboard();
      const size_t bytes = (url.size() + 1) * sizeof(wchar_t);
      if (HGLOBAL handle = GlobalAlloc(GMEM_MOVEABLE, bytes)) {
        bool copied = false;
        if (auto* target = static_cast<wchar_t*>(GlobalLock(handle))) {
          std::memcpy(target, url.c_str(), bytes);
          GlobalUnlock(handle);
          copied = SetClipboardData(CF_UNICODETEXT, handle) != nullptr;
        }
        if (!copied) GlobalFree(handle);
      }
      CloseClipboard();
    }
    result->Success();
    return;
  }

  if (method == "enablePullToRefresh") {
    // Pull-to-refresh is a touch gesture; there is nothing to do on desktop.
    result->Success();
    return;
  }

  result->NotImplemented();
}

void WebViewMasterPlugin::CreateWebView(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const HWND host = (registrar_ != nullptr && registrar_->GetView() != nullptr)
                        ? registrar_->GetView()->GetNativeWindow()
                        : nullptr;
  if (host == nullptr) {
    result->Error("NO_WINDOW", "There is no Flutter window to host a WebView");
    return;
  }

  const int id = next_web_view_id_++;
  auto owned = std::make_unique<WebViewInstance>();
  owned->id = id;
  owned->hwnd = host;
  owned->support_multiple_windows =
      GetBool(args, "supportMultipleWindows", false);
  owned->block_external_schemes = GetBool(args, "blockExternalSchemes", true);
  web_views_[id] = std::move(owned);

  // Copies, not references: none of this outlives the async callbacks below.
  const std::string initial_url = GetString(args, "initialUrl");
  const std::string header_block = BuildHeaderBlock(args);
  const std::string user_agent = GetString(args, "userAgent");
  const bool enable_javascript = GetBool(args, "enableJavaScript", true);
  const bool enable_dom_storage = GetBool(args, "enableDomStorage", true);
  std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> shared(
      result.release());

  const HRESULT queued = CreateCoreWebView2EnvironmentWithOptions(
      nullptr, nullptr, nullptr,
      Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
          [this, id, host, initial_url, header_block, user_agent,
           enable_javascript, enable_dom_storage, shared](
              HRESULT error_code,
              ICoreWebView2Environment* environment) -> HRESULT {
            if (GetWebView(id) == nullptr) return S_OK;  // disposed meanwhile
            if (FAILED(error_code) || environment == nullptr) {
              web_views_.erase(id);
              shared->Error("WEBVIEW2_UNAVAILABLE",
                            "The WebView2 Runtime could not be started. "
                            "Install the Microsoft Edge WebView2 Runtime.");
              return S_OK;
            }
            GetWebView(id)->environment = environment;
            FinishWebViewCreation(id, host, initial_url, header_block,
                                  user_agent, enable_javascript,
                                  enable_dom_storage, shared);
            return S_OK;
          })
          .Get());

  if (FAILED(queued)) {
    web_views_.erase(id);
    shared->Error("WEBVIEW2_UNAVAILABLE",
                  "The WebView2 Runtime is not installed on this machine.");
  }
}

void WebViewMasterPlugin::FinishWebViewCreation(
    int id, HWND host, const std::string& initial_url,
    const std::string& header_block, const std::string& user_agent,
    bool enable_javascript, bool enable_dom_storage,
    std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto* instance = GetWebView(id);
  if (instance == nullptr || !instance->environment) return;

  instance->environment->CreateCoreWebView2Controller(
      host,
      Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
          [this, id, initial_url, header_block, user_agent, enable_javascript,
           enable_dom_storage, result](
              HRESULT error_code,
              ICoreWebView2Controller* controller) -> HRESULT {
            auto* instance = GetWebView(id);
            if (instance == nullptr) {
              if (controller != nullptr) controller->Close();
              return S_OK;
            }
            if (FAILED(error_code) || controller == nullptr) {
              web_views_.erase(id);
              result->Error("WEBVIEW_CREATION_FAILED",
                            "WebView2 could not create a controller for the "
                            "Flutter window.");
              return S_OK;
            }
            instance->controller = controller;
            controller->get_CoreWebView2(&instance->webview);
            if (!instance->webview) {
              web_views_.erase(id);
              result->Error("WEBVIEW_CREATION_FAILED",
                            "WebView2 controller has no CoreWebView2.");
              return S_OK;
            }

            ApplySettings(instance, enable_javascript, enable_dom_storage,
                          user_agent);
            // Handlers must be live *before* the first navigation, otherwise
            // the initial page load reports nothing back to Dart.
            RegisterEventHandlers(instance);
            ApplyBounds(instance);

            // Reply first: the channel is FIFO, so Dart registers its
            // callbacks before any navigation event can reach it.
            result->Success(flutter::EncodableValue(id));
            NavigateWithHeaders(instance->environment.Get(),
                                instance->webview.Get(), initial_url,
                                header_block);
            return S_OK;
          })
          .Get());
}

void WebViewMasterPlugin::ApplySettings(WebViewInstance* instance,
                                        bool enable_javascript,
                                        bool enable_dom_storage,
                                        const std::string& user_agent) {
  if (instance == nullptr || !instance->webview) return;
  ComPtr<ICoreWebView2Settings> settings;
  if (FAILED(instance->webview->get_Settings(&settings))) return;

  settings->put_IsScriptEnabled(enable_javascript ? TRUE : FALSE);
  settings->put_IsWebMessageEnabled(TRUE);
  settings->put_AreDefaultScriptDialogsEnabled(TRUE);
  settings->put_AreDefaultContextMenusEnabled(TRUE);
  settings->put_IsBuiltInErrorPageEnabled(TRUE);
  settings->put_IsZoomControlEnabled(TRUE);
  settings->put_IsStatusBarEnabled(FALSE);
  settings->put_AreDevToolsEnabled(TRUE);
  // Payment gateways and 3-D Secure challenges are routinely opened with
  // window.open(); WebView2's own popup blocker must stay out of the way so
  // NewWindowRequested can decide instead.
  settings->put_AreHostObjectsAllowed(TRUE);
  // WebView2 always keeps DOM storage on for a profile-backed WebView, so
  // there is no switch to honour here.
  (void)enable_dom_storage;

  if (!user_agent.empty()) {
    ComPtr<ICoreWebView2Settings2> settings2;
    if (SUCCEEDED(settings.As(&settings2))) {
      settings2->put_UserAgent(Utf16FromUtf8(user_agent).c_str());
    }
  }
}

void WebViewMasterPlugin::RegisterEventHandlers(WebViewInstance* instance) {
  if (instance == nullptr || !instance->webview) return;
  const int id = instance->id;
  ICoreWebView2* webview = instance->webview.Get();

  webview->add_NavigationStarting(
      Callback<ICoreWebView2NavigationStartingEventHandler>(
          [this, id](ICoreWebView2*,
                     ICoreWebView2NavigationStartingEventArgs* e) -> HRESULT {
            auto* instance = GetWebView(id);
            if (instance == nullptr) return S_OK;
            LPWSTR raw = nullptr;
            e->get_Uri(&raw);
            const std::string url = TakeString(raw);
            BOOL redirected = FALSE;
            e->get_IsRedirected(&redirected);

            // This is the fix for "the link jumped to the default browser":
            // WebView2 cannot render this scheme, so unless the navigation is
            // cancelled here it quietly hands the URI to the OS shell, which
            // launches whichever app is registered for it.
            if (instance->block_external_schemes && IsExternalScheme(url)) {
              e->put_Cancel(TRUE);
              SendEvent("onNavigationRequest", id,
                        {{flutter::EncodableValue("url"),
                          flutter::EncodableValue(url)},
                         {flutter::EncodableValue("isForMainFrame"),
                          flutter::EncodableValue(true)}});
              SendError(id, url, -10,
                        "Unsupported scheme: blocked WebView2 from handing "
                        "this URL to an external app");
              return S_OK;
            }

            instance->progress = 0;
            AskNavigationDecision(
                "onNavigationRequest", id,
                {{flutter::EncodableValue("url"), flutter::EncodableValue(url)},
                 {flutter::EncodableValue("isForMainFrame"),
                  flutter::EncodableValue(true)},
                 {flutter::EncodableValue("isRedirect"),
                  flutter::EncodableValue(redirected != FALSE)}});
            SendEvent("onPageStarted", id,
                      {{flutter::EncodableValue("url"),
                        flutter::EncodableValue(url)}});
            SendProgress(instance, 10);
            return S_OK;
          })
          .Get(),
      nullptr);

  // WebView2 has no progress notifications, so the load milestones it does
  // report are mapped onto the 0-100 range Dart expects.
  webview->add_ContentLoading(
      Callback<ICoreWebView2ContentLoadingEventHandler>(
          [this, id](ICoreWebView2*,
                     ICoreWebView2ContentLoadingEventArgs*) -> HRESULT {
            SendProgress(GetWebView(id), 40);
            return S_OK;
          })
          .Get(),
      nullptr);

  ComPtr<ICoreWebView2_2> webview2;
  if (SUCCEEDED(instance->webview.As(&webview2))) {
    webview2->add_DOMContentLoaded(
        Callback<ICoreWebView2DOMContentLoadedEventHandler>(
            [this, id](ICoreWebView2*,
                       ICoreWebView2DOMContentLoadedEventArgs*) -> HRESULT {
              SendProgress(GetWebView(id), 70);
              return S_OK;
            })
            .Get(),
        nullptr);
  }

  webview->add_NavigationCompleted(
      Callback<ICoreWebView2NavigationCompletedEventHandler>(
          [this, id](ICoreWebView2* sender,
                     ICoreWebView2NavigationCompletedEventArgs* e) -> HRESULT {
            auto* instance = GetWebView(id);
            if (instance == nullptr) return S_OK;
            LPWSTR raw = nullptr;
            sender->get_Source(&raw);
            const std::string url = TakeString(raw);
            BOOL succeeded = FALSE;
            e->get_IsSuccess(&succeeded);
            SendProgress(instance, 100);
            if (succeeded) {
              SendEvent("onPageFinished", id,
                        {{flutter::EncodableValue("url"),
                          flutter::EncodableValue(url)}});
              return S_OK;
            }
            // Without this branch a failed load just showed a blank page:
            // nothing ever reached onWebResourceError on Windows.
            COREWEBVIEW2_WEB_ERROR_STATUS status =
                COREWEBVIEW2_WEB_ERROR_STATUS_UNKNOWN;
            e->get_WebErrorStatus(&status);
            if (status == COREWEBVIEW2_WEB_ERROR_STATUS_OPERATION_CANCELED) {
              // A deliberate block looks exactly like this; it is not an error.
              return S_OK;
            }
            SendError(id, url, WebErrorToCode(status), WebErrorToName(status));
            return S_OK;
          })
          .Get(),
      nullptr);

  webview->add_NewWindowRequested(
      Callback<ICoreWebView2NewWindowRequestedEventHandler>(
          [this, id](ICoreWebView2*,
                     ICoreWebView2NewWindowRequestedEventArgs* e) -> HRESULT {
            if (GetWebView(id) == nullptr) return S_OK;
            LPWSTR raw = nullptr;
            e->get_Uri(&raw);
            const std::string url = TakeString(raw);
            BOOL user_initiated = FALSE;
            e->get_IsUserInitiated(&user_initiated);
            ComPtr<ICoreWebView2Deferral> deferral;
            e->GetDeferral(&deferral);
            HandleNewWindowRequest(id, url, user_initiated != FALSE, e,
                                   deferral);
            return S_OK;
          })
          .Get(),
      nullptr);

  // Single-page apps navigate with history.pushState, which raises neither
  // NavigationStarting nor NavigationCompleted. Report those separately so
  // Dart still sees the URL change.
  webview->add_SourceChanged(
      Callback<ICoreWebView2SourceChangedEventHandler>(
          [this, id](ICoreWebView2* sender,
                     ICoreWebView2SourceChangedEventArgs* e) -> HRESULT {
            BOOL new_document = FALSE;
            e->get_IsNewDocument(&new_document);
            if (new_document || GetWebView(id) == nullptr) return S_OK;
            LPWSTR raw = nullptr;
            sender->get_Source(&raw);
            SendEvent("onPageFinished", id,
                      {{flutter::EncodableValue("url"),
                        flutter::EncodableValue(TakeString(raw))}});
            return S_OK;
          })
          .Get(),
      nullptr);

  webview->add_ProcessFailed(
      Callback<ICoreWebView2ProcessFailedEventHandler>(
          [this, id](ICoreWebView2* sender,
                     ICoreWebView2ProcessFailedEventArgs* e) -> HRESULT {
            if (GetWebView(id) == nullptr) return S_OK;
            COREWEBVIEW2_PROCESS_FAILED_KIND kind =
                COREWEBVIEW2_PROCESS_FAILED_KIND_BROWSER_PROCESS_EXITED;
            e->get_ProcessFailedKind(&kind);
            LPWSTR raw = nullptr;
            sender->get_Source(&raw);
            SendError(id, TakeString(raw), -1,
                      kind == COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_EXITED
                          ? "The page's render process crashed"
                          : "A WebView2 process failed");
            return S_OK;
          })
          .Get(),
      nullptr);
}

void WebViewMasterPlugin::HandleNewWindowRequest(
    int id, const std::string& url, bool user_initiated,
    ComPtr<ICoreWebView2NewWindowRequestedEventArgs> args,
    ComPtr<ICoreWebView2Deferral> deferral) {
  // Runs once Dart has answered (or immediately, if it cannot).
  auto apply = [this, id, url, args, deferral](bool prevent) {
    auto* instance = GetWebView(id);
    if (instance != nullptr) {
      if (prevent) {
        // Handled with no NewWindow set: the popup is dropped.
        args->put_Handled(TRUE);
      } else if (instance->support_multiple_windows || url.empty() ||
                 url.rfind("about:", 0) == 0) {
        // Leave Handled == FALSE and let WebView2 open its own window. A
        // window.open() with no URL — how 3-D Secure and most payment
        // gateways open their challenge page — is written to from script
        // afterwards, so navigating the host WebView there would destroy the
        // page that is still driving the flow. The popup is an in-app
        // WebView2 window, not the system browser.
      } else if (instance->block_external_schemes && IsExternalScheme(url)) {
        args->put_Handled(TRUE);
        SendError(id, url, -10,
                  "Unsupported scheme: blocked WebView2 from handing this "
                  "popup to an external app");
      } else {
        args->put_Handled(TRUE);
        instance->progress = 0;
        instance->webview->Navigate(Utf16FromUtf8(url).c_str());
      }
    }
    if (deferral) deferral->Complete();
  };

  if (!channel_) {
    apply(false);
    return;
  }
  // The deferral must be completed exactly once, whatever Dart replies.
  auto answered = std::make_shared<bool>(false);
  auto once = [apply, answered](bool prevent) {
    if (*answered) return;
    *answered = true;
    apply(prevent);
  };
  const flutter::EncodableMap payload = {
      {flutter::EncodableValue("webViewId"), flutter::EncodableValue(id)},
      {flutter::EncodableValue("url"), flutter::EncodableValue(url)},
      {flutter::EncodableValue("isDialog"), flutter::EncodableValue(false)},
      {flutter::EncodableValue("isUserGesture"),
       flutter::EncodableValue(user_initiated)}};
  channel_->InvokeMethod(
      "onCreateWindow", std::make_unique<flutter::EncodableValue>(payload),
      std::make_unique<flutter::MethodResultFunctions<flutter::EncodableValue>>(
          [once](const flutter::EncodableValue* response) {
            const auto* text =
                response != nullptr ? std::get_if<std::string>(response)
                                    : nullptr;
            once(text != nullptr && *text == "prevent");
          },
          [once](const std::string&, const std::string&,
                 const flutter::EncodableValue*) { once(false); },
          [once]() { once(false); }));
}

}  // namespace web_view_master
