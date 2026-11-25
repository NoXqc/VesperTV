package com.nox.nox_iptv

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.StatFs
import android.util.Log
import java.io.File

/**
 * Settings > Check for Updates: did the update the app handed to Android's installer arrive?
 * GitHub #22 (Fire TV Stick 4K Max, 1.0.74-dev.980 -> 1013): "it downloads, says it is
 * installed, but doesn't update", and the log had no updater line at all. The installer runs in
 * its own app and tells us nothing back (ACTION_VIEW), so the attempt is written down here
 * (version in the APK, the installed one, free storage) and checked at the next start: same
 * version = the install didn't take. Send log gets `VesperUpdater:` lines either way, and
 * [lastFailure] lets the Check for Updates screen say so.
 *
 * Own SharedPreferences file (not Flutter's), so Transfer, sync and backups never carry it.
 */
internal class UpdateAttempts(private val context: Context) {
    private val prefs = context.getSharedPreferences("vesper_update_attempt", Context.MODE_PRIVATE)

    /** Before the installer opens: what goes in, what is installed, the room left. */
    fun record(apk: File, installer: String?) {
        try {
            val target = context.packageManager.getPackageArchiveInfo(apk.path, 0)
            val targetName = target?.versionName ?: "?"
            val targetCode = target?.let { versionCode(it) } ?: -1L
            if (target != null && target.packageName != context.packageName) {
                // Another app (the remote buttons add-on): nothing to check at our next start.
                Log.i(TAG, "VesperUpdater: installing ${target.packageName} $targetName")
                return
            }
            val (name, code) = installed()
            val freeMb = try {
                StatFs(context.filesDir.path).availableBytes / (1024 * 1024)
            } catch (_: Exception) {
                -1L
            }
            prefs.edit()
                .putString("target", targetName)
                .putLong("targetCode", targetCode)
                .putString("from", name)
                .putLong("fromCode", code)
                .putLong("at", System.currentTimeMillis())
                .apply()
            Log.i(
                TAG,
                "VesperUpdater: installing $targetName ($targetCode) over $name ($code), " +
                    "apk ${apk.length() / (1024 * 1024)} MB, free $freeMb MB, " +
                    "installer ${installer ?: "?"}"
            )
        } catch (e: Exception) {
            Log.w(TAG, "VesperUpdater: could not note the update (${e.javaClass.simpleName})")
        }
    }

    /** At start: the last attempt's result, once. */
    fun checkAtStart() {
        try {
            val at = prefs.getLong("at", 0L)
            if (at == 0L) return
            val target = prefs.getString("target", "?") ?: "?"
            val targetCode = prefs.getLong("targetCode", -1L)
            val (name, code) = installed()
            prefs.edit().clear().apply()
            val minutes = (System.currentTimeMillis() - at) / 60_000
            val failure = outcome(targetCode, code)
            if (failure) {
                lastFailure = target
                Log.w(
                    TAG,
                    "VesperUpdater: the update to $target ($targetCode) did not install, " +
                        "still $name ($code), tried $minutes min ago"
                )
            } else {
                Log.i(TAG, "VesperUpdater: updated to $name ($code), $minutes min after the install")
            }
        } catch (e: Exception) {
            Log.w(TAG, "VesperUpdater: could not check the last update (${e.javaClass.simpleName})")
        }
    }

    private fun installed(): Pair<String, Long> = try {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        (info.versionName ?: "?") to versionCode(info)
    } catch (_: PackageManager.NameNotFoundException) {
        "?" to -1L
    }

    @Suppress("DEPRECATION")
    private fun versionCode(info: android.content.pm.PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode
        else info.versionCode.toLong()

    companion object {
        private const val TAG = "VesperUpdater"

        /** The version whose install didn't take, found at this start (null = none). */
        @Volatile
        var lastFailure: String? = null

        /** True when the APK's version never arrived (unknown target = can't tell = no). */
        fun outcome(targetCode: Long, installedCode: Long): Boolean =
            targetCode > 0 && installedCode in 0 until targetCode
    }
}
