package com.nox.nox_iptv

/** A foreground visit permanently invalidates a running worker's lease. */
class EpisodeWorkGate {
    @Volatile var foreground = false
        private set
    private var generation = 0L
    private var owner: Long? = null

    @Synchronized fun setVisible(visible: Boolean) {
        foreground = visible
        if (visible) generation++
    }
    @Synchronized fun acquire(): Long? {
        if (foreground || owner != null) return null
        val token = ++generation
        owner = token
        return token
    }
    @Synchronized fun allowed(token: Long?) =
        token != null && owner == token && generation == token && !foreground
    @Synchronized fun release(token: Long?) {
        if (owner == token) owner = null
    }
}
