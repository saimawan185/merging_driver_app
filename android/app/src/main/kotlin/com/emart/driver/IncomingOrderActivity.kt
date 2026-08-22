package com.doordelights.rider

import android.app.Activity
import android.app.KeyguardManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import org.json.JSONObject

/**
 * Native half-screen incoming order UI (app closed only).
 * - Close: reject in Firestore without opening the app
 * - Accept: open Flutter app to accept
 */
class IncomingOrderActivity : Activity() {
    private var orderId: String = ""
    private var type: String = ""
    private var title: String = ""
    private var body: String = ""
    private var amount: String = ""
    private var pickup: String = ""
    private var destination: String = ""
    private var paymentMethod: String = ""
    private var distance: String = ""
    private var duration: String = ""
    private var vehicleLabel: String = ""
    private var busy = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableShowWhenLocked()
        setContentView(R.layout.activity_incoming_order)
        applySafeArea()

        parseIntent(intent)
        bindUi()

        findViewById<Button>(R.id.btn_accept).setOnClickListener {
            if (busy) return@setOnClickListener
            openAppToAccept()
        }
        findViewById<ImageButton>(R.id.btn_close).setOnClickListener {
            if (busy) return@setOnClickListener
            rejectWithoutOpeningApp()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        parseIntent(intent)
        bindUi()
    }

    private fun applySafeArea() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val root = findViewById<View>(R.id.incoming_root)
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(
                WindowInsetsCompat.Type.systemBars() or
                    WindowInsetsCompat.Type.displayCutout()
            )
            view.setPadding(
                bars.left + dp(12),
                bars.top + dp(12),
                bars.right + dp(12),
                bars.bottom + dp(12),
            )
            insets
        }
        ViewCompat.requestApplyInsets(root)
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun enableShowWhenLocked() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguard = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
            keyguard.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun parseIntent(intent: Intent?) {
        if (intent == null) return
        val payload = intent.getStringExtra(IncomingOrderLauncher.EXTRA_PAYLOAD)
        if (!payload.isNullOrBlank()) {
            try {
                val obj = JSONObject(payload)
                orderId = obj.optString("orderId")
                type = obj.optString("type")
                title = obj.optString("title")
                body = obj.optString("body")
                amount = obj.optString("amount")
                pickup = obj.optString("pickup")
                destination = obj.optString("destination")
                paymentMethod = obj.optString("paymentMethod")
                distance = obj.optString("distance")
                duration = obj.optString("duration")
                vehicleLabel = obj.optString("vehicleLabel")
                return
            } catch (_: Exception) {
            }
        }
        orderId = intent.getStringExtra("orderId").orEmpty()
        type = intent.getStringExtra("type").orEmpty()
        title = intent.getStringExtra("title").orEmpty()
        body = intent.getStringExtra("body").orEmpty()
        amount = intent.getStringExtra("amount").orEmpty()
        pickup = intent.getStringExtra("pickup").orEmpty()
        destination = intent.getStringExtra("destination").orEmpty()
        paymentMethod = intent.getStringExtra("paymentMethod").orEmpty()
        distance = intent.getStringExtra("distance").orEmpty()
        duration = intent.getStringExtra("duration").orEmpty()
        vehicleLabel = intent.getStringExtra("vehicleLabel").orEmpty()
    }

    private fun bindUi() {
        val amountView = findViewById<TextView>(R.id.tv_amount)
        amountView.text = when {
            amount.isNotBlank() -> amount
            title.isNotBlank() -> title
            else -> "New Order"
        }

        setChip(R.id.tv_vehicle, vehicleLabel)
        setChip(R.id.tv_payment, paymentMethod)
        setChip(
            R.id.tv_distance,
            if (distance.isNotBlank()) "$distance km" else ""
        )

        findViewById<TextView>(R.id.tv_pickup).text =
            pickup.ifBlank { title.ifBlank { "New order request" } }

        val subtitle = duration.ifBlank { body }
        val bodyView = findViewById<TextView>(R.id.tv_body)
        if (subtitle.isBlank()) {
            bodyView.visibility = View.GONE
        } else {
            bodyView.visibility = View.VISIBLE
            bodyView.text = subtitle
        }

        val destRow = findViewById<LinearLayout>(R.id.destination_row)
        if (destination.isBlank()) {
            destRow.visibility = View.GONE
        } else {
            destRow.visibility = View.VISIBLE
            findViewById<TextView>(R.id.tv_destination).text = destination
        }
    }

    private fun setChip(id: Int, text: String) {
        val view = findViewById<TextView>(id)
        if (text.isBlank()) {
            view.visibility = View.GONE
        } else {
            view.visibility = View.VISIBLE
            view.text = text
        }
    }

    private fun setBusy(value: Boolean) {
        busy = value
        findViewById<Button>(R.id.btn_accept).isEnabled = !value
        findViewById<ImageButton>(R.id.btn_close).isEnabled = !value
        findViewById<ProgressBar>(R.id.progress).visibility =
            if (value) View.VISIBLE else View.GONE
    }

    /** Close / X — reject order in Firestore, do not open the app. */
    private fun rejectWithoutOpeningApp() {
        setBusy(true)
        IncomingOrderLauncher.cancelIncomingNotification(this)
        IncomingOrderLauncher.clearPending(this)

        IncomingOrderRejectHelper.rejectAsync(orderId, type) { ok ->
            runOnUiThread {
                if (!ok) {
                    Toast.makeText(
                        this,
                        "Could not decline order",
                        Toast.LENGTH_SHORT
                    ).show()
                }
                finish()
            }
        }
    }

    /** Accept — open Flutter app only (driver accepts in-app). */
    private fun openAppToAccept() {
        setBusy(true)
        val data = hashMapOf(
            "orderId" to orderId,
            "type" to type,
            "title" to title,
            "body" to body,
            "amount" to amount,
            "pickup" to pickup,
            "destination" to destination,
            "paymentMethod" to paymentMethod,
            "distance" to distance,
            "duration" to duration,
            "vehicleLabel" to vehicleLabel,
        )
        IncomingOrderLauncher.persistPending(this, data)
        IncomingOrderLauncher.cancelIncomingNotification(this)

        val intent = Intent(this, MainActivity::class.java).apply {
            this.action = IncomingOrderLauncher.ACTION
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra(
                IncomingOrderLauncher.EXTRA_PAYLOAD,
                IncomingOrderLauncher.toJsonPublic(data)
            )
            putExtra("incoming_order", true)
            data.forEach { (k, v) -> putExtra(k, v) }
        }
        startActivity(intent)
        finish()
    }
}
