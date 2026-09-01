package com.example.web_view_master

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        val actionRoute = intent.getStringExtra("action_route") ?: ""
        val actionTitle = intent.getStringExtra("action_title") ?: ""

        Log.d("WebViewMaster", "Notification action clicked: $actionTitle -> $actionRoute")

        // Here you could send the action back to Flutter if needed
        // For now, we'll just log it
        
        // You could also launch the app with specific data
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        launchIntent?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            it.putExtra("notification_action_route", actionRoute)
            it.putExtra("notification_action_title", actionTitle)
            context.startActivity(it)
        }
    }
}
