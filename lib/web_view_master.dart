// Internal imports for use within this file
import 'src/web_view_controller.dart';
import 'src/web_view_models.dart';
import 'web_view_master_platform_interface.dart';

// Public API exports
export 'src/notification_helper.dart';
export 'src/tools/web_view_loading_state.dart';
export 'src/web_view_controller.dart';
export 'src/web_view_models.dart';
export 'src/web_view_widget.dart';
export 'web_view_master_platform_interface.dart'
    show
        NavigationDecision,
        NavigationRequest,
        CreateWindowRequest,
        WebNotification,
        WebViewMasterPlatform;

class WebViewMaster {
  Future<String?> getPlatformVersion() {
    return WebViewMasterPlatform.instance.getPlatformVersion();
  }

  static Future<WebViewController> createController({
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
    return WebViewController.create(
      initialUrl: initialUrl,
      headers: headers,
      settings: settings,
      onPageStarted: onPageStarted,
      onPageFinished: onPageFinished,
      onWebResourceError: onWebResourceError,
      onProgressChanged: onProgressChanged,
      onNavigationRequest: onNavigationRequest,
      onCreateWindow: onCreateWindow,
      onWebNotificationReceived: onWebNotificationReceived,
    );
  }
}
