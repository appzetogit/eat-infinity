package com.appzetofood.restaurant

/**
 * Whether the restaurant is currently looking at the app.
 *
 * Set from MainActivity's resume/pause. The FCM service reads it to decide who
 * owns a new order: the in-app [IncomingOrderDialog] when the app is in front,
 * the floating overlay when it is not. Without it both would fire and the same
 * order would be shown twice.
 */
object AppForeground {
    @Volatile
    var isForeground: Boolean = false
}
