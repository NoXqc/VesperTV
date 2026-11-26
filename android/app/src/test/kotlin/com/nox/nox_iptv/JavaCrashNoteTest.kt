package com.nox.nox_iptv

import org.junit.Assert.*
import org.junit.Test

/** Send log names a Java crash's thread and trace (cillfog, LOG-PESV4J). */
class JavaCrashNoteTest {
    private fun crash(): Throwable = try {
        try {
            throw NullPointerException("input stream gone")
        } catch (e: NullPointerException) {
            throw IllegalStateException("read failed for http://user:pass@host/live/1.ts", e)
        }
    } catch (e: IllegalStateException) {
        e
    }

    @Test fun theNoteForThatExitIsShown() {
        val note = JavaCrashNote.format(1_000_000L, "vesper-timeshift", crash())
        val lines = JavaCrashNote.linesFrom(note, 1_000_500L)
        assertEquals("  thread vesper-timeshift", lines.first())
        assertTrue(lines[1].contains("IllegalStateException"))
        assertTrue("the cause comes along", lines.any { it.contains("Caused by") })
        assertTrue(lines.size <= JavaCrashNote.MAX_LINES + 1)
    }

    @Test fun addressesAreRemoved() {
        val note = JavaCrashNote.format(1L, "main", crash())
        assertFalse(note.contains("user:pass"))
        assertTrue(note.contains("<url>"))
    }

    @Test fun anOlderNoteIsNotThisExitsOne() {
        val note = JavaCrashNote.format(1_000_000L, "main", crash())
        val far = 1_000_000L + JavaCrashNote.MATCH_MS + 1
        assertEquals(listOf("  (no trace kept)"), JavaCrashNote.linesFrom(note, far))
        assertEquals(listOf("  (no trace kept)"), JavaCrashNote.linesFrom(null, 5L))
        assertEquals(listOf("  (no trace kept)"), JavaCrashNote.linesFrom("garbage", 5L))
    }
}
