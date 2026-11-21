package com.nox.nox_iptv

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.tvprovider.media.tv.PreviewChannelHelper
import androidx.tvprovider.media.tv.PreviewProgram
import androidx.tvprovider.media.tv.TvContractCompat

/**
 * The "Live now in Sports" row shows scores, so it must not outlive the app keeping it current.
 * Dart re-sends it every few minutes while VesperTV runs in the background (and says it's still
 * there while it's on screen); each time, [fresh] moves this alarm [FRESH_MS] ahead. If Android
 * stops or freezes the app, the alarm fires and empties the row: no game stays "live" with an old
 * score after it ended. The next send (the app hidden again, or 20 s after a launch) fills it.
 */
class LauncherLiveExpiry : BroadcastReceiver() {
    companion object {
        private const val TAG = "VesperLauncher"
        private const val PREFS = "vesper_launcher_native"
        private const val KEY = "live_fresh_until"
        const val CHANNEL_ID = "live"
        const val FRESH_MS = 20 * 60_000L

        /** Live cards were sent or confirmed ([hasCards]), or the row is empty / gone. */
        fun fresh(context: Context, hasCards: Boolean) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val alarms = context.getSystemService(AlarmManager::class.java) ?: return
            val pending = pending(context)
            if (!hasCards) {
                prefs.edit().remove(KEY).apply()
                alarms.cancel(pending)
                return
            }
            val until = System.currentTimeMillis() + FRESH_MS
            prefs.edit().putLong(KEY, until).apply()
            // Not a wakeup: a box asleep has no launcher on screen; it fires on waking.
            alarms.set(AlarmManager.RTC, until, pending)
        }

        private fun pending(context: Context): PendingIntent = PendingIntent.getBroadcast(
            context, 0x11FE,
            Intent(context, LauncherLiveExpiry::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        /** Removes every card of our live row (the row itself stays, empty). */
        private fun clear(context: Context): Int {
            val helper = PreviewChannelHelper(context)
            val resolver = context.contentResolver
            var removed = 0
            for (c in helper.allChannels) {
                if (c.internalProviderId != CHANNEL_ID) continue
                if (c.packageName != null && c.packageName != context.packageName) continue
                resolver.query(
                    TvContractCompat.buildPreviewProgramsUriForChannel(c.id),
                    PreviewProgram.PROJECTION, null, null, null
                )?.use { cursor ->
                    while (cursor.moveToNext()) {
                        helper.deletePreviewProgram(PreviewProgram.fromCursor(cursor).id)
                        removed++
                    }
                }
            }
            return removed
        }

        private fun expire(context: Context) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val until = prefs.getLong(KEY, 0L)
            if (until == 0L) return
            if (System.currentTimeMillis() < until - 5_000L) {
                // Refreshed since this alarm was set (an older alarm firing late).
                context.getSystemService(AlarmManager::class.java)
                    ?.set(AlarmManager.RTC, until, pending(context))
                return
            }
            val removed = clear(context)
            prefs.edit().remove(KEY).apply()
            Log.i(TAG, "live row not refreshed for ${FRESH_MS / 60_000} min: removed $removed cards")
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val result = goAsync()
        val app = context.applicationContext
        Thread {
            try {
                expire(app)
            } catch (e: Exception) {
                // No TvProvider (the row was never sent), or it refused us.
                Log.w(TAG, "live row expiry failed", e)
            } finally {
                result.finish()
            }
        }.start()
    }
}
