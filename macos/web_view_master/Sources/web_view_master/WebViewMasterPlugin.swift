import Cocoa
import FlutterMacOS
import WebKit

public class WebViewMasterPlugin: NSObject, FlutterPlugin {
  private var registrar: FlutterPluginRegistrar
  private var channel: FlutterMethodChannel
  private var webViews: [Int: WKWebView] = [:]
  private var nextWebViewId = 1

  init(registrar: FlutterPluginRegistrar, channel: FlutterMethodChannel) {
    self.registrar = registrar
    self.channel = channel
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "web_view_master", binaryMessenger: registrar.messenger)
    let instance = WebViewMasterPlugin(registrar: registrar, channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)

    let factory = WebViewFactory(plugin: instance)
    registrar.register(factory, withId: "web_view_master")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]

    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)

    case "createWebView":
      guard let initialUrl = args?["initialUrl"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing initialUrl", details: nil))
        return
      }
      let enableJavaScript = args?["enableJavaScript"] as? Bool ?? true
      let userAgent = args?["userAgent"] as? String
      let headers = args?["headers"] as? [String: String]

      let id = nextWebViewId
      nextWebViewId += 1

      let configuration = WKWebViewConfiguration()
      if #available(macOS 14.0, *) {
        configuration.defaultWebpagePreferences.allowsContentJavaScript = enableJavaScript
      } else {
        configuration.preferences.javaScriptEnabled = enableJavaScript
      }

      let webView = WKWebView(frame: .zero, configuration: configuration)
      if let ua = userAgent { webView.customUserAgent = ua }
      webView.navigationDelegate = self
      webView.uiDelegate = self
      webViews[id] = webView

      if let url = URL(string: initialUrl) {
        var request = URLRequest(url: url)
        if let headers = headers {
          for (key, value) in headers { request.addValue(value, forHTTPHeaderField: key) }
        }
        webView.load(request)
      }
      result(id)

    case "loadUrl":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id],
            let urlString = args?["url"] as? String, let url = URL(string: urlString) else {
        result(FlutterError(code: "WEBVIEW_NOT_FOUND", message: "WebView not found", details: nil))
        return
      }
      var request = URLRequest(url: url)
      if let headers = args?["headers"] as? [String: String] {
        for (key, value) in headers { request.addValue(value, forHTTPHeaderField: key) }
      }
      webView.load(request)
      result(nil)

    case "loadHtmlString":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id],
            let html = args?["html"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        return
      }
      let baseUrl = args?["baseUrl"] as? String
      webView.loadHTMLString(html, baseURL: baseUrl.flatMap { URL(string: $0) })
      result(nil)

    case "evaluateJavaScript":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id],
            let script = args?["script"] as? String else {
        result(FlutterError(code: "WEBVIEW_NOT_FOUND", message: "WebView not found", details: nil))
        return
      }
      webView.evaluateJavaScript(script) { val, err in
        if let err = err {
          result(FlutterError(code: "JS_ERROR", message: err.localizedDescription, details: nil))
        } else {
          result(val.map { String(describing: $0) })
        }
      }

    case "goBack":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id] else {
        result(FlutterError(code: "WEBVIEW_NOT_FOUND", message: "WebView not found", details: nil))
        return
      }
      if webView.canGoBack { webView.goBack() }
      result(nil)

    case "goForward":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id] else {
        result(FlutterError(code: "WEBVIEW_NOT_FOUND", message: "WebView not found", details: nil))
        return
      }
      if webView.canGoForward { webView.goForward() }
      result(nil)

    case "reload":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id] else {
        result(FlutterError(code: "WEBVIEW_NOT_FOUND", message: "WebView not found", details: nil))
        return
      }
      webView.reload()
      result(nil)

    case "canGoBack":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id] else {
        result(false); return
      }
      result(webView.canGoBack)

    case "canGoForward":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id] else {
        result(false); return
      }
      result(webView.canGoForward)

    case "getCurrentUrl":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id] else {
        result(nil); return
      }
      result(webView.url?.absoluteString)

    case "getTitle":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id] else {
        result(nil); return
      }
      result(webView.title)

    case "clearCache":
      let dataStore = WKWebsiteDataStore.default()
      dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date.distantPast) {
        result(nil)
      }

    case "clearCookies":
      let cookieStore = WKWebsiteDataStore.default().httpCookieStore
      cookieStore.getAllCookies { cookies in
        for cookie in cookies { cookieStore.delete(cookie) }
        result(nil)
      }

    case "setUserAgent":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id],
            let userAgent = args?["userAgent"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        return
      }
      webView.customUserAgent = userAgent
      result(nil)

    case "disposeWebView":
      if let id = args?["webViewId"] as? Int {
        webViews[id]?.stopLoading()
        webViews[id]?.navigationDelegate = nil
        webViews.removeValue(forKey: id)
      }
      result(nil)

    case "injectCSS":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id],
            let css = args?["css"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        return
      }
      let escaped = css.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`").replacingOccurrences(of: "$", with: "\\$")
      let js = "(function(){var s=document.createElement('style');s.textContent=`\(escaped)`;document.head.appendChild(s);})();"
      webView.evaluateJavaScript(js, completionHandler: nil)
      result(nil)

    case "findInPage":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id],
            let searchText = args?["searchText"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        return
      }
      let escaped = searchText.replacingOccurrences(of: "'", with: "\\'")
      webView.evaluateJavaScript("window.find('\(escaped)')") { findResult, _ in
        result(findResult.map { String(describing: $0) })
      }

    case "clearFindMatches":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id] else {
        result(nil); return
      }
      webView.evaluateJavaScript("window.getSelection().removeAllRanges()", completionHandler: nil)
      result(nil)

    case "takeScreenshot":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id] else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        return
      }
      let config = WKSnapshotConfiguration()
      webView.takeSnapshot(with: config) { image, error in
        if let image = image, let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
          result(pngData.base64EncodedString())
        } else {
          result(FlutterError(code: "SCREENSHOT_ERROR", message: error?.localizedDescription ?? "Failed", details: nil))
        }
      }

    case "getSelectedText":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id] else {
        result(nil); return
      }
      webView.evaluateJavaScript("window.getSelection().toString()") { selResult, _ in
        result(selResult as? String)
      }

    case "getPageAnalytics":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id] else {
        result(nil); return
      }
      let js = """
      (function(){return{url:window.location.href,title:document.title,referrer:document.referrer,userAgent:navigator.userAgent,language:navigator.language,onLine:navigator.onLine,screenWidth:screen.width,screenHeight:screen.height,windowWidth:window.innerWidth,windowHeight:window.innerHeight};})();
      """
      webView.evaluateJavaScript(js) { analyticsData, error in
        if let error = error {
          result(FlutterError(code: "ANALYTICS_FAILED", message: error.localizedDescription, details: nil))
        } else {
          result(analyticsData)
        }
      }

    case "isDarkModeEnabled":
      guard let id = args?["webViewId"] as? Int, let webView = webViews[id] else {
        result(false); return
      }
      webView.evaluateJavaScript("window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches") { isDark, _ in
        result(isDark as? Bool ?? false)
      }

    case "enableWebNotifications", "disableWebNotifications", "shareCurrentPage", "enablePullToRefresh":
      // Stub implementations for macOS
      result(call.method == "enableWebNotifications" || call.method == "disableWebNotifications" ? true : nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func getWebView(id: Int) -> NSView? {
    return webViews[id]
  }
}

extension WebViewMasterPlugin: WKNavigationDelegate {
  public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    if let id = webViews.first(where: { $0.value == webView })?.key {
      channel.invokeMethod("onPageStarted", arguments: ["webViewId": id, "url": webView.url?.absoluteString ?? ""])
    }
  }

  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    if let id = webViews.first(where: { $0.value == webView })?.key {
      channel.invokeMethod("onPageFinished", arguments: ["webViewId": id, "url": webView.url?.absoluteString ?? ""])
    }
  }

  public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    if let id = webViews.first(where: { $0.value == webView })?.key {
      channel.invokeMethod("onWebResourceError", arguments: [
        "webViewId": id,
        "url": webView.url?.absoluteString ?? "",
        "errorCode": (error as NSError).code
      ])
    }
  }

  public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    if let id = webViews.first(where: { $0.value == webView })?.key {
      channel.invokeMethod("onWebResourceError", arguments: [
        "webViewId": id,
        "url": webView.url?.absoluteString ?? "",
        "errorCode": (error as NSError).code
      ])
    }
  }

  public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if let id = webViews.first(where: { $0.value == webView })?.key {
      channel.invokeMethod("onNavigationRequest", arguments: [
        "webViewId": id,
        "url": navigationAction.request.url?.absoluteString ?? "",
        "isForMainFrame": navigationAction.targetFrame?.isMainFrame ?? true
      ])
    }
    decisionHandler(.allow)
  }
}

extension WebViewMasterPlugin: WKUIDelegate {
  public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
    completionHandler()
  }

  public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
    completionHandler(true)
  }

  public func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
    completionHandler(defaultText)
  }
}

class WebViewFactory: NSObject, FlutterPlatformViewFactory {
  private var plugin: WebViewMasterPlugin

  init(plugin: WebViewMasterPlugin) {
    self.plugin = plugin
    super.init()
  }

  public func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    let params = args as? [String: Any]
    let webViewId = params?["webViewId"] as? Int ?? 0
    return plugin.getWebView(id: webViewId) ?? NSView()
  }

  public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}
