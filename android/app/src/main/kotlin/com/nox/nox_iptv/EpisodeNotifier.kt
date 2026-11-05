package com.nox.nox_iptv

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * "Notify me" new-episode alerts (Dart `EpisodeAlerts`): one system
 * notification per show, replaced by a newer one; tapping it opens the app,
 * where Home has the "New episodes" row. Channel `vespertv/notify`.
 */
class EpisodeNotifier(private val activity: Activity) {
    companion object {
        private const val CHANNEL_ID = "episodes"
        private const val PERMISSION_REQUEST = 4711
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "episode" -> {
                post(
                    call.argument<Int>("id") ?: 0,
                    call.argument<String>("title") ?: "VesperTV",
                    call.argument<String>("text") ?: "",
                    call.argument<String>("channel") ?: "New episodes"
                )
                result.success(null)
            }
            "requestPermission" -> {
                if (Build.VERSION.SDK_INT >= 33 &&
                    activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                    PackageManager.PERMISSION_GRANTED
                ) {
                    activity.requestPermissions(
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST
                    )
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun post(id: Int, title: String, text: String, channelName: String) {
        val nm = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            nm.getNotificationChannel(CHANNEL_ID) == null
        ) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, channelName, NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
        val open = activity.packageManager.getLaunchIntentForPackage(activity.packageName)?.let {
            PendingIntent.getActivity(
                activity, id, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(activity, CHANNEL_ID) else Notification.Builder(activity)
        val n = b.setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        try {
            nm.notify("episode", id, n)
        } catch (_: SecurityException) {
            // Notifications denied: the Home row still shows it.
        }
    }
}
