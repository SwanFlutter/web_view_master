import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:web_view_master/web_view_master.dart';
import 'package:web_view_master/web_view_master_method_channel.dart';

class MockWebViewMasterPlatform
    with MockPlatformInterfaceMixin
    implements WebViewMasterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<int> createWebView({
    required String initialUrl,
    Map<String, String>? headers,
    bool enableJavaScript = true,
    bool enableDomStorage = true,
    String? userAgent,
    bool supportMultipleWindows = false,
    bool blockExternalSchemes = true,
  }) => Future.value(1);

  @override
  void setCallbacks({
    required int webViewId,
    Function(String)? onPageStarted,
    Function(String)? onPageFinished,
    Function(String, int)? onWebResourceError,
    Function(int)? onProgressChanged,
    Future<NavigationDecision> Function(NavigationRequest)? onNavigationRequest,
    Future<NavigationDecision> Function(CreateWindowRequest)? onCreateWindow,
    Function(WebNotification)? onWebNotificationReceived,
  }) {}

  @override
  Future<void> loadUrl(
    int webViewId,
    String url, {
    Map<String, String>? headers,
  }) => Future.value();

  @override
  Future<void> loadHtmlString(int webViewId, String html, {String? baseUrl}) =>
      Future.value();

  @override
  Future<String?> evaluateJavaScript(int webViewId, String script) =>
      Future.value('result');

  @override
  Future<void> goBack(int webViewId) => Future.value();

  @override
  Future<void> goForward(int webViewId) => Future.value();

  @override
  Future<void> reload(int webViewId) => Future.value();

  @override
  Future<bool> canGoBack(int webViewId) => Future.value(false);

  @override
  Future<bool> canGoForward(int webViewId) => Future.value(false);

  @override
  Future<String?> getCurrentUrl(int webViewId) =>
      Future.value('https://example.com');

  @override
  Future<String?> getTitle(int webViewId) => Future.value('Example Title');

  @override
  Future<void> clearCache(int webViewId) => Future.value();

  @override
  Future<void> clearCookies(int webViewId) => Future.value();

  @override
  Future<void> setUserAgent(int webViewId, String userAgent) => Future.value();

  @override
  void disposeWebView(int webViewId) {}

  @override
  Future<bool> enableWebNotifications(int webViewId) => Future.value(true);

  @override
  Future<bool> disableWebNotifications(int webViewId) => Future.value(true);

  @override
  Future<void> shareCurrentPage(int webViewId) => Future.value();

  @override
  Future<void> enablePullToRefresh(int webViewId, bool enabled) =>
      Future.value();

  @override
  Future<String?> findInPage(int webViewId, String searchText) =>
      Future.value("Found");

  @override
  Future<void> clearFindMatches(int webViewId) => Future.value();

  @override
  Future<String?> takeScreenshot(int webViewId) => Future.value("base64image");

  @override
  Future<void> injectCSS(int webViewId, String css) => Future.value();

  @override
  Future<String?> getSelectedText(int webViewId) =>
      Future.value("selected text");

  @override
  Future<Map<String, dynamic>?> getPageAnalytics(int webViewId) =>
      Future.value({"url": "test"});

  @override
  Future<bool> isDarkModeEnabled(int webViewId) => Future.value(false);

  @override
  Future<bool> hasNotificationPermission() {
    throw UnimplementedError();
  }

  @override
  Future<String> requestNotificationPermission() {
    throw UnimplementedError();
  }

  @override
  Future<void> setBounds(
    int webViewId,
    int left,
    int top,
    int right,
    int bottom,
  ) => Future.value();

  @override
  Future<void> setVisible(int webViewId, bool visible) => Future.value();
}

void main() {
  final WebViewMasterPlatform initialPlatform = WebViewMasterPlatform.instance;

  test('$MethodChannelWebViewMaster is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWebViewMaster>());
  });

  test('getPlatformVersion', () async {
    WebViewMaster webViewMasterPlugin = WebViewMaster();
    MockWebViewMasterPlatform fakePlatform = MockWebViewMasterPlatform();
    WebViewMasterPlatform.instance = fakePlatform;

    expect(await webViewMasterPlugin.getPlatformVersion(), '42');
  });
}
