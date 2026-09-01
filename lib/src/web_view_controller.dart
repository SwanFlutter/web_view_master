import '../web_view_master_platform_interface.dart';
import 'web_view_models.dart';

/// Controller for managing WebView instances
class WebViewController {
  late int _webViewId;
  Function(String)? _onPageStarted;
  Function(String)? _onPageFinished;
  Function(WebViewError)? _onWebResourceError;
  Function(WebViewProgress)? _onProgressChanged;
  Future<NavigationDecision> Function(NavigationRequest)? _onNavigationRequest;
  Future<NavigationDecision> Function(CreateWindowRequest)? _onCreateWindow;
  Function(WebNotification)? _onWebNotificationReceived;

  WebViewController._();

  /// Creates a new WebView controller.
  ///
  /// [onNavigationRequest] is called for every main-frame navigation.
  /// Return [NavigationDecision.prevent] to block the navigation or
  /// [NavigationDecision.navigate] to allow it (default when null).
  ///
  /// [onCreateWindow] is called when a page tries to open a new window
  /// (target="_blank", window.open(), etc.).
  /// Return [NavigationDecision.prevent] to block it or
  /// [NavigationDecision.navigate] to load it inside this WebView.
  static Future<WebViewController> create({
    required String initialUrl,
    Map<String, String>? headers,
    WebViewSettings? settings,
    Function(String)? onPageStarted,
    Function(String)? onPageFinished,
    Function(WebViewError)? onWebResourceError,
    Function(WebViewProgress)? onProgressChanged,
    Future<NavigationDecision> Function(NavigationRequest)? onNavigationRequest,
    Future<NavigationDecision> Function(CreateWindowRequest)? onCreateWindow,
    Function(WebNotification)? onWebNotificationReceived,
  }) async {
    final controller = WebViewController._();
    await controller._initialize(
      initialUrl: initialUrl,
      headers: headers,
      settings: settings ?? const WebViewSettings(),
      onPageStarted: onPageStarted,
      onPageFinished: onPageFinished,
      onWebResourceError: onWebResourceError,
      onProgressChanged: onProgressChanged,
      onNavigationRequest: onNavigationRequest,
      onCreateWindow: onCreateWindow,
      onWebNotificationReceived: onWebNotificationReceived,
    );
    return controller;
  }

  Future<void> _initialize({
    required String initialUrl,
    Map<String, String>? headers,
    required WebViewSettings settings,
    Function(String)? onPageStarted,
    Function(String)? onPageFinished,
    Function(WebViewError)? onWebResourceError,
    Function(WebViewProgress)? onProgressChanged,
    Future<NavigationDecision> Function(NavigationRequest)? onNavigationRequest,
    Future<NavigationDecision> Function(CreateWindowRequest)? onCreateWindow,
    Function(WebNotification)? onWebNotificationReceived,
  }) async {
    _onPageStarted = onPageStarted;
    _onPageFinished = onPageFinished;
    _onWebResourceError = onWebResourceError;
    _onProgressChanged = onProgressChanged;
    _onNavigationRequest = onNavigationRequest;
    _onCreateWindow = onCreateWindow;
    _onWebNotificationReceived = onWebNotificationReceived;

    _webViewId = await WebViewMasterPlatform.instance.createWebView(
      initialUrl: initialUrl,
      headers: headers,
      enableJavaScript: settings.enableJavaScript,
      enableDomStorage: settings.enableDomStorage,
      userAgent: settings.userAgent,
    );

    WebViewMasterPlatform.instance.setCallbacks(
      webViewId: _webViewId,
      onPageStarted: _onPageStarted,
      onPageFinished: _onPageFinished,
      onWebResourceError: (url, errorCode) {
        _onWebResourceError?.call(
          WebViewError(
            url: url,
            errorCode: errorCode,
            description: _getErrorDescription(errorCode),
          ),
        );
      },
      onProgressChanged: (progress) {
        _onProgressChanged?.call(WebViewProgress(progress: progress, url: ''));
      },
      onNavigationRequest: _onNavigationRequest,
      onCreateWindow: _onCreateWindow,
      onWebNotificationReceived: _onWebNotificationReceived,
    );
  }

  String _getErrorDescription(int errorCode) {
    switch (errorCode) {
      case -1:
        return 'Unknown error';
      case -2:
        return 'Host lookup failed';
      case -3:
        return 'Unsupported authentication scheme';
      case -4:
        return 'Authentication failed';
      case -5:
        return 'Proxy authentication failed';
      case -6:
        return 'Connection failed';
      case -7:
        return 'IO error';
      case -8:
        return 'Timeout';
      case -9:
        return 'Redirect loop';
      case -10:
        return 'Unsupported scheme';
      case -11:
        return 'Failed SSL handshake';
      case -12:
        return 'Bad URL';
      case -13:
        return 'File not found';
      case -14:
        return 'File access denied';
      case -15:
        return 'Too many requests';
      default:
        return 'Error code: $errorCode';
    }
  }

