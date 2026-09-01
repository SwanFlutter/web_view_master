import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../web_view_master_platform_interface.dart';

/// Helper class for managing web notifications using native implementation
class NotificationHelper {
  static const MethodChannel _channel = MethodChannel('web_view_master');
  static bool _isInitialized = false;

  /// Initialize notification permissions
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Check if notification permission is granted using native implementation
      final hasPermission =
          await _channel.invokeMethod<bool>('hasNotificationPermission') ??
          false;

      if (!hasPermission) {
        debugPrint('Notification permission not granted');
        return false;
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
      return false;
    }
  }

  /// Show a web notification using native implementation
  static Future<void> showWebNotification(WebNotification notification) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        debugPrint('Notifications not initialized, cannot show notification');
        return;
      }
    }

    try {
      final title = notification.title ?? 'Web Notification';
      final body = notification.body ?? '';

      await _channel.invokeMethod('showNativeNotification', {
        'title': title,
        'body': body,
        'origin': notification.origin,
        'tag': notification.tag,
      });

      debugPrint('Native notification sent: $title - $body');
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('hasNotificationPermission') ??
          false;
    } catch (e) {
      debugPrint('Failed to check notification permission: $e');
      return false;
    }
  }

  /// Request notification permission
  static Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasNotificationPermission') ??
          false;
    } catch (e) {
      debugPrint('Failed to request notification permission: $e');
      return false;
    }
  }

  /// Show notification with image
  static Future<void> showImageNotification({
    required String title,
    required String message,
    required String imageUrl,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        debugPrint(
          'Notifications not initialized, cannot show image notification',
        );
        return;
      }
    }

    try {
      await _channel.invokeMethod('showImageNotification', {
        'title': title,
        'message': message,
        'imageUrl': imageUrl,
      });

      debugPrint('Native image notification sent: $title - $message');
    } catch (e) {
      debugPrint('Failed to show image notification: $e');
    }
  }

  /// Show notification with custom actions
  static Future<void> showNotificationWithActions({
    required String title,
    required String message,
    required List<Map<String, String>> actions,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        debugPrint(
          'Notifications not initialized, cannot show notification with actions',
        );
        return;
      }
    }

    try {
      await _channel.invokeMethod('showNotificationWithActions', {
        'title': title,
        'message': message,
        'actions': actions,
      });

      debugPrint('Native notification with actions sent: $title - $message');
    } catch (e) {
      debugPrint('Failed to show notification with actions: $e');
    }
  }
}
