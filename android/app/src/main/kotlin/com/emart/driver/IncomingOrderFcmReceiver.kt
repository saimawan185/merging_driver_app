package com.doordelights.rider

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.firebase.messaging.RemoteMessage

/**
 * High-priority C2DM receiver so we still open the half-screen UI when the app
 * is killed (FlutterFire also listens on the same action).
 */
class IncomingOrderFcmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.extras == null) return
        try {
            val remoteMessage = RemoteMessage(intent.extras!!)
            val data = remoteMessage.data
            if (data.isEmpty()) return
            if (!IncomingOrderLauncher.isIncomingOrder(data)) return

            Log.d(TAG, "C2DM incoming order — launching UI")
            IncomingOrderLauncher.launch(context.applicationContext, HashMap(data))
        } catch (e: Exception) {
            Log.e(TAG, "IncomingOrderFcmReceiver failed", e)
        }
    }

    companion object {
        private const val TAG = "IncomingOrderFcmRx"
    }
}
