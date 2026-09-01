import Flutter
import UIKit
import WebKit
import UserNotifications

public class WebViewMasterPlugin: NSObject, FlutterPlugin {
  private var channel: FlutterMethodChannel?
  private var webViews: [Int: WKWebView] = [:]
  private var webViewIdGenerator = 0

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "web_view_master", binaryMessenger: registrar.messenger())
    let instance = WebViewMasterPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)

    // Register platform view factory
    let factory = WebViewFactory(plugin: instance)
    registrar.register(factory, withId: "web_view_master")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "createWebView":
      createWebView(call: call, result: result)
    case "loadUrl":
      loadUrl(call: call, result: result)
    case "loadHtmlString":
      loadHtmlString(call: call, result: result)
    case "evaluateJavaScript":
      evaluateJavaScript(call: call, result: result)
    case "goBack":
      goBack(call: call, result: result)
    case "goForward":
      goForward(call: call, result: result)
    case "reload":
      reload(call: call, result: result)
    case "canGoBack":
      canGoBack(call: call, result: result)
    case "canGoForward":
      canGoForward(call: call, result: result)
    case "getCurrentUrl":
      getCurrentUrl(call: call, result: result)
    case "getTitle":
      getTitle(call: call, result: result)
    case "clearCache":
      clearCache(call: call, result: result)
    case "clearCookies":
      clearCookies(call: call, result: result)
    case "setUserAgent":
      setUserAgent(call: call, result: result)
    case "disposeWebView":
      disposeWebView(call: call, result: result)
    case "enableWebNotifications":
      enableWebNotifications(call: call, result: result)
    case "disableWebNotifications":
      disableWebNotifications(call: call, result: result)
    case "shareCurrentPage":
      shareCurrentPage(call: call, result: result)
    case "enablePullToRefresh":
      enablePullToRefresh(call: call, result: result)
    case "findInPage":
      findInPage(call: call, result: result)
    case "clearFindMatches":
      clearFindMatches(call: call, result: result)
    case "takeScreenshot":
      takeScreenshot(call: call, result: result)
    case "injectCSS":
      injectCSS(call: call, result: result)
    case "getSelectedText":
      getSelectedText(call: call, result: result)
    case "getPageAnalytics":
      getPageAnalytics(call: call, result: result)
    case "isDarkModeEnabled":
      isDarkModeEnabled(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func createWebView(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let initialUrl = args["initialUrl"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    webViewIdGenerator += 1
    let webViewId = webViewIdGenerator

    let headers = args["headers"] as? [String: String]
    let enableJavaScript = args["enableJavaScript"] as? Bool ?? true
    let enableDomStorage = args["enableDomStorage"] as? Bool ?? true
    let userAgent = args["userAgent"] as? String

    let configuration = WKWebViewConfiguration()
    configuration.preferences.javaScriptEnabled = enableJavaScript

    if #available(iOS 14.0, *) {
      configuration.defaultWebpagePreferences.allowsContentJavaScript = enableJavaScript
    }

    let webView = WKWebView(frame: .zero, configuration: configuration)

    // Set user agent if provided
    if let userAgent = userAgent {
      webView.customUserAgent = userAgent
    }

    // Set up navigation delegate
    webView.navigationDelegate = WebViewNavigationDelegate(webViewId: webViewId, channel: channel)

    // Set up UI delegate
    webView.uiDelegate = WebViewUIDelegate(webViewId: webViewId, channel: channel)

    webViews[webViewId] = webView

    // Load initial URL
    if !initialUrl.isEmpty {
      if let url = URL(string: initialUrl) {
        var request = URLRequest(url: url)

        // Add headers if provided
        if let headers = headers {
          for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
          }
        }

        webView.load(request)
      }
    }

    result(webViewId)
  }

  private func loadUrl(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let urlString = args["url"] as? String,
          let webView = webViews[webViewId],
          let url = URL(string: urlString) else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    var request = URLRequest(url: url)

    if let headers = args["headers"] as? [String: String] {
      for (key, value) in headers {
        request.addValue(value, forHTTPHeaderField: key)
      }
    }

    webView.load(request)
    result(nil)
  }

  private func loadHtmlString(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let html = args["html"] as? String,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    let baseUrl = args["baseUrl"] as? String
    let baseURL = baseUrl != nil ? URL(string: baseUrl!) : nil

    webView.loadHTMLString(html, baseURL: baseURL)
    result(nil)
  }

  private func evaluateJavaScript(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let script = args["script"] as? String,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    webView.evaluateJavaScript(script) { (value, error) in
      if let error = error {
        result(FlutterError(code: "JS_ERROR", message: error.localizedDescription, details: nil))
      } else {
        result(value as? String)
      }
    }
  }

  private func goBack(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    if webView.canGoBack {
      webView.goBack()
    }
    result(nil)
  }

  private func goForward(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    if webView.canGoForward {
      webView.goForward()
    }
    result(nil)
  }

  private func reload(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    webView.reload()
    result(nil)
  }

  private func canGoBack(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    result(webView.canGoBack)
  }

  private func canGoForward(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    result(webView.canGoForward)
  }

  private func getCurrentUrl(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    result(webView.url?.absoluteString)
  }

  private func getTitle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    result(webView.title)
  }

  private func clearCache(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let dataStore = WKWebsiteDataStore.default()
    let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

    dataStore.removeData(ofTypes: dataTypes, modifiedSince: Date(timeIntervalSince1970: 0)) {
      result(nil)
    }
  }

  private func clearCookies(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let dataStore = WKWebsiteDataStore.default()

    dataStore.removeData(ofTypes: [WKWebsiteDataTypeCookies], modifiedSince: Date(timeIntervalSince1970: 0)) {
      result(nil)
    }
  }

  private func setUserAgent(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let userAgent = args["userAgent"] as? String,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    webView.customUserAgent = userAgent
    result(nil)
  }

  private func disposeWebView(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    webViews.removeValue(forKey: webViewId)
    result(nil)
  }

  func getWebView(webViewId: Int) -> WKWebView? {
    return webViews[webViewId]
  }

  private func enableWebNotifications(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    // Inject JavaScript to enable notifications
    let script = """
      (function() {
        if ('Notification' in window) {
          // Override the Notification constructor to intercept notification requests
          const OriginalNotification = window.Notification;
          window.Notification = function(title, options) {
            // Send notification data to native side via webkit message handler
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.webNotification) {
              window.webkit.messageHandlers.webNotification.postMessage({
                title: title,
                body: options ? options.body : '',
                icon: options ? options.icon : '',
                tag: options ? options.tag : ''
              });
            }
            return new OriginalNotification(title, options);
          };

          // Copy static methods and properties
          Object.setPrototypeOf(window.Notification, OriginalNotification);
          Object.defineProperty(window.Notification, 'permission', {
            get: function() { return 'granted'; }
          });

          window.Notification.requestPermission = function() {
            return Promise.resolve('granted');
          };
        }
      })();
    """

    webView.evaluateJavaScript(script) { (_, error) in
      if let error = error {
        result(FlutterError(code: "SCRIPT_ERROR", message: error.localizedDescription, details: nil))
      } else {
        result(true)
      }
    }
  }

  private func disableWebNotifications(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    // Inject JavaScript to disable notifications
    let script = """
      (function() {
        if ('Notification' in window) {
          Object.defineProperty(window.Notification, 'permission', {
            get: function() { return 'denied'; }
          });

          window.Notification.requestPermission = function() {
            return Promise.resolve('denied');
          };
        }
      })();
    """

    webView.evaluateJavaScript(script) { (_, error) in
      if let error = error {
        result(FlutterError(code: "SCRIPT_ERROR", message: error.localizedDescription, details: nil))
      } else {
        result(true)
      }
    }
  }

  private func shareCurrentPage(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    guard let url = webView.url else {
      result(FlutterError(code: "NO_URL", message: "No URL to share", details: nil))
      return
    }

    let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)

    if let viewController = UIApplication.shared.windows.first?.rootViewController {
      viewController.present(activityViewController, animated: true, completion: nil)
      result(nil)
    } else {
      result(FlutterError(code: "NO_CONTROLLER", message: "No view controller available", details: nil))
    }
  }

  private func enablePullToRefresh(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let enabled = args["enabled"] as? Bool else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    // Pull to refresh would require modifying the container view
    // For now, we'll just acknowledge the call
    result(nil)
  }

  private func findInPage(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let searchText = args["searchText"] as? String,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    let script = """
      window.find('\(searchText)', false, false, true, false, true, false);
    """

    webView.evaluateJavaScript(script) { (_, error) in
      if let error = error {
        result(FlutterError(code: "SEARCH_ERROR", message: error.localizedDescription, details: nil))
      } else {
        result("Search initiated for: \(searchText)")
      }
    }
  }

  private func clearFindMatches(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    let script = """
      if (window.getSelection) {
        window.getSelection().removeAllRanges();
      }
    """

    webView.evaluateJavaScript(script) { (_, error) in
      if let error = error {
        result(FlutterError(code: "CLEAR_ERROR", message: error.localizedDescription, details: nil))
      } else {
        result(nil)
      }
    }
  }

  private func takeScreenshot(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    let renderer = UIGraphicsImageRenderer(bounds: webView.bounds)
    let image = renderer.image { context in
      webView.layer.render(in: context.cgContext)
    }

    guard let imageData = image.pngData() else {
      result(FlutterError(code: "SCREENSHOT_FAILED", message: "Failed to convert image to data", details: nil))
      return
    }

    let base64String = imageData.base64EncodedString()
    result(base64String)
  }

  private func injectCSS(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let css = args["css"] as? String,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    let script = """
      (function() {
        var style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = `\(css)`;
        document.head.appendChild(style);
      })();
    """

    webView.evaluateJavaScript(script) { (_, error) in
      if let error = error {
        result(FlutterError(code: "CSS_INJECTION_FAILED", message: error.localizedDescription, details: nil))
      } else {
        result(nil)
      }
    }
  }

  private func getSelectedText(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    let script = """
      (function() {
        return window.getSelection().toString();
      })();
    """

    webView.evaluateJavaScript(script) { (selectedText, error) in
      if let error = error {
        result(FlutterError(code: "GET_SELECTION_FAILED", message: error.localizedDescription, details: nil))
      } else {
        result(selectedText as? String ?? "")
      }
    }
  }

  private func getPageAnalytics(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    let script = """
      (function() {
        return {
          url: window.location.href,
          title: document.title,
          referrer: document.referrer,
          userAgent: navigator.userAgent,
          language: navigator.language,
          cookieEnabled: navigator.cookieEnabled,
          onLine: navigator.onLine,
          screenWidth: screen.width,
          screenHeight: screen.height,
          windowWidth: window.innerWidth,
          windowHeight: window.innerHeight,
          scrollX: window.scrollX,
          scrollY: window.scrollY,
          documentHeight: document.documentElement.scrollHeight,
          documentWidth: document.documentElement.scrollWidth,
          loadTime: performance.timing ? (performance.timing.loadEventEnd - performance.timing.navigationStart) : 0,
          domContentLoadedTime: performance.timing ? (performance.timing.domContentLoadedEventEnd - performance.timing.navigationStart) : 0
        };
      })();
    """

    webView.evaluateJavaScript(script) { (analyticsData, error) in
      if let error = error {
        result(FlutterError(code: "ANALYTICS_FAILED", message: error.localizedDescription, details: nil))
      } else {
        var analytics: [String: Any] = [:]
        analytics["rawData"] = analyticsData ?? [:]
        result(analytics)
      }
    }
  }

  private func isDarkModeEnabled(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let webViewId = args["webViewId"] as? Int,
          let webView = webViews[webViewId] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    let script = """
      (function() {
        return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
      })();
    """

    webView.evaluateJavaScript(script) { (isDark, error) in
      if let error = error {
        result(FlutterError(code: "DARK_MODE_CHECK_FAILED", message: error.localizedDescription, details: nil))
      } else {
        result(isDark as? Bool ?? false)
      }
    }
  }
}

