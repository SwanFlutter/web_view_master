import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:web_view_master/web_view_master.dart';

/// One timestamped line in the event panel at the bottom of the browser.
class BrowserEvent {
  BrowserEvent(this.kind, this.detail) : at = DateTime.now();

  final DateTime at;
  final String kind;
  final String detail;
}

/// A full-screen browser page: toolbar, progress bar, [WebViewWidget] and an
/// expandable event log.
///
/// The log sits in the same [Column] as the WebView instead of on top of it.
/// On Windows the native WebView2 window paints over everything Flutter draws
/// in the same area, so an overlay panel would simply be invisible there.
class BrowserPage extends StatefulWidget {
  const BrowserPage({
    super.key,
    required this.title,
    required this.initialUrl,
    required this.settings,
    this.initialHtml,
    this.showLoadingIndicator = false,
    this.appScheme = 'myapp',
  });

  /// Shown in the app bar until the page reports a title of its own.
  final String title;

  /// The first URL to load. With [initialHtml] set it is only the base URL.
  final String initialUrl;

  /// Settings handed to the native WebView.
  final WebViewSettings settings;

  /// HTML to render instead of fetching [initialUrl].
  final String? initialHtml;

  /// Whether the plugin covers the WebView while a page is loading.
  final bool showLoadingIndicator;

