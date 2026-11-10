package com.nox.nox_iptv

import android.content.Context
import android.os.Build
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * What a download may do right now (lib/services/recording_service.dart
 * sends it): the speed limit, and which provider accounts the app is
 * playing from. Saved, because an overnight download starts from an alarm
 * with the app closed.
 *
 * - One connection: a download never takes a connection the app needs.
 *   While the player (or a Multiview tile, or a recording) uses the
 *   account's last connection, the download lets go and waits.
 * - Wi-Fi: while anything plays from the network, a download is held to
 *   [WHILE_PLAYING] so the stream keeps its bandwidth.
 */
object DownloadPolicy {
    private const val PREFS = "vesper_download_policy"
    const val WHILE_PLAYING = 625_000L // 5 Mbit/s

    /** "watch" (about the movie's own bitrate), "10" / "25" / "50" Mbit/s, "none". */
    @Volatile var speed = "watch"

    /**
     * Network streams the app is playing, per provider account ("" = not
     * an IPTV account). Dart re-sends it every minute while a download
     * runs; an older one is ignored, so a dead app can't hold a download
     * back all night.
     */
    @Volatile private var playing: Map<String, Int> = emptyMap()
    @Volatile private var playingAt = 0L
    val streams: Map<String, Int>
        get() = if (System.currentTimeMillis() - playingAt > 3 * 60_000) emptyMap() else playing

    fun setStreams(value: Map<String, Int>) {
        playing = value
        playingAt = System.currentTimeMillis()
    }

    fun clearStreams() {
        playing = emptyMap()
    }

    fun load(context: Context) {
        speed = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString("speed", "watch") ?: "watch"
    }

    fun setSpeed(context: Context, value: String) {
        speed = value
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("speed", value).apply()
    }

    /** Bytes per second for [d]; Long.MAX_VALUE = no limit. */
    fun rate(d: Download): Long {
        var r = when (speed) {
            "none" -> Long.MAX_VALUE
            "10" -> 1_250_000L
            "25" -> 3_125_000L
            "50" -> 6_250_000L
            // Like watching: the file's average bitrate with some headroom,
            // so the provider sees about what a viewer would pull.
            else -> if (d.total > 0 && d.durationSec > 60) {
                maxOf(500_000L, d.total / d.durationSec * 5 / 4)
            } else {
                1_500_000L
            }
        }
        if (streams.isNotEmpty()) r = minOf(r, WHILE_PLAYING)
        return r
    }

    /** Why [d] must wait (a note for the Recordings tab), or null. */
    fun blocked(d: Download): String? {
        if (d.account.isEmpty()) return null
        val limit = if (d.maxConnections > 0) d.maxConnections else 1
        val used = (streams[d.account] ?: 0) +
            RecorderService.active.values.count { it.account == d.account }
        return if (used >= limit) "connection" else null
    }
}

/**
 * One movie / episode download: a plain HTTP GET written to [path] (a
 * local file or the network folder), resumed with a Range request after a
 * drop, a pause or a reboot. Runs on its own thread; downloads go one at a
 * time ([RecorderService.turnOf]). State goes to [statusPath] like a
 * recording's: queued / downloading / paused / done / stopped / failed.
 */
