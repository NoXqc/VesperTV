package com.nox.nox_iptv

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Timed recordings survive the app being closed: Dart hands the whole
 * upcoming list to [setAll] (stored in prefs, one exact alarm each), the
 * alarm starts [RecorderService], and [BootReceiver] re-arms the alarms
 * after a reboot. Dart re-sends the list whenever it changes, so this is
 * only a mirror of `RecordingService` (lib/services/recording_service.dart).
 */
object RecorderScheduler {
    private const val PREFS = "vesper_recorder"
    private const val KEY = "schedule"

    fun load(context: Context): JSONArray =
        try {
            JSONArray(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }

    private fun save(context: Context, items: JSONArray) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY, items.toString()).apply()
    }

    private fun pending(context: Context, id: String, flags: Int): PendingIntent? =
        PendingIntent.getBroadcast(
            context, id.hashCode(),
            Intent(context, RecorderAlarmReceiver::class.java)
                .setAction("com.nox.nox_iptv.RECORD_ALARM").putExtra("id", id),
            flags or PendingIntent.FLAG_IMMUTABLE,
        )

    /** Replaces the schedule with [items]; returns false when only an
     *  inexact alarm was possible (no exact-alarm permission). */
    fun setAll(context: Context, items: JSONArray): Boolean {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val old = load(context)
        for (i in 0 until old.length()) {
            val id = old.getJSONObject(i).optString("id")
            pending(context, id, PendingIntent.FLAG_NO_CREATE)?.let { am.cancel(it); it.cancel() }
        }
        save(context, items)
        return arm(context)
    }

    /** Sets an alarm for every stored item; starts those already due. */
    fun arm(context: Context): Boolean {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val exact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        val items = load(context)
        val now = System.currentTimeMillis()
        val keep = JSONArray()
        for (i in 0 until items.length()) {
            val item = items.getJSONObject(i)
            val startAt = item.optLong("startAt")
            val endAt = item.optLong("endAt")
            if (endAt in 1..now) continue
            if (startAt <= now) {
                RecorderService.start(context, item)
                continue
            }
            keep.put(item)
            val pi = pending(context, item.getString("id"), PendingIntent.FLAG_UPDATE_CURRENT)!!
            if (exact) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, startAt, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, startAt, pi)
            }
        }
        save(context, keep)
        return exact
    }

    fun fire(context: Context, id: String) {
        val items = load(context)
        val keep = JSONArray()
        for (i in 0 until items.length()) {
            val item = items.getJSONObject(i)
            if (item.optString("id") == id) {
                RecorderService.start(context, item)
            } else {
                keep.put(item)
            }
        }
        save(context, keep)
    }
}

class RecorderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("id") ?: return
        Log.i(RecorderService.TAG, "alarm for $id")
        RecorderScheduler.fire(context, id)
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        RecorderScheduler.arm(context)
    }
}

/** MethodChannel `vespertv/recorder`. */
class RecorderBridge(private val activity: Activity) {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val ctx = activity.applicationContext
        try {
            when (call.method) {
                "schedule" -> {
                    val raw = call.argument<String>("items") ?: "[]"
                    result.success(RecorderScheduler.setAll(ctx, JSONArray(raw)))
                }
                "start" -> {
                    RecorderService.start(ctx, JSONObject(call.argument<String>("item")!!))
                    result.success(null)
                }
                "stop" -> {
                    RecorderService.stop(ctx, call.argument<String>("id")!!)
                    result.success(null)
                }
                "active" -> result.success(
                    RecorderService.active.values.map { mapOf("id" to it.id, "bytes" to it.bytes) }
                )
                "teePort" -> result.success(LiveTee.port())
                "storage" -> {
                    // App storage first, then every external volume the app
                    // can write without a permission (USB drive / SD card on
                    // most boxes show up here once mounted).
                    val dirs = mutableListOf<Map<String, Any>>()
                    val internal = ctx.getExternalFilesDir(null) ?: ctx.filesDir
                    val all = ctx.getExternalFilesDirs(null).filterNotNull()
                    val seen = mutableSetOf<String>()
                    for (d in listOf(internal) + all) {
                        if (!seen.add(d.absolutePath)) continue
                        val removable = try {
                            Environment.isExternalStorageRemovable(d)
                        } catch (_: Exception) {
                            d != internal
                        }
                        dirs.add(
                            mapOf(
                                "path" to java.io.File(d, "Recordings").absolutePath,
                                "free" to d.usableSpace,
                                "total" to d.totalSpace,
                                "removable" to (removable && d != internal),
                            )
                        )
                    }
                    result.success(dirs)
                }
                "canExact" -> {
                    val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    result.success(Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms())
                }
                "askNotifications" -> {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4712)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("RECORDER", e.toString(), null)
        }
    }
}
