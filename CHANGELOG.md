# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-09-01

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

## [1.0.0] - 2026-09-01

### Added
- Initial release of WebView Master plugin
- Complete WebView implementation for Android and iOS
- JavaScript execution support with `evaluateJavaScript`
- Navigation controls (back, forward, reload)
- URL loading with custom headers support
- HTML string loading with base URL
- Real-time loading progress tracking
- Page load state monitoring (loading, finished, error)
- Navigation request interception (informational)
- Comprehensive error handling with detailed error codes
- Cache management (clear cache functionality)
- Cookie management (clear cookies functionality)
- Custom user agent configuration
- DOM storage and local storage support
- Mixed content handling
- Automatic permission handling for Android
- Privacy manifest compliance for iOS
- Easy-to-use Widget API (`WebViewWidget`)
- Comprehensive callback system
- Customizable loading and error states
- Platform-optimized implementations:
  - Android: Uses WebView with comprehensive settings
  - iOS: Uses WKWebView with modern APIs
- Web notifications via native implementation (Android)
- Share current page via system share dialog
- Pull-to-refresh support
- Find in page
- Screenshot capture (base64 PNG)
- Custom CSS injection
- Selected text retrieval
- Page analytics
- Dark mode detection
- Complete example app demonstrating all features
- Comprehensive documentation and API reference

### Platform Support
- Android: API 24+ (Android 7.0+)
- iOS: iOS 15.0+
- macOS: macOS 10.11+
- Windows: Windows 10+ (stub)

### Permissions Included (Android)
- `INTERNET` — internet access
- `ACCESS_NETWORK_STATE` — network state monitoring
- `ACCESS_WIFI_STATE` — WiFi state monitoring
- `READ_EXTERNAL_STORAGE` — file access for uploads
- `WRITE_EXTERNAL_STORAGE` — file write access
- `CAMERA` — camera access for web apps
- `RECORD_AUDIO` — microphone access for web apps
- `ACCESS_FINE_LOCATION` — precise location access
- `ACCESS_COARSE_LOCATION` — approximate location access

### Permissions Included (iOS)
- Privacy manifest compliance
- WebKit framework integration
- AVFoundation framework for media
- CoreLocation framework for location services
