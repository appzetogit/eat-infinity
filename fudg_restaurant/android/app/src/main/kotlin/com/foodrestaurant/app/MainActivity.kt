package com.appzetofood.restaurant

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val overlayChannel = "app.mintorestaurant/new_order_overlay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, overlayChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Which order the restaurant tapped on the overlay.
                    //
                    // Cleared from the Intent on read, so a resume or a rotation
                    // cannot re-raise an order that has already been answered.
                    "consumeLaunchOrder" -> {
                        val orderId = intent?.getStringExtra(NewOrderOverlay.EXTRA_ORDER_ID)
                        if (orderId.isNullOrBlank()) {
                            result.success(null)
                        } else {
                            val autoAccept =
                                intent.getBooleanExtra(NewOrderOverlay.EXTRA_AUTO_ACCEPT, false)
                            intent.removeExtra(NewOrderOverlay.EXTRA_ORDER_ID)
                            intent.removeExtra(NewOrderOverlay.EXTRA_AUTO_ACCEPT)
                            result.success(
                                mapOf("orderId" to orderId, "autoAccept" to autoAccept)
                            )
                        }
                    }

                    "hasOverlayPermission" ->
                        result.success(NewOrderOverlay.canDrawOverlay(this))

                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                            !Settings.canDrawOverlays(this)
                        ) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName"),
                                )
                            )
                        }
                        result.success(true)
                    }

                    // The in-app dialog has taken over — never show two copies
                    // of the same order.
                    "dismissOverlay" -> {
                        NewOrderOverlay.dismiss()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        AppForeground.isForeground = true
        // The app is in front now, so the in-app dialog owns any order that is
        // still on screen behind it.
        NewOrderOverlay.dismiss()
    }

    override fun onPause() {
        super.onPause()
        AppForeground.isForeground = false
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // A tap on the overlay while the app is already running arrives here,
        // not in the Intent configureFlutterEngine read. Without this the
        // launch order would be the one from the previous cold start.
        setIntent(intent)
    }
}
