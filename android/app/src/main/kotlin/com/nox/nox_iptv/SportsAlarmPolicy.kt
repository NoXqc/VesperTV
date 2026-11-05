package com.nox.nox_iptv

/** Shared scheduling/expiry rules, independent of Android framework stubs. */
object SportsAlarmPolicy {
    fun deadline(kind: String, at: Long, end: Long, now: Long): Long? {
        if (end <= now || at <= 0 || end <= at) return null
        if (kind == "reminder") return if (at > now) at else null
        return if (kind == "goals") maxOf(at, now + 1000) else null
    }
    fun goalText(hide: Boolean, text: String, hidden: String) = if (hide) hidden else text
    fun stopReason(allowed: Boolean, active: Int, offlineAt: Long?, now: Long): String? = when {
        !allowed -> "foreground"
        active == 0 -> "empty_or_hard_cap"
        offlineAt != null && now - offlineAt >= 10 * 60 * 1000L -> "offline"
        else -> null
    }
    fun canDeliver(now: Long, at: Long, end: Long, alreadySent: Boolean, visible: Boolean) =
        !alreadySent && !visible && now >= at && now < end
}
