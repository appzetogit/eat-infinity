package com.appzetofood.restaurant

import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Sees every push before Flutter does, purely so a new order can be drawn
 * without waking a Flutter engine first.
 *
 * This exists because `fullScreenIntent` — what the app relied on before — is
 * only honoured by Android while the screen is off or locked. With the phone in
 * the restaurant's hand the OS deliberately downgrades it to a heads-up banner,
 * which is why the alert made a sound and never took over the screen. An
 * overlay is the only window type that draws over an unlocked, in-use device.
 *
 * `super.onMessageReceived` is always called, so the existing Dart handlers —
 * `onMessage`, `onBackgroundMessage`, the notification the background isolate
 * posts — behave exactly as before. This adds a path; it replaces nothing. When
 * the overlay cannot draw (permission not granted) the old behaviour is all
 * that happens, which is the correct fallback rather than a regression.
 *
 * Declared in AndroidManifest.xml with the MESSAGING_EVENT filter, which
 * supersedes the plugin's own service registration. Because this class extends
 * that service, superseding it costs nothing.
 */
class RestaurantMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val data: Map<String, String> = remoteMessage.data

        // Foreground is excluded deliberately: IncomingOrderDialog owns that
        // case, and floating a second copy over our own screen helps nobody.
        if (data["type"] == "new_order" && !AppForeground.isForeground) {
            if (NewOrderOverlay.show(applicationContext, data)) {
                Log.d(TAG, "[NEW_ORDER] overlay owns this one")
            } else {
                Log.d(TAG, "[NEW_ORDER] overlay unavailable — Dart's notification stands")
            }
        }

        super.onMessageReceived(remoteMessage)

        when (data["type"]) {
            // Withdrawn by the customer. Takes the card down wherever it is —
            // this is the only path that reaches a restaurant whose app is
            // closed, so it is what stops the ringtone.
            "order_cancelled", "cancel_order" -> {
                val orderId: String? = ORDER_ID_KEYS
                    .mapNotNull { key -> data[key] }
                    .firstOrNull { value -> value.isNotBlank() }
                if (orderId != null) NewOrderOverlay.dismissFor(orderId)
            }
        }
    }

    companion object {
        private const val TAG = "MintoMessaging"
        private val ORDER_ID_KEYS = listOf("orderMongoId", "orderId", "_id")
    }
}
