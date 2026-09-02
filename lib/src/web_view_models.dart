import 'dart:typed_data';

class WebViewSettings {
  final bool enableJavaScript;
  final bool enableDomStorage;
  final bool enableZoom;
  final bool enableBuiltInZoomControls;
  final bool displayZoomControls;
  final String? userAgent;
  final bool allowFileAccess;
  final bool allowContentAccess;
  final bool allowFileAccessFromFileURLs;
  final bool allowUniversalAccessFromFileURLs;
  final bool supportMultipleWindows;
  final bool enableSafeBrowsing;

  /// Whether URLs with a scheme the WebView cannot render itself
  /// (`myapp://`, `tel:`, `mailto:`, `intent://`, bank deep links …) should be
  /// blocked instead of handed to the operating system.
  ///
  /// This only affects Windows, where WebView2 otherwise passes such URLs to
  /// the shell — which launches the registered app, usually the default
  /// browser, and makes it look as though the WebView lost the link. When it
  /// is blocked, `onNavigationRequest` fires and `onWebResourceError` reports
  /// error code -10 so the app can decide what to do.
  final bool blockExternalSchemes;

  const WebViewSettings({
    this.enableJavaScript = true,
    this.enableDomStorage = true,
    this.enableZoom = true,
    this.enableBuiltInZoomControls = false,
    this.displayZoomControls = false,
    this.userAgent,
    this.allowFileAccess = true,
    this.allowContentAccess = true,
    this.allowFileAccessFromFileURLs = false,
    this.allowUniversalAccessFromFileURLs = false,
    this.supportMultipleWindows = false,
    this.enableSafeBrowsing = true,
    this.blockExternalSchemes = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'enableJavaScript': enableJavaScript,
      'enableDomStorage': enableDomStorage,
      'enableZoom': enableZoom,
      'enableBuiltInZoomControls': enableBuiltInZoomControls,
      'displayZoomControls': displayZoomControls,
      'userAgent': userAgent,
      'allowFileAccess': allowFileAccess,
      'allowContentAccess': allowContentAccess,
      'allowFileAccessFromFileURLs': allowFileAccessFromFileURLs,
      'allowUniversalAccessFromFileURLs': allowUniversalAccessFromFileURLs,
      'supportMultipleWindows': supportMultipleWindows,
      'enableSafeBrowsing': enableSafeBrowsing,
      'blockExternalSchemes': blockExternalSchemes,
    };
  }
}

class WebViewError {
  final String url;
  final int errorCode;
  final String description;

  const WebViewError({
    required this.url,
    required this.errorCode,
    required this.description,
  });

  @override
  String toString() {
    return 'WebViewError(url: $url, errorCode: $errorCode, description: $description)';
  }
}

class WebViewProgress {
  final int progress;
  final String url;

  const WebViewProgress({required this.progress, required this.url});

  @override
  String toString() {
    return 'WebViewProgress(progress: $progress%, url: $url)';
  }
}

class WebViewRequest {
  final String url;
  final Map<String, String>? headers;
  final String? method;
  final Uint8List? body;

  const WebViewRequest({
    required this.url,
    this.headers,
    this.method = 'GET',
    this.body,
  });

  Map<String, dynamic> toMap() {
    return {'url': url, 'headers': headers, 'method': method, 'body': body};
  }
}

class WebViewCookie {
  final String name;
  final String value;
  final String domain;
  final String path;
  final DateTime? expiryDate;
  final bool isSecure;
  final bool isHttpOnly;

  const WebViewCookie({
    required this.name,
    required this.value,
    required this.domain,
    this.path = '/',
    this.expiryDate,
    this.isSecure = false,
    this.isHttpOnly = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'value': value,
      'domain': domain,
      'path': path,
      'expiryDate': expiryDate?.millisecondsSinceEpoch,
      'isSecure': isSecure,
      'isHttpOnly': isHttpOnly,
    };
  }

  factory WebViewCookie.fromMap(Map<String, dynamic> map) {
    return WebViewCookie(
      name: map['name'] ?? '',
      value: map['value'] ?? '',
      domain: map['domain'] ?? '',
      path: map['path'] ?? '/',
      expiryDate: map['expiryDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiryDate'])
          : null,
      isSecure: map['isSecure'] ?? false,
      isHttpOnly: map['isHttpOnly'] ?? false,
    );
  }
}
