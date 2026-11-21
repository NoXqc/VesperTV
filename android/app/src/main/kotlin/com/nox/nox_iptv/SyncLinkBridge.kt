package com.nox.nox_iptv

import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Sync > Link a device shows a QR with https://pair.vespertv.app/sync#<16-digit
 * code>; a phone's camera opens VesperTV with it (an App Link), or that page's
 * "Open VesperTV" button with vespertv://sync?c=<code>. The code waits here
 * until Dart takes it (`vespertv/sync_link`: "has", "take"; "link" says one arrived
 * while the app runs). Dart opens the join screen with the code filled in and
 * asks before joining (lib/services/sync_link.dart).
 */
class SyncLinkBridge {
    private var channel: MethodChannel? = null
    private var pending: String? = null

    fun connect(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "vespertv/sync_link").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "has" -> result.success(pending != null)
                    "take" -> {
                        result.success(pending)
                        pending = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun onIntent(intent: Intent?) {
        val data = intent?.data ?: return
        val code = codeOf(data) ?: return
        pending = code
        // Once: recreating the activity must not open the join screen again.
        intent.data = null
        channel?.invokeMethod("link", null)
    }

    companion object {
        /** The 16 digits of a sync link, else null. */
        fun codeOf(uri: Uri): String? {
            val web = uri.scheme == "https" && uri.host == "pair.vespertv.app" &&
                (uri.path ?: "").trimEnd('/') == "/sync"
            val app = uri.scheme == "vespertv" && uri.host == "sync"
            if (!web && !app) return null
            val raw = (if (web) uri.fragment else uri.getQueryParameter("c")) ?: return null
            val digits = raw.filter { it.isDigit() }
            return if (digits.length == 16) digits else null
        }
    }
}
