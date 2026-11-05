package com.nox.nox_iptv

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.provider.Settings
import androidx.lifecycle.Lifecycle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Only explicit user actions from the visible TV app may launch the probe. */
class OverlayProbeBridge(private val activity: FlutterActivity) {
    private var settingsFailed = false

    @Suppress("DEPRECATION")
    private fun isTv(): Boolean =
        (activity.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager)
            ?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            activity.packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            activity.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEVISION)

    private fun visible(): Boolean = activity.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)

    private fun intents() = listOf(
        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${activity.packageName}")),
        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION),
    )

    private fun hasSettings(): Boolean = !settingsFailed && intents().any {
        try {
            activity.packageManager.resolveActivity(it, PackageManager.MATCH_DEFAULT_ONLY)
                ?.activityInfo?.exported == true
        } catch (_: RuntimeException) { false }
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> {
                val tv = isTv()
                val granted = tv && Settings.canDrawOverlays(activity)
                val settings = tv && hasSettings()
                result.success(mapOf(
                    "access" to if (granted) "granted" else if (settings) "settings" else "unavailable",
                    "canOpenSettings" to settings,
                    "running" to OverlayProbeService.running,
                    "result" to OverlayProbeService.outcome,
                ))
            }
            "openSettings" -> {
                if (!isTv() || !visible()) { result.success(false); return }
                // Try the actual launch too: resolver filtering must not block a valid route.
                for (intent in intents()) {
                    try {
                        activity.startActivity(intent)
                        settingsFailed = false
                        result.success(true)
                        return
                    } catch (_: RuntimeException) { /* Try the generic route. */ }
                }
                settingsFailed = true
                result.success(false)
            }
            "testPopup" -> {
                if (!isTv() || !visible() || !Settings.canDrawOverlays(activity)) {
                    result.success(false)
                    return
                }
                val keys = listOf("title", "message", "waiting", "channelName", "cancel")
                val text = keys.associateWith { call.argument<String>(it) ?: "" }
                if (text.values.any { it.isBlank() || it.length > 300 }) {
                    result.success(false)
                    return
                }
                result.success(OverlayProbeService.start(activity, text))
            }
            else -> result.notImplemented()
        }
    }
}
