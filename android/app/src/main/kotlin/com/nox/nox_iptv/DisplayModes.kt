package com.nox.nox_iptv

import android.app.Activity
import android.os.Build
import android.view.Display
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Settings > Interface > Display: Match frame rate / Match resolution (MethodChannel
 * "vespertv/display", Dart `DisplayMatch`). Asks for a display mode through the window's
 * `preferredDisplayModeId`, the API Fire OS and Android TV honour for this (TiviMate does the
 * same). Android drops the request when the app's window leaves the screen, so leaving the app
 * restores the TV's own mode by itself; `reset` hands it back while the app stays open.
 */
class DisplayModes(private val activity: Activity) {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(null)
            return
        }
        when (call.method) {
            "match" -> {
                val fps = call.argument<Double>("fps") ?: 0.0
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val rate = call.argument<Boolean>("rate") ?: false
                val only5060 = call.argument<Boolean>("only5060") ?: false
                val resolution = call.argument<Boolean>("resolution") ?: false
                activity.runOnUiThread {
                    result.success(match(fps, width, height, rate, only5060, resolution))
                }
            }
            "reset" -> activity.runOnUiThread {
                setPreferred(0)
                result.success(null)
            }
            "modes" -> activity.runOnUiThread {
                val display = display()
                result.success(display?.supportedModes?.map(::describe))
            }
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun display(): Display? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) activity.display
        else activity.windowManager.defaultDisplay

    /** The mode switched to ("3840x2160@50.00"), "same" when already right, null = no change. */
    private fun match(
        fps: Double, width: Int, height: Int,
        rate: Boolean, only5060: Boolean, resolution: Boolean,
    ): String? {
        val display = display() ?: return null
        val modes = display.supportedModes.toList()
        val current = display.mode
        val target = DisplayModePicker.pick(
            modes.map { DisplayModePicker.Mode(it.modeId, it.physicalWidth, it.physicalHeight, it.refreshRate.toDouble()) },
            DisplayModePicker.Mode(current.modeId, current.physicalWidth, current.physicalHeight, current.refreshRate.toDouble()),
            fps, width, height, rate, only5060, resolution,
        ) ?: return null
        if (target == current.modeId) return "same"
        setPreferred(target)
        return modes.firstOrNull { it.modeId == target }?.let(::describe)
    }

    private fun setPreferred(modeId: Int) {
        val window = activity.window ?: return
        val params = window.attributes
        if (params.preferredDisplayModeId == modeId) return
        params.preferredDisplayModeId = modeId
        window.attributes = params
    }

    private fun describe(mode: Display.Mode) =
        "${mode.physicalWidth}x${mode.physicalHeight}@${"%.2f".format(java.util.Locale.ROOT, mode.refreshRate)}"
}

/** The mode choice, kept free of Android types. */
object DisplayModePicker {
    data class Mode(val id: Int, val width: Int, val height: Int, val refresh: Double)

    // Broadcast / film rates a measured fps is snapped to (live TS rarely declares one, and a
    // measured 49.87 means 50).
    private val standardRates = doubleArrayOf(23.976, 24.0, 25.0, 29.97, 30.0, 50.0, 59.94, 60.0)

    fun snap(fps: Double): Double? {
        if (fps <= 0) return null
        val best = standardRates.minByOrNull { abs(it - fps) } ?: return null
        return if (abs(best - fps) <= 1.0) best else null
    }

    /**
     * [rate]: pick a refresh that is a whole multiple of the video's frame rate. [only5060]:
     * only switch between the 50 Hz and 60 Hz families (24p films stay on the current
     * refresh). [resolution]: the smallest mode that holds the video (else the largest).
     * Returns the mode id to ask for, or null to leave the display alone.
     */
    fun pick(
        modes: List<Mode>, current: Mode, fps: Double, width: Int, height: Int,
        rate: Boolean, only5060: Boolean, resolution: Boolean,
    ): Int? {
        if (modes.isEmpty() || (!rate && !resolution)) return null
        // 1. Size.
        val sizes = modes.map { it.width to it.height }.distinct()
        val size = if (resolution && width > 0 && height > 0) {
            sizes.filter { it.first >= width * 0.95 && it.second >= height * 0.95 }
                .minByOrNull { it.first * it.second }
                ?: sizes.maxByOrNull { it.first * it.second }!!
        } else {
            current.width to current.height
        }
        val atSize = modes.filter { it.width == size.first && it.height == size.second }
        if (atSize.isEmpty()) return null
        // 2. Refresh.
        val video = if (rate) snap(fps) else null
        val wanted: Double? = when {
            video == null -> null
            // Broadcast 25/30 fps (often de-interlaced 50i/60i) goes to 50/60 Hz like 50/60
            // fps: many TVs judder or flicker at 25/30 Hz. Films keep 24p unless only5060.
            video == 25.0 || video == 50.0 -> 50.0
            video == 29.97 || video == 59.94 -> 59.94
            video == 30.0 || video == 60.0 -> 60.0
            only5060 -> null // 24p: not a 50/60 switch
            else -> video // 23.976 / 24
        }
        val chosen = if (wanted == null) {
            atSize.minByOrNull { abs(it.refresh - current.refresh) }
        } else {
            atSize.filter { multipleOf(it.refresh, wanted) }
                // Lowest exact multiple first (50 over 100), then the closest.
                .minWithOrNull(compareBy<Mode> { (it.refresh / wanted).roundToInt() }
                    .thenBy { abs(it.refresh / (it.refresh / wanted).roundToInt() - wanted) })
                ?: if (resolution) atSize.minByOrNull { abs(it.refresh - current.refresh) } else null
        }
        return chosen?.id
    }

    private fun multipleOf(refresh: Double, fps: Double): Boolean {
        val k = (refresh / fps).roundToInt()
        if (k < 1 || k > 5) return false
        // 59.94 and 60 both count for a 59.94/60 video (a measured rate can't tell them apart),
        // and 23.976 vs 24 likewise: within 0.2 % per frame.
        return abs(refresh / k - fps) <= fps * 0.002 + 0.06
    }
}
