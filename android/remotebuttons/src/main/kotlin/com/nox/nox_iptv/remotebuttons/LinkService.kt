package com.nox.nox_iptv.remotebuttons

import android.app.Service
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.os.RemoteException

/**
 * The add-on's side of the link with VesperTV (VesperTV's RemoteKeysLink.kt has the same
 * message numbers). VesperTV binds this service (signature permission: only apps signed with
 * VesperTV's key) and sends [HELLO] with its own Messenger, then [STATE] whenever it comes on
 * or leaves the screen and when Settings > Remote buttons changes the buttons it takes. The
 * accessibility service ([RemoteKeyService], same process) reads [Link] and hands the keys it
 * takes to VesperTV as [KEY]; [STATUS] tells VesperTV whether that service is running.
 */
class LinkService : Service() {
    companion object {
        const val HELLO = 1
        const val STATE = 2
        const val KEY = 3
        const val STATUS = 4
    }

    private val messenger = Messenger(Handler(Looper.getMainLooper()) { m ->
        when (m.what) {
            HELLO -> {
                Link.client = m.replyTo
                Link.pushStatus()
            }
            STATE -> {
                Link.onScreen = m.arg1 == 1
                Link.learning = m.arg2 == 1
                Link.taken = m.data?.getIntArray("taken")?.toSet() ?: emptySet()
            }
        }
        true
    })

    override fun onBind(intent: Intent?): IBinder = messenger.binder

    override fun onUnbind(intent: Intent?): Boolean {
        Link.client = null
        Link.onScreen = false
        return false
    }
}

/** What VesperTV last told the add-on, and the way back to it. */
object Link {
    @Volatile
    var client: Messenger? = null

    /** VesperTV's activity is on screen (resumed). */
    @Volatile
    var onScreen = false

    /** Android key codes of the viewer's buttons (Settings > Remote buttons). */
    @Volatile
    var taken: Set<Int> = emptySet()

    /** Settings > Remote buttons is waiting for a button. */
    @Volatile
    var learning = false

    /** The accessibility service is running (enabled and allowed). */
    @Volatile
    var connected = false

    fun send(message: Message): Boolean {
        val to = client ?: return false
        return try {
            to.send(message)
            true
        } catch (_: RemoteException) {
            client = null
            onScreen = false
            false
        }
    }

    fun pushStatus() {
        send(Message.obtain(null, LinkService.STATUS, if (connected) 1 else 0, 0))
    }
}
