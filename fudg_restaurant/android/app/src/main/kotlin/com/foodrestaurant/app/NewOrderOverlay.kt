package com.appzetofood.restaurant

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import androidx.core.app.NotificationManagerCompat

/**
 * The incoming-order card, drawn directly by the window manager.
 *
 * Everything here runs in the app's own process off the FCM `RemoteMessage`, so
 * there is no Flutter engine, no background isolate and no cross-isolate handoff
 * involved in getting the order onto the screen.
 *
 * An overlay rather than a `fullScreenIntent` notification because Android only
 * launches a full-screen intent while the screen is off or locked — with the
 * phone unlocked and in use it is downgraded to a heads-up banner by design. An
 * overlay is the only thing that draws over an app the restaurant is using.
 */
object NewOrderOverlay {
    private const val TAG = "NewOrderOverlay"

    /** Matches IncomingOrderDialog's default; the server's own window overrides it. */
    private const val DEFAULT_WINDOW_SECONDS = 60L

    private val main = Handler(Looper.getMainLooper())

    private var view: View? = null
    private var windowManager: WindowManager? = null
    private var timer: CountDownTimer? = null
    private var player: MediaPlayer? = null

    /**
     * The order currently on screen.
     *
     * The de-duplication key for the whole feature: the same order arriving
     * again — a duplicate push, both transports firing — refreshes the card in
     * place instead of stacking a second window or restarting the ringtone.
     */
    private var showingOrderId: String? = null

    /** The repeating notification sweep, so dismiss can stop it. */
    private var cancelPass: Runnable? = null

    fun canDrawOverlay(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)

    /**
     * Returns whether the card will be on screen, so the caller knows whether
     * Dart's notification is still the only alert the restaurant has.
     */
    @SuppressLint("InflateParams")
    fun show(context: Context, data: Map<String, String>): Boolean {
        val orderId = data.firstNonEmpty("orderMongoId", "orderId", "_id")
        if (orderId.isEmpty()) {
            Log.w(TAG, "[NEW_ORDER] push carries no order id — nothing to show")
            return false
        }
        if (!canDrawOverlay(context)) {
            Log.w(TAG, "[NEW_ORDER] 'Display over other apps' not granted — skipping overlay")
            return false
        }

        main.post {
            try {
                if (showingOrderId == orderId && view != null) {
                    view?.let { bind(context, it, data, orderId) }
                    return@post
                }
                dismissInternal()
                showingOrderId = orderId

                val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val card = LayoutInflater.from(context).inflate(R.layout.overlay_new_order, null)
                bind(context, card, data, orderId)

                wm.addView(card, layoutParams())
                windowManager = wm
                view = card

                startAlarm(context)
                startCountdown(data)
                clearNotifications(context, orderId)
                Log.d(TAG, "[NEW_ORDER] overlay shown for $orderId")
            } catch (e: Exception) {
                // A window that fails to attach must not take the process with
                // it. Dart's notification is still posted either way, so the
                // restaurant is still told.
                Log.e(TAG, "[NEW_ORDER] overlay failed: $e")
                showingOrderId = null
            }
        }
        return true
    }

    /** Called when the order is cancelled or otherwise withdrawn. */
    fun dismissFor(orderId: String) = main.post {
        if (showingOrderId == null || showingOrderId == orderId) dismissInternal()
    }

    fun dismiss() = main.post { dismissInternal() }

    // ------------------------------------------------------------------ bind

