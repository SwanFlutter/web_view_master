// Runs the real plugin against the real platform WebView.
//
//   flutter test integration_test/navigation_test.dart -d windows
//
// The point of these tests is the regression that made a payment gateway
// disappear from the WebView on Windows: WebView2 hands every URI scheme it
// cannot render itself to the OS shell, which opens the default browser. Dart
// answers `navigate` on purpose here — the platform side must still keep the
// URL inside the app and report it instead of launching another program.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_view_master/web_view_master.dart';

const String kTestPage = '''
<!DOCTYPE html>
<html><head><title>nav-test</title></head>
<body>
  <h1 id="marker">nav-test</h1>
  <a id="deep" href="myapp://payment/result?status=ok&amp;ref=A1">pay</a>
  <script>
    function openDeep() {
      window.open('myapp://payment/result?status=popup', '_blank');
    }
  </script>
</body></html>
''';

/// Collects everything the WebView reports back to Dart.
class Recorder {
  final List<String> navigations = <String>[];
  final List<String> newWindows = <String>[];
  final List<WebViewError> errors = <WebViewError>[];
  final List<String> finished = <String>[];
  WebViewController? controller;

  bool get sawDeepLinkNavigation =>
      navigations.any((url) => url.startsWith('myapp:'));

  bool get sawBlockedSchemeError =>
      errors.any((error) => error.errorCode == -10);

  Widget build() {
    return MaterialApp(
      home: Scaffold(
        body: WebViewWidget(
          initialUrl: 'about:blank',
          onWebViewCreated: (value) => controller = value,
          onPageFinished: finished.add,
          onWebResourceError: errors.add,
          onNavigationRequest: (request) async {
            navigations.add(request.url);
            return NavigationDecision.navigate;
          },
          onCreateWindow: (request) async {
            newWindows.add(request.url);
            return NavigationDecision.navigate;
          },
        ),
      ),
    );
  }
}

Future<void> waitFor(
  WidgetTester tester,
  bool Function() predicate, {
  required String reason,
  Duration timeout = const Duration(seconds: 25),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) fail(reason);
    await tester.pump(const Duration(milliseconds: 60));
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
}

/// Loads [kTestPage] and returns once the page has finished loading.
Future<Recorder> loadTestPage(WidgetTester tester) async {
  final recorder = Recorder();
  await tester.pumpWidget(recorder.build());
  await waitFor(
    tester,
    () => recorder.controller != null,
    reason: 'the native WebView was never created',
  );
  await recorder.controller!.loadHtmlString(kTestPage);
  await waitFor(
    tester,
    () => recorder.finished.isNotEmpty,
    reason: 'the test page never finished loading',
  );
  return recorder;
}

Future<String?> marker(Recorder recorder) => recorder.controller!
    .evaluateJavaScript('document.getElementById("marker").textContent');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a deep link stays inside the app and is reported to Dart', (
    WidgetTester tester,
  ) async {
    final recorder = await loadTestPage(tester);
    expect(await marker(recorder), contains('nav-test'));

    recorder.navigations.clear();
    await recorder.controller!.evaluateJavaScript(
      'document.getElementById("deep").click()',
    );
    await waitFor(
      tester,
      () => recorder.sawDeepLinkNavigation,
      reason: 'the deep link never reached onNavigationRequest',
    );

    // The document that tried to open the deep link is still alive.
    expect(await marker(recorder), contains('nav-test'));

    if (defaultTargetPlatform == TargetPlatform.windows) {
      await waitFor(
        tester,
        () => recorder.sawBlockedSchemeError,
        reason: 'the blocked scheme was not reported as error code -10',
      );
      final blocked =
          recorder.errors.firstWhere((error) => error.errorCode == -10);
      expect(blocked.url, startsWith('myapp:'));
    }
  });

  testWidgets('an ordinary navigation is still allowed through', (
    WidgetTester tester,
  ) async {
    final recorder = await loadTestPage(tester);
    recorder.finished.clear();

    // A data: URL exercises loadUrl and the allow path of the scheme filter
    // without depending on the network.
    await recorder.controller!.loadUrl(
      'data:text/html,<h1 id="marker">data-url</h1>',
    );
    await waitFor(
      tester,
      () => recorder.finished.isNotEmpty,
      reason: 'the data: URL never finished loading',
    );

    expect(await marker(recorder), contains('data-url'));
    expect(recorder.sawBlockedSchemeError, isFalse);
  });

  testWidgets('window.open with a deep link does not open another program', (
    WidgetTester tester,
  ) async {
    final recorder = await loadTestPage(tester);

    await recorder.controller!.evaluateJavaScript('openDeep()');
    await waitFor(
      tester,
      () =>
          recorder.newWindows.any((url) => url.startsWith('myapp:')) ||
          recorder.sawBlockedSchemeError,
      reason: 'the popup deep link was never reported to Dart',
    );

    // The host page must survive the popup attempt.
    expect(await marker(recorder), contains('nav-test'));
  });
}
