package com.nox.nox_iptv.remotebuttons

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.os.SystemClock
import android.util.Log
import android.view.KeyEvent
import android.view.ViewConfiguration
import android.view.accessibility.AccessibilityEvent

/**
 * Android Settings > Accessibility > "VesperTV remote buttons" (owner, 2026-11-12; its own
 * add-on app since 2026-11-24: Play Protect blocks a sideloaded app that declares an
 * accessibility service, so VesperTV can't carry it). Some boxes' firmware takes remote
 * buttons before any app sees them: on the Homatics the TV button (KEYCODE_GUIDE) is a
 * "global key" that com.nes.tvglobalkeyhandler takes, and YouTube / Prime / the app button /
 * Settings open their apps. An accessibility service that filters key events is asked first
 * (tested on the Homatics, +750: all of those arrive here; Netflix doesn't, Android's window
 * manager handles it before any filter).
 *
 * While VesperTV is on screen ([Link.onScreen], from VesperTV over [LinkService]) this takes
 * the Guide key, the buttons the viewer set in Settings > Remote buttons ([Link.taken]) and,
 * while that screen waits for a button ([Link.learning]), any button that isn't system or
 * navigation ([never]); it hands them to VesperTV over the link. Everything else, and
 * everything while another app is on screen, passes through untouched. A button taken going
 * down is taken coming up too: the firmware runs its action on the release. Taken keys get no
 * repeats from Android, so a held one gets them here (the hold actions of Settings > Remote
 * buttons are made of them).
 */
class RemoteKeyService : AccessibilityService() {
    companion object {
        private const val TAG = "VesperRemoteKeys"

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
        Link.connected = true
        Link.pushStatus()
    }

    override fun onUnbind(intent: Intent?): Boolean {
        Link.connected = false
        Link.pushStatus()
        release()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        Link.connected = false
        Link.pushStatus()
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
        if (!Link.onScreen || code in never) return false
        if (code != KeyEvent.KEYCODE_GUIDE && code !in Link.taken && !Link.learning) return false
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
        if (!Link.onScreen) return false
        return Link.send(Message.obtain(null, LinkService.KEY).apply { obj = event })
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}
}
