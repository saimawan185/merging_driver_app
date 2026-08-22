package com.doordelights.rider

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * High-priority FCM handler that brings the app up for incoming ride/order requests.
 * Flutter's Dart background handler still runs via FlutterFirebaseMessagingReceiver
 * (com.google.android.c2dm.intent.RECEIVE).
 */
class DriverFirebaseMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data
        if (data.isEmpty()) return
        if (!IncomingOrderLauncher.isIncomingOrder(data)) return

        Log.d(TAG, "Incoming order FCM — launching UI. orderId=${data["orderId"]} type=${data["type"]}")
        IncomingOrderLauncher.launch(applicationContext, HashMap(data))
    }

    override fun onNewToken(token: String) {
        // Forward to FlutterFire the same way FlutterFirebaseMessagingService does.
        try {
            val clazz = Class.forName(
                "io.flutter.plugins.firebase.messaging.FlutterFirebaseTokenLiveData"
            )
            val instance = clazz.getMethod("getInstance").invoke(null)
            clazz.getMethod("postToken", String::class.java).invoke(instance, token)
        } catch (e: Exception) {
            Log.w(TAG, "Could not forward FCM token to FlutterFire", e)
        }
    }

    companion object {
        private const val TAG = "DriverFcmService"
    }
}
