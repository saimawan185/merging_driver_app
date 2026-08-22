package com.doordelights.rider

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var methodChannel: MethodChannel? = null
    private var pendingPayloadJson: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableShowWhenLocked()
        captureIncomingOrderIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureIncomingOrderIntent(intent)
        deliverPendingPayloadToFlutter()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "canUseFullScreenIntent" -> {
                        result.success(IncomingOrderLauncher.canUseFullScreenIntent(this))
                    }
                    "openFullScreenIntentSettings" -> {
                        openFullScreenIntentSettings()
                        result.success(true)
                    }
                    "openOverlaySettings" -> {
                        openOverlaySettings()
                        result.success(true)
                    }
                    "canDrawOverlays" -> {
                        result.success(
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                Settings.canDrawOverlays(this)
                            } else {
                                true
                            }
                        )
                    }
                    else -> result.notImplemented()
                }
            }
        }
        deliverPendingPayloadToFlutter()
    }

    private fun enableShowWhenLocked() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    private fun captureIncomingOrderIntent(intent: Intent?) {
        if (intent == null) return
        val isIncoming = intent.action == IncomingOrderLauncher.ACTION ||
            intent.getBooleanExtra("incoming_order", false)
        if (!isIncoming) return

        val payload = intent.getStringExtra(IncomingOrderLauncher.EXTRA_PAYLOAD)
        if (!payload.isNullOrBlank()) {
            pendingPayloadJson = payload
            return
        }

        // Rebuild JSON from extras if needed.
        val map = mutableMapOf<String, String>()
        intent.extras?.keySet()?.forEach { key ->
            val value = intent.extras?.get(key)
            if (value is String) map[key] = value
        }
        if (map.isNotEmpty()) {
            val obj = org.json.JSONObject()
            map.forEach { (k, v) -> obj.put(k, v) }
            pendingPayloadJson = obj.toString()
            IncomingOrderLauncher.persistPending(this, map)
        }
    }

    private fun deliverPendingPayloadToFlutter() {
        val payload = pendingPayloadJson ?: return
        val channel = methodChannel ?: return
        channel.invokeMethod("onIncomingOrder", payload)
        pendingPayloadJson = null
    }

    private fun openFullScreenIntentSettings() {
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            } else {
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
                startActivity(intent)
            }
        } catch (_: Exception) {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            })
        }
    }

    private fun openOverlaySettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                )
            }
        } catch (_: Exception) {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            })
        }
    }

    companion object {
        const val CHANNEL = "com.doordelights.rider/incoming_order"
    }
}
