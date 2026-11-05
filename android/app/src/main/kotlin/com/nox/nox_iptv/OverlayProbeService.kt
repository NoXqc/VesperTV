package com.nox.nox_iptv

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.hardware.input.InputManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

/** Synthetic capability probe only: no scores, network, saved watches or restart. */
class OverlayProbeService : Service() {
    companion object {
        private const val TEST = "com.nox.nox_iptv.OVERLAY_PROBE"
        private const val STOP = "com.nox.nox_iptv.OVERLAY_PROBE_STOP"
        private const val CHANNEL = "vespertv_overlay_probe"
        private const val NOTIFICATION_ID = 4712
        @Volatile var running = false
            private set
        @Volatile var outcome: String? = null
            private set

        @Synchronized fun start(context: Context, text: Map<String, String>): Boolean {
            if (running) return false
            running = true
            outcome = null
            return try {
                val intent = Intent(context, OverlayProbeService::class.java).setAction(TEST)
                text.forEach { (key, value) -> intent.putExtra(key, value) }
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent)
                else context.startService(intent)
                true
            } catch (_: RuntimeException) {
                running = false
                outcome = "failed"
                false
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var session: OverlayProbeSession? = null
    private var overlay: View? = null
    private var shown = false
    private var finished = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != TEST) {
            outcome = "cancelled"
            session?.stop() ?: finishProbe()
            return START_NOT_STICKY
        }
        // Duplicate requests never reset the 10s/6s deadline.
        if (session != null) return START_NOT_STICKY
        val keys = listOf("title", "message", "waiting", "channelName", "cancel")
        val text = keys.associateWith { intent.getStringExtra(it) ?: "" }
        try {
            if (text.values.any { it.isBlank() || it.length > 300 }) {
                outcome = "failed"
                finishProbe()
                return START_NOT_STICKY
            }
            val notification = notification(text)
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTIFICATION_ID, notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            session = OverlayProbeSession(
                schedule = { delay, block ->
                    val runnable = Runnable { block() }
                    handler.postDelayed(runnable, delay)
                    val cancel: () -> Unit = { handler.removeCallbacks(runnable) }
                    cancel
                },
                show = { showCard(text) },
                finish = { finishProbe() },
            ).also { it.start() }
        } catch (_: RuntimeException) {
            outcome = "failed"
            finishProbe()
        }
        return START_NOT_STICKY
    }

    private fun notification(text: Map<String, String>): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL, text.getValue("channelName"), NotificationManager.IMPORTANCE_LOW
            ).apply {
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            })
        }
        val stop = PendingIntent.getService(this, 0,
            Intent(this, OverlayProbeService::class.java).setAction(STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
            else Notification.Builder(this)
        @Suppress("DEPRECATION")
        return builder.setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(text.getValue("title"))
            .setContentText(text.getValue("waiting"))
            .setCategory(Notification.CATEGORY_STATUS)
            .setPriority(Notification.PRIORITY_LOW)
            .setSound(null).setDefaults(0).setVibrate(null)
            .setOnlyAlertOnce(true).setOngoing(true).setLocalOnly(true)
            .addAction(Notification.Action.Builder(null, text.getValue("cancel"), stop).build())
            .build()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    @Suppress("DEPRECATION")
    private fun showCard(text: Map<String, String>): Boolean {
        return try {
            val power = getSystemService(PowerManager::class.java)
            val keyguard = getSystemService(KeyguardManager::class.java)
            if (!Settings.canDrawOverlays(this) || !power.isInteractive || keyguard.isKeyguardLocked) {
                outcome = "failed"
                return false
            }
            val card = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(18), dp(14), dp(18), dp(14))
                background = GradientDrawable().apply {
                    setColor(Color.rgb(20, 22, 27))
                    cornerRadius = dp(16).toFloat()
                    setStroke(dp(1).coerceAtLeast(1), Color.rgb(222, 183, 91))
                }
                isFocusable = false
                isClickable = false
                addView(TextView(this@OverlayProbeService).apply {
                    this.text = text.getValue("title")
                    textSize = 18f
                    setTextColor(Color.rgb(244, 209, 127))
                    setTypeface(Typeface.DEFAULT, Typeface.BOLD)
                    maxLines = 3
                })
                addView(TextView(this@OverlayProbeService).apply {
                    this.text = text.getValue("message")
                    textSize = 15f
                    setTextColor(Color.WHITE)
                    setPadding(0, dp(8), 0, 0)
                    maxLines = 3
                })
            }
            val params = WindowManager.LayoutParams(
                minOf(dp(320), resources.displayMetrics.widthPixels - dp(48)).coerceAtLeast(1),
                WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    else WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.RIGHT
                x = dp(24)
                y = dp(24)
                // Touch-through on Android 12+ must obey the obscuring-opacity limit.
                alpha = if (Build.VERSION.SDK_INT >= 31) minOf(0.8f,
                    getSystemService(InputManager::class.java).maximumObscuringOpacityForTouch)
                    else 0.8f
            }
            overlay = card
            getSystemService(WindowManager::class.java).addView(card, params)
            shown = true
            true
        } catch (_: RuntimeException) {
            outcome = "failed"
            false
        }
    }

    private fun finishProbe() {
        if (finished) return
        finished = true
        handler.removeCallbacksAndMessages(null)
        overlay?.let {
            try { getSystemService(WindowManager::class.java).removeViewImmediate(it) }
            catch (_: RuntimeException) { /* Already detached or permission revoked. */ }
        }
        overlay = null
        if (outcome == null) outcome = if (shown) "completed" else "cancelled"
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onTimeout(startId: Int) {
        outcome = "failed"
        session?.stop() ?: finishProbe()
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        onTimeout(startId)
    }

    override fun onDestroy() {
        session?.stop() ?: finishProbe()
        running = false
        super.onDestroy()
    }
}
