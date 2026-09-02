import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../web_view_master_platform_interface.dart';
import 'tools/web_view_loading_state.dart';
import 'web_view_controller.dart';
import 'web_view_models.dart';

/// A WebView widget that displays web content.
class WebViewWidget extends StatefulWidget {
  /// The initial URL to load.
  final String initialUrl;

  /// Initial headers to send with the request.
  final Map<String, String>? headers;

  /// WebView settings.
  final WebViewSettings? settings;

  /// Called when a page starts loading.
  final Function(String url)? onPageStarted;

  /// Called when a page finishes loading.
  final Function(String url)? onPageFinished;

  /// Called when a web resource error occurs.
  final Function(WebViewError error)? onWebResourceError;

  /// Called when the loading progress changes.
  final Function(WebViewProgress progress)? onProgressChanged;

  /// Called for every main-frame navigation request.
  ///
  /// Return [NavigationDecision.prevent] to block the navigation,
  /// or [NavigationDecision.navigate] to allow it.
  /// When null, all navigations are allowed.
  final Future<NavigationDecision> Function(NavigationRequest request)?
  onNavigationRequest;

  /// Called when a page attempts to open a new window
  /// (e.g. target="_blank" links or window.open() calls).
  ///
  /// Return [NavigationDecision.prevent] to discard the new window,
  /// or [NavigationDecision.navigate] to load the URL inside this WebView.
  /// When null, new-window URLs are loaded inside this WebView.
  final Future<NavigationDecision> Function(CreateWindowRequest request)?
  onCreateWindow;

  /// Called when a web notification is received.
  final Function(WebNotification notification)? onWebNotificationReceived;

  /// Called when the WebView controller is ready.
  final Function(WebViewController controller)? onWebViewCreated;

  /// Whether to show a loading indicator overlay while a page is loading.
  final bool showLoadingIndicator;

  /// Custom widget shown while the native WebView is being initialised.
  final Widget? loadingWidget;

  /// Custom widget shown when the page fails to load.
  final Widget Function(WebViewError error)? errorWidget;

  /// Background color of the WebView container.
  final Color? backgroundColor;

  const WebViewWidget({
    super.key,
    required this.initialUrl,
    this.headers,
    this.settings,
    this.onPageStarted,
    this.onPageFinished,
    this.onWebResourceError,
    this.onProgressChanged,
    this.onNavigationRequest,
    this.onCreateWindow,
    this.onWebNotificationReceived,
    this.onWebViewCreated,
    this.showLoadingIndicator = false,
    this.loadingWidget,
    this.errorWidget,
    this.backgroundColor,
  });

  @override
  State<WebViewWidget> createState() => _WebViewWidgetState();
}

