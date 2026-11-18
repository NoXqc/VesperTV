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
import com.github.dart_lang.jni.JniPlugin
import com.github.dart_lang.jni_flutter.JniFlutterPlugin
import com.tekartik.sqflite.SqflitePlugin
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Settings > Profiles & startup > Startup > Update while VesperTV is closed: an hourly job
 * that refreshes the guide and the playlists due for a full sync while the app isn't on
 * screen. lib/services/content_updates.dart decides what's due.
 *  - The app's own engine still exists (Back > Exit only hides the app): it updates itself
 *    (`runInApp`), no second copy of the catalog in memory.
 *  - Otherwise a headless engine runs `contentUpdateBackgroundMain` with only the plugins the
 *    update needs. It stops when the app comes on screen (the gate), and the app waits for it
 *    at launch (`isRunning`). Both engines share sqflite's native connection (static, one per
 *    database file), so neither may close it.
 * All methods that touch an engine run on the main thread.
 */
object ContentUpdateWork {
    const val CHANNEL = "vespertv/content_updates"
    const val NAME = "vespertv-content-updates"
    private const val STATUS = "vespertv-content-updates"
    val gate = EpisodeWorkGate()

    /** A headless run's engine exists: the app waits for it at launch. */
    @Volatile var headlessRunning = false

    /** The app's own engine's channel, while that engine exists. */
    var app: MethodChannel? = null
    private var appEngine: FlutterEngine? = null

    private fun flutterPrefs(context: Context) =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    fun enabled(context: Context) =
        flutterPrefs(context).getBoolean("flutter.vesper_content_updates", false)

    /** When something is next due (ms), written by the Dart side; 0 = check now. */
    fun nextDue(context: Context): Long = try {
        flutterPrefs(context).getLong("flutter.vesper_content_next_due", 0L)
    } catch (_: ClassCastException) {
        0L
    }

    fun schedule(context: Context, on: Boolean) {
        try {
            val work = WorkManager.getInstance(context)
            if (!on) {
                work.cancelUniqueWork(NAME)
                return
            }
            val request = PeriodicWorkRequest.Builder(
                ContentUpdateWorker::class.java, 1, TimeUnit.HOURS
            ).setConstraints(Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .setRequiresStorageNotLow(true)
                .setRequiresBatteryNotLow(true).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.MINUTES).build()
            work.enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        } catch (e: Exception) {
            Log.w("ContentUpdateBg", "schedule failed: ${e.javaClass.simpleName}")
        }
    }

    private fun stamp(ms: Long) = SimpleDateFormat("MM-dd HH:mm", Locale.US).format(Date(ms))

    /** A job firing, even when nothing was due (Send log: is it running at all?). */
    fun checked(context: Context) {
        context.getSharedPreferences(STATUS, Context.MODE_PRIVATE).edit()
            .putLong("lastCheck", System.currentTimeMillis()).apply()
    }

    /** One run that did something: kept with the 5 before it. */
    fun record(context: Context, outcome: Map<*, *>?, path: String, startedAt: Long) {
        val result = outcome?.get("result") as? String ?: "error"
        val line = "${stamp(startedAt)} $path result=$result" +
            " guide=${outcome?.get("guide") ?: "-"}" +
            " playlists=${outcome?.get("synced") ?: 0}/${outcome?.get("due") ?: 0}" +
            " took=${(System.currentTimeMillis() - startedAt) / 1000}s"
        val prefs = context.getSharedPreferences(STATUS, Context.MODE_PRIVATE)
        val runs = (listOf(line) + (prefs.getString("runs", "") ?: "").lines())
            .filter { it.isNotBlank() }.take(6)
        prefs.edit().putString("runs", runs.joinToString("\n")).apply()
        Log.i("ContentUpdateBg", line)
    }

    fun diagnostics(context: Context): String {
        val prefs = context.getSharedPreferences(STATUS, Context.MODE_PRIVATE)
        val last = prefs.getLong("lastCheck", 0L)
        val next = nextDue(context)
        val head = "ContentUpdateBg: on=${enabled(context)}" +
            " lastCheck=${if (last == 0L) "never" else stamp(last)}" +
            " nextDue=${if (next == 0L) "now" else stamp(next)}"
        val runs = prefs.getString("runs", "") ?: ""
        return if (runs.isBlank()) head
        else head + "\n" + runs.lines().joinToString("\n") { "  $it" }
    }

    fun connect(context: Context, engine: FlutterEngine) {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    schedule(context, call.argument<Boolean>("on") == true)
                    result.success(null)
                }
                "isRunning" -> result.success(headlessRunning)
                "diagnostics" -> result.success(diagnostics(context))
                else -> result.notImplemented()
            }
        }
        app = channel
        appEngine = engine
    }

    fun disconnect(engine: FlutterEngine) {
        if (appEngine !== engine) return
        app = null
        appEngine = null
    }
}

class ContentUpdateWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    private val main = Handler(Looper.getMainLooper())
    private val finished = CountDownLatch(1)
    private val closed = AtomicBoolean(false)
    private val startedAt = System.currentTimeMillis()
    private var engine: FlutterEngine? = null
    private var lease: Long? = null
    /** "app" (the app's own engine) or "closed" (a headless one), for the record. */
    @Volatile private var path = "app"
    /** Last call from the headless engine's Dart side (it asks every second). */
    @Volatile private var lastHeard = 0L

    override fun doWork(): Result {
        val context = applicationContext
        if (!ContentUpdateWork.enabled(context)) {
            ContentUpdateWork.schedule(context, false)
            return Result.success()
        }
        ContentUpdateWork.checked(context)
        // On screen: the app updates itself (launch sync, guide timer).
        if (ContentUpdateWork.gate.foreground) return Result.success()
        if (System.currentTimeMillis() < ContentUpdateWork.nextDue(context)) return Result.success()
        main.post { start() }
        try {
            // Android stops a job after 10 minutes; the Dart side stops at 8.
            val deadline = startedAt + TimeUnit.MINUTES.toMillis(9)
            while (!finished.await(15, TimeUnit.SECONDS)) {
                val now = System.currentTimeMillis()
                val silent = lastHeard != 0L && now - lastHeard > 60_000
                if (now < deadline && !silent) continue
                // A headless engine that never runs its Dart side (or stops answering) isn't
                // kept for the whole 9 minutes.
                ContentUpdateWork.record(context,
                    mapOf("result" to if (silent) "error(no_answer)" else "error(timeout)"),
                    path, startedAt)
                break
            }
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        } finally {
            closed.set(true)
            main.post { cleanup() }
        }
        return Result.success()
    }

    private fun start() {
        if (closed.get() || isStopped) {
            finished.countDown()
            return
        }
        val app = ContentUpdateWork.app
        if (app != null) runInApp(app) else startEngine()
    }

    private fun runInApp(app: MethodChannel) {
        app.invokeMethod("runInApp", null, object : MethodChannel.Result {
            override fun success(result: Any?) {
                if (!closed.get()) {
                    ContentUpdateWork.record(applicationContext, result as? Map<*, *>, "app", startedAt)
                }
                finished.countDown()
            }

            override fun error(code: String, message: String?, details: Any?) {
                if (!closed.get()) {
                    ContentUpdateWork.record(applicationContext, mapOf("result" to "error(app)"),
                        "app", startedAt)
                }
                finished.countDown()
            }

            // The app's engine hasn't finished starting (warm exit during the splash).
            override fun notImplemented() {
                finished.countDown()
            }
        })
    }

    private fun startEngine() {
        path = "closed"
        lease = ContentUpdateWork.gate.acquire()
        if (lease == null) {
            finished.countDown()
            return
        }
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            val headless = FlutterEngine(applicationContext, null, false)
            engine = headless
            ContentUpdateWork.headlessRunning = true
            lastHeard = System.currentTimeMillis()
            // Only what the update needs. No GeneratedPluginRegistrant: that would register the
            // native player. JNI = path_provider.
            headless.plugins.add(SharedPreferencesPlugin())
            headless.plugins.add(SqflitePlugin())
            headless.plugins.add(JniPlugin())
            headless.plugins.add(JniFlutterPlugin())
            MethodChannel(headless.dartExecutor.binaryMessenger, ContentUpdateWork.CHANNEL)
                .setMethodCallHandler { call, result ->
                    lastHeard = System.currentTimeMillis()
                    when (call.method) {
                        "stopReason" -> result.success(when {
                            isStopped -> "android"
                            !ContentUpdateWork.gate.allowed(lease) -> "app_opened"
                            else -> null
                        })
                        "finish" -> {
                            result.success(null)
                            if (!closed.get()) {
                                ContentUpdateWork.record(applicationContext,
                                    call.arguments as? Map<*, *>, "closed", startedAt)
                            }
                            finished.countDown()
                        }
                        else -> result.notImplemented()
                    }
                }
            headless.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(
                loader.findAppBundlePath(),
                "package:nox_iptv/services/content_updates.dart",
                "contentUpdateBackgroundMain"
            ))
        } catch (e: Exception) {
            ContentUpdateWork.record(applicationContext,
                mapOf("result" to "error(engine ${e.javaClass.simpleName})"), "closed", startedAt)
            finished.countDown()
        }
    }

    private fun cleanup() {
        engine?.destroy()
        engine = null
        ContentUpdateWork.headlessRunning = false
        ContentUpdateWork.gate.release(lease)
        lease = null
    }

    override fun onStopped() {
        closed.set(true)
        finished.countDown()
        main.post { cleanup() }
    }
}
