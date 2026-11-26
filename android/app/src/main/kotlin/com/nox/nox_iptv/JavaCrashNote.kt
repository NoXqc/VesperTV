package com.nox.nox_iptv

import android.content.Context
import java.io.File
import kotlin.math.abs

/**
 * Android keeps no stack trace for a Java crash (ApplicationExitInfo has one for not-responding
 * and native crashes only), so Send log's "crash (java)" line couldn't say where (cillfog,
 * LOG-PESV4J, 2026-11-26). The process's default handler writes the crashing thread and the top
 * of the trace to a small file just before the process dies, then hands over to Android's own
 * handler as before; the next Send log prints it under that exit ([MainActivity.lastExits]).
 */
internal object JavaCrashNote {
    private const val FILE = "vespertv_java_crash.txt"

    /** Trace lines kept (with "Caused by" chains, enough to see the culprit). */
    const val MAX_LINES = 24

    /** An exit and the note written for it are at most this far apart. */
    const val MATCH_MS = 60_000L

    fun install(context: Context) {
        val file = File(context.filesDir, FILE)
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                file.writeText(format(System.currentTimeMillis(), thread.name, error))
            } catch (_: Throwable) {
                // Never stand between the crash and Android's handler.
            }
            previous?.uncaughtException(thread, error)
        }
    }

    /**
     * First line = when, second = the thread, then each exception of the chain with its first
     * frames (the root cause is often the last one: a plain capped trace lost it), capped at
     * [MAX_LINES], addresses removed.
     */
    fun format(atMs: Long, threadName: String, error: Throwable): String {
        val trace = mutableListOf<String>()
        val seen = HashSet<Throwable>()
        var t: Throwable? = error
        while (t != null && seen.add(t) && trace.size < MAX_LINES) {
            trace += (if (t === error) "" else "Caused by: ") + t.toString()
            t.stackTrace.take(if (t === error) 8 else 5).forEach { trace += "    at $it" }
            t = t.cause
        }
        val lines = trace.take(MAX_LINES)
            // An exception message can carry a stream link with the account in it.
            .map { it.replace(Regex("""\b\w+://\S+"""), "<url>") }
        return (listOf(atMs.toString(), "thread $threadName") + lines).joinToString("\n")
    }

    /** Send log lines for a "crash (java)" exit at [exitMs], from this device's note. */
    fun linesFor(context: Context, exitMs: Long): List<String> = try {
        val file = File(context.filesDir, FILE)
        linesFrom(if (file.isFile) file.readText() else null, exitMs)
    } catch (_: Exception) {
        emptyList()
    }

    /** [note] as written by [format]: its lines, indented, when it belongs to [exitMs]. */
    fun linesFrom(note: String?, exitMs: Long): List<String> {
        if (note.isNullOrBlank()) return listOf("  (no trace kept)")
        val lines = note.lines()
        val at = lines.first().trim().toLongOrNull() ?: return listOf("  (no trace kept)")
        if (abs(exitMs - at) > MATCH_MS) return listOf("  (no trace kept)")
        return lines.drop(1).filter { it.isNotBlank() }.map { "  $it" }
    }
}
