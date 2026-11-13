package com.nox.nox_iptv

import android.accessibilityservice.AccessibilityService
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import android.view.ViewConfiguration
import android.view.accessibility.AccessibilityEvent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * Android Settings > Accessibility > "VesperTV remote buttons" (owner, 2026-11-12). Some
 * boxes' firmware takes remote buttons before any app sees them: on the Homatics the TV
 * button (KEYCODE_GUIDE) is a "global key" that com.nes.tvglobalkeyhandler takes ("function
 * is on developing"), and YouTube / Prime / the app button / Settings open their apps. An
 * accessibility service that filters key events is asked first (tested on the Homatics,
 * +750: all of those arrive here; Netflix doesn't, Android's window manager handles it
 * before any filter).
 *
 * While VesperTV is on screen this takes the Guide key, the buttons the viewer set in
 * Settings > Remote buttons ([taken], from Dart) and, while that screen waits for a button
 * ([learning]), any button that isn't system or navigation ([never]); it hands them to
 * VesperTV's activity. Everything else, and everything while another app is on screen,
 * passes through untouched. A button taken going down is taken coming up too: the firmware
 * runs its action on the release. Taken keys get no repeats from Android, so a held one gets
 * them here (the hold actions of Settings > Remote buttons are made of them).
 */
class RemoteKeyService : AccessibilityService() {
    companion object {
        private const val TAG = "VesperRemoteKeys"

        /** VesperTV's activity while it is on screen (MainActivity onResume / onPause). */
        @Volatile
        var onScreen: WeakReference<MainActivity>? = null

        /** Android key codes of the viewer's buttons (Dart, `vespertv/remote_keys`). */
        @Volatile
        var taken: Set<Int> = emptySet()

        /** Settings > Remote buttons is waiting for a button. */
        @Volatile
        var learning = false

        /** The service is running (enabled and allowed). */
        @Volatile
        var connected = false
            private set

        /** `vespertv/remote_keys`, from Settings > Remote buttons (RemoteKeys in Dart). */
        fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
            when (call.method) {
                "setTaken" -> {
                    taken = (call.arguments as? List<*>)
                        ?.mapNotNull { (it as? Number)?.toInt() }?.toSet() ?: emptySet()
                    result.success(null)
                }
                "setLearning" -> {
                    learning = call.arguments == true
                    result.success(null)
                }
                "status" -> result.success(
                    mapOf("enabled" to enabled(activity), "connected" to connected)
                )
                "openSettings" -> result.success(
                    open(activity, Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                )
                // Android 13+ blocks a sideloaded app's service ("restricted setting"):
                // App info is where it's allowed.
                "openAppInfo" -> result.success(
                    open(
                        activity,
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            .setData(Uri.fromParts("package", activity.packageName, null))
                    )
                )
                else -> result.notImplemented()
            }
        }

        private fun open(activity: Activity, intent: Intent): Boolean = try {
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }

        /** Switched on in Android's Accessibility settings (it may still be blocked). */
        fun enabled(context: Context): Boolean {
            val list = Settings.Secure.getString(
                context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            val me = ComponentName(context, RemoteKeyService::class.java)
            return list.split(':').any { ComponentName.unflattenFromString(it) == me }
        }

        private val never = setOf(
            KeyEvent.KEYCODE_HOME, KeyEvent.KEYCODE_POWER, KeyEvent.KEYCODE_SLEEP,
            KeyEvent.KEYCODE_SOFT_SLEEP, KeyEvent.KEYCODE_WAKEUP,
            KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_VOLUME_DOWN,
            KeyEvent.KEYCODE_VOLUME_MUTE, KeyEvent.KEYCODE_MUTE,
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN, KeyEvent.KEYCODE_DPAD_LEFT,
            KeyEvent.KEYCODE_DPAD_RIGHT, KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_NUMPAD_ENTER, KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE,
            KeyEvent.KEYCODE_BUTTON_A, KeyEvent.KEYCODE_BUTTON_B,
            KeyEvent.KEYCODE_VOICE_ASSIST, KeyEvent.KEYCODE_ASSIST, KeyEvent.KEYCODE_SEARCH,
        )
    }

    private val main = Handler(Looper.getMainLooper())

    /** Taken keys still held: their repeat timers. */
    private val held = HashMap<Int, Runnable>()

    override fun onServiceConnected() {
        connected = true
    }

    override fun onUnbind(intent: Intent?): Boolean {
        connected = false
        release()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        connected = false
        release()
        super.onDestroy()
    }

    private fun release() {
        held.values.forEach(main::removeCallbacks)
        held.clear()
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        val code = event.keyCode
        if (event.action == KeyEvent.ACTION_UP) {
            val repeat = held.remove(code) ?: return false
            main.removeCallbacks(repeat)
            deliver(KeyEvent(event))
            return true
        }
        if (event.action != KeyEvent.ACTION_DOWN) return false
        if (held.containsKey(code)) return true
        if (onScreen?.get() == null || code in never) return false
        if (code != KeyEvent.KEYCODE_GUIDE && code !in taken && !learning) return false
        Log.i(TAG, "took ${KeyEvent.keyCodeToString(code)} ($code)")
        val down = KeyEvent(event)
        if (!deliver(down)) return false
        var count = 0
        val repeat = object : Runnable {
            override fun run() {
                count++
                deliver(KeyEvent.changeTimeRepeat(down, SystemClock.uptimeMillis(), count))
                main.postDelayed(this, ViewConfiguration.getKeyRepeatDelay().toLong())
            }
        }
        held[code] = repeat
        main.postDelayed(repeat, ViewConfiguration.getKeyRepeatTimeout().toLong())
        return true
    }

    /** Hands [event] to VesperTV; false when it isn't on screen any more. */
    private fun deliver(event: KeyEvent): Boolean {
        val activity = onScreen?.get() ?: return false
        main.post { activity.dispatchKeyEvent(event) }
        return true
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}
}