    private fun bind(context: Context, root: View, data: Map<String, String>, orderId: String) {
        val display = data.firstNonEmpty("orderDisplayId", "orderNumber")
            .ifEmpty { orderId.takeLast(6).uppercase() }
        root.text(R.id.order_ref, "Order #$display")

        root.text(R.id.customer_name, data.firstNonEmpty("customerName").ifEmpty { "Customer" })
        root.text(R.id.address, data.firstNonEmpty("address", "customerAddress").ifEmpty { "—" })

        val itemCount = data.firstNonEmpty("itemCount", "itemsCount", "totalItems")
        val itemsN = itemCount.toIntOrNull() ?: 0
        root.text(
            R.id.items_count,
            if (itemCount.isEmpty()) "—" else "$itemCount ${if (itemsN == 1) "item" else "items"}",
        )
        root.text(R.id.items_list, data.firstNonEmpty("itemsList").ifEmpty { "—" })

        val total = data.firstNonEmpty("total", "orderValue")
        root.text(R.id.order_value, if (total.isEmpty()) "—" else "₹$total")

        // Cash vs prepaid decides whether money is collected at the door, so it
        // carries a word and a colour rather than a colour alone.
        val cash = data.firstNonEmpty("paymentMethod").lowercase().let {
            it == "cash" || it == "cod" || it == "razorpay_qr"
        }
        root.findViewById<TextView>(R.id.payment_chip)?.apply {
            text = if (cash) "Cash on delivery" else "Prepaid"
            setTextColor(if (cash) 0xFFD97706.toInt() else 0xFF069291.toInt())
        }

        root.findViewById<View>(R.id.btn_accept)?.setOnClickListener {
            Log.d(TAG, "[NEW_ORDER] ACCEPT tapped for $orderId")
            stopAlarm()
            // The app owns the accept: it holds the auth token in encrypted
            // storage this process cannot read, and the restaurant needs the
            // order screen next anyway.
            openApp(context, orderId, autoAccept = true)
            dismissInternal()
        }
        root.findViewById<View>(R.id.btn_reject)?.setOnClickListener {
            Log.d(TAG, "[NEW_ORDER] REJECT tapped for $orderId")
            stopAlarm()
            // Opened rather than rejected from here, for the same token reason —
            // and rejecting an order is a decision that deserves the app's own
            // confirmation step rather than one tap on a floating card.
            openApp(context, orderId, autoAccept = false)
            dismissInternal()
        }
        root.findViewById<View>(R.id.overlay_root)?.setOnClickListener {
            stopAlarm()
            openApp(context, orderId, autoAccept = false)
            dismissInternal()
        }
    }

    // -------------------------------------------------------------- lifecycle

