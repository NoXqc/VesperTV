package com.nox.nox_iptv

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin
import org.json.JSONObject

/** One phone notification session for all overlapping subscribed games. */
class SportsGoalService : Service() {
    companion object {
        private const val NOTIFICATION = 0x531991
        const val STOP = "vespertv.STOP_GOALS"
        var instance: SportsGoalService? = null
        var stopReason = "not_started"
    }
    private val main = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var lease: Long? = null
    private var wake: PowerManager.WakeLock? = null
    private var offlineAt: Long? = null
    private var polls = 0
    private var goals = 0
    private var lastTitle: String? = null
    private fun allowed() = SportsNotifications.gate.allowed(lease) && instance === this

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP) {
            SportsNotifications.stopGames(this, SportsNotifications.active(this))
            stopReason = "user_stop"; stopSelf(); return START_NOT_STICKY
        }
        if (SportsNotifications.gate.foreground || SportsNotifications.active(this).isEmpty()) {
            stopReason = "foreground_or_empty"; stopSelf(); return START_NOT_STICKY
        }
        instance = this
        if (engine != null) return START_NOT_STICKY
        lease = SportsNotifications.gate.acquire()
        if (lease == null) { stopReason = "busy"; stopSelf(); return START_NOT_STICKY }
        stopReason = "running"
        val item = SportsNotifications.active(this).first()
        try {
            val notification = ongoing(item)
            if (Build.VERSION.SDK_INT >= 34) startForeground(NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            else startForeground(NOTIFICATION, notification)
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wake = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:goal-notifications").apply {
                setReferenceCounted(false); acquire(5 * 60 * 60 * 1000L)
            }
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            val headless = FlutterEngine(applicationContext, null, false)
            engine = headless
            headless.plugins.add(SharedPreferencesPlugin())
            MethodChannel(headless.dartExecutor.binaryMessenger, SportsNotifications.CHANNEL)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "foreground" -> result.success(SportsNotifications.gate.foreground)
                        "state" -> result.success(mapOf("allowed" to allowed(), "items" to SportsNotifications.active(this).map { obj ->
                            obj.keys().asSequence().associateWith { obj.opt(it) }
                        }))
                        "checkpoint" -> result.success(SportsNotifications.checkpoint(this, call, allowed()))
                        "goal" -> {
                            if (allowed()) { SportsNotifications.goal(this, call, true); goals++ }
                            result.success(null)
                        }
                        "tick" -> {
                            polls++
                            lastTitle = call.argument<String>("ongoing")
                            SportsNotifications.active(this).firstOrNull()?.let { item ->
                                if (allowed()) {
                                    try { (getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager)
                                        .notify(NOTIFICATION, ongoing(item)) } catch (_: SecurityException) {}
                                }
                            }
                            SportsNotifications.status(this, SportsNotifications.active(this).size, polls, goals, stopReason)
                            result.success(null)
                        }
                        "complete" -> {
                            val ids = call.argument<List<String>>("finished") ?: emptyList()
                            SportsNotifications.stopGames(this, SportsNotifications.active(this).filter { it.optString("id") in ids })
                            result.success(null)
                        }
                        "finish" -> {
                            stopReason = call.argument<String>("reason") ?: "finished"
                            val finished = call.argument<List<String>>("finished") ?: emptyList()
                            SportsNotifications.stopGames(this, SportsNotifications.active(this).filter { it.optString("id") in finished })
                            result.success(null); stopSelf()
                        }
                        else -> result.notImplemented()
                    }
                }
            headless.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "sportsPhoneGoalMain"))
            main.post(guard)
        } catch (_: Exception) { stopReason = "engine_error"; stopSelf() }
        return START_NOT_STICKY
    }
    private fun ongoing(item: JSONObject): Notification {
        SportsNotifications.channel(this, "sports_following", item.optString("followingChannel"), true)
        val stop = PendingIntent.getService(this, 0, Intent(this, SportsGoalService::class.java).setAction(STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "sports_following") else Notification.Builder(this)
        return b.setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle(lastTitle ?: item.optString("ongoing"))
            .setOngoing(true).setOnlyAlertOnce(true).setCategory(Notification.CATEGORY_SERVICE)
            .setContentIntent(SportsNotifications.launch(this, item, "following"))
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, item.optString("stop"), stop).build()
    }
    private val guard = object : Runnable {
        override fun run() {
            val active = SportsNotifications.active(this@SportsGoalService)
            val connected = (getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager).activeNetwork != null
            val now = System.currentTimeMillis()
            if (!connected && offlineAt == null) offlineAt = now
            if (connected) offlineAt = null
            val reason = SportsAlarmPolicy.stopReason(allowed(), active.size, offlineAt, now)
            if (reason != null) { stopReason = reason; stopSelf(); return }
            if (wake?.isHeld == false) wake?.acquire(5 * 60 * 60 * 1000L)
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            try { nm.notify(NOTIFICATION, ongoing(active.first())) } catch (_: SecurityException) {}
            SportsNotifications.status(this@SportsGoalService, active.size, polls, goals, stopReason)
            main.postDelayed(this, 60_000)
        }
    }
    override fun onTimeout(startId: Int, fgsType: Int) { stopReason = "os_timeout"; stopSelf() }
    override fun onDestroy() {
        main.removeCallbacksAndMessages(null)
        engine?.destroy(); engine = null
        if (wake?.isHeld == true) wake?.release()
        wake = null
        SportsNotifications.gate.release(lease); lease = null
        if (instance === this) instance = null
        SportsNotifications.goalStartPending = false
        SportsNotifications.status(this, SportsNotifications.active(this).size, polls, goals, stopReason)
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else { @Suppress("DEPRECATION") stopForeground(true) }
        super.onDestroy()
        if (stopReason == "final" || (stopReason == "foreground" && !SportsNotifications.gate.foreground)) {
            SportsNotifications.arm(this)
        }
    }
}
