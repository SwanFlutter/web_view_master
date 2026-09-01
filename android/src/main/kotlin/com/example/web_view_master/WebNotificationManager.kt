package com.example.web_view_master

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import java.net.URL
import kotlinx.coroutines.*

class WebNotificationManager(private val context: Context) {
    companion object {
        private const val CHANNEL_ID = "web_view_master_notifications"
        private const val CHANNEL_NAME = "Web Notifications"
        private const val CHANNEL_DESCRIPTION = "Notifications from web pages"
        private var notificationId = 1000
    }

    private val notificationManager = NotificationManagerCompat.from(context)

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = CHANNEL_DESCRIPTION
                enableLights(true)
                enableVibration(true)
            }

            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            notificationManager.areNotificationsEnabled()
        }
    }

    fun requestNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // For Android 13+, we need to request permission through activity
            false // Will be handled by activity
        } else {
            // For older versions, notifications are enabled by default
            notificationManager.areNotificationsEnabled()
        }
    }

    fun showNotification(
        title: String?,
        body: String?,
        iconUrl: String? = null,
        tag: String? = null,
        origin: String? = null
    ) {
        if (!hasNotificationPermission()) {
            return
        }

        val notificationTitle = title ?: "Web Notification"
        val notificationBody = body ?: ""
        val notificationTag = tag ?: "web_notification_${System.currentTimeMillis()}"

        // Create intent for when notification is tapped
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(getSmallIcon())
            .setContentTitle(notificationTitle)
            .setContentText(notificationBody)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        // Add origin info if available
        origin?.let {
            builder.setSubText("From: $it")
        }

        // Handle long text
        if (notificationBody.length > 50) {
            builder.setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(notificationBody)
                    .setBigContentTitle(notificationTitle)
            )
        }

        // Load icon if URL provided
        iconUrl?.let { url ->
            loadIconAsync(url) { bitmap ->
                bitmap?.let {
                    builder.setLargeIcon(it)
                }
                showNotificationInternal(builder, notificationTag)
            }
        } ?: run {
            showNotificationInternal(builder, notificationTag)
        }
    }

    private fun showNotificationInternal(
        builder: NotificationCompat.Builder,
        tag: String
    ) {
        try {
            notificationManager.notify(tag, getNextNotificationId(), builder.build())
        } catch (e: SecurityException) {
            // Handle case where permission was revoked
        }
    }

    private fun loadIconAsync(iconUrl: String, callback: (Bitmap?) -> Unit) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val url = URL(iconUrl)
                val bitmap = BitmapFactory.decodeStream(url.openConnection().getInputStream())
                withContext(Dispatchers.Main) {
                    callback(bitmap)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(null)
                }
            }
        }
    }

    private fun getSmallIcon(): Int {
        // Try to get app icon, fallback to Android default
        return try {
            val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            packageInfo.applicationInfo?.icon ?: android.R.drawable.ic_dialog_info
        } catch (e: Exception) {
            android.R.drawable.ic_dialog_info
        }
    }

    private fun getNextNotificationId(): Int {
        return ++notificationId
    }

    fun showImageNotification(
        title: String,
        message: String,
        imageUrl: String
    ) {
        if (!hasNotificationPermission()) {
            return
        }

        loadIconAsync(imageUrl) { bitmap ->
            val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(getSmallIcon())
                .setContentTitle(title)
                .setContentText(message)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)

            bitmap?.let {
                builder.setLargeIcon(it)
                    .setStyle(
                        NotificationCompat.BigPictureStyle()
                            .bigPicture(it)
                            .setBigContentTitle(title)
                            .setSummaryText(message)
                    )
            }

            showNotificationInternal(builder, "image_notification_${System.currentTimeMillis()}")
        }
    }

    fun showNotificationWithActions(
        title: String,
        message: String,
        actions: List<Map<String, String>>
    ) {
        if (!hasNotificationPermission()) {
            return
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(getSmallIcon())
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)

        // Add actions (max 3 actions supported)
        actions.take(3).forEachIndexed { index, action ->
            val actionTitle = action["title"] ?: "Action ${index + 1}"
            val actionRoute = action["route"] ?: ""

            val actionIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                putExtra("action_route", actionRoute)
                putExtra("action_title", actionTitle)
            }

            val actionPendingIntent = PendingIntent.getBroadcast(
                context,
                index,
                actionIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            builder.addAction(
                android.R.drawable.ic_menu_send,
                actionTitle,
                actionPendingIntent
            )
        }

        showNotificationInternal(builder, "action_notification_${System.currentTimeMillis()}")
    }
}