  /// Load a URL in the WebView
  Future<void> loadUrl(String url, {Map<String, String>? headers}) {
    return WebViewMasterPlatform.instance.loadUrl(
      _webViewId,
      url,
      headers: headers,
    );
  }

  /// Load HTML string in the WebView
  Future<void> loadHtmlString(String html, {String? baseUrl}) {
    return WebViewMasterPlatform.instance.loadHtmlString(
      _webViewId,
      html,
      baseUrl: baseUrl,
    );
  }

  /// Execute JavaScript in the WebView
  Future<String?> evaluateJavaScript(String script) {
    return WebViewMasterPlatform.instance.evaluateJavaScript(
      _webViewId,
      script,
    );
  }

  /// Navigate back in the WebView history
  Future<void> goBack() {
    return WebViewMasterPlatform.instance.goBack(_webViewId);
  }

  /// Navigate forward in the WebView history
  Future<void> goForward() {
    return WebViewMasterPlatform.instance.goForward(_webViewId);
  }

  /// Reload the current page
  Future<void> reload() {
    return WebViewMasterPlatform.instance.reload(_webViewId);
  }

  /// Check if the WebView can navigate back
  Future<bool> canGoBack() {
    return WebViewMasterPlatform.instance.canGoBack(_webViewId);
  }

  /// Check if the WebView can navigate forward
  Future<bool> canGoForward() {
    return WebViewMasterPlatform.instance.canGoForward(_webViewId);
  }

  /// Get the current URL
  Future<String?> getCurrentUrl() {
    return WebViewMasterPlatform.instance.getCurrentUrl(_webViewId);
  }

  /// Get the current page title
  Future<String?> getTitle() {
    return WebViewMasterPlatform.instance.getTitle(_webViewId);
  }

  /// Clear the WebView cache
  Future<void> clearCache() {
    return WebViewMasterPlatform.instance.clearCache(_webViewId);
  }

  /// Clear all cookies
  Future<void> clearCookies() {
    return WebViewMasterPlatform.instance.clearCookies(_webViewId);
  }

  /// Set the user agent string
  Future<void> setUserAgent(String userAgent) {
    return WebViewMasterPlatform.instance.setUserAgent(_webViewId, userAgent);
  }

  /// Enable web notifications
  Future<bool> enableWebNotifications() {
    return WebViewMasterPlatform.instance.enableWebNotifications(_webViewId);
  }

  /// Disable web notifications
  Future<bool> disableWebNotifications() {
    return WebViewMasterPlatform.instance.disableWebNotifications(_webViewId);
  }

  /// Share the current page using the system share dialog
  Future<void> shareCurrentPage() {
    return WebViewMasterPlatform.instance.shareCurrentPage(_webViewId);
  }

  /// Enable or disable pull-to-refresh functionality
  Future<void> enablePullToRefresh(bool enabled) {
    return WebViewMasterPlatform.instance.enablePullToRefresh(
      _webViewId,
      enabled,
    );
  }

  /// Find text in the current page
  Future<String?> findInPage(String searchText) {
    return WebViewMasterPlatform.instance.findInPage(_webViewId, searchText);
  }

  /// Clear find matches and highlights
  Future<void> clearFindMatches() {
    return WebViewMasterPlatform.instance.clearFindMatches(_webViewId);
  }

  /// Take a screenshot of the current page.
  /// Returns a base64 encoded PNG image.
  Future<String?> takeScreenshot() {
    return WebViewMasterPlatform.instance.takeScreenshot(_webViewId);
  }

  /// Inject custom CSS into the current page
  Future<void> injectCSS(String css) {
    return WebViewMasterPlatform.instance.injectCSS(_webViewId, css);
  }

  /// Get the currently selected text on the page
  Future<String?> getSelectedText() {
    return WebViewMasterPlatform.instance.getSelectedText(_webViewId);
  }

  /// Get comprehensive analytics data about the current page
  Future<Map<String, dynamic>?> getPageAnalytics() {
    return WebViewMasterPlatform.instance.getPageAnalytics(_webViewId);
  }

  /// Check if dark mode is enabled in the current page
  Future<bool> isDarkModeEnabled() {
    return WebViewMasterPlatform.instance.isDarkModeEnabled(_webViewId);
  }

  /// Check if notification permission is granted
  Future<bool> hasNotificationPermission() {
    return WebViewMasterPlatform.instance.hasNotificationPermission();
  }

  /// Request notification permission.
  /// Returns 'granted', 'denied', or 'requested'.
  Future<String> requestNotificationPermission() {
    return WebViewMasterPlatform.instance.requestNotificationPermission();
  }

  /// Get the WebView ID
  int get webViewId => _webViewId;

  /// Dispose the WebView controller
  void dispose() {
    WebViewMasterPlatform.instance.disposeWebView(_webViewId);
  }
}