class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
  private let webViewId: Int
  private let channel: FlutterMethodChannel?

  init(webViewId: Int, channel: FlutterMethodChannel?) {
    self.webViewId = webViewId
    self.channel = channel
  }

  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    channel?.invokeMethod("onPageStarted", arguments: [
      "webViewId": webViewId,
      "url": webView.url?.absoluteString ?? ""
    ])
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    channel?.invokeMethod("onPageFinished", arguments: [
      "webViewId": webViewId,
      "url": webView.url?.absoluteString ?? ""
    ])
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    channel?.invokeMethod("onWebResourceError", arguments: [
      "webViewId": webViewId,
      "url": webView.url?.absoluteString ?? "",
      "errorCode": (error as NSError).code
    ])
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    let url = navigationAction.request.url?.absoluteString ?? ""

    channel?.invokeMethod("onNavigationRequest", arguments: [
      "webViewId": webViewId,
      "url": url,
      "isForMainFrame": navigationAction.targetFrame?.isMainFrame ?? false
    ])

    decisionHandler(.allow)
  }
}

class WebViewUIDelegate: NSObject, WKUIDelegate {
  private let webViewId: Int
  private let channel: FlutterMethodChannel?

  init(webViewId: Int, channel: FlutterMethodChannel?) {
    self.webViewId = webViewId
    self.channel = channel
  }
}

class WebViewFactory: NSObject, FlutterPlatformViewFactory {
  private let plugin: WebViewMasterPlugin

  init(plugin: WebViewMasterPlugin) {
    self.plugin = plugin
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    let params = args as? [String: Any]
    let webViewId = params?["webViewId"] as? Int ?? 0
    return WebViewPlatformView(webView: plugin.getWebView(webViewId: webViewId))
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

class WebViewPlatformView: NSObject, FlutterPlatformView {
  private let webView: WKWebView?

  init(webView: WKWebView?) {
    self.webView = webView
  }

  func view() -> UIView {
    return webView ?? UIView()
  }
}