    private fun layoutParams(): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            // NOT_FOCUSABLE keeps the keyboard and the app underneath usable;
            // the card still receives its own taps. WRAP_CONTENT above means
            // the window is exactly as tall as the card, so everything below it
            // belongs to whatever app the restaurant was already using.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP
            y = 0
        }
    }

    private fun startCountdown(data: Map<String, String>) {
        val seconds = data.remainingSeconds()
        val countdown = view?.findViewById<TextView>(R.id.countdown)
        timer?.cancel()
        timer = object : CountDownTimer(seconds * 1000, 1000) {
            override fun onTick(msLeft: Long) {
                val left = (msLeft / 1000).toInt()
                val colour = if (left <= seconds * 0.3) "#FF6464" else "#069291"
                countdown?.setHtml(
                    "Respond within <font color='$colour'><b>$left</b></font> sec"
                )
            }

            // The window closing does NOT take the card down or stop the
            // ringtone. The restaurant asked for an alert that keeps ringing
            // until somebody actually accepts or rejects — an order that rang
            // for a minute and then went quiet on its own is one nobody
            // notices. The card still leaves on accept, on reject, and on the
            // `order_cancelled` push, so there is always a way out.
            override fun onFinish() {
                countdown?.setHtml("<font color='#FF6464'><b>Expired</b></font>")
            }
        }.start()
    }

    /** Server-driven, exactly as the in-app card is. */
    private fun Map<String, String>.remainingSeconds(): Long {
        this["acceptanceDeadlineAt"]?.takeIf { it.isNotBlank() }?.let { raw ->
            runCatching {
                val deadline = java.time.Instant.parse(raw).toEpochMilli()
                val left = (deadline - System.currentTimeMillis()) / 1000
                // A push held in Doze arrives already past its deadline; opening
                // the card at zero is worse than opening it short.
                if (left > 0) return left
            }
        }
        this["acceptTimeoutSeconds"]?.toLongOrNull()?.takeIf { it > 0 }?.let { return it }
        return DEFAULT_WINDOW_SECONDS
    }

    private fun startAlarm(context: Context) {
        stopAlarm()
        try {
            player = MediaPlayer.create(context, R.raw.tujh_bin1)?.apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        // Alarm usage, so it is audible with media volume down —
                        // the normal state for a phone sitting on a counter.
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                start()
            }
        } catch (e: Exception) {
            Log.w(TAG, "ringtone failed: $e")
        }

        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            // A bounded pattern, repeated a fixed number of times rather than
            // forever — a phone that will not stop buzzing is worse than a
            // missed order.
            val pattern = longArrayOf(0, 400, 300, 400, 900, 400, 300, 400)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, -1)
            }
        } catch (e: Exception) {
            Log.w(TAG, "vibration failed: $e")
        }
    }

    private fun stopAlarm() {
        try {
            player?.let { if (it.isPlaying) it.stop(); it.release() }
        } catch (_: Exception) {
        }
        player = null
    }

    /**
     * Keeps every other copy of this order's alert off the screen while the card
     * is up.
     *
     * Two things post one: FCM's own tray copy (tagged `order_<id>` by the
     * backend) and the notification the Dart background isolate builds. The
     * second is the reason this repeats instead of firing once — that isolate has
     * to start a Flutter engine first, so it posts seconds *after* this service
     * has already drawn the card, and a single cancel here lands before there is
     * anything to cancel.
     *
     * ponytail: a 1s poll for the card's lifetime, not a handshake — the Dart
     * background isolate has no channel back into this process. It stops with the
     * card, so the cost is bounded by the acceptance window. Replace with a real
     * handshake if the isolate ever gains one.
     */
    private fun clearNotifications(context: Context, orderId: String) {
        val manager = NotificationManagerCompat.from(context)
        cancelPass = object : Runnable {
            override fun run() {
                // Stop the moment the card is gone or a different order took it
                // over, or this would outlive what it exists to protect.
                if (showingOrderId != orderId) return
                runCatching {
                    manager.cancel("order_$orderId", 0)
                    manager.cancel(orderId.notificationId())
                }.onFailure { Log.w(TAG, "[NEW_ORDER] cancel failed: $it") }
                main.postDelayed(this, 1000)
            }
        }
        main.post(cancelPass!!)
    }

    private fun dismissInternal() {
        timer?.cancel()
        timer = null
        cancelPass?.let { main.removeCallbacks(it) }
        cancelPass = null
        stopAlarm()
        val current = view
        val wm = windowManager
        view = null
        windowManager = null
        showingOrderId = null
        if (current != null && wm != null) {
            try {
                wm.removeView(current)
            } catch (_: Exception) {
                // Already detached — nothing to undo.
            }
        }
    }

    // ------------------------------------------------------------- app handoff

    private fun openApp(context: Context, orderId: String, autoAccept: Boolean) {
        val intent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(EXTRA_ORDER_ID, orderId)
                putExtra(EXTRA_AUTO_ACCEPT, autoAccept)
            } ?: return
        context.startActivity(intent)
    }

    const val EXTRA_ORDER_ID = "minto.newOrderId"
    const val EXTRA_AUTO_ACCEPT = "minto.autoAccept"
}

/**
 * The notification id Dart posts a new-order alert under.
 *
 * Must stay in lockstep with `LocalNotificationService.notificationIdFor` — it
 * is the only handle this process has on a notification built in another
 * isolate.
 */
internal fun String.notificationId(): Int = hashCode() and 0x7FFFFFFF

private fun View.text(id: Int, value: String) {
    findViewById<TextView>(id)?.text = value
}

private fun TextView.setHtml(value: String) {
    text = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
        android.text.Html.fromHtml(value, android.text.Html.FROM_HTML_MODE_LEGACY)
    } else {
        @Suppress("DEPRECATION")
        android.text.Html.fromHtml(value)
    }
}

private fun Map<String, String>.firstNonEmpty(vararg keys: String): String {
    for (key in keys) {
        val value = this[key]?.trim()
        if (!value.isNullOrEmpty()) return value
    }
    return ""
}
