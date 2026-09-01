import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_view_master/web_view_master.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebView Master Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const WebViewDemoPage(),
    );
  }
}

class WebViewDemoPage extends StatefulWidget {
  const WebViewDemoPage({super.key});

  @override
  State<WebViewDemoPage> createState() => _WebViewDemoPageState();
}

class _WebViewDemoPageState extends State<WebViewDemoPage> {
  String _platformVersion = 'Unknown';
  final _webViewMasterPlugin = WebViewMaster();
  WebViewController? _controller;
  String _currentUrl = 'https://flutter.dev';
  String _pageTitle = '';
  bool _isLoading = false;
  int _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _notificationsEnabled = false;

  final TextEditingController _urlController = TextEditingController();
  Timer? _urlUpdateTimer;

  @override
  void initState() {
    super.initState();
    _urlController.text = _currentUrl;
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion =
          await _webViewMasterPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  void _onPageStarted(String url) {
    setState(() {
      _isLoading = true;
      _currentUrl = url;
    });

    // Debounce URL controller updates to reduce UI blocking
    _urlUpdateTimer?.cancel();
    _urlUpdateTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _urlController.text = url;
      }
    });

    // Defer heavy operations to avoid blocking main thread
    Future.microtask(() => _updateNavigationState());
  }

  void _onPageFinished(String url) {
    setState(() {
      _isLoading = false;
      _currentUrl = url;
    });
    // Defer heavy operations to avoid blocking main thread
    Future.microtask(() async {
      await _updateNavigationState();
      await _updateTitle();
    });
  }

  void _onProgressChanged(WebViewProgress progress) {
    // Throttle progress updates to reduce setState calls
    if ((progress.progress - _progress).abs() >= 5 ||
        progress.progress == 100) {
      setState(() {
        _progress = progress.progress;
      });
    }
  }

  void _onWebResourceError(WebViewError error) {
    setState(() {
      _isLoading = false;
    });

    // Only show error for main frame errors, not resource errors
    if (error.errorCode <= -1 && error.errorCode >= -15) {
      // Defer snackbar to avoid blocking main thread
      Future.microtask(() {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading page: ${error.description}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  Future<void> _updateNavigationState() async {
    if (_controller != null) {
      try {
        final results = await Future.wait([
          _controller!.canGoBack(),
          _controller!.canGoForward(),
        ]);

        if (mounted) {
          setState(() {
            _canGoBack = results[0];
            _canGoForward = results[1];
          });
        }
      } catch (e) {
        // Silently handle navigation state errors
        if (kDebugMode) {
          debugPrint('Navigation state update error: $e');
        }
      }
    }
  }

  Future<void> _updateTitle() async {
    if (_controller != null) {
      try {
        final title = await _controller!.getTitle();
        if (mounted) {
          setState(() {
            _pageTitle = title ?? '';
          });
        }
      } catch (e) {
        // Silently handle title update errors
        if (kDebugMode) {
          debugPrint('Title update error: $e');
        }
      }
    }
  }

  void _loadUrl() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty && _controller != null) {
      String finalUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        finalUrl = 'https://$url';
      }
      _controller!.loadUrl(finalUrl);
    }
  }

  void _goBack() {
    if (_controller != null && _canGoBack) {
      _controller!.goBack();
    }
  }

  void _goForward() {
    if (_controller != null && _canGoForward) {
      _controller!.goForward();
    }
  }

  void _reload() {
    if (_controller != null) {
      _controller!.reload();
    }
  }

  void _clearCache() {
    if (_controller != null) {
      _controller!.clearCache();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
    }
  }

  void _clearCookies() {
    if (_controller != null) {
      _controller!.clearCookies();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cookies cleared')));
    }
  }

  Future<void> _executeJavaScript() async {
    if (_controller != null) {
      try {
        final result = await _controller!.evaluateJavaScript('document.title');
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('JavaScript Result'),
              content: Text('Page title: $result'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('JavaScript error: $e')));
        }
      }
    }
  }

  void _onWebNotificationReceived(WebNotification notification) {
    // Show notification using notification_master
    NotificationHelper.showWebNotification(notification);

    // Also show a snackbar for demo purposes
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Web Notification: ${notification.title ?? 'No title'}',
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _toggleNotifications() async {
    if (_controller != null) {
      try {
        if (_notificationsEnabled) {
          await _controller!.disableWebNotifications();
          setState(() {
            _notificationsEnabled = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Web notifications disabled')),
            );
          }
        } else {
          // Initialize notification helper first
          final initialized = await NotificationHelper.initialize();
          if (initialized) {
            await _controller!.enableWebNotifications();
            setState(() {
              _notificationsEnabled = true;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Web notifications enabled')),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to initialize notifications'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Notification error: $e')));
        }
      }
    }
  }

  Future<void> _testNotification() async {
    // Test notification using notification_master directly
    await NotificationHelper.showWebNotification(
      WebNotification(
        title: 'Test Notification',
        body: 'This is a test notification from WebView Master!',
        origin: 'webview_master_demo',
      ),
    );
  }

  Future<void> _requestNotificationPermission() async {
    if (_controller != null) {
      try {
        final hasPermission = await _controller!.hasNotificationPermission();

        if (hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notification permission already granted!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // Use WebView's native permission request
          final result = await _controller!.requestNotificationPermission();

          if (mounted) {
            final message = result == 'granted'
                ? 'Notification permission granted!'
                : 'Please enable notifications in Settings > Apps > web_view_master_example > Permissions';
            final backgroundColor = result == 'granted'
                ? Colors.green
                : Colors.orange;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: backgroundColor,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Permission request error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadNotificationTestPage() async {
    if (_controller != null) {
      try {
        // Load the local HTML test page
        final htmlContent = await DefaultAssetBundle.of(
          context,
        ).loadString('assets/notification_test.html');
        await _controller!.loadHtmlString(htmlContent);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification test page loaded'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load test page: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _sharePage() async {
    if (_controller != null) {
      try {
        await _controller!.shareCurrentPage();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to share page: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showFindDialog() async {
    if (_controller == null) return;

    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Find in Page'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Enter text to search...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final searchText = searchController.text.trim();
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              if (searchText.isNotEmpty) {
                try {
                  final result = await _controller!.findInPage(searchText);
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(content: Text(result ?? 'Search completed')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Search failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Search'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              try {
                await _controller!.clearFindMatches();
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Search cleared')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Clear failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _takeScreenshot() async {
    if (_controller != null) {
      try {
        final screenshot = await _controller!.takeScreenshot();
        if (screenshot != null && mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Screenshot Taken'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Screenshot captured successfully!'),
                  const SizedBox(height: 16),
                  Text('Size: ${screenshot.length} characters (base64)'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Screenshot failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showCSSDialog() async {
    if (_controller == null) return;

    final cssController = TextEditingController(
      text:
          '''
body {
  background-color: #f0f8ff !important;
  color: #333 !important;
}

h1, h2, h3 {
  color: #007bff !important;
  text-shadow: 1px 1px 2px rgba(0,0,0,0.1) !important;
}

a {
  color: #28a745 !important;
  text-decoration: underline !important;
}
      '''
              .trim(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inject CSS'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: TextField(
            controller: cssController,
            decoration: const InputDecoration(
              hintText: 'Enter CSS code...',
              border: OutlineInputBorder(),
            ),
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final css = cssController.text.trim();
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              if (css.isNotEmpty) {
                try {
                  await _controller!.injectCSS(css);
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('CSS injected successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('CSS injection failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Inject'),
          ),
        ],
      ),
    );
  }

  Future<void> _getPageAnalytics() async {
    if (_controller != null) {
      try {
        final analytics = await _controller!.getPageAnalytics();
        if (analytics != null && mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Page Analytics'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: SingleChildScrollView(
                  child: Text(
                    analytics.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('\n'),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to get analytics: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _checkDarkMode() async {
    if (_controller != null) {
      try {
        final isDark = await _controller!.isDarkModeEnabled();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isDark ? 'Dark mode is enabled' : 'Dark mode is disabled',
              ),
              backgroundColor: isDark ? Colors.grey[800] : Colors.blue,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to check dark mode: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WebView Master Demo'),
            if (_pageTitle.isNotEmpty)
              Text(
                _pageTitle,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: 'Enter URL',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _loadUrl(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _loadUrl, child: const Text('Go')),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Progress bar
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress / 100,
              backgroundColor: Colors.grey[300],
            ),

          // WebView
          Expanded(
            child: WebViewWidget(
              initialUrl: _currentUrl,
              onWebViewCreated: (controller) {
                setState(() {
                  _controller = controller;
                });
                // Defer navigation state update to avoid blocking main thread
                Future.microtask(() => _updateNavigationState());
              },
              onPageStarted: _onPageStarted,
              onPageFinished: _onPageFinished,
              onProgressChanged: _onProgressChanged,
              onWebResourceError: _onWebResourceError,
              onWebNotificationReceived: _onWebNotificationReceived,
              settings: const WebViewSettings(
                enableJavaScript: true,
                enableDomStorage: true,
                enableZoom: true,
                enableBuiltInZoomControls: true,
                displayZoomControls: false,
                allowFileAccess: false, // Improve security and performance
                allowContentAccess: false, // Improve security and performance
                supportMultipleWindows: false, // Reduce memory usage
                enableSafeBrowsing: true,
              ),
              // Custom loading widget for better UX
              loadingWidget: Container(
                color: Colors.white,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Initializing WebView...',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Navigation controls
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: _canGoBack ? _goBack : null,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
                IconButton(
                  onPressed: _canGoForward ? _goForward : null,
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Forward',
                ),
                IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reload',
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'javascript':
                        _executeJavaScript();
                        break;
                      case 'clear_cache':
                        _clearCache();
                        break;
                      case 'clear_cookies':
                        _clearCookies();
                        break;
                      case 'toggle_notifications':
                        _toggleNotifications();
                        break;
                      case 'test_notification':
                        _testNotification();
                        break;
                      case 'request_permission':
                        _requestNotificationPermission();
                        break;
                      case 'load_test_page':
                        _loadNotificationTestPage();
                        break;
                      case 'share_page':
                        _sharePage();
                        break;
                      case 'find_in_page':
                        _showFindDialog();
                        break;
                      case 'take_screenshot':
                        _takeScreenshot();
                        break;
                      case 'inject_css':
                        _showCSSDialog();
                        break;
                      case 'get_analytics':
                        _getPageAnalytics();
                        break;
                      case 'check_dark_mode':
                        _checkDarkMode();
                        break;
                      case 'platform_info':
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Platform Info'),
                            content: Text('Running on: $_platformVersion'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'javascript',
                      child: Text('Execute JavaScript'),
                    ),
                    const PopupMenuItem(
                      value: 'clear_cache',
                      child: Text('Clear Cache'),
                    ),
                    const PopupMenuItem(
                      value: 'clear_cookies',
                      child: Text('Clear Cookies'),
                    ),
                    PopupMenuItem(
                      value: 'toggle_notifications',
                      child: Row(
                        children: [
                          Icon(
                            _notificationsEnabled
                                ? Icons.notifications_off
                                : Icons.notifications,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _notificationsEnabled
                                ? 'Disable Notifications'
                                : 'Enable Notifications',
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'test_notification',
                      child: Row(
                        children: [
                          Icon(Icons.notification_add),
                          SizedBox(width: 8),
                          Text('Test Notification'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'request_permission',
                      child: Row(
                        children: [
                          Icon(Icons.security),
                          SizedBox(width: 8),
                          Text('Request Permission'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'load_test_page',
                      child: Row(
                        children: [
                          Icon(Icons.web),
                          SizedBox(width: 8),
                          Text('Load Test Page'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share_page',
                      child: Row(
                        children: [
                          Icon(Icons.share),
                          SizedBox(width: 8),
                          Text('Share Page'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'find_in_page',
                      child: Row(
                        children: [
                          Icon(Icons.search),
                          SizedBox(width: 8),
                          Text('Find in Page'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'take_screenshot',
                      child: Row(
                        children: [
                          Icon(Icons.camera_alt),
                          SizedBox(width: 8),
                          Text('Take Screenshot'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'inject_css',
                      child: Row(
                        children: [
                          Icon(Icons.style),
                          SizedBox(width: 8),
                          Text('Inject CSS'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'get_analytics',
                      child: Row(
                        children: [
                          Icon(Icons.analytics),
                          SizedBox(width: 8),
                          Text('Page Analytics'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'check_dark_mode',
                      child: Row(
                        children: [
                          Icon(Icons.dark_mode),
                          SizedBox(width: 8),
                          Text('Check Dark Mode'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'platform_info',
                      child: Text('Platform Info'),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlUpdateTimer?.cancel();
    _urlController.dispose();
    _controller?.dispose();
    super.dispose();
  }
}
