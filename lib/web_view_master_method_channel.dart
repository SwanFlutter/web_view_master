import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'web_view_master_platform_interface.dart';

/// An implementation of [WebViewMasterPlatform] that uses method channels.
class MethodChannelWebViewMaster extends WebViewMasterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('web_view_master');

  final Map<int, Map<String, Function?>> _callbacks = {};

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<int> createWebView({
    required String initialUrl,
    Map<String, String>? headers,
    bool enableJavaScript = true,
    bool enableDomStorage = true,
    String? userAgent,
    bool supportMultipleWindows = false,
    bool blockExternalSchemes = true,
  }) async {
    final webViewId = await methodChannel.invokeMethod<int>('createWebView', {
      'initialUrl': initialUrl,
      'headers': headers,
      'enableJavaScript': enableJavaScript,
      'enableDomStorage': enableDomStorage,
      'userAgent': userAgent,
      'supportMultipleWindows': supportMultipleWindows,
      'blockExternalSchemes': blockExternalSchemes,
    });
    return webViewId!;
  }

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
  }) {
    _callbacks[webViewId] = {
      'onPageStarted': onPageStarted,
      'onPageFinished': onPageFinished,
      'onWebResourceError': onWebResourceError,
      'onProgressChanged': onProgressChanged,
      'onNavigationRequest': onNavigationRequest,
      'onCreateWindow': onCreateWindow,
      'onWebNotificationReceived': onWebNotificationReceived,
    };

    methodChannel.setMethodCallHandler((call) async {
      final callWebViewId = call.arguments['webViewId'] as int?;
      if (callWebViewId == null || !_callbacks.containsKey(callWebViewId)) {
        return null;
      }

      final callbacks = _callbacks[callWebViewId]!;

      switch (call.method) {
        case 'onPageStarted':
          final url = call.arguments['url'] as String;
          (callbacks['onPageStarted'] as Function(String)?)?.call(url);
          return null;

        case 'onPageFinished':
          final url = call.arguments['url'] as String;
          (callbacks['onPageFinished'] as Function(String)?)?.call(url);
          return null;

        case 'onWebResourceError':
          final url = call.arguments['url'] as String;
          final errorCode = call.arguments['errorCode'] as int;
          (callbacks['onWebResourceError'] as Function(String, int)?)?.call(
            url,
            errorCode,
          );
          return null;

        case 'onProgressChanged':
          final progress = call.arguments['progress'] as int;
          (callbacks['onProgressChanged'] as Function(int)?)?.call(progress);
          return null;

        case 'onNavigationRequest':
          // Android blocks on this call (CountDownLatch, 500 ms timeout), so
          // answer as quickly as possible. Windows cannot defer a navigation
          // that already started: a late 'prevent' is honoured by stopping the
          // load, and URLs WebView2 would hand to another app are blocked
          // natively before this ever fires.
          final url = call.arguments['url'] as String;
          final isForMainFrame = call.arguments['isForMainFrame'] as bool;
          final navCallback =
              callbacks['onNavigationRequest']
                  as Future<NavigationDecision> Function(NavigationRequest)?;
          if (navCallback != null) {
            final decision = await navCallback(
              NavigationRequest(url: url, isForMainFrame: isForMainFrame),
            );
            return decision == NavigationDecision.prevent
                ? 'prevent'
                : 'navigate';
          }
          // No callback registered → allow by default
          return 'navigate';

        case 'onCreateWindow':
          // Android blocks like onNavigationRequest; Windows defers the popup
          // until this returns, so the decision is applied exactly.
          final url = call.arguments['url'] as String;
          final isDialog = call.arguments['isDialog'] as bool? ?? false;
          final isUserGesture =
              call.arguments['isUserGesture'] as bool? ?? false;
          final windowCallback =
              callbacks['onCreateWindow']
                  as Future<NavigationDecision> Function(CreateWindowRequest)?;
          if (windowCallback != null) {
            final decision = await windowCallback(
              CreateWindowRequest(
                url: url,
                isDialog: isDialog,
                isUserGesture: isUserGesture,
              ),
            );
            return decision == NavigationDecision.prevent
                ? 'prevent'
                : 'navigate';
          }
          // No callback → allow (load in same WebView, native side handles it)
          return 'navigate';

        case 'onWebNotificationReceived':
          final origin = call.arguments['origin'] as String?;
          final title = call.arguments['title'] as String?;
          final body = call.arguments['body'] as String?;
          final tag = call.arguments['tag'] as String?;
          (callbacks['onWebNotificationReceived'] as Function(WebNotification)?)
              ?.call(
                WebNotification(
                  origin: origin,
                  title: title,
                  body: body,
                  tag: tag,
                ),
              );
          return null;

        default:
          return null;
      }
    });
  }

  @override
  Future<void> loadUrl(
    int webViewId,
    String url, {
    Map<String, String>? headers,
  }) async {
    await methodChannel.invokeMethod('loadUrl', {
      'webViewId': webViewId,
      'url': url,
      'headers': headers,
    });
  }

  @override
  Future<void> loadHtmlString(
    int webViewId,
    String html, {
    String? baseUrl,
  }) async {
    await methodChannel.invokeMethod('loadHtmlString', {
      'webViewId': webViewId,
      'html': html,
      'baseUrl': baseUrl,
    });
  }

  @override
  Future<String?> evaluateJavaScript(int webViewId, String script) async {
    final result = await methodChannel.invokeMethod<String>(
      'evaluateJavaScript',
      {'webViewId': webViewId, 'script': script},
    );
    return result;
  }

  @override
  Future<void> goBack(int webViewId) async {
    await methodChannel.invokeMethod('goBack', {'webViewId': webViewId});
  }

  @override
  Future<void> goForward(int webViewId) async {
    await methodChannel.invokeMethod('goForward', {'webViewId': webViewId});
  }

  @override
  Future<void> reload(int webViewId) async {
    await methodChannel.invokeMethod('reload', {'webViewId': webViewId});
  }

  @override
  Future<bool> canGoBack(int webViewId) async {
    final result = await methodChannel.invokeMethod<bool>('canGoBack', {
      'webViewId': webViewId,
    });
    return result ?? false;
  }

  @override
  Future<bool> canGoForward(int webViewId) async {
    final result = await methodChannel.invokeMethod<bool>('canGoForward', {
      'webViewId': webViewId,
    });
    return result ?? false;
  }

  @override
  Future<String?> getCurrentUrl(int webViewId) async {
    final result = await methodChannel.invokeMethod<String>('getCurrentUrl', {
      'webViewId': webViewId,
    });
    return result;
  }

  @override
  Future<String?> getTitle(int webViewId) async {
    final result = await methodChannel.invokeMethod<String>('getTitle', {
      'webViewId': webViewId,
    });
    return result;
  }

  @override
  Future<void> clearCache(int webViewId) async {
    await methodChannel.invokeMethod('clearCache', {'webViewId': webViewId});
  }

  @override
  Future<void> clearCookies(int webViewId) async {
    await methodChannel.invokeMethod('clearCookies', {'webViewId': webViewId});
  }

  @override
  Future<void> setUserAgent(int webViewId, String userAgent) async {
    await methodChannel.invokeMethod('setUserAgent', {
      'webViewId': webViewId,
      'userAgent': userAgent,
    });
  }

  @override
  Future<void> setBounds(
    int webViewId,
    int left,
    int top,
    int right,
    int bottom,
  ) async {
    await methodChannel.invokeMethod('setBounds', {
      'webViewId': webViewId,
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
    });
  }

  @override
  Future<void> setVisible(int webViewId, bool visible) async {
    await methodChannel.invokeMethod('setVisible', {
      'webViewId': webViewId,
      'visible': visible,
    });
  }

  @override
  void disposeWebView(int webViewId) {
    _callbacks.remove(webViewId);
    methodChannel.invokeMethod('disposeWebView', {'webViewId': webViewId});
  }

  @override
  Future<bool> enableWebNotifications(int webViewId) async {
    final result = await methodChannel.invokeMethod<bool>(
      'enableWebNotifications',
      {'webViewId': webViewId},
    );
    return result ?? false;
  }

  @override
  Future<bool> disableWebNotifications(int webViewId) async {
    final result = await methodChannel.invokeMethod<bool>(
      'disableWebNotifications',
      {'webViewId': webViewId},
    );
    return result ?? false;
  }

  @override
  Future<void> shareCurrentPage(int webViewId) async {
    await methodChannel.invokeMethod('shareCurrentPage', {
      'webViewId': webViewId,
    });
  }

  @override
  Future<void> enablePullToRefresh(int webViewId, bool enabled) async {
    await methodChannel.invokeMethod('enablePullToRefresh', {
      'webViewId': webViewId,
      'enabled': enabled,
    });
  }

  @override
  Future<String?> findInPage(int webViewId, String searchText) async {
    final result = await methodChannel.invokeMethod<String>('findInPage', {
      'webViewId': webViewId,
      'searchText': searchText,
    });
    return result;
  }

  @override
  Future<void> clearFindMatches(int webViewId) async {
    await methodChannel.invokeMethod('clearFindMatches', {
      'webViewId': webViewId,
    });
  }

  @override
  Future<String?> takeScreenshot(int webViewId) async {
    final result = await methodChannel.invokeMethod<String>('takeScreenshot', {
      'webViewId': webViewId,
    });
    return result;
  }

  @override
  Future<void> injectCSS(int webViewId, String css) async {
    await methodChannel.invokeMethod('injectCSS', {
      'webViewId': webViewId,
      'css': css,
    });
  }

  @override
  Future<String?> getSelectedText(int webViewId) async {
    final result = await methodChannel.invokeMethod<String>('getSelectedText', {
      'webViewId': webViewId,
    });
    return result;
  }

  @override
  Future<Map<String, dynamic>?> getPageAnalytics(int webViewId) async {
    final result = await methodChannel.invokeMethod('getPageAnalytics', {
      'webViewId': webViewId,
    });
    // Android replies with a map; Windows evaluates JSON.stringify in the page
    // and replies with the document itself.
    if (result is Map) return result.cast<String, dynamic>();
    if (result is String && result.isNotEmpty) {
      try {
        final decoded = jsonDecode(result);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  @override
  Future<bool> isDarkModeEnabled(int webViewId) async {
    final result = await methodChannel.invokeMethod<bool>('isDarkModeEnabled', {
      'webViewId': webViewId,
    });
    return result ?? false;
  }

  @override
  Future<bool> hasNotificationPermission() async {
    final result = await methodChannel.invokeMethod<bool>(
      'hasNotificationPermission',
    );
    return result ?? false;
  }

  @override
  Future<String> requestNotificationPermission() async {
    final result = await methodChannel.invokeMethod<String>(
      'requestNotificationPermission',
    );
    return result ?? 'denied';
  }
}
