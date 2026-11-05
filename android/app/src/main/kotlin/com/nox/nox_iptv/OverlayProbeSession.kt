package com.nox.nox_iptv

/** Bounded one-shot timing, independent of an Activity, network or persistence. */
internal class OverlayProbeSession(
    private val schedule: (Long, () -> Unit) -> (() -> Unit),
    private val show: () -> Boolean,
    private val finish: () -> Unit,
) {
    private var started = false
    private var stopped = false
    private var cancel: (() -> Unit)? = null

    fun start() {
        if (started || stopped) return
        started = true
        cancel = schedule(10_000L) {
            if (!stopped) {
                val added = try { show() } catch (_: RuntimeException) { false }
                if (added) {
                    cancel = schedule(6_000L) { stop() }
                } else {
                    stop()
                }
            }
        }
    }

    fun stop() {
        if (stopped) return
        stopped = true
        cancel?.invoke()
        cancel = null
        finish()
    }
}