  /// The deep-link scheme this "app" owns. A navigation to `<appScheme>:…` is
  /// treated as a payment gateway returning to the app: it is caught and
  /// reported here instead of being handed to another program.
  final String appScheme;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  final List<BrowserEvent> _events = <BrowserEvent>[];
  WebViewController? _controller;
  bool _logExpanded = true;
  bool _busy = true;
  int _progress = 0;
  String _url = '';
  String? _pageTitle;
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _url = widget.initialUrl;
  }

  void _update(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _log(String kind, String detail) {
    _update(() {
      _events.insert(0, BrowserEvent(kind, detail));
      if (_events.length > 300) _events.removeLast();
    });
  }

  bool _isAppLink(String url) =>
      url.toLowerCase().startsWith('${widget.appScheme.toLowerCase()}:');

  Future<void> _refreshNavState() async {
    final controller = _controller;
    if (controller == null) return;
    final back = await controller.canGoBack();
    final forward = await controller.canGoForward();
    final title = await controller.getTitle();
    _update(() {
      _canGoBack = back;
      _canGoForward = forward;
      _pageTitle = (title == null || title.isEmpty) ? null : title;
    });
  }

  Future<NavigationDecision> _onNavigationRequest(NavigationRequest request) {
    if (_isAppLink(request.url)) {
      _log('app-link', 'درگاه به اپ برگشت ← ${request.url}');
      Future.microtask(() => _showAppLinkResult(request.url));
      return Future.value(NavigationDecision.prevent);
    }
    _log('navigation', '${request.url}   mainFrame=${request.isForMainFrame}');
    return Future.value(NavigationDecision.navigate);
  }

  Future<NavigationDecision> _onCreateWindow(CreateWindowRequest request) {
    final target = request.url.isEmpty
        ? '(بدون آدرس — window.open خالی)'
        : request.url;
    _log(
      'new-window',
      '$target   dialog=${request.isDialog} gesture=${request.isUserGesture}',
    );
    if (_isAppLink(request.url)) {
      Future.microtask(() => _showAppLinkResult(request.url));
      return Future.value(NavigationDecision.prevent);
    }
    return Future.value(NavigationDecision.navigate);
  }

  /// The point of the whole example: a gateway that redirects to the app's own
  /// scheme is handled *inside* the app instead of leaking to another program.
  void _showAppLinkResult(String url) {
    if (!mounted) return;
    final params =
        Uri.tryParse(url)?.queryParameters ?? const <String, String>{};
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.verified, color: Colors.green),
                title: Text('بازگشت درگاه به اپلیکیشن'),
                subtitle: Text(
                  'لینک بازگشت داخل اپ گرفته شد و به هیچ برنامه‌ی دیگری '
                  'تحویل داده نشد.',
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: SelectableText(
                  url,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              for (final entry in params.entries)
                Text('${entry.key}: ${entry.value}'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).maybePop();
                },
                icon: const Icon(Icons.close),
                label: const Text('بستن مرورگر و بازگشت به اپ'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('ادامه در همین صفحه'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runTool(String id) async {
    final controller = _controller;
    if (controller == null) return;
    switch (id) {
      case 'title':
        _show('عنوان صفحه', await controller.getTitle() ?? '—');
        break;
      case 'url':
        _show('آدرس فعلی', await controller.getCurrentUrl() ?? '—');
        break;
      case 'selection':
        _show('متن انتخاب‌شده', await controller.getSelectedText() ?? '—');
        break;
      case 'analytics':
        final data = await controller.getPageAnalytics();
        _show(
          'آنالیز صفحه',
          data == null
              ? '—'
              : const JsonEncoder.withIndent('  ').convert(data),
        );
        break;
      case 'dark':
        _snack('صفحه تاریک است؟ ${await controller.isDarkModeEnabled()}');
        break;
      case 'css':
        await controller.injectCSS(
          'a{outline:2px solid #ff5722 !important}body{filter:saturate(1.15)}',
        );
        _snack('CSS تزریق شد: دور همه‌ی لینک‌ها کادر نارنجی');
        break;
      case 'js':
        final code = await _prompt('کد جاوااسکریپت', initial: 'document.title');
        if (code == null || code.isEmpty) return;
        _show('نتیجه‌ی JS', await controller.evaluateJavaScript(code) ?? '—');
        break;
      case 'find':
        final text = await _prompt('جستجو در صفحه');
        if (text == null || text.isEmpty) return;
        _snack(await controller.findInPage(text) ?? 'نتیجه‌ای برنگشت');
        break;
      case 'clearFind':
        await controller.clearFindMatches();
        _snack('هایلایت‌ها پاک شد');
        break;
      case 'shot':
        _showImage(await controller.takeScreenshot());
        break;
      case 'share':
        await controller.shareCurrentPage();
        _snack('آدرس صفحه برای اشتراک‌گذاری آماده شد');
        break;
      case 'cache':
        await controller.clearCache();
        _snack('کش پاک شد');
        break;
      case 'cookies':
        await controller.clearCookies();
        _snack('کوکی‌ها پاک شد');
        break;
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    _log('tool', message);
  }

  void _show(String title, String body) {
    if (!mounted) return;
    _log('tool', '$title → ${body.length > 90 ? '${body.substring(0, 90)}…' : body}');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(
              body,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Future<String?> _prompt(String title, {String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.ltr,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('اجرا'),
          ),
        ],
      ),
    );
  }

  void _showImage(String? base64Png) {
    if (!mounted) return;
    if (base64Png == null || base64Png.isEmpty) {
      _snack('اسکرین‌شات گرفته نشد');
      return;
    }
    final comma = base64Png.indexOf(',');
    final payload = base64Png.startsWith('data:') && comma != -1
        ? base64Png.substring(comma + 1)
        : base64Png;
    Uint8List bytes;
    try {
      bytes = base64Decode(payload);
    } on FormatException {
      _snack('داده‌ی تصویر نامعتبر بود');
      return;
    }
    _log('tool', 'اسکرین‌شات: ${bytes.length} بایت');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: InteractiveViewer(child: Image.memory(bytes)),
      ),
    );
  }

  Future<void> _openUrlDialog() async {
    final url = await _prompt('آدرس جدید', initial: _url);
    final target = url?.trim() ?? '';
    if (target.isEmpty) return;
    _log('load-url', target);
    await _controller?.loadUrl(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pageTitle ?? widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [_buildMenu()],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(child: _buildWebView()),
          _buildLogPanel(),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    return WebViewWidget(
      initialUrl: widget.initialUrl,
      settings: widget.settings,
      showLoadingIndicator: widget.showLoadingIndicator,
      onWebViewCreated: (controller) {
        _controller = controller;
        _log('created', 'WebView ساخته شد — id=${controller.webViewId}');
        final html = widget.initialHtml;
        if (html != null) {
          _log('load-html', '${html.length} بایت HTML روی ${widget.initialUrl}');
          controller.loadHtmlString(html, baseUrl: widget.initialUrl);
        }
      },
      onPageStarted: (url) {
        _update(() {
          _busy = true;
          _progress = 0;
          _url = url;
        });
        _log('started', url);
      },
      onPageFinished: (url) {
        _update(() {
          _busy = false;
          _progress = 100;
          _url = url;
        });
        _log('finished', url);
        _refreshNavState();
      },
      onProgressChanged: (progress) {
        _update(() => _progress = progress.progress);
      },
      onWebResourceError: (error) {
        _update(() => _busy = false);
        _log('error', 'code=${error.errorCode} — ${error.description}\n'
            '        ${error.url}');
      },
      onNavigationRequest: _onNavigationRequest,
      onCreateWindow: _onCreateWindow,
    );
  }

  Widget _buildToolbar() {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'صفحه‌ی قبل',
              onPressed: _canGoBack ? () => _controller?.goBack() : null,
              icon: const Icon(Icons.arrow_back),
            ),
            IconButton(
              tooltip: 'صفحه‌ی بعد',
              onPressed: _canGoForward ? () => _controller?.goForward() : null,
              icon: const Icon(Icons.arrow_forward),
            ),
            IconButton(
              tooltip: 'بارگذاری مجدد',
              onPressed: () => _controller?.reload(),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'رفتن به آدرس دیگر',
              onPressed: _openUrlDialog,
              icon: const Icon(Icons.edit_outlined),
            ),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  _url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        SizedBox(
          height: 3,
          child: _busy
              ? LinearProgressIndicator(
                  minHeight: 3,
                  value: _progress <= 0 ? null : _progress / 100,
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildMenu() {
    return PopupMenuButton<String>(
      tooltip: 'ابزارها',
      onSelected: _runTool,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'title', child: Text('عنوان صفحه')),
        PopupMenuItem(value: 'url', child: Text('آدرس فعلی')),
        PopupMenuItem(value: 'js', child: Text('اجرای JavaScript')),
        PopupMenuItem(value: 'css', child: Text('تزریق CSS')),
        PopupMenuItem(value: 'selection', child: Text('متن انتخاب‌شده')),
        PopupMenuItem(value: 'analytics', child: Text('آنالیز صفحه')),
        PopupMenuItem(value: 'dark', child: Text('حالت تاریک صفحه')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'find', child: Text('جستجو در صفحه')),
        PopupMenuItem(value: 'clearFind', child: Text('پاک کردن هایلایت')),
        PopupMenuItem(value: 'shot', child: Text('اسکرین‌شات')),
        PopupMenuItem(value: 'share', child: Text('اشتراک‌گذاری آدرس')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'cache', child: Text('پاک کردن کش')),
        PopupMenuItem(value: 'cookies', child: Text('پاک کردن کوکی‌ها')),
      ],
    );
  }

  Widget _buildLogPanel() {
    return Material(
      color: const Color(0xFF10141A),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _update(() => _logExpanded = !_logExpanded),
            child: Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: Row(
                children: [
                  const Icon(Icons.terminal, size: 18, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    'رویدادهای WebView (${_events.length})',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'پاک کردن گزارش',
                    onPressed: () => _update(_events.clear),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.white54),
                  ),
                  Icon(
                    _logExpanded ? Icons.expand_more : Icons.expand_less,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          if (_logExpanded)
            SizedBox(
              height: 168,
              child: _events.isEmpty
                  ? const Center(
                      child: Text(
                        'هنوز رویدادی ثبت نشده',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      itemCount: _events.length,
                      itemBuilder: (_, index) => _buildLogRow(_events[index]),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogRow(BrowserEvent event) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Text.rich(
          TextSpan(
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.white70,
            ),
            children: [
              TextSpan(
                text: '${event.at.toIso8601String().substring(11, 19)}  ',
                style: const TextStyle(color: Colors.white38),
              ),
              TextSpan(
                text: '${event.kind.padRight(11)} ',
                style: TextStyle(
                  color: _kindColor(event.kind),
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(text: event.detail),
            ],
          ),
        ),
      ),
    );
  }

  Color _kindColor(String kind) {
    switch (kind) {
      case 'error':
        return const Color(0xFFFF8A80);
      case 'app-link':
        return const Color(0xFFFFD479);
      case 'new-window':
        return const Color(0xFF9AD4FF);
      case 'finished':
        return const Color(0xFF9DF2A8);
      case 'created':
      case 'load-html':
      case 'load-url':
        return const Color(0xFFC792EA);
      default:
        return const Color(0xFFCBD5E1);
    }
  }
}
