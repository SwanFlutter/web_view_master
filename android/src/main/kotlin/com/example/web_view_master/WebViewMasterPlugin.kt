package com.example.web_view_master

import android.content.Context
import android.content.Intent
import android.webkit.*
import android.graphics.Bitmap
import android.graphics.Canvas
import android.app.Activity
import android.util.Base64
import android.view.View
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** WebViewMasterPlugin */
class WebViewMasterPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var activity: Activity? = null
  private val webViews = mutableMapOf<Int, WebView>()
  private val webViewIdGenerator = AtomicInteger(0)
  private lateinit var notificationManager: WebNotificationManager

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "web_view_master")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
    notificationManager = WebNotificationManager(context)

    // Register platform view factory
    flutterPluginBinding.platformViewRegistry.registerViewFactory(
      "web_view_master",
      WebViewFactory(this)
    )
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "createWebView" -> {
        createWebView(call, result)
      }
      "loadUrl" -> {
        loadUrl(call, result)
      }
      "loadHtmlString" -> {
        loadHtmlString(call, result)
      }
      "evaluateJavaScript" -> {
        evaluateJavaScript(call, result)
      }
      "goBack" -> {
        goBack(call, result)
      }
      "goForward" -> {
        goForward(call, result)
      }
      "reload" -> {
        reload(call, result)
      }
      "canGoBack" -> {
        canGoBack(call, result)
      }
      "canGoForward" -> {
        canGoForward(call, result)
      }
      "getCurrentUrl" -> {
        getCurrentUrl(call, result)
      }
      "getTitle" -> {
        getTitle(call, result)
      }
      "clearCache" -> {
        clearCache(call, result)
      }
      "clearCookies" -> {
        clearCookies(call, result)
      }
      "setUserAgent" -> {
        setUserAgent(call, result)
      }
      "disposeWebView" -> {
        disposeWebView(call, result)
      }
      "enableWebNotifications" -> {
        enableWebNotifications(call, result)
      }
      "disableWebNotifications" -> {
        disableWebNotifications(call, result)
      }
      "shareCurrentPage" -> {
        shareCurrentPage(call, result)
      }
      "enablePullToRefresh" -> {
        enablePullToRefresh(call, result)
      }
      "findInPage" -> {
        findInPage(call, result)
      }
      "clearFindMatches" -> {
        clearFindMatches(call, result)
      }
      "takeScreenshot" -> {
        takeScreenshot(call, result)
      }
      "injectCSS" -> {
        injectCSS(call, result)
      }
      "getSelectedText" -> {
        getSelectedText(call, result)
      }
      "getPageAnalytics" -> {
        getPageAnalytics(call, result)
      }
      "isDarkModeEnabled" -> {
        isDarkModeEnabled(call, result)
      }
      "showNativeNotification" -> {
        showNativeNotification(call, result)
      }
      "hasNotificationPermission" -> {
        hasNotificationPermission(call, result)
      }
      "showImageNotification" -> {
        showImageNotification(call, result)
      }
      "showNotificationWithActions" -> {
        showNotificationWithActions(call, result)
      }
      "shareFromJS" -> {
        shareFromJS(call, result)
      }
      "requestNotificationPermission" -> {
        requestNotificationPermission(call, result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private val mainHandler = Handler(Looper.getMainLooper())

  /**
   * Calls Flutter synchronously by blocking the background thread until Flutter responds.
   * Must NOT be called from the main thread (would deadlock).
   * Returns true = block navigation, false = allow navigation.
   */
  private fun askFlutterShouldBlock(url: String, webViewId: Int, isForMainFrame: Boolean): Boolean {
    // If called from main thread (shouldn't happen), allow by default
    if (Looper.myLooper() == Looper.getMainLooper()) return false

    val latch = CountDownLatch(1)
    var shouldBlock = false

    mainHandler.post {
      channel.invokeMethod(
        "onNavigationRequest",
        mapOf("webViewId" to webViewId, "url" to url, "isForMainFrame" to isForMainFrame),
        object : MethodChannel.Result {
          override fun success(result: Any?) {
            // Flutter returns "prevent" to block, anything else allows
            shouldBlock = (result as? String) == "prevent"
            latch.countDown()
          }
          override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            shouldBlock = false
            latch.countDown()
          }
          override fun notImplemented() {
            shouldBlock = false
            latch.countDown()
          }
        }
      )
    }

    // Wait max 500ms for Flutter to respond; allow on timeout
    latch.await(500, TimeUnit.MILLISECONDS)
    return shouldBlock
  }

  private fun createWebView(call: MethodCall, result: Result) {
    val webViewId = webViewIdGenerator.incrementAndGet()
    val initialUrl = call.argument<String>("initialUrl") ?: ""
    val headers = call.argument<Map<String, String>>("headers")
    val enableJavaScript = call.argument<Boolean>("enableJavaScript") ?: true
    val enableDomStorage = call.argument<Boolean>("enableDomStorage") ?: true
    val userAgent = call.argument<String>("userAgent")

    val webView = WebView(context).apply {
      settings.apply {
        javaScriptEnabled = enableJavaScript
        domStorageEnabled = enableDomStorage
        allowFileAccess = true
        allowContentAccess = true
        setSupportZoom(true)
        builtInZoomControls = false
        displayZoomControls = false
        loadWithOverviewMode = true
        useWideViewPort = true
        mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        setSupportMultipleWindows(true)
        javaScriptCanOpenWindowsAutomatically = false

        userAgent?.let { userAgentString = it }
      }

      webViewClient = object : WebViewClient() {
        override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
          super.onPageStarted(view, url, favicon)
          mainHandler.post {
            channel.invokeMethod("onPageStarted", mapOf(
              "webViewId" to webViewId,
              "url" to url
            ))
          }
        }

        override fun onPageFinished(view: WebView?, url: String?) {
          super.onPageFinished(view, url)
          mainHandler.post {
            channel.invokeMethod("onPageFinished", mapOf(
              "webViewId" to webViewId,
              "url" to url
            ))
          }
        }

        override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
          super.onReceivedError(view, request, error)
          mainHandler.post {
            channel.invokeMethod("onWebResourceError", mapOf(
              "webViewId" to webViewId,
              "url" to request?.url?.toString(),
              "errorCode" to error?.errorCode
            ))
          }
        }

        /**
         * This is called on a background thread by Android.
         * We block here (max 500ms) waiting for Flutter's NavigationDecision.
         * Returning true = we handle it (block), false = WebView loads it.
         */
        override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
          val url = request?.url?.toString() ?: return false
          val isForMainFrame = request.isForMainFrame

          // Only intercept main-frame navigations by default; sub-frame resources
          // (images, iframes) are allowed through without asking Flutter.
          if (!isForMainFrame) return false

          return askFlutterShouldBlock(url, webViewId, isForMainFrame)
        }
      }

      webChromeClient = object : WebChromeClient() {
        override fun onProgressChanged(view: WebView?, newProgress: Int) {
          super.onProgressChanged(view, newProgress)
          mainHandler.post {
            channel.invokeMethod("onProgressChanged", mapOf(
              "webViewId" to webViewId,
              "progress" to newProgress
            ))
          }
        }

        /**
         * Called when a page tries to open a new window (target="_blank", window.open(), etc.)
         * We intercept the URL and send it to Flutter as a navigation request.
         * If Flutter says "prevent", we discard the window. Otherwise we load it
         * in the SAME WebView (no external browser).
         */
        override fun onCreateWindow(
          view: WebView?,
          isDialog: Boolean,
          isUserGesture: Boolean,
          resultMsg: android.os.Message?
        ): Boolean {
          // Extract the URL from the new-window request via a temporary WebView
          val tempWebView = WebView(context)
          tempWebView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(v: WebView?, req: WebResourceRequest?): Boolean {
              val newUrl = req?.url?.toString() ?: return false

              // Ask Flutter whether to allow or block this popup URL
              val blocked = askFlutterShouldBlock(newUrl, webViewId, isForMainFrame = true)
              if (!blocked) {
                // Load in the parent WebView instead of a new window
                mainHandler.post { view?.loadUrl(newUrl) }
              }
              // Notify Flutter about the popup attempt regardless
              mainHandler.post {
                channel.invokeMethod("onCreateWindow", mapOf(
                  "webViewId" to webViewId,
                  "url" to newUrl,
                  "isDialog" to isDialog,
                  "isUserGesture" to isUserGesture,
                  "blocked" to blocked
                ))
              }
              tempWebView.destroy()
              return true
            }
          }

          val transport = resultMsg?.obj as? WebView.WebViewTransport
          transport?.webView = tempWebView
          resultMsg?.sendToTarget()
          return true
        }
      }
    }

    // Add JavaScript Interface
    val jsInterface = WebViewJavaScriptInterface(channel, webViewId, notificationManager, context)
    webView.addJavascriptInterface(jsInterface, "WebViewMaster")

    webViews[webViewId] = webView

    if (initialUrl.isNotEmpty()) {
      if (headers != null) {
        webView.loadUrl(initialUrl, headers)
      } else {
        webView.loadUrl(initialUrl)
      }
    }

    result.success(webViewId)
  }

  private fun loadUrl(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val url = call.argument<String>("url") ?: return result.error("INVALID_ARGS", "url is required", null)
    val headers = call.argument<Map<String, String>>("headers")

    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    if (headers != null) {
      webView.loadUrl(url, headers)
    } else {
      webView.loadUrl(url)
    }
    result.success(null)
  }

  private fun loadHtmlString(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val html = call.argument<String>("html") ?: return result.error("INVALID_ARGS", "html is required", null)
    val baseUrl = call.argument<String>("baseUrl")

    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    webView.loadDataWithBaseURL(baseUrl, html, "text/html", "UTF-8", null)
    result.success(null)
  }

  private fun evaluateJavaScript(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val script = call.argument<String>("script") ?: return result.error("INVALID_ARGS", "script is required", null)

    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    webView.evaluateJavascript(script) { value ->
      result.success(value)
    }
  }

  private fun goBack(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    if (webView.canGoBack()) {
      webView.goBack()
    }
    result.success(null)
  }

  private fun goForward(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    if (webView.canGoForward()) {
      webView.goForward()
    }
    result.success(null)
  }

  private fun reload(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    webView.reload()
    result.success(null)
  }

  private fun canGoBack(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    result.success(webView.canGoBack())
  }

  private fun canGoForward(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    result.success(webView.canGoForward())
  }

  private fun getCurrentUrl(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    result.success(webView.url)
  }

  private fun getTitle(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    result.success(webView.title)
  }

  private fun clearCache(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    webView.clearCache(true)
    result.success(null)
  }

  private fun clearCookies(call: MethodCall, result: Result) {
    CookieManager.getInstance().removeAllCookies(null)
    result.success(null)
  }

  private fun setUserAgent(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val userAgent = call.argument<String>("userAgent") ?: return result.error("INVALID_ARGS", "userAgent is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    webView.settings.userAgentString = userAgent
    result.success(null)
  }

  private fun disposeWebView(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews.remove(webViewId)

    webView?.destroy()
    result.success(null)
  }

  fun getWebView(webViewId: Int): WebView? {
    return webViews[webViewId]
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    webViews.values.forEach { it.destroy() }
    webViews.clear()
  }

  private fun enableWebNotifications(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    // Enable notifications in WebView settings
    webView.settings.javaScriptEnabled = true
    webView.settings.domStorageEnabled = true

    // Inject JavaScript to enable notifications
    val script = """
      (function() {
        if ('Notification' in window) {
          // Override the Notification constructor to intercept notification requests
          const OriginalNotification = window.Notification;
          window.Notification = function(title, options) {
            // Send notification data to native side
            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
              window.flutter_inappwebview.callHandler('onWebNotification', {
                title: title,
                body: options ? options.body : '',
                icon: options ? options.icon : '',
                tag: options ? options.tag : ''
              });
            }
            return new OriginalNotification(title, options);
          };

          // Copy static methods and properties
          Object.setPrototypeOf(window.Notification, OriginalNotification);
          Object.defineProperty(window.Notification, 'permission', {
            get: function() { return 'granted'; }
          });

          window.Notification.requestPermission = function() {
            return Promise.resolve('granted');
          };
        }
      })();
    """.trimIndent()

    webView.evaluateJavascript(script, null)
    result.success(true)
  }

  private fun disableWebNotifications(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    // Inject JavaScript to disable notifications
    val script = """
      (function() {
        if ('Notification' in window) {
          Object.defineProperty(window.Notification, 'permission', {
            get: function() { return 'denied'; }
          });

          window.Notification.requestPermission = function() {
            return Promise.resolve('denied');
          };
        }
      })();
    """.trimIndent()

    webView.evaluateJavascript(script, null)
    result.success(true)
  }

  private fun shareCurrentPage(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    val currentUrl = webView.url
    val title = webView.title

    if (currentUrl != null && activity != null) {
      val shareIntent = Intent().apply {
        action = Intent.ACTION_SEND
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, currentUrl)
        putExtra(Intent.EXTRA_SUBJECT, title ?: "Shared from WebView")
      }
      activity!!.startActivity(Intent.createChooser(shareIntent, "Share Page"))
      result.success(null)
    } else {
      result.error("SHARE_FAILED", "Unable to share page", null)
    }
  }

  private fun enablePullToRefresh(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val enabled = call.argument<Boolean>("enabled") ?: return result.error("INVALID_ARGS", "enabled is required", null)

    // This would require modifying the WebView container to include SwipeRefreshLayout
    // For now, we'll just acknowledge the call
    result.success(null)
  }

  private fun findInPage(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val searchText = call.argument<String>("searchText") ?: return result.error("INVALID_ARGS", "searchText is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    webView.findAllAsync(searchText)
    result.success("Search initiated for: $searchText")
  }

  private fun clearFindMatches(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    webView.clearMatches()
    result.success(null)
  }

  private fun takeScreenshot(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    try {
      val bitmap = Bitmap.createBitmap(webView.width, webView.height, Bitmap.Config.ARGB_8888)
      val canvas = Canvas(bitmap)
      webView.draw(canvas)

      val outputStream = ByteArrayOutputStream()
      bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
      val byteArray = outputStream.toByteArray()
      val base64String = Base64.encodeToString(byteArray, Base64.DEFAULT)

      result.success(base64String)
    } catch (e: Exception) {
      result.error("SCREENSHOT_FAILED", "Failed to take screenshot: ${e.message}", null)
    }
  }

  private fun injectCSS(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val css = call.argument<String>("css") ?: return result.error("INVALID_ARGS", "css is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    val script = """
      (function() {
        var style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = `$css`;
        document.head.appendChild(style);
      })();
    """.trimIndent()

    webView.evaluateJavascript(script, null)
    result.success(null)
  }

  private fun getSelectedText(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    val script = """
      (function() {
        return window.getSelection().toString();
      })();
    """.trimIndent()

    webView.evaluateJavascript(script) { selectedText ->
      result.success(selectedText?.replace("\"", "") ?: "")
    }
  }

  private fun getPageAnalytics(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    val script = """
      (function() {
        return {
          url: window.location.href,
          title: document.title,
          referrer: document.referrer,
          userAgent: navigator.userAgent,
          language: navigator.language,
          cookieEnabled: navigator.cookieEnabled,
          onLine: navigator.onLine,
          screenWidth: screen.width,
          screenHeight: screen.height,
          windowWidth: window.innerWidth,
          windowHeight: window.innerHeight,
          scrollX: window.scrollX,
          scrollY: window.scrollY,
          documentHeight: document.documentElement.scrollHeight,
          documentWidth: document.documentElement.scrollWidth,
          loadTime: performance.timing.loadEventEnd - performance.timing.navigationStart,
          domContentLoadedTime: performance.timing.domContentLoadedEventEnd - performance.timing.navigationStart
        };
      })();
    """.trimIndent()

    webView.evaluateJavascript(script) { analyticsJson ->
      try {
        // Parse the JSON result and convert to Map
        val analytics = mutableMapOf<String, Any>()
        analytics["rawData"] = analyticsJson ?: "{}"
        result.success(analytics)
      } catch (e: Exception) {
        result.error("ANALYTICS_FAILED", "Failed to get analytics: ${e.message}", null)
      }
    }
  }

  private fun isDarkModeEnabled(call: MethodCall, result: Result) {
    val webViewId = call.argument<Int>("webViewId") ?: return result.error("INVALID_ARGS", "webViewId is required", null)
    val webView = webViews[webViewId] ?: return result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)

    val script = """
      (function() {
        return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
      })();
    """.trimIndent()

    webView.evaluateJavascript(script) { isDark ->
      result.success(isDark == "true")
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  private fun showNativeNotification(call: MethodCall, result: Result) {
    val title = call.argument<String>("title")
    val body = call.argument<String>("body")
    val iconUrl = call.argument<String>("iconUrl")
    val tag = call.argument<String>("tag")
    val origin = call.argument<String>("origin")

    notificationManager.showNotification(
      title = title,
      body = body,
      iconUrl = iconUrl,
      tag = tag,
      origin = origin
    )

    result.success(true)
  }

  private fun hasNotificationPermission(call: MethodCall, result: Result) {
    val hasPermission = notificationManager.hasNotificationPermission()
    result.success(hasPermission)
  }

  private fun showImageNotification(call: MethodCall, result: Result) {
    val title = call.argument<String>("title") ?: return result.error("INVALID_ARGS", "title is required", null)
    val message = call.argument<String>("message") ?: return result.error("INVALID_ARGS", "message is required", null)
    val imageUrl = call.argument<String>("imageUrl") ?: return result.error("INVALID_ARGS", "imageUrl is required", null)

    notificationManager.showImageNotification(title, message, imageUrl)
    result.success(true)
  }

  private fun showNotificationWithActions(call: MethodCall, result: Result) {
    val title = call.argument<String>("title") ?: return result.error("INVALID_ARGS", "title is required", null)
    val message = call.argument<String>("message") ?: return result.error("INVALID_ARGS", "message is required", null)
    val actions = call.argument<List<Map<String, String>>>("actions") ?: return result.error("INVALID_ARGS", "actions is required", null)

    notificationManager.showNotificationWithActions(title, message, actions)
    result.success(true)
  }

  private fun shareFromJS(call: MethodCall, result: Result) {
    val url = call.argument<String>("url") ?: return result.error("INVALID_ARGS", "url is required", null)
    val title = call.argument<String>("title") ?: "Shared from WebView"

    if (activity != null) {
      val shareIntent = Intent().apply {
        action = Intent.ACTION_SEND
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, url)
        putExtra(Intent.EXTRA_SUBJECT, title)
      }
      activity!!.startActivity(Intent.createChooser(shareIntent, "Share Page"))
      result.success(null)
    } else {
      result.error("SHARE_FAILED", "Activity not available", null)
    }
  }

  private fun requestNotificationPermission(call: MethodCall, result: Result) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      if (activity != null) {
        val permission = android.Manifest.permission.POST_NOTIFICATIONS
        if (ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED) {
          ActivityCompat.requestPermissions(activity!!, arrayOf(permission), 1001)
          result.success("requested")
        } else {
          result.success("granted")
        }
      } else {
        result.error("NO_ACTIVITY", "Activity not available", null)
      }
    } else {
      // For older Android versions, notifications are enabled by default
      result.success("granted")
    }
  }
}

class WebViewFactory(private val plugin: WebViewMasterPlugin) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
  override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
    val params = args as? Map<String, Any>
    val webViewId = params?.get("webViewId") as? Int ?: 0
    return WebViewPlatformView(plugin.getWebView(webViewId))
  }
}

class WebViewPlatformView(private val webView: WebView?) : PlatformView {
  override fun getView() = webView

  override fun dispose() {
    // WebView disposal is handled by the plugin
  }
}
