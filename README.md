[![pub package](https://img.shields.io/pub/v/image_picker_master.svg)](https://pub.dev/packages/image_picker_master)
[![Pub Points](https://img.shields.io/pub/points/image_picker_master)](https://pub.dev/packages/image_picker_master/score)
[![Popularity](https://img.shields.io/pub/popularity/image_picker_master)](https://pub.dev/packages/image_picker_master)
[![Pub Likes](https://img.shields.io/pub/likes/image_picker_master)](https://pub.dev/packages/image_picker_master)
[![GitHub issues](https://img.shields.io/github/issues/SwanFlutter/image_picker_master)](https://github.com/SwanFlutter/image_picker_master/issues)
[![GitHub forks](https://img.shields.io/github/forks/SwanFlutter/image_picker_master)](https://github.com/SwanFlutter/image_picker_master/network/members)
[![GitHub stars](https://img.shields.io/github/stars/SwanFlutter/image_picker_master?style=social)](https://github.com/SwanFlutter/image_picker_master/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter Platform](https://img.shields.io/badge/platform-android%20%7C%20ios%20%7C%20macos%20%7C%20linux%20%7C%20windows%20%7C%20web-lightgrey)](https://pub.dev/packages/image_picker_master)

# WebView Master

A comprehensive WebView plugin for Flutter that provides advanced features and seamless integration for both Android and iOS platforms.

---

<img width="1024" height="1024" alt="Copilot_20260901_075458" src="https://github.com/user-attachments/assets/4acd9d75-30a7-4830-a2f9-d1deff166893" />




## Features

✅ **Complete WebView Implementation**
- Full JavaScript support with execution capabilities
- DOM storage and local storage support
- Custom user agent configuration
- Mixed content handling

✅ **Navigation & Controls**
- Back/Forward navigation with history management
- Page reload functionality
- URL loading with custom headers
- HTML string loading with base URL support

✅ **Progress & State Management**
- Real-time loading progress tracking
- Page load state monitoring (loading, finished, error)
- Navigation request interception
- Error handling with detailed error codes

✅ **Advanced Features**
- Cache management (clear cache)
- Cookie management (clear cookies)
- File upload/download support
- Geolocation support
- Camera and microphone access for web apps

✅ **Platform Optimized**
- Android: Uses WebView with comprehensive settings
- iOS: Uses WKWebView with modern APIs
- **🎉 Automatic permission handling - zero configuration needed**
- **🎉 Privacy manifest compliance for iOS - automatically included**

✅ **Developer Friendly**
- Easy-to-use Widget API
- Comprehensive callback system
- Error handling with user-friendly messages
- Customizable loading and error states

## Installation

### 🚀 **Super Simple Installation**

1. Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  web_view_master: ^1.0.0
```

2. Run:

```bash
flutter pub get
```

3. **That's it!** 🎉
   - All permissions are automatically configured
   - No additional setup required
   - Ready to use immediately

## Permissions

### 🎉 **Automatic Permission Handling**

**No manual configuration required!** The plugin automatically handles all necessary permissions for you.

### Android
✅ **All permissions are automatically included** - no need to add anything to your AndroidManifest.xml:
- Internet access and network state monitoring
- File access for uploads and downloads
- Camera and microphone for web-based media features
- Location services for geolocation APIs
- All other WebView-related permissions

### iOS
✅ **Privacy manifest and frameworks are automatically configured** - no manual setup needed:
- WebKit framework integration
- Privacy manifest compliance
- Required frameworks (AVFoundation, CoreLocation) included

### Optional iOS Permissions
**Only add these to your `Info.plist` if your web content specifically uses these features:**

```xml
<!-- Only if your web content uses camera -->
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for web-based camera features</string>

<!-- Only if your web content uses microphone -->
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for web-based audio features</string>

<!-- Only if your web content uses location -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access for web-based location features</string>
```

> **Note:** These iOS permissions are only needed if your web content actually uses camera, microphone, or location features. For basic WebView functionality, no additional configuration is required.

## Usage

### Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:web_view_master/web_view_master.dart';

class MyWebView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('WebView Master')),
      body: WebViewWidget(
        initialUrl: 'https://flutter.dev',
        onWebViewCreated: (WebViewController controller) {
          // WebView is ready to use
        },
        onPageFinished: (String url) {
          print('Page finished loading: $url');
        },
      ),
    );
  }
}
```

### Advanced Usage with Controller

```dart
class AdvancedWebView extends StatefulWidget {
  @override
  _AdvancedWebViewState createState() => _AdvancedWebViewState();
}

class _AdvancedWebViewState extends State<AdvancedWebView> {
  WebViewController? _controller;
  bool _isLoading = false;
  int _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Advanced WebView'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _controller?.reload(),
          ),
          IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => _controller?.goBack(),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward),
            onPressed: () => _controller?.goForward(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(value: _progress / 100),
          Expanded(
            child: WebViewWidget(
              initialUrl: 'https://flutter.dev',
              settings: WebViewSettings(
                enableJavaScript: true,
                enableDomStorage: true,
                enableZoom: true,
                userAgent: 'MyApp/1.0',
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              onPageStarted: (url) {
                setState(() => _isLoading = true);
              },
              onPageFinished: (url) {
                setState(() => _isLoading = false);
              },
              onProgressChanged: (progress) {
                setState(() => _progress = progress.progress);
              },
              onWebResourceError: (error) {
                print('Error: ${error.description}');
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _executeJavaScript,
        child: Icon(Icons.code),
      ),
    );
  }

  void _executeJavaScript() async {
    if (_controller != null) {
      final result = await _controller!.evaluateJavaScript('document.title');
      print('Page title: $result');
    }
  }
}
```

### Navigation Control

Control which URLs the WebView is allowed to navigate to, and intercept new-window requests:

```dart
WebViewWidget(
  initialUrl: 'https://example.com',

  // Called for every main-frame navigation.
  // Return NavigationDecision.prevent to block,
  // NavigationDecision.navigate to allow.
  onNavigationRequest: (req) async {
    if (req.url.contains('ads.com')) return NavigationDecision.prevent;
    return NavigationDecision.navigate;
  },

  // Called when a page tries to open a new window
  // (target="_blank" links, window.open(), etc.).
  // Return NavigationDecision.navigate to load the URL
  // inside this WebView instead of an external browser.
  onCreateWindow: (req) async {
    // Allow all popups to open inside this WebView
    return NavigationDecision.navigate;
  },
)
```

### Custom Headers and POST Requests

```dart
// Load URL with custom headers
_controller?.loadUrl(
  'https://api.example.com/data',
  headers: {
    'Authorization': 'Bearer your-token',
    'Content-Type': 'application/json',
  },
);

// Load HTML content
_controller?.loadHtmlString(
  '<html><body><h1>Hello World!</h1></body></html>',
  baseUrl: 'https://example.com',
);
```

### JavaScript Execution

```dart
// Execute JavaScript and get result
final result = await _controller?.evaluateJavaScript('''
  (function() {
    return {
      title: document.title,
      url: window.location.href,
      userAgent: navigator.userAgent
    };
  })();
''');

print('JavaScript result: $result');
```

### Complete Example with Notifications

```dart
import 'package:flutter/material.dart';
import 'package:web_view_master/web_view_master.dart';

class WebViewWithNotifications extends StatefulWidget {
  @override
  _WebViewWithNotificationsState createState() => _WebViewWithNotificationsState();
}

class _WebViewWithNotificationsState extends State<WebViewWithNotifications> {
  WebViewController? _controller;
  bool _notificationsEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WebView with Notifications'),
        actions: [
          IconButton(
            icon: Icon(_notificationsEnabled ? Icons.notifications : Icons.notifications_off),
            onPressed: _toggleNotifications,
          ),
        ],
      ),
      body: WebViewWidget(
        initialUrl: 'https://example.com',
        onWebViewCreated: (controller) {
          _controller = controller;
        },
        onWebNotificationReceived: (notification) {
          // Handle web notifications
          NotificationHelper.showWebNotification(notification);

          // Show snackbar for demo
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Notification: ${notification.title}')),
          );
        },
        onPageFinished: (url) async {
          // Auto-enable notifications when page loads
          if (_controller != null && !_notificationsEnabled) {
            await _enableNotifications();
          }
        },
      ),
    );
  }

  Future<void> _toggleNotifications() async {
    if (_controller == null) return;

    if (_notificationsEnabled) {
      await _controller!.disableWebNotifications();
      setState(() => _notificationsEnabled = false);
    } else {
      await _enableNotifications();
    }
  }

  Future<void> _enableNotifications() async {
    if (_controller == null) return;

    // Initialize notification helper
    final initialized = await NotificationHelper.initialize();
    if (initialized) {
      await _controller!.enableWebNotifications();
      setState(() => _notificationsEnabled = true);
    }
  }
}
```

### Web Notifications (Native Implementation)

**✅ Fully Functional**: Web notifications are now implemented natively without external dependencies! This provides better performance, stability, and compatibility across all Android versions.

WebView Master supports web notifications using a custom native implementation that displays notifications as native system notifications.

#### Setup

The plugin automatically handles notification permissions and setup. Simply enable notifications for your WebView:

```dart
// Enable web notifications
await controller.enableWebNotifications();

// Disable web notifications
await controller.disableWebNotifications();
```

#### Handling Web Notifications

```dart
WebViewWidget(
  initialUrl: 'https://example.com',
  onWebNotificationReceived: (WebNotification notification) {
    print('Received notification: ${notification.title}');
    print('Body: ${notification.body}');
    print('Origin: ${notification.origin}');
  },
  // ... other properties
)
```

#### Manual Notification Testing

You can also send test notifications:

```dart
import 'package:web_view_master/web_view_master.dart';

// Send a test notification
await NotificationHelper.showWebNotification(
  WebNotification(
    title: 'Test Notification',
    body: 'This is a test notification!',
    origin: 'your_app',
  ),
);
```

#### Notification Features

The notification system supports:

- ✅ **Simple notifications** with title and body
- ✅ **Big text notifications** for longer content
- ✅ **Image notifications** with custom images
- ✅ **Custom actions** on notifications
- ✅ **Automatic permission management** (Android 13+)
- ✅ **Background notification polling**
- ✅ **Foreground service** for reliable delivery

#### JavaScript Integration

Websites can use the standard Web Notification API:

```javascript
// Check if notifications are supported
if ('Notification' in window) {
  // Request permission
  Notification.requestPermission().then(permission => {
    if (permission === 'granted') {
      // Send a notification
      new Notification('Hello!', {
        body: 'This is a web notification',
        icon: '/icon.png'
      });
    }
  });
}
```

## API Reference

### WebViewWidget

| Property | Type | Description |
|----------|------|-------------|
| `initialUrl` | `String` | The initial URL to load |
| `headers` | `Map<String, String>?` | Initial headers for the request |
| `settings` | `WebViewSettings?` | WebView configuration settings |
| `onWebViewCreated` | `Function(WebViewController)?` | Called when WebView is created |
| `onPageStarted` | `Function(String)?` | Called when page starts loading |
| `onPageFinished` | `Function(String)?` | Called when page finishes loading |
| `onProgressChanged` | `Function(WebViewProgress)?` | Called when loading progress changes |
| `onWebResourceError` | `Function(WebViewError)?` | Called when an error occurs |
| `onNavigationRequest` | `Future<NavigationDecision> Function(NavigationRequest)?` | Called for main-frame navigation requests. Return `NavigationDecision.prevent` to block or `NavigationDecision.navigate` to allow |
| `onCreateWindow` | `Future<NavigationDecision> Function(CreateWindowRequest)?` | Called when a page tries to open a new window (target="_blank", window.open()). Return `NavigationDecision.prevent` to block or `NavigationDecision.navigate` to load in this WebView |
| `onWebNotificationReceived` | `Function(WebNotification)?` | Called when a web notification is received |

### WebViewController Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `loadUrl(String url, {Map<String, String>? headers})` | `Future<void>` | Load a URL |
| `loadHtmlString(String html, {String? baseUrl})` | `Future<void>` | Load HTML content |
| `evaluateJavaScript(String script)` | `Future<String?>` | Execute JavaScript |
| `goBack()` | `Future<void>` | Navigate back |
| `goForward()` | `Future<void>` | Navigate forward |
| `reload()` | `Future<void>` | Reload current page |
| `canGoBack()` | `Future<bool>` | Check if can go back |
| `canGoForward()` | `Future<bool>` | Check if can go forward |
| `getCurrentUrl()` | `Future<String?>` | Get current URL |
| `getTitle()` | `Future<String?>` | Get page title |
| `clearCache()` | `Future<void>` | Clear cache |
| `clearCookies()` | `Future<void>` | Clear cookies |
| `setUserAgent(String userAgent)` | `Future<void>` | Set user agent |
| `enableWebNotifications()` | `Future<bool>` | Enable web notifications |
| `disableWebNotifications()` | `Future<bool>` | Disable web notifications |
| `shareCurrentPage()` | `Future<void>` | Share current page using system share dialog |
| `enablePullToRefresh(bool enabled)` | `Future<void>` | Enable/disable pull-to-refresh |
| `findInPage(String searchText)` | `Future<String?>` | Find text in current page |
| `clearFindMatches()` | `Future<void>` | Clear find matches and highlights |
| `takeScreenshot()` | `Future<String?>` | Take screenshot (returns base64 PNG) |
| `injectCSS(String css)` | `Future<void>` | Inject custom CSS into page |
| `getSelectedText()` | `Future<String?>` | Get currently selected text |
| `getPageAnalytics()` | `Future<Map<String, dynamic>?>` | Get comprehensive page analytics |
| `isDarkModeEnabled()` | `Future<bool>` | Check if dark mode is enabled |

### WebViewSettings

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enableJavaScript` | `bool` | `true` | Enable JavaScript execution |
| `enableDomStorage` | `bool` | `true` | Enable DOM storage |
| `enableZoom` | `bool` | `true` | Enable zoom functionality |
| `enableBuiltInZoomControls` | `bool` | `false` | Show built-in zoom controls |
| `displayZoomControls` | `bool` | `false` | Display zoom control buttons |
| `userAgent` | `String?` | `null` | Custom user agent string |
| `allowFileAccess` | `bool` | `true` | Allow file access |
| `allowContentAccess` | `bool` | `true` | Allow content access |
| `supportMultipleWindows` | `bool` | `false` | Support multiple windows |
| `enableSafeBrowsing` | `bool` | `true` | Enable safe browsing |

## Error Handling

The plugin provides comprehensive error handling with detailed error codes:

```dart
onWebResourceError: (WebViewError error) {
  switch (error.errorCode) {
    case -2:
      print('Host lookup failed');
      break;
    case -6:
      print('Connection failed');
      break;
    case -8:
      print('Timeout');
      break;
    default:
      print('Error: ${error.description}');
  }
},
```

### NotificationHelper API

The `NotificationHelper` class provides additional methods for advanced notification management:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `initialize()` | `Future<bool>` | Initialize notification permissions |
| `showWebNotification(WebNotification)` | `Future<void>` | Show a web notification |
| `areNotificationsEnabled()` | `Future<bool>` | Check if notifications are enabled |
| `requestPermission()` | `Future<bool>` | Request notification permission |
| `showImageNotification({title, message, imageUrl})` | `Future<void>` | Show notification with image |
| `showNotificationWithActions({title, message, actions})` | `Future<void>` | Show notification with custom actions |

### WebNotification Class

| Property | Type | Description |
|----------|------|-------------|
| `origin` | `String?` | The origin of the notification |
| `title` | `String?` | The notification title |
| `body` | `String?` | The notification body text |
| `tag` | `String?` | The notification tag for grouping |

## Platform Support

| Platform | Minimum Version | Implementation | Notifications |
|----------|----------------|----------------|---------------|
| Android | API 21 (Android 5.0) | WebView | ✅ Native Implementation |
| iOS | iOS 15.0 | WKWebView | ✅ JS Bridge |
| macOS | macOS 10.11 | WKWebView | ✅ JS Bridge |
| Windows | Windows 10+ | WebView2 | ⚠️ Stub Only |

### Platform Setup

#### Android

All permissions are automatically included via the plugin's `AndroidManifest.xml`. No manual configuration is required.

Optional: If your web content uses camera, microphone, or location, add these to your app's `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

#### iOS

Minimum deployment target: **iOS 15.0** (configured in podspec).

The WebKit framework is linked automatically. No manual setup is needed.

Optional: Add these keys to your `ios/Runner/Info.plist` only if your web content requires them:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is needed for web-based camera features.</string>

<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is needed for web-based audio features.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Location access is needed for web-based location features.</string>
```

#### macOS

Minimum deployment target: **macOS 10.11** (configured in podspec).

The WebKit framework is linked automatically. Ensure your `macos/Runner/DebugProfile.entitlements` and `Release.entitlements` include network client entitlement if loading remote URLs:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

#### Windows

Requires **Windows 10 or later** with the [Microsoft Edge WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/) installed. The WebView2 SDK is fetched automatically during build via CMake FetchContent.

If WebView2 Runtime is not installed on the target machine, the plugin will fail to initialize. You can bundle the Evergreen Bootstrapper or check at runtime using the WebView2 detection API.

No additional dependencies or manual setup are required. The `WebView2Loader.dll` is copied to the output directory automatically during build.

## Android NDK Configuration

This plugin requires Android NDK version 29.0.13113456 or higher.

### Quick Setup (Recommended)

Use our automated setup scripts:

**Windows:**
```bash
setup_ndk.bat
```

**macOS/Linux:**
```bash
chmod +x setup_ndk.sh && ./setup_ndk.sh
```

### Manual Setup

If you encounter NDK version conflicts, add the following to your `android/app/build.gradle.kts`:

```kotlin
android {
    // ... other configurations
    ndkVersion = "29.0.13113456"
}
```

Or add to your `android/gradle.properties`:

```properties
android.ndkVersion=29.0.13113456
```

Or specify the NDK path in your `android/local.properties`:

```properties
ndk.dir=C:\\Users\\YourUserName\\AppData\\Local\\Android\\Sdk\\ndk\\29.0.13113456
```

For detailed setup instructions, see [NDK_SETUP.md](NDK_SETUP.md).

## Testing Notifications

The plugin includes a comprehensive test page for notifications. You can load it in your app:

```dart
// Load the notification test page
final htmlContent = await DefaultAssetBundle.of(context)
    .loadString('assets/notification_test.html');
await controller.loadHtmlString(htmlContent);
```

The test page includes:
- ✅ Permission management
- ✅ Simple notifications
- ✅ Rich notifications with icons
- ✅ Multiple notifications
- ✅ Event handling
- ✅ Real-time testing interface

### Example Test Cases

```dart
// Test 1: Simple notification
await NotificationHelper.showWebNotification(
  WebNotification(
    title: 'Simple Test',
    body: 'This is a simple notification test',
  ),
);

// Test 2: Rich notification
await NotificationHelper.showImageNotification(
  title: 'Image Notification',
  message: 'This notification has an image',
  imageUrl: 'https://example.com/image.png',
);

// Test 3: Notification with actions
await NotificationHelper.showNotificationWithActions(
  title: 'Action Notification',
  message: 'This notification has actions',
  actions: [
    {'title': 'Accept', 'route': '/accept'},
    {'title': 'Decline', 'route': '/decline'},
  ],
);
```

### Advanced Features

WebView Master includes many advanced features for enhanced user experience:

#### 🔗 Share Current Page

```dart
// Share the current page using system share dialog
await controller.shareCurrentPage();
```

#### 🔍 Find in Page

```dart
// Search for text in the current page
final result = await controller.findInPage('search term');
print('Search result: $result');

// Clear search highlights
await controller.clearFindMatches();
```

#### 📷 Take Screenshot

```dart
// Capture screenshot of current page
final base64Image = await controller.takeScreenshot();
if (base64Image != null) {
  // Convert base64 to image and display or save
  final bytes = base64Decode(base64Image);
  // Use bytes to create Image widget or save to file
}
```

#### 🎨 Inject Custom CSS

```dart
// Inject custom CSS to modify page appearance
await controller.injectCSS('''
  body {
    background-color: #f0f8ff !important;
    color: #333 !important;
  }

  h1, h2, h3 {
    color: #007bff !important;
    text-shadow: 1px 1px 2px rgba(0,0,0,0.1) !important;
  }
''');
```

#### 📋 Get Selected Text

```dart
// Get currently selected text on the page
final selectedText = await controller.getSelectedText();
if (selectedText != null && selectedText.isNotEmpty) {
  print('Selected text: $selectedText');
}
```

#### 📊 Page Analytics

```dart
// Get comprehensive analytics about the current page
final analytics = await controller.getPageAnalytics();
if (analytics != null) {
  print('Page URL: ${analytics['url']}');
  print('Page Title: ${analytics['title']}');
  print('Load Time: ${analytics['loadTime']}ms');
  print('Screen Size: ${analytics['screenWidth']}x${analytics['screenHeight']}');
  // And much more...
}
```

#### 🌙 Dark Mode Detection

```dart
// Check if the page has dark mode enabled
final isDarkMode = await controller.isDarkModeEnabled();
print('Dark mode: ${isDarkMode ? 'enabled' : 'disabled'}');
```

#### 🔄 Pull to Refresh

```dart
// Enable pull-to-refresh functionality
await controller.enablePullToRefresh(true);

// Disable pull-to-refresh
await controller.enablePullToRefresh(false);
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions, please file an issue on the [GitHub repository](https://github.com/SwanFlutter/web_view_master/issues).

