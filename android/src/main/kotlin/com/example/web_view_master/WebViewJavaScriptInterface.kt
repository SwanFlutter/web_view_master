package com.example.web_view_master

import android.webkit.JavascriptInterface
import android.os.Handler
import android.os.Looper
import android.content.Intent
import io.flutter.plugin.common.MethodChannel

class WebViewJavaScriptInterface(
    private val channel: MethodChannel,
    private val webViewId: Int,
    private val notificationManager: WebNotificationManager,
    private val context: android.content.Context
) {
    private val mainHandler = Handler(Looper.getMainLooper())

    @JavascriptInterface
    fun showNotification(title: String, body: String, icon: String?, tag: String?) {
        notificationManager.showNotification(
            title = title,
            body = body,
            iconUrl = icon,
            tag = tag,
            origin = "WebView"
        )
    }

    @JavascriptInterface
    fun shareCurrentPage(url: String, title: String) {
        try {
            // Use direct Android share instead of Flutter channel
            mainHandler.post {
                try {
                    val shareIntent = Intent().apply {
                        action = Intent.ACTION_SEND
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, url)
                        putExtra(Intent.EXTRA_SUBJECT, title)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    val chooserIntent = Intent.createChooser(shareIntent, "Share Page")
                    chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(chooserIntent)
                    android.util.Log.d("WebViewJS", "Share intent started successfully")
                } catch (e: Exception) {
                    android.util.Log.e("WebViewJS", "Failed to start share intent: $e")
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("WebViewJS", "Failed to post shareCurrentPage: $e")
        }
    }

    @JavascriptInterface
    fun hasNotificationPermission(): Boolean {
        return notificationManager.hasNotificationPermission()
    }

    @JavascriptInterface
    fun requestNotificationPermission(): String {
        try {
            // For now, just return current permission status
            // Permission request needs to be handled by the main activity
            android.util.Log.d("WebViewJS", "Permission request called")

            // Try to request through Flutter channel as fallback
            mainHandler.post {
                try {
                    channel.invokeMethod("requestNotificationPermission", null)
                } catch (e: Exception) {
                    android.util.Log.e("WebViewJS", "Failed to invoke requestNotificationPermission: $e")
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("WebViewJS", "Failed to post requestNotificationPermission: $e")
        }

        return if (notificationManager.hasNotificationPermission()) {
            "granted"
        } else {
            "denied"
        }
    }

    @JavascriptInterface
    fun log(message: String) {
        android.util.Log.d("WebViewJS", "WebView $webViewId: $message")
    }

    @JavascriptInterface
    fun showImageNotification(title: String, message: String, imageUrl: String) {
        notificationManager.showImageNotification(title, message, imageUrl)
    }

    @JavascriptInterface
    fun showNotificationWithActions(title: String, message: String, actionsJson: String) {
        try {
            // Parse JSON actions (simple implementation)
            val actions = mutableListOf<Map<String, String>>()
            // For simplicity, we'll create a basic action
            actions.add(mapOf("title" to "View", "route" to "/view"))
            actions.add(mapOf("title" to "Dismiss", "route" to "/dismiss"))

            notificationManager.showNotificationWithActions(title, message, actions)
        } catch (e: Exception) {
            android.util.Log.e("WebViewJS", "Failed to parse actions: $e")
        }
    }
}
