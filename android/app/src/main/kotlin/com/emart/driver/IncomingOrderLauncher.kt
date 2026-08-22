package com.doordelights.rider

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject

/**
 * Brings up the native half-screen incoming-order UI when the Flutter app is closed.
 */
object IncomingOrderLauncher {
    const val ACTION = "com.doordelights.rider.INCOMING_ORDER"
    const val EXTRA_PAYLOAD = "incoming_order_payload"
    const val ACTION_ACCEPT = "accept_order"
    const val ACTION_DECLINE = "decline_order"
    const val NOTIFICATION_ID = 99101
    const val CHANNEL_ID = "incoming_order_fullscreen"

    private const val TAG = "IncomingOrderLauncher"
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val PENDING_KEY = "flutter.pending_incoming_order"
    private const val DEBOUNCE_MS = 2500L

    @Volatile
    private var lastLaunchOrderId: String = ""
    @Volatile
    private var lastLaunchAtMs: Long = 0L

    fun isIncomingOrder(data: Map<String, String>): Boolean {
        val type = (data["type"] ?: "").lowercase()
        val title = (data["title"] ?: "").lowercase()
        if (type.contains("cab_order") ||
            type.contains("vendor_order") ||
            type.contains("parcel_order") ||
            type.contains("rental_order") ||
            type.contains("order_request") ||
            type.contains("new_order")
        ) {
            return true
        }
        if (title.contains("new") &&
            (title.contains("ride") ||
                title.contains("order") ||
                title.contains("parcel") ||
                title.contains("request"))
        ) {
            return true
        }
        return (data["orderId"] ?: "").isNotEmpty() && title.contains("new")
    }

    fun launch(context: Context, data: Map<String, String>) {
        try {
            val orderId = data["orderId"].orEmpty()
            val now = System.currentTimeMillis()
            if (orderId.isNotEmpty() &&
                orderId == lastLaunchOrderId &&
                now - lastLaunchAtMs < DEBOUNCE_MS
            ) {
                Log.d(TAG, "Debounce duplicate launch for orderId=$orderId")
                return
            }
            lastLaunchOrderId = orderId
            lastLaunchAtMs = now

            ensureChannel(context)
            // App open: tray notification only (no half-screen).
            if (isAppInForeground(context)) {
                Log.d(TAG, "App in foreground — tray notification only")
                showTrayNotification(context, data, withFullScreenIntent = false)
                return
            }
            persistPending(context, data)
            wakeScreen(context)
            showTrayNotification(context, data, withFullScreenIntent = true)
            startIncomingOrderActivity(context, data)
            Log.d(TAG, "Launched IncomingOrderActivity + FSI notification")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch incoming order UI", e)
        }
    }

    private fun startIncomingOrderActivity(context: Context, data: Map<String, String>) {
        val intent = buildIncomingIntent(context, data)
        // Critical for closed app: NEW_TASK from FCM service / receiver.
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        )
        context.startActivity(intent)
    }

    fun buildIncomingIntent(context: Context, data: Map<String, String>): Intent {
        return Intent(context, IncomingOrderActivity::class.java).apply {
            action = ACTION
            putExtra(EXTRA_PAYLOAD, toJsonPublic(data))
            putExtra("incoming_order", true)
            data.forEach { (k, v) -> putExtra(k, v) }
        }
    }

    private fun showTrayNotification(
        context: Context,
        data: Map<String, String>,
        withFullScreenIntent: Boolean,
    ) {
        val title = data["title"].orEmpty().ifBlank { "New Order Request" }
        val body = data["body"].orEmpty().ifBlank { "Tap to open" }

        val contentIntent = Intent(context, MainActivity::class.java).apply {
            action = ACTION
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra(EXTRA_PAYLOAD, toJsonPublic(data))
            putExtra("incoming_order", true)
            putExtra("open_half_screen", false)
            data.forEach { (k, v) -> putExtra(k, v) }
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val contentPi = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID + 1,
            contentIntent,
            flags
        )

        val soundUri = Uri.parse("android.resource://${context.packageName}/raw/notification_sound")

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setOngoing(false)
            .setOnlyAlertOnce(true)
            .setSound(soundUri)
            .setContentIntent(contentPi)

        if (withFullScreenIntent) {
            val fullScreenIntent = buildIncomingIntent(context, data).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            val fullScreenPi = PendingIntent.getActivity(
                context,
                NOTIFICATION_ID,
                fullScreenIntent,
                flags
            )
            builder.setFullScreenIntent(fullScreenPi, true)
        }

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, builder.build())
    }

    fun clearPending(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(PENDING_KEY)
            .apply()
    }

    fun cancelIncomingNotification(context: Context) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(NOTIFICATION_ID)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = nm.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return

        val soundUri = Uri.parse("android.resource://${context.packageName}/raw/notification_sound")
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Incoming Order Requests",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Full-screen alerts for new ride and order requests"
            setSound(soundUri, attrs)
            enableVibration(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            setBypassDnd(true)
        }
        nm.createNotificationChannel(channel)
    }

    fun persistPending(
        context: Context,
        data: Map<String, String>,
        action: String = ""
    ) {
        try {
            val preview = JSONObject().apply {
                put("amount", data["amount"] ?: "")
                put("pickup", data["pickup"] ?: "")
                put("destination", data["destination"] ?: "")
                put("paymentMethod", data["paymentMethod"] ?: "")
                put("distance", data["distance"] ?: "")
                put("duration", data["duration"] ?: "")
                put("vehicleLabel", data["vehicleLabel"] ?: "")
                put("type", data["type"] ?: "")
            }
            val pending = JSONObject().apply {
                put("orderId", data["orderId"] ?: "")
                put("type", data["type"] ?: "")
                put("action", action.ifBlank { data["action"] ?: "" })
                put("title", data["title"] ?: "")
                put("body", data["body"] ?: "")
                put("preview", preview)
                put("savedAt", System.currentTimeMillis())
            }
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(PENDING_KEY, pending.toString())
                .apply()
        } catch (e: Exception) {
            Log.e(TAG, "persistPending failed", e)
        }
    }

    fun toJsonPublic(data: Map<String, String>): String {
        val obj = JSONObject()
        data.forEach { (k, v) -> obj.put(k, v) }
        return obj.toString()
    }

    fun canDrawOverlays(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    private fun wakeScreen(context: Context) {
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = pm.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                "doordelights:incoming_order"
            )
            wakeLock.acquire(5000L)
        } catch (e: Exception) {
            Log.w(TAG, "wakeScreen failed: ${e.message}")
        }
    }

    fun isAppInForeground(context: Context): Boolean {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val processes = am.runningAppProcesses ?: return false
        val pkg = context.packageName
        for (process in processes) {
            if (process.processName == pkg &&
                process.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE
            ) {
                return true
            }
        }
        return false
    }

    fun canUseFullScreenIntent(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= 34) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.canUseFullScreenIntent()
        } else {
            true
        }
    }
}
