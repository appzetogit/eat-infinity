package com.appzetofood.delivery

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
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
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * The incoming-order card, drawn directly by the window manager.
 *
 * Everything here runs in the app's own process off the FCM `RemoteMessage`, so
 * there is no Flutter engine, no background isolate and no cross-isolate handoff
 * involved in getting the order onto the screen. That handoff is what failed
 * repeatedly on device ("key empty after 30 reads, 0 direct messages") and this
 * exists to remove it rather than keep debugging it.
 *
 * An overlay rather than a custom notification because Android caps notification
 * layouts at roughly 256dp and this card is about 450dp; a RemoteViews version
 * would be clipped.
 */
object NewOrderOverlay {
    private const val TAG = "NewOrderOverlay"

    /** Matches the Dart-side default; the server's own window overrides it. */
    private const val DEFAULT_WINDOW_SECONDS = 20L

    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newCachedThreadPool()

    private var view: View? = null
    private var windowManager: WindowManager? = null
    private var timer: CountDownTimer? = null
    private var player: MediaPlayer? = null

    /**
     * The order currently on screen.
     *
     * The de-duplication key for the whole feature: the same order arriving
     * again — a re-offer round, a duplicate push, both transports firing —
     * refreshes the card in place instead of stacking a second window or
     * restarting the ringtone.
     */
    private var showingOrderId: String? = null

    fun canDrawOverlay(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)

