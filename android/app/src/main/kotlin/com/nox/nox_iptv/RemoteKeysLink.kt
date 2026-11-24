package com.nox.nox_iptv

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.os.RemoteException
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * Settings > Remote buttons > "Buttons your box keeps" (owner, 2026-11-12). The accessibility
 * service that catches the buttons a box's firmware keeps (TV, YouTube, Prime...) lives in the
 * separate "VesperTV remote buttons" add-on since 2026-11-24 (android/remotebuttons): Play
 * Protect blocks a sideloaded app that declares an accessibility service outright ("App blocked
 * to protect your device", no Install anyway; See61 on Reddit, Homatics R Plus), so VesperTV
 * must not declare one.
 *
 * This binds the add-on's LinkService (signature permission: same key) and keeps it told
 * whether VesperTV is on screen, which buttons the viewer set ([taken]) and whether Settings is
 * learning one; the add-on sends the keys it takes back, and they go to [MainActivity] as if
 * the remote had sent them. Message numbers = the add-on's LinkService.
 */
object RemoteKeysLink {
    private const val TAG = "VesperRemoteKeys"
    const val ADDON = "com.nox.nox_iptv.remotebuttons"
    private val linkComponent = ComponentName(ADDON, "$ADDON.LinkService")
    private val serviceComponent = ComponentName(ADDON, "$ADDON.RemoteKeyService")

    private const val HELLO = 1
    private const val STATE = 2
    private const val KEY = 3
    private const val STATUS = 4

    /** VesperTV's activity while it is on screen (MainActivity onResume / onPause). */
    private var onScreen: WeakReference<MainActivity>? = null
    private var taken: IntArray = IntArray(0)
    private var learning = false

    private var remote: Messenger? = null
    private var bound = false

    /** The add-on's accessibility service is running (it says so over the link). */
    private var connected = false

    private val incoming = Messenger(Handler(Looper.getMainLooper()) { m ->
        when (m.what) {
            KEY -> (m.obj as? KeyEvent)?.let { event ->
                onScreen?.get()?.dispatchKeyEvent(event)
            }
            STATUS -> connected = m.arg1 == 1
        }
        true
    })

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            remote = Messenger(service)
            send(Message.obtain(null, HELLO).apply { replyTo = incoming })
            pushState()
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            remote = null
            connected = false
        }

        // The add-on was updated or removed: bind again on the next resume.
        override fun onBindingDied(name: ComponentName?) {
            remote = null
            connected = false
            unbind(appContext ?: return)
        }

        override fun onNullBinding(name: ComponentName?) {
            unbind(appContext ?: return)
        }
    }

    private var appContext: Context? = null

    fun onResume(activity: MainActivity) {
        onScreen = WeakReference(activity)
        bind(activity.applicationContext)
        pushState()
    }

    fun onPause(activity: MainActivity) {
        if (onScreen?.get() === activity) onScreen = null
        pushState()
    }

    /** Binds the add-on when it's installed; a no-op when bound or missing. */
    private fun bind(context: Context) {
        if (bound) return
        appContext = context
        if (!installed(context)) return
        bound = try {
            context.bindService(
                Intent().setComponent(linkComponent), connection, Context.BIND_AUTO_CREATE
            )
        } catch (e: SecurityException) {
            // Not signed with VesperTV's key (a debug build, or someone else's add-on).
            Log.w(TAG, "add-on refused the link: ${e.message}")
            false
        }
        if (!bound) {
            try {
                context.unbindService(connection)
            } catch (_: Exception) {
            }
        }
    }

    private fun unbind(context: Context) {
        if (!bound) return
        bound = false
        try {
            context.unbindService(connection)
        } catch (_: Exception) {
        }
    }

    private fun send(message: Message) {
        val to = remote ?: return
        try {
            to.send(message)
        } catch (_: RemoteException) {
            remote = null
            connected = false
        }
    }

    private fun pushState() {
        send(
            Message.obtain(
                null, STATE, if (onScreen?.get() != null) 1 else 0, if (learning) 1 else 0
            ).apply { data = Bundle().apply { putIntArray("taken", taken) } }
        )
    }

    /** `vespertv/remote_keys`, from Settings > Remote buttons (RemoteKeys in Dart). */
    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setTaken" -> {
                taken = (call.arguments as? List<*>)
                    ?.mapNotNull { (it as? Number)?.toInt() }?.toIntArray() ?: IntArray(0)
                pushState()
                result.success(null)
            }
            "setLearning" -> {
                learning = call.arguments == true
                pushState()
                result.success(null)
            }
            "status" -> {
                val context = activity.applicationContext
                val installed = installed(context)
                if (installed) bind(context)
                result.success(
                    mapOf(
                        "installed" to installed,
                        "enabled" to (installed && enabled(context)),
                        "connected" to (installed && connected),
                    )
                )
            }
            "openSettings" -> result.success(
                open(activity, Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            )
            // Android 13+ blocks a sideloaded app's service ("restricted setting"): the
            // add-on's App info is where it's allowed.
            "openAppInfo" -> result.success(
                open(
                    activity,
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.fromParts("package", ADDON, null))
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

    private fun installed(context: Context): Boolean = try {
        context.packageManager.getPackageInfo(ADDON, 0)
        true
    } catch (_: Exception) {
        false
    }

    /** Switched on in Android's Accessibility settings (it may still be blocked). */
    private fun enabled(context: Context): Boolean {
        val list = Settings.Secure.getString(
            context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return list.split(':').any { ComponentName.unflattenFromString(it) == serviceComponent }
    }
}
