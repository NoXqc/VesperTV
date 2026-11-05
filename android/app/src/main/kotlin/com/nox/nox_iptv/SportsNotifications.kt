package com.nox.nox_iptv

import android.app.Activity
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

object SportsNotifications {
    const val CHANNEL = "vespertv/sports_notifications"
    private const val STORE = "vespertv_sports_notifications"
    val gate = EpisodeWorkGate()
    @Volatile var goalStartPending = false
    private fun prefs(c: Context) = c.getSharedPreferences(STORE, Context.MODE_PRIVATE)
    fun flutter(c: Context) = c.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    fun key(base: String, viewer: String) = "flutter." + base + if (viewer == "main") "" else "__vp_$viewer"
    private fun array(raw: String?) = try { JSONArray(raw ?: "[]") } catch (_: Exception) { JSONArray() }
    fun plans(c: Context): List<JSONObject> {
        val raw = array(prefs(c).getString("plans", "[]"))
        return (0 until raw.length()).mapNotNull { raw.optJSONObject(it) }
    }
    fun viewerExists(c: Context, viewer: String): Boolean {
        if (viewer == "main") return true
        val raw = array(flutter(c).getString("flutter.nox_viewer_profiles", "[]"))
        return (0 until raw.length()).any { raw.optJSONObject(it)?.optString("id") == viewer }
    }
    fun enabled(c: Context, viewer: String, goal: Boolean) = viewerExists(c, viewer) &&
        flutter(c).getBoolean(key(if (goal) "vesper_phone_goal_alerts" else "vesper_phone_game_reminders", viewer), true)
    fun active(c: Context, now: Long = System.currentTimeMillis()): List<JSONObject> = plans(c).filter {
        it.optString("kind") == "goals" && it.optLong("at") <= now && it.optLong("endAt") > now &&
            enabled(c, it.optString("viewer"), true) && !prefs(c).getBoolean("stopped:${it.optString("id")}", false)
    }
    private fun pending(c: Context, id: String, flags: Int): PendingIntent? = PendingIntent.getBroadcast(
        c, 0, Intent(c, SportsAlarmReceiver::class.java).setAction("vespertv.SPORTS_ALARM")
            .setData(Uri.parse("vespertv://sports/" + Uri.encode(id))).putExtra("id", id),
        flags or PendingIntent.FLAG_IMMUTABLE)

