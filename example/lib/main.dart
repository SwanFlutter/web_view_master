import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_view_master/web_view_master.dart';

import 'browser_page.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'web_view_master',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B5ED7),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const LauncherPage(),
    );
  }
}

/// One button in the platform row on the launcher page.
class PlatformTarget {
  const PlatformTarget(this.platform, this.label, this.icon, this.engine);

  /// The platform this button stands for; `null` means Flutter web.
  final TargetPlatform? platform;
  final String label;
  final IconData icon;

  /// The browser engine the plugin drives on that platform.
  final String engine;
}

const List<PlatformTarget> kTargets = [
  PlatformTarget(
      TargetPlatform.android, 'Android', Icons.android, 'android.webkit.WebView'),
  PlatformTarget(TargetPlatform.iOS, 'iOS', Icons.phone_iphone, 'WKWebView'),
  PlatformTarget(TargetPlatform.windows, 'Windows', Icons.desktop_windows,
      'WebView2 (Edge/Chromium)'),
  PlatformTarget(TargetPlatform.macOS, 'macOS', Icons.laptop_mac, 'WKWebView'),
  PlatformTarget(
      TargetPlatform.linux, 'Linux', Icons.computer, 'پیاده‌سازی نشده'),
  PlatformTarget(null, 'Web', Icons.public, 'پشتیبانی نمی‌شود'),
];

/// Sentinel understood by [_LauncherPageState._open]: instead of fetching a
/// URL, read the bundled asset and render it with `loadHtmlString`.
const String kLocalTestPage = 'asset:assets/nav_test.html';

class QuickLink {
  const QuickLink(this.label, this.url);

  final String label;
  final String url;
}

const List<QuickLink> kQuickLinks = [
  QuickLink('صفحه‌ی تست ناوبری (داخلی)', kLocalTestPage),
  QuickLink('example.com', 'https://example.com'),
  QuickLink('flutter.dev', 'https://flutter.dev'),
  QuickLink('درگاه سپ / شاپرک', 'https://sep.shaparak.ir/OnlinePG/OnlinePG'),
  QuickLink('درگاه زرین‌پال', 'https://www.zarinpal.com/pg/StartPay/0'),
  QuickLink('اسکیم خارجی: myapp://', 'myapp://pay?amount=150000&ref=A1'),
];

class LauncherPage extends StatefulWidget {
  const LauncherPage({super.key});

  @override
  State<LauncherPage> createState() => _LauncherPageState();
}

class _LauncherPageState extends State<LauncherPage> {
  final TextEditingController _urlController =
      TextEditingController(text: kLocalTestPage);
  final WebViewMaster _plugin = WebViewMaster();

  bool _blockExternalSchemes = true;
  bool _supportMultipleWindows = false;
  bool _enableJavaScript = true;
  bool _showLoadingIndicator = false;
  String _platformVersion = '…';

