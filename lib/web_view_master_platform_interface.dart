import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'web_view_master_method_channel.dart';

/// Whether to allow or block a navigation.
enum NavigationDecision {
  /// Allow the navigation or new window to proceed.
  navigate,

  /// Block the navigation or discard the new window.
  prevent,
}

abstract class WebViewMasterPlatform extends PlatformInterface {
  /// Constructs a WebViewMasterPlatform.
  WebViewMasterPlatform() : super(token: _token);

  static final Object _token = Object();

  static WebViewMasterPlatform _instance = MethodChannelWebViewMaster();

  /// The default instance of [WebViewMasterPlatform] to use.
  ///
  /// Defaults to [MethodChannelWebViewMaster].
  static WebViewMasterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WebViewMasterPlatform] when
  /// they register themselves.
  static set instance(WebViewMasterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<int> createWebView({
    required String initialUrl,
    Map<String, String>? headers,
    bool enableJavaScript = true,
    bool enableDomStorage = true,
    String? userAgent,
  }) {
    throw UnimplementedError('createWebView() has not been implemented.');
  }

  void setCallbacks({
    required int webViewId,
    Function(String)? onPageStarted,
    Function(String)? onPageFinished,
    Function(String, int)? onWebResourceError,
    Function(int)? onProgressChanged,
    Future<NavigationDecision> Function(NavigationRequest)? onNavigationRequest,
    Future<NavigationDecision> Function(CreateWindowRequest)? onCreateWindow,
    Function(WebNotification)? onWebNotificationReceived,
  }) {
    throw UnimplementedError('setCallbacks() has not been implemented.');
  }

  Future<void> loadUrl(
    int webViewId,
    String url, {
    Map<String, String>? headers,
  }) {
    throw UnimplementedError('loadUrl() has not been implemented.');
  }

  Future<void> loadHtmlString(int webViewId, String html, {String? baseUrl}) {
    throw UnimplementedError('loadHtmlString() has not been implemented.');
  }

  Future<String?> evaluateJavaScript(int webViewId, String script) {
    throw UnimplementedError('evaluateJavaScript() has not been implemented.');
  }

  Future<void> goBack(int webViewId) {
    throw UnimplementedError('goBack() has not been implemented.');
  }

  Future<void> goForward(int webViewId) {
    throw UnimplementedError('goForward() has not been implemented.');
  }

  Future<void> reload(int webViewId) {
    throw UnimplementedError('reload() has not been implemented.');
  }

  Future<bool> canGoBack(int webViewId) {
    throw UnimplementedError('canGoBack() has not been implemented.');
  }

  Future<bool> canGoForward(int webViewId) {
    throw UnimplementedError('canGoForward() has not been implemented.');
  }

  Future<String?> getCurrentUrl(int webViewId) {
    throw UnimplementedError('getCurrentUrl() has not been implemented.');
  }

  Future<String?> getTitle(int webViewId) {
    throw UnimplementedError('getTitle() has not been implemented.');
  }

  Future<void> clearCache(int webViewId) {
    throw UnimplementedError('clearCache() has not been implemented.');
  }

  Future<void> clearCookies(int webViewId) {
    throw UnimplementedError('clearCookies() has not been implemented.');
  }

  Future<void> setUserAgent(int webViewId, String userAgent) {
    throw UnimplementedError('setUserAgent() has not been implemented.');
  }

  void disposeWebView(int webViewId) {
    throw UnimplementedError('disposeWebView() has not been implemented.');
  }

  Future<bool> enableWebNotifications(int webViewId) {
    throw UnimplementedError(
      'enableWebNotifications() has not been implemented.',
    );
  }

  Future<bool> disableWebNotifications(int webViewId) {
    throw UnimplementedError(
      'disableWebNotifications() has not been implemented.',
    );
  }

  Future<void> shareCurrentPage(int webViewId) {
    throw UnimplementedError('shareCurrentPage() has not been implemented.');
  }

  Future<void> enablePullToRefresh(int webViewId, bool enabled) {
    throw UnimplementedError('enablePullToRefresh() has not been implemented.');
  }

  Future<String?> findInPage(int webViewId, String searchText) {
    throw UnimplementedError('findInPage() has not been implemented.');
  }

  Future<void> clearFindMatches(int webViewId) {
    throw UnimplementedError('clearFindMatches() has not been implemented.');
  }

  Future<String?> takeScreenshot(int webViewId) {
    throw UnimplementedError('takeScreenshot() has not been implemented.');
  }

  Future<void> injectCSS(int webViewId, String css) {
    throw UnimplementedError('injectCSS() has not been implemented.');
  }

  Future<String?> getSelectedText(int webViewId) {
    throw UnimplementedError('getSelectedText() has not been implemented.');
  }

  Future<Map<String, dynamic>?> getPageAnalytics(int webViewId) {
    throw UnimplementedError('getPageAnalytics() has not been implemented.');
  }

  Future<bool> isDarkModeEnabled(int webViewId) {
    throw UnimplementedError('isDarkModeEnabled() has not been implemented.');
  }

  Future<bool> hasNotificationPermission() {
    throw UnimplementedError(
      'hasNotificationPermission() has not been implemented.',
    );
  }

  Future<String> requestNotificationPermission() {
    throw UnimplementedError(
      'requestNotificationPermission() has not been implemented.',
    );
  }
}

class NavigationRequest {
  final String url;
  final bool isForMainFrame;

  NavigationRequest({required this.url, required this.isForMainFrame});
}

class CreateWindowRequest {
  final String url;
  final bool isDialog;
  final bool isUserGesture;

  CreateWindowRequest({
    required this.url,
    required this.isDialog,
    required this.isUserGesture,
  });
}

class WebNotification {
  final String? origin;
  final String? title;
  final String? body;
  final String? tag;

  WebNotification({this.origin, this.title, this.body, this.tag});
}