    fun sync(c: Context, items: JSONArray) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        pending(c, "next", PendingIntent.FLAG_NO_CREATE)?.let { am.cancel(it); it.cancel() }
        val ids = (0 until items.length()).mapNotNull { items.optJSONObject(it)?.optString("id") }.toSet()
        val edit = prefs(c).edit().putString("plans", items.toString())
        for (key in prefs(c).all.keys) if (key.startsWith("stopped:") && key.removePrefix("stopped:") !in ids) edit.remove(key)
        edit.commit()
        arm(c)
        if (active(c).isEmpty()) c.stopService(Intent(c, SportsGoalService::class.java))
    }
    fun arm(c: Context) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        pending(c, "next", PendingIntent.FLAG_NO_CREATE)?.let { am.cancel(it) }
        val exact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        val now = System.currentTimeMillis()
        var count = 0; var next = Long.MAX_VALUE
        for (item in plans(c)) {
            if (prefs(c).getBoolean("stopped:${item.optString("id")}", false)) continue
            val kind = item.optString("kind")
            if (!enabled(c, item.optString("viewer"), kind == "goals")) continue
            if (kind == "goals" && (!exact || gate.foreground ||
                (item.optLong("at") <= now && (SportsGoalService.instance != null || goalStartPending)))) continue
            val at = SportsAlarmPolicy.deadline(kind, item.optLong("at"), item.optLong("endAt"), now) ?: continue
            next = minOf(next, at)
            if (kind == "reminder") count++
        }
        var armed = false
        if (next != Long.MAX_VALUE) {
            val pi = pending(c, "next", PendingIntent.FLAG_UPDATE_CURRENT)!!
            try {
                if (exact) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pi)
                else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pi)
                armed = true
            } catch (_: Exception) { Log.w("SportsNotify", "alarm denied") }
        }
        val line = "SportsNotify: reminders armed=$count next=${if (next == Long.MAX_VALUE) "none" else next} exact=$exact alarms=${if (armed) 1 else 0}"
        prefs(c).edit().putString("alarms", line).apply(); Log.i("SportsNotify", line)
    }
    fun fireNext(c: Context) {
        val now = System.currentTimeMillis()
        for (item in plans(c)) {
            if (item.optLong("at") <= now && item.optLong("endAt") > now) fire(c, item.optString("id"))
        }
        arm(c)
    }
    fun onVisible(c: Context, visible: Boolean) {
        gate.setVisible(visible)
        if (visible) {
            goalStartPending = false
            SportsGoalService.stopReason = "foreground"
            c.stopService(Intent(c, SportsGoalService::class.java))
        } else arm(c)
    }
    fun diagnostics(c: Context) = (prefs(c).getString("alarms", "SportsNotify: reminders armed=0 next=none") ?: "") +
        "\n" + (prefs(c).getString("goals", "GoalService: lastRun=never games=0 polls=0 goals=0 stop=not_started") ?: "")
    fun status(c: Context, games: Int, polls: Int, goals: Int, stop: String) {
        val line = "GoalService: lastRun=${System.currentTimeMillis()} games=$games polls=$polls goals=$goals stop=$stop"
        prefs(c).edit().putString("goals", line).apply(); Log.i("GoalService", line)
    }
    fun stopGames(c: Context, items: List<JSONObject>) {
        val edit = prefs(c).edit()
        for (item in items) edit.putBoolean("stopped:${item.optString("id")}", true)
        edit.apply()
    }
    fun fire(c: Context, id: String) {
        val item = plans(c).firstOrNull { it.optString("id") == id } ?: return
        val now = System.currentTimeMillis()
        if (item.optLong("endAt") <= now || prefs(c).getBoolean("stopped:$id", false)) return
        if (item.optString("kind") == "goals") {
            val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (gate.foreground || active(c).isEmpty() || goalStartPending || SportsGoalService.instance != null ||
                (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms())) return
            goalStartPending = true
            try {
                val intent = Intent(c, SportsGoalService::class.java)
                if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(intent) else c.startService(intent)
            } catch (_: Exception) {
                goalStartPending = false
                stopGames(c, active(c))
                status(c, active(c).size, 0, 0, "start_denied")
            }
            return
        }
        val viewer = item.optString("viewer")
        if (!enabled(c, viewer, false)) return
        // Do not consume the in-app popup's flag while its UI is visible.
        if (gate.foreground) return
        val fp = flutter(c); val prefKey = key("vesper_game_reminders", viewer)
        val raw = fp.getString(prefKey, null) ?: return
        val root = try {
            if (raw.trimStart().startsWith("[")) JSONObject().put("entries", JSONArray(raw)) else JSONObject(raw)
        } catch (_: Exception) { return }
        val entries = root.optJSONArray("entries") ?: return
        val phase = item.optString("phase")
        val entry = (0 until entries.length()).mapNotNull { entries.optJSONObject(it) }.firstOrNull {
            it.optString("key") == item.optString("key") &&
            it.optString("start") == item.optString("entryStart") &&
            it.optInt("leadMinutes", 15) == item.optInt("lead")
        } ?: return
        if (!SportsAlarmPolicy.canDeliver(now, item.optLong("at"), item.optLong("endAt"), entry.optBoolean(phase), gate.foreground)) return
        entry.put(phase, true)
        if (!fp.edit().putString(prefKey, root.toString()).commit()) return
        notify(c, "sports_reminders", item.optString("reminderChannel"), "reminder:$id",
            item.optString("title"), item.optString("text"), item)
    }
    fun launch(c: Context, target: JSONObject, id: String): PendingIntent? =
        c.packageManager.getLaunchIntentForPackage(c.packageName)?.let {
            it.putExtra("vespertv_sports_target", JSONObject().put("key", target.optString("key"))
                .put("startAt", target.optLong("startAt")).toString())
            it.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            it.action = "vespertv.SPORTS_TAP.$id"
            PendingIntent.getActivity(c, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
    fun channel(c: Context, id: String, name: String, low: Boolean = false) {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(NotificationChannel(id, name,
                if (low) NotificationManager.IMPORTANCE_LOW else NotificationManager.IMPORTANCE_DEFAULT))
        }
    }
    fun notify(c: Context, channelId: String, channelName: String, id: String, title: String, text: String, target: JSONObject) {
        channel(c, channelId, channelName)
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, channelId) else Notification.Builder(c)
        val n = b.setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle(title)
            .setContentText(text).setStyle(Notification.BigTextStyle().bigText(text)).setAutoCancel(true)
            .setOnlyAlertOnce(true).setContentIntent(launch(c, target, id)).build()
        try { (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(id, 0, n) }
        catch (_: SecurityException) { Log.i("SportsNotify", "notification permission denied") }
    }
    fun checkpoint(c: Context, call: MethodCall, allowed: Boolean): Boolean {
        val viewer = call.argument<String>("viewer") ?: return false
        val data = call.argument<String>("data") ?: return false
        val prefKey = key("vesper_goal_phone_checkpoint", viewer)
        val fp = flutter(c)
        return allowed && viewerExists(c, viewer) && fp.getString(prefKey, null) == call.argument<String>("expected") &&
            fp.edit().putString(prefKey, data).commit()
    }
    fun goal(c: Context, call: MethodCall, allowed: Boolean) {
        val viewer = call.argument<String>("viewer") ?: return
        if (!allowed || gate.foreground || !enabled(c, viewer, true)) return
        if (active(c).none { it.optString("viewer") == viewer && it.optString("key") == call.argument<String>("key") }) return
        val hidden = active(c).filter { it.optString("key") == call.argument<String>("key") }.any {
            flutter(c).getBoolean(key("vesper_sports_hide_scores", it.optString("viewer")), false)
        }
        val target = JSONObject().put("key", call.argument<String>("key")).put("startAt", call.argument<Long>("startAt"))
        notify(c, "sports_goals", call.argument<String>("channel") ?: "Goal alerts",
            call.argument<String>("id") ?: return, call.argument<String>("title") ?: "",
            SportsAlarmPolicy.goalText(hidden, call.argument<String>("text") ?: "",
                call.argument<String>("hiddenText") ?: ""), target)
    }
    /** Serialize app writes with alarm delivery; retain sent flags only for
     *  the same game/start/lead, while new removals/edits remain authoritative. */
    private fun saveReminders(c: Context, viewer: String, data: String) {
        if (!viewerExists(c, viewer)) return
        val fp = flutter(c); val prefKey = key("vesper_game_reminders", viewer)
        fun entries(raw: String?): JSONArray = try {
            if (raw?.trimStart()?.startsWith("[") == true) JSONArray(raw)
            else JSONObject(raw ?: "{}").optJSONArray("entries") ?: JSONArray()
        } catch (_: Exception) { JSONArray() }
        val old = entries(fp.getString(prefKey, null))
        val root = JSONObject(data)
        val list = root.optJSONArray("entries") ?: JSONArray()
        for (i in 0 until list.length()) {
            val item = list.optJSONObject(i) ?: continue
            val previous = (0 until old.length()).mapNotNull { old.optJSONObject(it) }.firstOrNull {
                it.optString("key") == item.optString("key") && it.optString("start") == item.optString("start") &&
                    it.optInt("leadMinutes", 15) == item.optInt("leadMinutes", 15)
            } ?: continue
            item.put("early", item.optBoolean("early") || previous.optBoolean("early"))
            item.put("started", item.optBoolean("started") || previous.optBoolean("started"))
        }
        check(fp.edit().putString(prefKey, root.toString()).commit())
    }
    fun connect(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "reminders" -> {
                    saveReminders(activity, call.argument<String>("viewer") ?: "main", call.argument<String>("data") ?: "{}")
                    result.success(null)
                }
                "sync" -> {
                    val items = JSONArray()
                    for (item in call.argument<List<Map<String, Any?>>>("items") ?: emptyList()) items.put(JSONObject(item))
                    sync(activity, items)
                    if (gate.foreground && items.length() > 0 && !prefs(activity).getBoolean("permission_asked", false)) {
                        prefs(activity).edit().putBoolean("permission_asked", true).apply()
                        EpisodeNotifier(activity).handle(MethodCall("requestPermission", null), result)
                    } else result.success(null)
                }
                "plans" -> result.success(plans(activity).map { obj -> obj.keys().asSequence().associateWith { obj.opt(it) } })
                "foreground" -> result.success(gate.foreground)
                "checkpoint" -> result.success(checkpoint(activity, call, gate.foreground))
                "goal" -> { goal(activity, call, true); result.success(null) }
                "diagnostics" -> result.success(diagnostics(activity))
                "hasTap" -> result.success(activity.intent?.hasExtra("vespertv_sports_target") == true)
                "target" -> {
                    val target = runCatching { JSONObject(activity.intent?.getStringExtra("vespertv_sports_target") ?: "{}") }.getOrNull()
                    result.success(if (target == null) null else mapOf("key" to target.optString("key"), "startAt" to target.optLong("startAt")))
                }
                "clearTap" -> { activity.intent?.removeExtra("vespertv_sports_target"); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
}
class SportsAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("id") ?: return
        if (id == "next") SportsNotifications.fireNext(context)
    }
}