  @override
  void initState() {
    super.initState();
    _loadPlatformVersion();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadPlatformVersion() async {
    String version;
    try {
      version = await _plugin.getPlatformVersion() ?? 'نامشخص';
    } on MissingPluginException {
      version = 'پلاگین روی این پلتفرم پیاده‌سازی نشده';
    } on PlatformException catch (e) {
      version = 'خطا: ${e.message}';
    }
    if (!mounted) return;
    setState(() => _platformVersion = version);
  }

  bool _isCurrent(PlatformTarget target) => kIsWeb
      ? target.platform == null
      : target.platform == defaultTargetPlatform;

  PlatformTarget get _current =>
      kTargets.firstWhere(_isCurrent, orElse: () => kTargets.last);

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Opens whatever is in the address field on a full-screen browser page.
  Future<void> _open() async {
    final raw = _urlController.text.trim();
    if (raw.isEmpty) {
      _snack('اول یک آدرس وارد کنید');
      return;
    }

    var url = raw;
    String? html;
    if (raw.startsWith('asset:')) {
      html = await rootBundle.loadString(raw.substring('asset:'.length));
      // Only used as the base URL for relative links inside the page.
      url = 'https://webviewmaster.local/nav_test.html';
    } else if (!raw.contains(':')) {
      url = 'https://$raw';
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BrowserPage(
          title: 'آزمون WebView',
          initialUrl: url,
          initialHtml: html,
          showLoadingIndicator: _showLoadingIndicator,
          settings: WebViewSettings(
            enableJavaScript: _enableJavaScript,
            supportMultipleWindows: _supportMultipleWindows,
            blockExternalSchemes: _blockExternalSchemes,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('web_view_master — آزمایشگاه')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPlatformCard(),
          const SizedBox(height: 12),
          _buildUrlCard(),
          const SizedBox(height: 12),
          _buildSettingsCard(),
          const SizedBox(height: 12),
          _buildScenarioCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformCard() {
    return _card(
      icon: Icons.devices,
      title: 'پلتفرم',
      subtitle: 'دستگاه فعلی: ${_current.label} — ${_current.engine}\n'
          'نسخه‌ی سیستم: $_platformVersion',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final target in kTargets) _platformButton(target)],
      ),
    );
  }

  /// The button of the platform we are actually running on opens the WebView;
  /// the others only explain that the app has to be run there instead.
  Widget _platformButton(PlatformTarget target) {
    final icon = Icon(target.icon, size: 18);
    final label = Text(target.label);
    if (_isCurrent(target)) {
      return FilledButton.icon(onPressed: _open, icon: icon, label: label);
    }
    return OutlinedButton.icon(
      onPressed: () => _snack(
        'برای آزمودن ${target.label} باید اپ را روی همان پلتفرم اجرا کنید. '
        'دستگاه فعلی: ${_current.label}',
      ),
      icon: icon,
      label: label,
    );
  }

  Widget _buildUrlCard() {
    return _card(
      icon: Icons.link,
      title: 'لینکی که باید در WebView باز شود',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlController,
            textDirection: TextDirection.ltr,
            onSubmitted: (_) => _open(),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              hintText: 'https://…',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final link in kQuickLinks)
                ActionChip(
                  label: Text(link.label),
                  onPressed: () => _urlController.text = link.url,
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _open,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('نمایش در WebView'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return _card(
      icon: Icons.tune,
      title: 'تنظیمات WebView',
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _blockExternalSchemes,
            onChanged: (value) =>
                setState(() => _blockExternalSchemes = value),
            title: const Text('بلاک کردن اسکیم‌های خارجی'),
            subtitle: const Text(
              'روشن: لینک‌هایی مثل myapp:// و tel: داخل اپ گرفته می‌شوند. '
              'خاموش: در ویندوز همان لینک به مرورگر پیش‌فرض تحویل داده می‌شود '
              '(همان مشکل قبلی).',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _supportMultipleWindows,
            onChanged: (value) =>
                setState(() => _supportMultipleWindows = value),
            title: const Text('پنجره‌ی جدید مجاز باشد'),
            subtitle: const Text(
              'روشن: window.open و target=_blank پنجره‌ی جداگانه‌ی WebView '
              'می‌سازند. خاموش: در همین WebView باز می‌شوند.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enableJavaScript,
            onChanged: (value) => setState(() => _enableJavaScript = value),
            title: const Text('JavaScript'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _showLoadingIndicator,
            onChanged: (value) =>
                setState(() => _showLoadingIndicator = value),
            title: const Text('نمایش لودینگ روی WebView'),
            subtitle: const Text(
              'در ویندوز تا پایان بارگذاری، WebView پنهان می‌شود.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioCard() {
    const steps = [
      'چیپ «صفحه‌ی تست ناوبری (داخلی)» را انتخاب کنید و «نمایش در WebView» '
          'را بزنید.',
      'در گروه ۵ روی «شروع پرداخت» بزنید: صفحه‌ی بانک نمونه باز می‌شود و '
          'پس از ۱٫۵ ثانیه به myapp://payment/result?status=ok برمی‌گردد.',
      'اپ همان لینک را می‌گیرد و نتیجه‌ی پرداخت را نشان می‌دهد؛ هیچ چیزی به '
          'مرورگر سیستم منتقل نمی‌شود.',
      'گروه ۴ همه‌ی اسکیم‌های خارجی را تست می‌کند و گروه ۲ الگوی '
          'window.open مربوط به 3-D Secure را.',
      'برای دیدن رفتار قبلی، کلید «بلاک کردن اسکیم‌های خارجی» را خاموش کنید.',
    ];
    return _card(
      icon: Icons.science_outlined,
      title: 'شبیه‌سازی اپلیکیشن پرداخت',
      subtitle: 'گزارش زنده‌ی رویدادها پایین صفحه‌ی مرورگر نشان داده می‌شود.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 11,
                    child: Text('${i + 1}',
                        style: const TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(steps[i])),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
