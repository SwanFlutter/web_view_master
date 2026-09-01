# Changelog

All notable changes to this project will be documented in this file.

## [0.0.5] - 2024-12-19

### Added
- **🔔 Native Web Notifications**: Complete native implementation without external dependencies
- **📱 Advanced Notification Features**: Support for image notifications, action buttons, and custom styling
- **⚡ Better Performance**: Native implementation provides faster and more reliable notifications
- **🛡️ Enhanced Stability**: No more dependency conflicts or NDK version issues

### Fixed
- **🔧 Build Issues**: Resolved all Kotlin compilation errors in Android native code
- **📱 Android Compatibility**: Removed incompatible dependencies and imports
- **⚡ Cache Issues**: Fixed Kotlin cache corruption problems
- **🔔 Notification Reliability**: Native implementation eliminates external dependency issues

### Changed
- **📦 Dependencies**: Removed notification_master dependency in favor of native implementation
- **🔔 Notifications**: Fully functional native web notifications with enhanced features
- **🏗️ Build System**: Improved Android build stability and compatibility

### Technical Implementation
- Custom `WebNotificationManager` class for native Android notifications
- Support for notification permissions, images, actions, and custom styling
- Automatic notification channel management for Android 8.0+
- Background image loading with coroutines for better performance

## [0.0.4] - 2024-12-19

### Fixed
- **🔧 Build Issues**: Resolved Kotlin compilation errors in Android native code
- **📱 Android Compatibility**: Removed incompatible SwipeRefreshLayout import
- **🔔 Notification Compatibility**: Temporarily disabled notification_master dependency to resolve NDK conflicts
- **⚡ Cache Issues**: Fixed Kotlin cache corruption problems

### Changed
- **📦 Dependencies**: Temporarily removed notification_master dependency for build stability
- **🔔 Notifications**: Web notifications temporarily disabled (will be re-enabled in future version)
- **🏗️ Build System**: Improved Android NDK version handling

### Technical Notes
- All advanced features (share, find, screenshot, CSS injection, analytics, dark mode) remain fully functional
- Web notifications will be re-enabled once NDK compatibility issues are resolved
- Plugin is now stable and builds without errors on all platforms

## [0.0.3] - 2024-12-19

### Added
- **🔗 Share Current Page**: Share current page using system share dialog
- **🔍 Find in Page**: Search for text within the current page with highlighting
- **📷 Screenshot Capture**: Take screenshots of the current page (returns base64 PNG)
- **🎨 CSS Injection**: Inject custom CSS to modify page appearance
- **📋 Text Selection**: Get currently selected text from the page
- **📊 Page Analytics**: Comprehensive analytics including load times, dimensions, and more
- **🌙 Dark Mode Detection**: Check if the page has dark mode enabled
- **🔄 Pull to Refresh**: Enable/disable pull-to-refresh functionality

### Enhanced
- **Example App**: Added interactive demos for all new features
- **Documentation**: Complete examples for all advanced features
- **Error Handling**: Improved error handling for all new methods

### Technical Details
- **Android**: Native implementations using WebView APIs
- **iOS**: Native implementations using WKWebView APIs
- **Cross-platform**: Unified API across both platforms
- **NDK Configuration**: Updated to use Android NDK 27.0.12077973 for compatibility

### Build Configuration
- **Added**: NDK version configuration in gradle files
- **Added**: Comprehensive NDK setup guide (NDK_SETUP.md)
- **Added**: Automated setup scripts (setup_ndk.bat for Windows, setup_ndk.sh for macOS/Linux)
- **Added**: local.properties template file
- **Added**: Automatic detection of Android SDK and Flutter paths
- **Fixed**: NDK version conflicts with notification_master dependency
- **Enhanced**: Cross-platform NDK setup support

## [0.0.2] - 2024-12-19

### Added
- **🔔 Web Notifications Support**: Complete implementation of web notifications using `notification_master` package
  - Native Android support with `WebChromeClient.onShowNotification`
  - Native iOS support with `WKUIDelegate` notification handling
  - JavaScript injection for seamless Web Notification API integration
  - Automatic permission management for Android 13+

- **NotificationHelper Class**: Comprehensive notification management
  - `initialize()` - Initialize notification permissions
  - `showWebNotification()` - Display web notifications
  - `areNotificationsEnabled()` - Check notification status
  - `requestPermission()` - Request notification permissions
  - `showImageNotification()` - Display notifications with images
  - `showNotificationWithActions()` - Display notifications with custom actions

- **WebViewController Methods**:
  - `enableWebNotifications()` - Enable web notification support
  - `disableWebNotifications()` - Disable web notification support

- **WebViewWidget Callback**:
  - `onWebNotificationReceived` - Handle incoming web notifications

- **WebNotification Model**: Data class for notification information
  - `origin` - Notification origin
  - `title` - Notification title
  - `body` - Notification body text
  - `tag` - Notification tag for grouping

- **Comprehensive Test Suite**:
  - Interactive HTML test page (`notification_test.html`)
  - Permission management testing
  - Simple and rich notification testing
  - Multiple notification testing
  - Event handling testing

- **Enhanced Example App**:
  - Notification toggle functionality
  - Test notification feature
  - Load test page feature
  - Real-time notification status display

### Enhanced
- **Documentation**: Complete README update with notification examples
- **Platform Support**: Added notification support for both Android and iOS
- **Error Handling**: Improved error handling with `debugPrint` instead of `print`
- **Code Quality**: Fixed all lint warnings and improved code structure

### Dependencies
- Added `notification_master: ^0.0.2` for advanced notification features

### Permissions
- **Android**: Added `POST_NOTIFICATIONS` permission for Android 13+
- **iOS**: Automatic permission handling through notification_master

## [0.0.1] - 2024-12-19

### Added
- Initial release of WebView Master plugin
- Complete WebView implementation for Android and iOS
- JavaScript execution support with `evaluateJavaScript`
- Navigation controls (back, forward, reload)
- URL loading with custom headers support
- HTML string loading with base URL
- Real-time loading progress tracking
- Page load state monitoring (loading, finished, error)
- Navigation request interception
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
- Complete example app demonstrating all features
- Comprehensive documentation and API reference

### Features
- **WebViewWidget**: Main widget for displaying web content
- **WebViewController**: Controller for programmatic WebView management
- **WebViewSettings**: Comprehensive configuration options
- **Error Handling**: Detailed error reporting with error codes
- **Progress Tracking**: Real-time loading progress updates
- **Navigation Management**: Full navigation control with history
- **JavaScript Integration**: Execute and receive results from JavaScript
- **Cache & Cookie Management**: Clear cache and cookies programmatically
- **Custom Headers**: Support for custom HTTP headers

### Platform Support
- Android: API 21+ (Android 5.0+)
- iOS: iOS 12.0+

### Permissions Included
#### Android
- `INTERNET` - Internet access
- `ACCESS_NETWORK_STATE` - Network state monitoring
- `ACCESS_WIFI_STATE` - WiFi state monitoring
- `READ_EXTERNAL_STORAGE` - File access for uploads
- `WRITE_EXTERNAL_STORAGE` - File write access
- `CAMERA` - Camera access for web apps
- `RECORD_AUDIO` - Microphone access for web apps
- `ACCESS_FINE_LOCATION` - Precise location access
- `ACCESS_COARSE_LOCATION` - Approximate location access

#### iOS
- Privacy manifest compliance
- WebKit framework integration
- AVFoundation framework for media
- CoreLocation framework for location services
