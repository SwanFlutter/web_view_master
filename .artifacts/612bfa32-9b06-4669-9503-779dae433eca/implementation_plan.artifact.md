# Implementation Plan - Multi-Platform WebView Support

Expand the `web_view_master` plugin to support Windows, macOS, and Linux by implementing native WebView components and wiring them through the existing `MethodChannel`.

## User Review Required

> [!IMPORTANT]
> The implementation for Windows requires the **WebView2 Runtime** to be installed on the user's machine (standard on Windows 10/11). The build process will attempt to fetch the WebView2 SDK via CMake.

> [!IMPORTANT]
> Linux support requires `libwebkit2gtk-4.0-dev` to be installed on the build machine.

## Proposed Changes

### [Dart / Flutter]

#### [MODIFY] [web_view_widget.dart](file:///G:/Android/Pakege/web_view_master/lib/src/web_view_widget.dart)
- Update `_buildWebView` to use the appropriate `PlatformView` widget for each platform (Android, iOS, macOS, Windows, Linux).

---

### [Windows]

#### [MODIFY] [CMakeLists.txt](file:///G:/Android/Pakege/web_view_master/windows/CMakeLists.txt)
- Add WebView2 SDK dependency using `FetchContent`.
- Link against `WebView2Loader.dll`.

#### [MODIFY] [web_view_master_plugin.h](file:///G:/Android/Pakege/web_view_master/windows/web_view_master_plugin.h)
- Declare methods to handle WebView creation, navigation, and JavaScript execution.
- Maintain a map of WebView instances.

#### [MODIFY] [web_view_master_plugin.cpp](file:///G:/Android/Pakege/web_view_master/windows/web_view_master_plugin.cpp)
- Implement `MethodChannel` handlers.
- Integrate `WebView2` with the Flutter window.
- Handle callbacks (onPageStarted, onPageFinished, etc.).

---

### [macOS]

#### [MODIFY] [WebViewMasterPlugin.swift](file:///G:/Android/Pakege/web_view_master/macos/web_view_master/Sources/web_view_master/WebViewMasterPlugin.swift)
- Implement `FlutterPlatformView` and `FlutterPlatformViewFactory` using `WKWebView`.
- Wire up `MethodChannel` calls to `WKWebView` methods.

---

### [Linux]

#### [MODIFY] [CMakeLists.txt](file:///G:/Android/Pakege/web_view_master/linux/CMakeLists.txt)
- Add dependency on `webkit2gtk-4.0`.

#### [MODIFY] [web_view_master_plugin.cc](file:///G:/Android/Pakege/web_view_master/linux/web_view_master_plugin.cc)
- Implement WebView functionality using `WebKitGTK`.
- Handle `MethodChannel` calls and signals from WebKit.

## Verification Plan

### Automated Tests
- Run existing Dart tests to ensure no regressions.
- Add basic integration tests for platform detection.

### Manual Verification
- Run the `example` app on each platform (Windows, macOS, Linux).
- Verify:
    - Initial URL loading.
    - Navigation (back/forward).
    - JavaScript execution.
    - Callbacks (page start/finish).
