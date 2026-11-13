package com.nox.nox_iptv

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.engine.FlutterEngine

/**
 * Flutter builds its accessibility (semantics) tree on every frame as soon as ANY
 * accessibility service is on. On TV boxes those are usually key filters: VesperTV's own
 * Remote buttons (RemoteKeyService) and launchers such as Monet. They never read the
 * screen, yet the tree cost 50-110 ms per heavy frame on the Homatics (2026-11-13 trace:
 * the glide to full screen and back). When no enabled service can retrieve window content,
 * the tree is turned off; a screen reader (TalkBack, Select to Speak...) turns it back on.
 *
 * Flutter's AccessibilityBridge switches it on when the view attaches and on every
 * accessibility state change, so this runs after those (posted to the main looper).
 */
class SemanticsGate(private val context: Context, private val engine: () -> FlutterEngine?) {
    private val handler = Handler(Looper.getMainLooper())
    private val manager =
        context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
    private var lastOff: Boolean? = null

    private val stateListener =
        AccessibilityManager.AccessibilityStateChangeListener { schedule() }
    private val servicesListener: Any? =
        if (Build.VERSION.SDK_INT >= 33) {
            AccessibilityManager.AccessibilityServicesStateChangeListener { schedule() }
        } else {
            null
        }

    fun start() {
        manager.addAccessibilityStateChangeListener(stateListener)
        if (Build.VERSION.SDK_INT >= 33) {
            manager.addAccessibilityServicesStateChangeListener(
                servicesListener as AccessibilityManager.AccessibilityServicesStateChangeListener
            )
        }
        schedule()
    }

    fun stop() {
        handler.removeCallbacksAndMessages(null)
        manager.removeAccessibilityStateChangeListener(stateListener)
        if (Build.VERSION.SDK_INT >= 33) {
            manager.removeAccessibilityServicesStateChangeListener(
                servicesListener as AccessibilityManager.AccessibilityServicesStateChangeListener
            )
        }
    }

    /** Also from onResume: services can change while the app is in the background. */
    fun schedule() {
        handler.removeCallbacksAndMessages(null)
        // After the bridge's own listener (it may have just switched the tree on).
        handler.post { apply() }
    }

    private fun apply() {
        val channel = engine()?.accessibilityChannel ?: return
        if (!manager.isEnabled) {
            lastOff = null // the bridge already turned the tree off
            return
        }
        val services = try {
            manager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        } catch (_: Exception) {
            return
        }
        val readsScreen = manager.isTouchExplorationEnabled || services.any {
            it.capabilities and AccessibilityServiceInfo.CAPABILITY_CAN_RETRIEVE_WINDOW_CONTENT != 0
        }
        if (readsScreen) {
            channel.onAndroidAccessibilityEnabled()
        } else {
            channel.onAndroidAccessibilityDisabled()
        }
        val off = !readsScreen
        if (off != lastOff) {
            lastOff = off
            val names = services.joinToString { it.resolveInfo?.serviceInfo?.name?.substringAfterLast('.') ?: "?" }
            Log.i("VesperSemantics", "${if (off) "off" else "on"} (services: $names)")
        }
    }
}