class _WebViewWidgetState extends State<WebViewWidget>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  WebViewLoadingState _loadingState = WebViewLoadingState.loading;
  WebViewError? _error;
  int _progress = 0;

  /// Windows only: the last rectangle and visibility pushed to WebView2, so
  /// the native call can be skipped while nothing actually moves.
  Rect? _lastBounds;
  bool? _lastVisible;
  bool _syncScheduled = false;

  bool get _isWindows => defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWebView();
    });
  }

  @override
  void didChangeMetrics() => _scheduleWindowsSync();

  Future<void> _initializeWebView() async {
    try {
      _controller = await WebViewController.create(
        initialUrl: widget.initialUrl,
        headers: widget.headers,
        settings: widget.settings,
        onPageStarted: (url) {
          Future.microtask(() {
            if (mounted) {
              setState(() {
                _loadingState = WebViewLoadingState.loading;
                _error = null;
              });
              widget.onPageStarted?.call(url);
            }
          });
        },
        onPageFinished: (url) {
          Future.microtask(() {
            if (mounted) {
              setState(() => _loadingState = WebViewLoadingState.finished);
              widget.onPageFinished?.call(url);
            }
          });
        },
        onWebResourceError: (error) {
          Future.microtask(() {
            if (mounted) {
              // A blocked external scheme (-10) is reported so the app can
              // react to it, but it must not replace the page: the document
              // that tried to open the deep link is still there and still
              // usable — that is exactly the payment-gateway case. Only show
              // the error screen when no page has been displayed yet.
              final keepPage =
                  error.errorCode == -10 &&
                  _loadingState == WebViewLoadingState.finished;
              if (!keepPage) {
                setState(() {
                  _loadingState = WebViewLoadingState.error;
                  _error = error;
                });
              }
              widget.onWebResourceError?.call(error);
            }
          });
        },
        onProgressChanged: (progress) {
          Future.microtask(() {
            if (mounted && (progress.progress - _progress).abs() >= 5) {
              setState(() => _progress = progress.progress);
              widget.onProgressChanged?.call(progress);
            }
          });
        },
        // Forward to widget callbacks; fall back to NavigationDecision.navigate
        onNavigationRequest:
            widget.onNavigationRequest ??
            (_) async => NavigationDecision.navigate,
        onCreateWindow:
            widget.onCreateWindow ?? (_) async => NavigationDecision.navigate,
        onWebNotificationReceived: widget.onWebNotificationReceived,
      );

      Future.microtask(() {
        if (!mounted) return;
        widget.onWebViewCreated?.call(_controller!);
        // Windows: WebView2 lives in its own child window, so it has to be
        // told where the Flutter widget is and when to hide.
        _scheduleWindowsSync();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingState = WebViewLoadingState.error;
          _error = WebViewError(
            url: widget.initialUrl,
            errorCode: -1,
            description: 'Failed to initialize WebView: $e',
          );
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  /// Windows only: keeps WebView2 aligned with this widget.
  ///
  /// The native window is a sibling of the Flutter surface rather than a
  /// texture inside it, so nothing moves it automatically — its rectangle has
  /// to be re-pushed whenever the layout changes. The callback re-arms itself,
  /// but a post-frame callback only runs when a frame is actually produced, so
  /// an idle app costs nothing.
  void _scheduleWindowsSync() {
    if (!_isWindows || _syncScheduled || _controller == null) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted || _controller == null) return;
      _syncWindowsGeometry();
      _scheduleWindowsSync();
    });
  }

  void _syncWindowsGeometry() {
    final box = context.findRenderObject() as RenderBox?;
    final visible = _nativeViewShouldBeVisible(box);
    if (box != null && box.attached && box.hasSize && !box.size.isEmpty) {
      final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
      final origin = box.localToGlobal(Offset.zero);
      final rect = Rect.fromLTRB(
        (origin.dx * dpr).roundToDouble(),
        (origin.dy * dpr).roundToDouble(),
        ((origin.dx + box.size.width) * dpr).roundToDouble(),
        ((origin.dy + box.size.height) * dpr).roundToDouble(),
      );
      if (rect != _lastBounds) {
        _lastBounds = rect;
        _controller!.setBounds(
          rect.left.toInt(),
          rect.top.toInt(),
          rect.right.toInt(),
          rect.bottom.toInt(),
        );
      }
    }
    if (visible != _lastVisible) {
      _lastVisible = visible;
      _controller!.setVisible(visible);
    }
  }

  /// WebView2 paints over everything Flutter draws, so it has to be hidden
  /// whenever Flutter is showing something on top of it: the error page, the
  /// loading overlay, a dialog, or another route.
  bool _nativeViewShouldBeVisible(RenderBox? box) {
    if (box == null || !box.attached || !box.hasSize || box.size.isEmpty) {
      return false;
    }
    if (_loadingState == WebViewLoadingState.error) return false;
    if (widget.showLoadingIndicator &&
        _loadingState == WebViewLoadingState.loading) {
      return false;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    return TickerMode.valuesOf(context).enabled;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor ?? Colors.white,
      child: Stack(
        children: [
          if (_controller != null) _buildWebView() else _buildLoadingWidget(),

          if (_loadingState == WebViewLoadingState.loading &&
              widget.showLoadingIndicator)
            _buildLoadingOverlay(),

          if (_loadingState == WebViewLoadingState.error && _error != null)
            _buildErrorWidget(),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    const String viewType = 'web_view_master';
    final Map<String, dynamic> creationParams = {
      'webViewId': _controller!.webViewId,
    };

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidView(
          viewType: viewType,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        );
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: viewType,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        );
      case TargetPlatform.macOS:
        return AppKitView(
          viewType: viewType,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        );
      case TargetPlatform.windows:
        // WebView2 renders into its own child window — not into a Flutter
        // Texture — and that window paints on top of the Flutter surface.
        // Reserve the space here and let _syncWindowsGeometry keep the native
        // window lined up with this box.
        return const SizedBox.expand();
      default:
        return Center(
          child: Text(
            '$defaultTargetPlatform is not yet supported by web_view_master',
          ),
        );
    }
  }

  Widget _buildLoadingWidget() {
    if (widget.loadingWidget != null) return widget.loadingWidget!;
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white.withValues(alpha: 0.8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Loading... $_progress%'),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _progress / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (widget.errorWidget != null && _error != null) {
      return widget.errorWidget!(_error!);
    }

    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load page',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(
                _error!.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _controller?.reload(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
