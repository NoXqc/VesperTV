package com.nox.nox_iptv

/**
 * Send log: where a native crash happened. Android 12+ keeps the crash report of each recent
 * native crash (`ApplicationExitInfo.getTraceInputStream`, a tombstone in protobuf:
 * system/core/debuggerd/proto/tombstone.proto) and only the app itself can read it. "crash
 * (native)" alone told us nothing (GitHub #23: Google TV Streamer, 5 crashes in the guide on
 * 1.0.74-dev.1013, no clue which code).
 *
 * A few lines per crash: the signal, the crash cause / abort message, the crashing thread with
 * its first frames (library + function) and the crashed process's last log lines. No protobuf
 * library: a small reader for the handful of fields used. When the fields aren't where this
 * expects (another Android version), the readable strings that name a library are listed
 * instead, so a log still says something.
 */
internal object TombstoneSummary {
    const val MAX_FRAMES = 14
    const val MAX_LOG_LINES = 12
    private const val MAX_TEXT = 300

    private class Field(val number: Int, val value: Long, val bytes: ByteArray?)

    private fun read(data: ByteArray): List<Field> {
        val out = ArrayList<Field>()
        var i = 0
        fun varint(): Long {
            var result = 0L
            var shift = 0
            while (true) {
                require(i < data.size && shift < 64) { "truncated" }
                val b = data[i++].toInt() and 0xff
                result = result or ((b and 0x7f).toLong() shl shift)
                if (b and 0x80 == 0) return result
                shift += 7
            }
        }
        while (i < data.size) {
            val key = varint()
            val number = (key ushr 3).toInt()
            when ((key and 7).toInt()) {
                0 -> out += Field(number, varint(), null)
                1 -> {
                    require(i + 8 <= data.size) { "truncated" }
                    i += 8
                }
                2 -> {
                    val length = varint()
                    require(length >= 0 && i + length <= data.size) { "truncated" }
                    out += Field(number, 0, data.copyOfRange(i, i + length.toInt()))
                    i += length.toInt()
                }
                5 -> {
                    require(i + 4 <= data.size) { "truncated" }
                    i += 4
                }
                else -> throw IllegalArgumentException("wire type")
            }
        }
        return out
    }

    private fun List<Field>.text(number: Int): String? =
        firstOrNull { it.number == number && it.bytes != null }?.bytes?.let {
            String(it, Charsets.UTF_8)
        }

    private fun List<Field>.number(number: Int): Long? =
        firstOrNull { it.number == number && it.bytes == null }?.value

    private fun List<Field>.messages(number: Int): List<List<Field>> =
        filter { it.number == number && it.bytes != null }.mapNotNull {
            try {
                read(it.bytes!!)
            } catch (_: Exception) {
                null
            }
        }

    private fun clip(s: String): String =
        s.replace('\n', ' ').trim().let { if (it.length > MAX_TEXT) it.take(MAX_TEXT) + "…" else it }

    /** The lines for one tombstone (each starts with two spaces, under its "Last exits" line). */
    fun summarize(data: ByteArray): List<String> {
        val lines = ArrayList<String>()
        try {
            val top = read(data)
            val tid = top.number(6)
            top.messages(10).firstOrNull()?.let { signal ->
                val name = signal.text(2) ?: "signal ${signal.number(1) ?: "?"}"
                val code = signal.text(4)?.let { " ($it)" } ?: ""
                val fault = if (signal.number(8) == 1L) {
                    " fault 0x" + java.lang.Long.toHexString(signal.number(9) ?: 0)
                } else ""
                lines += "  $name$code$fault"
            }
            top.text(14)?.takeIf { it.isNotBlank() }?.let { lines += "  abort: ${clip(it)}" }
            for (cause in top.messages(15).take(2)) {
                cause.text(1)?.takeIf { it.isNotBlank() }?.let { lines += "  cause: ${clip(it)}" }
            }
            val threads = top.messages(16).mapNotNull { entry ->
                val thread = entry.messages(2).firstOrNull() ?: return@mapNotNull null
                (entry.number(1) ?: thread.number(1)) to thread
            }
            val crashed = threads.firstOrNull { it.first == tid }?.second
            if (crashed != null) {
                lines += "  thread ${crashed.text(2) ?: "?"} (${tid ?: "?"}), " +
                    "${threads.size} threads"
                crashed.messages(4).take(MAX_FRAMES).forEachIndexed { i, frame ->
                    val file = frame.text(6)?.substringAfterLast('/') ?: "?"
                    val function = frame.text(4)?.takeIf { it.isNotEmpty() }?.let { f ->
                        " ($f+${frame.number(5) ?: 0})"
                    } ?: ""
                    val pc = java.lang.Long.toHexString(frame.number(1) ?: 0)
                    lines += "  #${i.toString().padStart(2, '0')} pc $pc $file$function"
                }
            }
            val logs = top.messages(18).flatMap { buffer -> buffer.messages(2) }
            for (log in logs.takeLast(MAX_LOG_LINES)) {
                val tag = log.text(5) ?: ""
                val message = log.text(6) ?: ""
                val time = log.text(1)?.substringAfter(' ')?.take(12) ?: ""
                lines += "  log $time $tag: ${clip(message)}"
            }
            if (crashed != null || lines.isNotEmpty()) return lines
        } catch (_: Exception) {
            // Not the layout this reader expects: fall back to the readable strings.
        }
        return strings(data)
    }

    /** Fallback: readable runs that name a native library or a function, in order. */
    internal fun strings(data: ByteArray): List<String> {
        val found = LinkedHashSet<String>()
        val run = StringBuilder()
        fun flush() {
            val s = run.toString()
            run.setLength(0)
            if (s.length >= 6 && (s.contains(".so") || s.contains("Abort") || s.contains("SIG"))) {
                found += clip(s)
            }
        }
        for (b in data) {
            val c = b.toInt() and 0xff
            if (c in 0x20..0x7e) run.append(c.toChar()) else flush()
        }
        flush()
        return found.take(MAX_FRAMES).map { "  ~ $it" }
    }
}
