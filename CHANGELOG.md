# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-09-02

### Fixed — Windows
- **Payment gateways and deep links no longer escape to the default browser.**
  WebView2 hands every URI scheme it cannot render itself (`myapp://`, `tel:`,
  `mailto:`, `intent://`, bank deep links …) straight to the OS shell, which
  launches the registered app. The hand-off was invisible to Flutter, so the
  page looked like it had simply vanished. Such navigations are now cancelled in
  `NavigationStarting`, reported through `onNavigationRequest`, and surfaced as
  `onWebResourceError` with error code `-10`.
- **`window.open()` no longer destroys the host page.** `NewWindowRequested`
  used to unconditionally navigate the main WebView to the requested URI, which
  for a URI-less `window.open()` (the 3-D Secure pattern) meant navigating to
  `about:blank`, and for a POST target meant losing the request body. The event
  is now answered through a deferral so the Dart decision is honoured exactly.
- Navigation failures are reported: `NavigationCompleted` reads `IsSuccess` and
  maps `WebErrorStatus` onto the plugin's error codes, and `ProcessFailed` is
  handled. Previously every failure was silent.
- `WebViewSettings` were never applied on Windows, and event handlers were
  registered *after* the first navigation started, so the first page produced no
  events at all. Both are fixed, and creation now replies to Dart before
  navigating so no event can be missed.
- Progress events are synthesised from the WebView2 lifecycle (10/40/70/100).
- Request headers are honoured on Windows via `NavigateWithWebResourceRequest`.
- The native WebView2 window now follows the Flutter widget: bounds are
  re-pushed on every layout change and the view is hidden while a dialog, route
  or loading overlay covers it (new `WebViewController.setVisible`).
- Implemented on Windows: `clearCache`, `clearCookies`, `setUserAgent`,
  `evaluateJavaScript`, `injectCSS`, `getSelectedText`, `isDarkModeEnabled`,
  `getPageAnalytics`, `findInPage`/`clearFindMatches`, `takeScreenshot`,
  `shareCurrentPage`.

### Added
- `WebViewSettings.blockExternalSchemes` (default `true`) — set it to `false` to
  get the old behaviour of letting the operating system handle unknown schemes.
- `WebViewController.setVisible(bool)` for HWND-based platforms.

### Changed
- A blocked external scheme (error `-10`) no longer replaces the page with the
  error screen when a page is already displayed: the document that tried to open
  the deep link stays alive, which is what a payment flow needs.
- The example app is now a test lab: a button per platform, an address field
  with quick-pick gateway URLs, WebView switches, a bundled navigation-test page
  (`assets/nav_test.html`), a live event log and a simulated payment return to
  `myapp://payment/result`.
- New integration tests (`example/integration_test/navigation_test.dart`) run
  against the real platform WebView and cover the deep-link, `window.open()` and
  ordinary-navigation paths.

## [1.0.0] - 2026-09-01

### Added
- **Blocking navigation control**: `onNavigationRequest` callback now returns
  `Future<NavigationDecision>` — return `NavigationDecision.prevent` to
  actually block a navigation instead of just being notified about it.
- **New `onCreateWindow` callback**: intercepts `target="_blank"` links and
  `window.open()` calls. Return `NavigationDecision.navigate` to load the URL
  inside the same WebView (no external browser), or `NavigationDecision.prevent`
  to discard it entirely.
- **`CreateWindowRequest` class**: carries `url`, `isDialog`, and `isUserGesture`
  fields for the new `onCreateWindow` callback.
- `NavigationDecision` enum moved to `web_view_master_platform_interface.dart`
  and is now a first-class export of the package.
- `WebViewMasterPlatform` is now exported from the main package barrel, enabling
  custom platform implementations without reaching into internal files.

### Changed
- `onNavigationRequest` signature changed from `Function(NavigationRequest)?`
  to `Future<NavigationDecision> Function(NavigationRequest)?`.
  **Breaking change** — update your callbacks to return a `NavigationDecision`.
- Native Android `WebViewClient.shouldOverrideUrlLoading` now waits (up to
  500 ms) for Flutter's decision before returning, making the block effective.
- `WebChromeClient.onCreateWindow` is now implemented in the native layer;
  popup windows are routed through Flutter instead of being discarded silently.
- `setSupportMultipleWindows(true)` and `javaScriptCanOpenWindowsAutomatically
  = false` are set by default so the plugin controls all new-window events.
- All native→Flutter callbacks are now dispatched via `mainHandler.post` for
  correct thread safety.
- `WebViewWidget` provides a safe default for both `onNavigationRequest` and
  `onCreateWindow` (allow everything) when the caller does not supply them.

### Fixed
- Previously `shouldOverrideUrlLoading` always returned `false`, so navigation
  could never be blocked even when the Dart callback requested it.
- `target="_blank"` and `window.open()` links silently fell through to the
  system browser with no way to intercept them.
- Thread-safety issue: some callbacks were invoked on a background thread
  instead of the main/UI thread.
- Removed duplicate `import` statements in `web_view_master.dart` that were
  shadowed by corresponding `export` directives.
- Removed stale blank lines at the top of `web_view_models.dart`.
- `MockWebViewMasterPlatform.setCallbacks` in the test file brought up to date
  with the new interface signature.

---

