package com.nox.nox_iptv

import org.junit.Assert.*
import org.junit.Test

class SportsAlarmPolicyTest {
    @Test fun remindersRemainExactAndPassedDeadlinesAreDroppedAtBoot() {
        assertEquals(2000L, SportsAlarmPolicy.deadline("reminder", 2000, 3000, 1000))
        assertNull(SportsAlarmPolicy.deadline("reminder", 2000, 3000, 2000))
        assertNull(SportsAlarmPolicy.deadline("reminder", 2000, 3000, 4000))
    }
    @Test fun liveGamesResumeAfterBootAndFutureGamesKeepTheirKickoff() {
        assertEquals(6000L, SportsAlarmPolicy.deadline("goals", 6000, 18000, 5000))
        assertEquals(6000L, SportsAlarmPolicy.deadline("goals", 2000, 18000, 5000))
        assertNull(SportsAlarmPolicy.deadline("goals", 2000, 18000, 18000))
    }
    @Test fun invalidSchedulesCannotStartAnything() {
        assertNull(SportsAlarmPolicy.deadline("goals", 0, 3000, 1000))
        assertNull(SportsAlarmPolicy.deadline("goals", 3000, 2000, 1000))
        assertNull(SportsAlarmPolicy.deadline("unknown", 2000, 3000, 1000))
    }
    @Test fun nativeDeliverySkipsVisibleAlreadySentAndExpiredReminders() {
        assertTrue(SportsAlarmPolicy.canDeliver(2001, 2000, 3000, false, false))
        assertFalse(SportsAlarmPolicy.canDeliver(2001, 2000, 3000, false, true))
        assertFalse(SportsAlarmPolicy.canDeliver(2001, 2000, 3000, true, false))
        assertFalse(SportsAlarmPolicy.canDeliver(1000, 2000, 3000, false, false))
        assertFalse(SportsAlarmPolicy.canDeliver(3000, 2000, 3000, false, false))
    }
    @Test fun serviceStopsOnForegroundNoGamesAndProlongedOffline() {
        assertEquals("foreground", SportsAlarmPolicy.stopReason(false, 2, null, 0))
        assertEquals("empty_or_hard_cap", SportsAlarmPolicy.stopReason(true, 0, null, 0))
        assertNull(SportsAlarmPolicy.stopReason(true, 2, 0, 599999))
        assertEquals("offline", SportsAlarmPolicy.stopReason(true, 2, 0, 600000))
        assertNull(SportsAlarmPolicy.stopReason(true, 2, null, 700000))
    }
    @Test fun lastMomentHideScoresCannotLeakTheRichBody() {
        assertEquals("Home scored!", SportsAlarmPolicy.goalText(true, "Scorer 2–1", "Home scored!"))
        assertEquals("Scorer 2–1", SportsAlarmPolicy.goalText(false, "Scorer 2–1", "Home scored!"))
    }
}
