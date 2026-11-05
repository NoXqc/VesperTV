package com.nox.nox_iptv

import org.junit.Assert.assertEquals
import org.junit.Test

class OverlayProbeSessionTest {
    private class Clock {
        data class Task(val at: Long, val run: () -> Unit, var cancelled: Boolean = false)
        private var now = 0L
        private val tasks = mutableListOf<Task>()
        fun schedule(delay: Long, run: () -> Unit): () -> Unit {
            val task = Task(now + delay, run)
            tasks.add(task)
            return { task.cancelled = true }
        }
        fun advance(ms: Long) {
            val end = now + ms
            while (true) {
                val next = tasks.filter { !it.cancelled && it.at <= end }.minByOrNull { it.at } ?: break
                tasks.remove(next)
                now = next.at
                next.run()
            }
            now = end
        }
    }

    @Test fun waitsTenSecondsAndFinishesSixSecondsAfterShowing() {
        val clock = Clock()
        var shows = 0
        var finishes = 0
        val probe = OverlayProbeSession(clock::schedule, { shows++; true }, { finishes++ })
        probe.start()
        clock.advance(9_999)
        assertEquals(0, shows)
        clock.advance(1)
        assertEquals(1, shows)
        clock.advance(5_999)
        assertEquals(0, finishes)
        clock.advance(1)
        assertEquals(1, finishes)
        clock.advance(60_000)
        assertEquals(1, shows)
        assertEquals(1, finishes)
    }

    @Test fun repeatedStartsDoNotExtendTheDeadline() {
        val clock = Clock()
        var shows = 0
        var finishes = 0
        val probe = OverlayProbeSession(clock::schedule, { shows++; true }, { finishes++ })
        probe.start()
        clock.advance(5_000)
        probe.start()
        clock.advance(5_000)
        assertEquals(1, shows)
        probe.start()
        clock.advance(6_000)
        assertEquals(1, finishes)
    }

    @Test fun stoppingDuringWaitNeverShowsAndFinishesOnce() {
        val clock = Clock()
        var shows = 0
        var finishes = 0
        val probe = OverlayProbeSession(clock::schedule, { shows++; true }, { finishes++ })
        probe.start()
        clock.advance(3_000)
        probe.stop()
        probe.stop()
        probe.start()
        clock.advance(60_000)
        assertEquals(0, shows)
        assertEquals(1, finishes)
    }

    @Test fun stoppingVisibleCardFinishesImmediatelyAndOnlyOnce() {
        val clock = Clock()
        var finishes = 0
        val probe = OverlayProbeSession(clock::schedule, { true }, { finishes++ })
        probe.start()
        clock.advance(10_000)
        probe.stop()
        assertEquals(1, finishes)
        clock.advance(60_000)
        assertEquals(1, finishes)
    }

    @Test fun revokedAccessOrFailedWindowStopsAtTheShowAttempt() {
        val clock = Clock()
        var finishes = 0
        val probe = OverlayProbeSession(clock::schedule, { false }, { finishes++ })
        probe.start()
        clock.advance(10_000)
        assertEquals(1, finishes)
        clock.advance(60_000)
        assertEquals(1, finishes)
    }

    @Test fun unexpectedWindowExceptionStillCleansUp() {
        val clock = Clock()
        var finishes = 0
        val probe = OverlayProbeSession(clock::schedule,
            { throw SecurityException("revoked") }, { finishes++ })
        probe.start()
        clock.advance(10_000)
        assertEquals(1, finishes)
    }

    @Test fun stopBeforeStartCannotScheduleAWindow() {
        val clock = Clock()
        var shows = 0
        var finishes = 0
        val probe = OverlayProbeSession(clock::schedule, { shows++; true }, { finishes++ })
        probe.stop()
        probe.start()
        clock.advance(60_000)
        assertEquals(0, shows)
        assertEquals(1, finishes)
    }
}
