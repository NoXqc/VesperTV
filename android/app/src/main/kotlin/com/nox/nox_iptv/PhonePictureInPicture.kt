package com.nox.nox_iptv

import android.app.Activity
import android.app.PictureInPictureParams
import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Rect
import android.os.Build
import android.util.Rational
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Phone fullscreen playback only. No permission request and no TV auto-entry. */
class PhonePictureInPicture(private val activity: Activity) {
    private var channel: MethodChannel? = null
    private var enabled = false
    private var aspect = Rational(16, 9)
    private val supported: Boolean
        get() {
            val mode = activity.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
            val pm = activity.packageManager
            return Build.VERSION.SDK_INT >= 26 &&
                pm.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE) &&
                mode.currentModeType != Configuration.UI_MODE_TYPE_TELEVISION &&
                !pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK) &&
                !pm.hasSystemFeature(PackageManager.FEATURE_TELEVISION)
        }

    fun connect(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "vespertv/phone_pip").also { bridge ->
            bridge.setMethodCallHandler { call, result ->
                if (call.method != "configure") {
                    result.notImplemented()
                } else {
                    enabled = supported && call.argument<Boolean>("enabled") == true
                    val ratio = call.argument<Number>("aspect")?.toDouble() ?: (16.0 / 9)
                    // Android rejects ratios outside [1/2.39, 2.39].
                    val safe = if (ratio.isFinite()) ratio.coerceIn(1.0 / 2.39, 2.39) else 16.0 / 9
                    aspect = Rational((safe * 10000).toInt(), 10000)
                    if (supported) {
                        try {
                            activity.setPictureInPictureParams(params())
                        } catch (_: IllegalArgumentException) {
                            enabled = false
                        } catch (_: IllegalStateException) {
                            enabled = false
                        }
                    }
                    result.success(null)
                }
            }
        }
    }

    private fun params(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder().setAspectRatio(aspect)
        val bounds = Rect()
        activity.window.decorView.getGlobalVisibleRect(bounds)
        if (!bounds.isEmpty) builder.setSourceRectHint(bounds)
        if (Build.VERSION.SDK_INT >= 31) builder.setAutoEnterEnabled(enabled)
        return builder.build()
    }

    fun onUserLeaveHint() {
        if (!enabled || !supported || Build.VERSION.SDK_INT >= 31) return
        try {
            activity.enterPictureInPictureMode(params())
        } catch (_: IllegalStateException) {
            // User/device may disallow PiP. Continue normal background behavior.
        } catch (_: IllegalArgumentException) {
            // Some vendor firmware rejects otherwise valid PiP parameters.
        }
    }

    fun onModeChanged(active: Boolean) {
        channel?.invokeMethod("modeChanged", active)
    }

    fun onStop() {
        // A visible PiP activity pauses, but does not stop. Closing its window
        // stops it: pause playback instead of leaving invisible audio running.
        channel?.invokeMethod("stopped", null)
    }
}
