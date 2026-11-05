package com.nox.nox_iptv

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin
import org.json.JSONArray
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/** All methods that access the engine or commit a checkpoint run on main. */
object EpisodeAlertsWork {
    const val CHANNEL = "vespertv/episode_background"
    const val NAME = "vespertv-episode-alerts"
    val gate = EpisodeWorkGate()

    fun enqueue(context: Context) {
        try {
            val request = PeriodicWorkRequest.Builder(
                EpisodeAlertsWorker::class.java, 3, TimeUnit.HOURS
            ).setConstraints(Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setInitialDelay(3, TimeUnit.HOURS)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.MINUTES).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                NAME, ExistingPeriodicWorkPolicy.KEEP, request
            )
        } catch (_: Exception) {
            record(context, "error(schedule)", 0, 0)
        }
    }

    fun record(context: Context, result: String, shows: Int, fresh: Int) {
        val line = "EpisodeAlertsBg: lastRun=${System.currentTimeMillis()} " +
            "result=$result shows=$shows new=$fresh"
        context.getSharedPreferences(NAME, Context.MODE_PRIVATE).edit()
            .putString("status", line).apply()
        Log.i("EpisodeAlertsBg", line)
    }

    fun diagnostics(context: Context): String = context
        .getSharedPreferences(NAME, Context.MODE_PRIVATE)
        .getString("status", "EpisodeAlertsBg: lastRun=never result=pending shows=0 new=0")!!

    fun connect(context: Context, engine: FlutterEngine,
                hasTap: () -> Boolean, clearTap: () -> Unit) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> { enqueue(context); result.success(null) }
                    "diagnostics" -> result.success(diagnostics(context))
                    "isForeground" -> result.success(gate.foreground)
                    "hasTap" -> result.success(hasTap())
                    "clearTap" -> { clearTap(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }
}

/** Bounded headless worker: no Activity, rendering, player or SQLite plugin. */
class EpisodeAlertsWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    private val main = Handler(Looper.getMainLooper())
    private val finished = CountDownLatch(1)
    private val closed = AtomicBoolean(false)
    private var engine: FlutterEngine? = null
    private var lease: Long? = null
    @Volatile private var outcome: Result = Result.retry()

    private fun allowed() = EpisodeAlertsWork.gate.allowed(lease) && !closed.get() && !isStopped

    override fun doWork(): Result {
        main.post { startEngine() }
        try {
            if (!finished.await(7, TimeUnit.MINUTES)) {
                EpisodeAlertsWork.record(applicationContext, "error(timeout)", 0, 0)
            }
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        } finally {
            closed.set(true)
            main.post { cleanup() }
        }
        return outcome
    }

    private fun startEngine() {
        if (closed.get() || isStopped) { finished.countDown(); return }
        lease = EpisodeAlertsWork.gate.acquire()
        if (lease == null) {
            EpisodeAlertsWork.record(applicationContext, "skipped(foreground_or_busy)", 0, 0)
            outcome = Result.success()
            finished.countDown()
            return
        }
        try {
            EpisodeAlertsWork.record(applicationContext, "running", 0, 0)
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            val headless = FlutterEngine(applicationContext, null, false)
            engine = headless
            // SharedPreferences is the only plugin this entrypoint needs. No
            // GeneratedPluginRegistrant: that would register the native player.
            headless.plugins.add(SharedPreferencesPlugin())
            val notifier = EpisodeNotifier(applicationContext)
            MethodChannel(headless.dartExecutor.binaryMessenger, "vespertv/notify")
                .setMethodCallHandler { call, result ->
                    if (allowed() && call.method == "episode") notifier.handle(call, result)
                    else result.success(null)
                }
            MethodChannel(headless.dartExecutor.binaryMessenger, EpisodeAlertsWork.CHANNEL)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "canRun" -> result.success(allowed())
                        "commit" -> {
                            val key = call.argument<String>("key")
                            val viewer = call.argument<String>("viewer")
                            val expected = call.argument<String>("expected")
                            val data = call.argument<String>("data")
                            val prefs = applicationContext.getSharedPreferences(
                                "FlutterSharedPreferences", Context.MODE_PRIVATE)
                            val validKey = if (viewer == "main") "vesper_episode_alerts"
                                else "vesper_episode_alerts__vp_$viewer"
                            val profiles = try {
                                JSONArray(prefs.getString("flutter.nox_viewer_profiles", "[]"))
                            } catch (_: Exception) { JSONArray() }
                            val viewerExists = viewer == "main" || (0 until profiles.length()).any {
                                profiles.optJSONObject(it)?.optString("id") == viewer
                            }
                            // Check and commit in this main-loop turn. Activity onStart
                            // invalidates the lease before the UI can edit preferences.
                            val saved = allowed() && viewerExists && key == validKey && data != null &&
                                prefs.getString("flutter.$key", null) == expected &&
                                prefs.edit().putString("flutter.$key", data).commit()
                            result.success(saved)
                        }
                        "finish" -> {
                            val code = call.argument<String>("result") ?: "error"
                            EpisodeAlertsWork.record(applicationContext, code,
                                call.argument<Int>("shows") ?: 0, call.argument<Int>("new") ?: 0)
                            outcome = if (code == "error") Result.retry() else Result.success()
                            result.success(null)
                            finished.countDown()
                        }
                        else -> result.notImplemented()
                    }
                }
            headless.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(
                loader.findAppBundlePath(),
                "package:nox_iptv/services/episode_alerts_background.dart",
                "episodeAlertsBackgroundMain"
            ))
        } catch (_: Exception) {
            EpisodeAlertsWork.record(applicationContext, "error(engine)", 0, 0)
            finished.countDown()
        }
    }

    private fun cleanup() {
        engine?.destroy()
        engine = null
        EpisodeAlertsWork.gate.release(lease)
        lease = null
    }

    override fun onStopped() {
        closed.set(true)
        EpisodeAlertsWork.record(applicationContext, "skipped(stopped)", 0, 0)
        finished.countDown()
        main.post { cleanup() }
    }
}