    /**
     * Returns whether the card will be on screen.
     *
     * The caller uses this to decide whether Flutter should also post its
     * notification. Two alerts for one order is what made the screen look
     * messy — the notification was landing on top of the card.
     */
    @SuppressLint("InflateParams")
    fun show(context: Context, data: Map<String, String>): Boolean {
        val orderId = data.firstNonEmpty("orderMongoId", "_id", "orderId")
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
                    Log.d(TAG, "[NEW_ORDER] $orderId already on screen — refreshing in place")
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
                startCountdown(context, data)
                // The server posts its own tray copy for ROMs where this never
                // runs. Ours is up, so that one goes — otherwise it sits on top
                // of the card.
                NewOrderNotifier.cancel(context, orderId)
                Log.d(TAG, "[NEW_ORDER_NOTIFICATION] overlay shown for $orderId")
            } catch (e: Exception) {
                // A window that fails to attach must not take the process with
                // it. The caller has already let Flutter post its notification
                // as the fallback, so the partner is still told.
                Log.e(TAG, "[NEW_ORDER] overlay failed: $e")
                showingOrderId = null
            }
        }
        return true
    }

    /** Called when the order is claimed, cancelled or otherwise withdrawn. */
    fun dismissFor(orderId: String) = main.post {
        if (showingOrderId == null || showingOrderId == orderId) dismissInternal()
    }

    fun dismiss() = main.post { dismissInternal() }

    // ------------------------------------------------------------------ bind

    private fun bind(context: Context, root: View, data: Map<String, String>, orderId: String) {
        val display = data.firstNonEmpty("orderDisplayId", "orderNumber")
            .ifEmpty { "#" + orderId.takeLast(6).uppercase() }
        val earning = data.firstNonEmpty("riderEarning", "earnings", "price")

        root.html(
            R.id.headline,
            buildString {
                append("Order ").append(display)
                if (earning.isNotEmpty()) {
                    append(" • <font color='#1E8E3E'><b>₹").append(earning)
                        .append("</b></font> earning")
                }
            },
        )

        root.text(R.id.pickup_name, data.firstNonEmpty("restaurantName", "storeName").ifEmpty { "Store" })
        root.text(R.id.pickup_address, data.firstNonEmpty("restaurantAddress", "pickupAddress"))
        root.text(R.id.pickup_distance, data.firstNonEmpty("pickupDistanceKm").km())

        root.text(R.id.drop_name, data.firstNonEmpty("customerName").ifEmpty { "Customer" })
        root.text(R.id.drop_address, data.firstNonEmpty("customerAddress", "dropAddress"))
        root.text(R.id.drop_distance, data.firstNonEmpty("tripDistanceKm", "distance").km())

        val itemCount = data.firstNonEmpty("itemsCount", "itemCount", "totalItems")
        val itemsN = itemCount.toIntOrNull() ?: 0
        root.text(
            R.id.items_count,
            if (itemCount.isEmpty()) "—" else "$itemCount ${if (itemsN == 1) "item" else "items"}",
        )

        val total = data.firstNonEmpty("total", "orderValue")
        root.text(R.id.order_value, if (total.isEmpty()) "—" else "₹$total")

        // Cash vs prepaid decides whether money is collected at the door, so it
        // carries a word and a colour rather than a colour alone.
        val cash = data.firstNonEmpty("paymentMethod").lowercase().let {
            it == "cash" || it == "cod" || it == "razorpay_qr"
        }
        root.findViewById<TextView>(R.id.payment_chip)?.apply {
            text = if (cash) "Cash" else "Prepaid"
            setTextColor(if (cash) 0xFFD97706.toInt() else 0xFF1E8E3E.toInt())
        }

        root.text(R.id.earning, if (earning.isEmpty()) "—" else "₹$earning")

        // Base pay and incentive are optional — the push does not carry them
        // yet, and an empty "Base Pay: ₹" line reads as a bug.
        val basePay = data.firstNonEmpty("basePay", "baseEarning")
        val incentive = data.firstNonEmpty("incentive", "surge")
        root.findViewById<TextView>(R.id.earning_breakdown)?.apply {
            val parts = listOfNotNull(
                basePay.takeIf { it.isNotEmpty() }?.let { "Base Pay: ₹$it" },
                incentive.takeIf { it.isNotEmpty() }?.let { "Incentive: ₹$it" },
            )
            if (parts.isEmpty()) {
                visibility = View.GONE
            } else {
                text = parts.joinToString("  •  ")
                visibility = View.VISIBLE
            }
        }

        // What the partner physically collects at the door.
        //
        // NOT the order total. A prepaid order is already paid for, and printing
        // "collect ₹486" on one would have the partner asking a customer for
        // money they have handed over — so this follows the payment method
        // rather than the mockup.
        if (cash) {
            root.text(R.id.collect_label, "👛  Total to Collect from Customer")
            root.text(R.id.collect_amount, if (total.isEmpty()) "—" else "₹$total")
            root.text(R.id.collect_note, "This is the total amount you have to collect.")
        } else {
            root.text(R.id.collect_label, "👛  Total to Collect from Customer")
            root.text(R.id.collect_amount, "₹0")
            root.text(R.id.collect_note, "Prepaid — collect nothing at delivery.")
        }

        val tripKm = data.firstNonEmpty("tripDistanceKm", "distance").km()
        val mins = data.firstNonEmpty("tripDurationMins").toFloatOrNull()?.toInt()
        val etaLabel = if (mins == null || mins <= 0) "—" else "$mins–${mins + 5} mins"

        root.html(R.id.map_chip_distance, "<b>$tripKm</b><br/><font color='#6B7280'>Total Distance</font>")
        root.html(R.id.map_chip_eta, "<b>$etaLabel</b><br/><font color='#6B7280'>Est. Delivery Time</font>")

        bindThumbnails(root, data["items"], itemCount.toIntOrNull() ?: 0)
        bindRider(root)

        root.findViewById<View>(R.id.btn_accept)?.setOnClickListener {
            Log.d(TAG, "[NEW_ORDER_NOTIFICATION] ACCEPT tapped for $orderId")
            stopAlarm()
            // The app owns the accept: it holds the auth token in encrypted
            // storage that this process cannot read, and the partner needs the
            // trip screen next anyway.
            openApp(context, orderId, autoAccept = true)
            dismissInternal()
        }
        root.findViewById<View>(R.id.btn_reject)?.setOnClickListener {
            Log.d(TAG, "[NEW_ORDER_NOTIFICATION] REJECT tapped for $orderId")
            stopAlarm()
            // Queued rather than sent from here, for the same token reason. The
            // app flushes it on next launch; the server's own dispatch timeout
            // re-offers the order regardless, so nothing is stranded.
            queueRejection(context, orderId)
            dismissInternal()
        }
        root.findViewById<View>(R.id.overlay_root)?.setOnClickListener {
            stopAlarm()
            openApp(context, orderId, autoAccept = false)
            dismissInternal()
        }
    }

    /**
     * The scooter illustration in the header.
     *
     * Resolved by name at runtime so the artwork is a drop-in: put
     * `rider_scooter.png` in `res/drawable/` and it appears, with no code
     * change. Hidden while that file is absent rather than showing a gap.
     */
    private fun bindRider(root: View) {
        val view = root.findViewById<ImageView>(R.id.rider_art) ?: return
        val id = root.context.resources.getIdentifier(
            "rider_scooter", "drawable", root.context.packageName
        )
        if (id != 0) {
            view.setImageResource(id)
            view.visibility = View.VISIBLE
        } else {
            view.visibility = View.GONE
        }
    }

    /**
     * Product thumbnails, loaded off the main thread.
     *
     * Silently degrades to the count alone: the backend does not send `items`
     * yet, and a picture is decoration on a card whose job is to be answered in
     * twenty seconds.
     */
    private fun bindThumbnails(root: View, itemsJson: String?, totalCount: Int) {
        val strip = root.findViewById<LinearLayout>(R.id.thumbnails) ?: return
        strip.removeAllViews()
        if (itemsJson.isNullOrBlank()) return

        val urls = try {
            val array = JSONArray(itemsJson)
            (0 until array.length())
                .mapNotNull { array.optJSONObject(it)?.optString("image") }
                .filter { it.isNotBlank() }
        } catch (e: Exception) {
            Log.w(TAG, "[NEW_ORDER] items payload unreadable: $e")
            return
        }

        val context = root.context
        val size = (38 * context.resources.displayMetrics.density).toInt()
        val gap = (6 * context.resources.displayMetrics.density).toInt()

        urls.take(3).forEach { url ->
            val image = ImageView(context).apply {
                layoutParams = LinearLayout.LayoutParams(size, size)
                    .also { it.marginEnd = gap }
                setBackgroundResource(R.drawable.bg_overlay_thumb)
                scaleType = ImageView.ScaleType.CENTER_CROP
                clipToOutline = true
            }
            strip.addView(image)
            io.execute {
                val bitmap = try {
                    (URL(url).openConnection() as HttpURLConnection).run {
                        connectTimeout = 4000
                        readTimeout = 4000
                        inputStream.use { BitmapFactory.decodeStream(it) }
                    }
                } catch (_: Exception) {
                    null
                }
                if (bitmap != null) main.post { image.setImageBitmap(bitmap) }
            }
        }

        val remaining = totalCount - minOf(urls.size, 3)
        if (remaining > 0) {
            strip.addView(TextView(context).apply {
                layoutParams = LinearLayout.LayoutParams(size, size)
                setBackgroundResource(R.drawable.bg_overlay_thumb)
                gravity = Gravity.CENTER
                text = "+$remaining"
                textSize = 13f
                setTextColor(0xFF181C2E.toInt())
            })
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
            // belongs to whatever app the partner was already using.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP
            y = 0
        }
    }

    private fun startCountdown(context: Context, data: Map<String, String>) {
        val seconds = data.remainingSeconds()
        val countdown = view?.findViewById<TextView>(R.id.countdown)
        timer?.cancel()
        timer = object : CountDownTimer(seconds * 1000, 1000) {
            override fun onTick(msLeft: Long) {
                val left = (msLeft / 1000).toInt()
                val colour = if (left <= seconds * 0.3) "#E04444" else "#1E8E3E"
                countdown?.setHtml(
                    "🕐  Accept within <font color='$colour'><b>$left</b></font> sec"
                )
            }

            // The window closing does NOT take the card down or stop the
            // ringtone — it rings until somebody accepts or rejects. An alert
            // that goes quiet on its own is one nobody notices. The card still
            // leaves on accept, on reject, and on the `order_taken` /
            // `order_cancelled` pushes, which is what covers the offer being
            // picked up by another rider.
            override fun onFinish() {
                countdown?.setHtml("🕐  <font color='#E04444'><b>Expired</b></font>")
                Log.d(TAG, "[NEW_ORDER] offer expired on screen — still ringing")
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
            player = MediaPlayer.create(context, R.raw.neworder)?.apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        // Alarm usage, so it is audible with media volume down —
                        // the normal state for someone riding with the phone mounted.
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

    private fun dismissInternal() {
        timer?.cancel()
        timer = null
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

    /**
     * Rejections the app has not reported to the server yet.
     *
     * Plain preferences on purpose: an order id is not a credential, and this
     * process cannot read the encrypted store the auth token lives in.
     */
    private fun queueRejection(context: Context, orderId: String) {
        val prefs = context.getSharedPreferences(REJECT_PREFS, Context.MODE_PRIVATE)
        val queued = prefs.getStringSet(REJECT_KEY, emptySet())!!.toMutableSet()
        queued.add(orderId)
        prefs.edit().putStringSet(REJECT_KEY, queued).apply()
    }

    const val EXTRA_ORDER_ID = "appzeto.newOrderId"
    const val EXTRA_AUTO_ACCEPT = "appzeto.autoAccept"
    const val REJECT_PREFS = "appzeto_overlay"
    const val REJECT_KEY = "pending_rejections"
}

private fun View.text(id: Int, value: String) {
    findViewById<TextView>(id)?.text = value
}

/** Small spans — a coloured number, a bolded name — without a SpannableBuilder. */
private fun View.html(id: Int, value: String) {
    findViewById<TextView>(id)?.setHtml(value)
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

private fun String.km(): String {
    val value = toFloatOrNull() ?: return "—"
    return if (value <= 0f) "—" else String.format("%.1f km", value)
}