class Download(
    private val context: Context,
    item: JSONObject,
    private val onChange: (Download) -> Unit,
    private val onDone: (Download) -> Unit,
) {
    val id: String = item.getString("id")
    val url: String = item.getString("url")
    val title: String = item.optString("title", "Download")
    val path: String = item.getString("path")
    private val statusPath: String = item.optString("statusPath", "$path.status")
    val account: String = item.optString("account", "")
    val maxConnections: Int = item.optInt("maxConnections", 1)
    val durationSec: Long = item.optLong("durationSec", 0L)
    val startAt: Long = item.optLong("startAt", 0L)
    private val minFreeBytes = item.optLong("minFreeBytes", 1L shl 30)
    private val maxBytes = item.optLong("maxBytes", 0L)
    private val headers: Map<String, String> = item.optJSONObject("headers")?.let { h ->
        h.keys().asSequence().associateWith { h.optString(it) }
    } ?: emptyMap()

    @Volatile var bytes = 0L
    @Volatile var total = 0L
    @Volatile var state = "queued"
    @Volatile private var note = ""
    @Volatile private var error = ""
    @Volatile private var stopReason: String? = null
    @Volatile private var conn: HttpURLConnection? = null
    private val startedAt = System.currentTimeMillis()
    private var lastStatusAt = 0L

    val finished get() = state == "done" || state == "stopped" || state == "failed"
    val thread = Thread({ run() }, "dl-$id")

    /** Thrown to close the connection and wait (policy says no). */
    private class Pause : IOException()

    /** A problem retrying won't fix. */
    private class Fatal(msg: String) : IOException(msg)

    fun stop(reason: String) {
        if (stopReason == null) stopReason = reason
        try { conn?.disconnect() } catch (_: Exception) {}
        thread.interrupt()
    }

    private fun run() {
        readStatus()
        val target = RecTarget.of(context, path)
        var failures = 0
        var bytesAtFailure = -1L
        var stateBefore = ""
        while (stopReason == null) {
            val reason = if (!RecorderService.turnOf(this)) "queue" else DownloadPolicy.blocked(this)
            if (reason != null) {
                state = if (reason == "queue") "queued" else "paused"
                note = reason
                if (state != stateBefore) {
                    writeStatus()
                    onChange(this)
                }
                stateBefore = state
                if (!sleep(2000)) break
                continue
            }
            try {
                state = "downloading"
                note = ""
                if (stateBefore != state) {
                    writeStatus()
                    onChange(this)
                }
                stateBefore = state
                transfer(target)
                state = "done"
                break
            } catch (_: Pause) {
                // Back to the top: waits until the connection is free.
            } catch (e: Fatal) {
                error = e.message ?: "failed"
                state = "failed"
                break
            } catch (e: InterruptedException) {
                break
            } catch (e: Throwable) {
                if (stopReason != null) break
                error = when {
                    NetworkFolder.isSmb(path) && e !is IOException -> NetworkFolder.describe(e)
                    e is IOException && !e.message.isNullOrBlank() -> e.message!!
                    else -> e.toString()
                }
                // Only failures in a row count: a link that drops every few
                // minutes but keeps delivering never gives up.
                if (bytes > bytesAtFailure) failures = 0
                bytesAtFailure = bytes
                failures++
                Log.w(RecorderService.TAG, "$id: ${e.javaClass.simpleName} ${e.message} (try $failures)")
                // A dropped link or a NAS that went to sleep: retry for ~20 min.
                if (failures > 40) {
                    state = "failed"
                    break
                }
                if (!sleep(if (failures <= 3) 2000L else 30_000L)) break
            }
        }
        if (stopReason != null && state != "done" && state != "failed") state = stopReason!!
        writeStatus()
        onDone(this)
    }

    private fun sleep(ms: Long): Boolean = try {
        Thread.sleep(ms)
        true
    } catch (_: InterruptedException) {
        false
    }

    /** Status left by an earlier run (bytes, total) — resumes from there. */
    private fun readStatus() {
        try {
            val f = File(statusPath)
            if (!f.exists()) return
            val o = JSONObject(f.readText())
            total = o.optLong("total", 0L)
        } catch (_: Exception) {}
    }

    /** Opens [url] from [from], following redirects (http <-> https too). */
    private fun open(from: Long): HttpURLConnection {
        var target = URL(url)
        repeat(8) {
            val c = target.openConnection() as HttpURLConnection
            c.instanceFollowRedirects = false
            c.connectTimeout = 20000
            c.readTimeout = 30000
            c.setRequestProperty("User-Agent", "VesperTV (Linux;Android ${Build.VERSION.RELEASE}) ExoPlayerLib/1.4.1")
            c.setRequestProperty("Accept", "*/*")
            for ((k, v) in headers) c.setRequestProperty(k, v)
            if (from > 0) c.setRequestProperty("Range", "bytes=$from-")
            val code = c.responseCode
            if (code in 300..399) {
                val loc = c.getHeaderField("Location") ?: throw IOException("redirect without Location")
                c.disconnect()
                target = URL(target, loc)
                return@repeat
            }
            return c
        }
        throw IOException("too many redirects")
    }

    /** One connection's worth; true when the whole file is written. */
    private fun transfer(target: RecTarget): Boolean {
        bytes = try { target.length() } catch (e: IOException) { throw e } catch (e: Throwable) {
            throw IOException(NetworkFolder.describe(e))
        }
        if (total > 0 && bytes >= total) return true
        val c = open(bytes)
        conn = c
        try {
            val code = c.responseCode
            var append = bytes > 0
            when {
                code == 416 -> {
                    // Asked past the end: the file is already complete (an
                    // earlier run finished just before it was cut).
                    if (bytes > 0 && (total == 0L || bytes >= total)) return true
                    append = false
                }
                code == 200 -> append = false // the server ignored Range: start over
                code == 206 -> {}
                // Often "too many connections" (another device watching on
                // the account): retried like a drop, failed after ~20 min.
                code == 401 || code == 403 || code == 458 || code == 509 ->
                    throw IOException("The provider refused the download (HTTP $code)")
                code == 404 || code == 410 -> throw Fatal("The file is gone at the provider (HTTP $code)")
                else -> throw IOException("HTTP $code")
            }
            if (!append) bytes = 0
            val range = c.getHeaderField("Content-Range")
            val length = c.getHeaderField("Content-Length")?.toLongOrNull() ?: -1L
            total = Regex("/(\\d+)$").find(range ?: "")?.groupValues?.get(1)?.toLongOrNull()
                ?: if (length > 0) bytes + length else total
            val type = (c.contentType ?: "").lowercase()
            // A page or an error reply, not a video. Some servers label a
            // real file text/plain: only a small or unsized reply counts.
            val page = (type.startsWith("text/") || type.contains("json")) &&
                (total <= 0 || total < 5L * 1024 * 1024)
            if (page || type.contains("mpegurl")) {
                val text = try {
                    c.inputStream.use { it.readNBytesCompat(300) }.toString(Charsets.UTF_8)
                } catch (_: Exception) { "" }
                throw Fatal(
                    if (type.contains("mpegurl")) "This stream is a playlist (HLS), not a file. It can't be downloaded."
                    else "The link sent a page, not a video" + (if (text.isNotBlank()) ": " + text.replace(Regex("<[^>]*>"), " ").trim().take(120) else "")
                )
            }
            // A debrid "being downloaded" clip is ~0.1 MB; no film is under 5 MB.
            if (total in 1 until 5L * 1024 * 1024) {
                throw Fatal("The source sent a short clip, not the file. Try again later or pick another stream.")
            }
            if (total > 0) {
                val left = total - bytes
                // maxBytes counts this file's own bytes so far (Dart's cap room).
                if (maxBytes in 1 until total) throw Fatal("Bigger than the space left for recordings")
                val free = target.freeBytes()
                if (free != Long.MAX_VALUE && free - left < minFreeBytes) throw Fatal("Not enough storage space")
            }
            target.open(append).use { out -> pump(c, out, target) }
            if (total > 0 && bytes < total) throw IOException("connection closed early")
            return true
        } finally {
            try { c.disconnect() } catch (_: Exception) {}
            conn = null
        }
    }

    private fun pump(c: HttpURLConnection, out: OutputStream, target: RecTarget) {
        val input = c.inputStream
        val buf = ByteArray(64 * 1024)
        var windowStart = System.currentTimeMillis()
        var windowBytes = 0L
        var rate = DownloadPolicy.rate(this)
        while (true) {
            if (stopReason != null) throw InterruptedException()
            if (DownloadPolicy.blocked(this) != null) throw Pause()
            val n = input.read(buf)
            if (n < 0) return
            if (n == 0) continue
            out.write(buf, 0, n)
            bytes += n
            // Speed limit: sleep off whatever ran ahead of the rate.
            val r = DownloadPolicy.rate(this)
            if (r != rate) {
                rate = r
                windowStart = System.currentTimeMillis()
                windowBytes = 0
            }
            if (rate != Long.MAX_VALUE) {
                windowBytes += n
                val due = windowBytes * 1000 / rate
                val spent = System.currentTimeMillis() - windowStart
                if (due > spent) Thread.sleep(minOf(due - spent, 2000))
                if (windowBytes > rate * 20) {
                    windowStart = System.currentTimeMillis()
                    windowBytes = 0
                }
            }
            val now = System.currentTimeMillis()
            if (now - lastStatusAt > 3000) {
                lastStatusAt = now
                if (maxBytes in 1..bytes) throw Fatal("Bigger than the space left for recordings")
                val free = target.freeBytes()
                if (free != Long.MAX_VALUE && free < minFreeBytes) throw Fatal("Not enough storage space")
                writeStatus()
                onChange(this)
            }
        }
    }

    private fun java.io.InputStream.readNBytesCompat(max: Int): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        val buf = ByteArray(max)
        var left = max
        while (left > 0) {
            val n = read(buf, 0, left)
            if (n <= 0) break
            out.write(buf, 0, n)
            left -= n
        }
        return out.toByteArray()
    }

    fun writeStatus() {
        try {
            val now = System.currentTimeMillis()
            val o = JSONObject()
                .put("state", state)
                .put("bytes", bytes)
                .put("total", total)
                .put("note", note)
                .put("startedAt", startedAt)
                .put("updatedAt", now)
                .put("error", error)
            if (finished) o.put("endedAt", now)
            val f = File(statusPath)
            f.parentFile?.mkdirs()
            val tmp = File("$statusPath.tmp")
            tmp.writeText(o.toString())
            tmp.renameTo(f)
        } catch (e: Exception) {
            Log.w(RecorderService.TAG, "$id: status write failed: $e")
        }
    }
}
