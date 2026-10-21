package com.nox.nox_iptv

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Sports Trak recording (lib/services/recording_service.dart). A foreground
 * service so a recording keeps going with the screen off / the box in
 * standby (wake + Wi-Fi lock while anything records). Each recording is one
 * thread that writes the provider's stream to a `.ts` file:
 *
 * - a plain TS stream is copied byte for byte (reconnecting on a drop);
 * - an HLS playlist (also a `.ts` URL that redirects to one, Strong8K) is
 *   polled and its new segments appended, so the file is still one TS.
 *
 * Every recording also feeds [LiveTee]: a tiny HTTP server on 127.0.0.1
 * that hands the same bytes to the app's player, so watching the channel
 * being recorded doesn't open a second provider connection (most accounts
 * allow one).
 *
 * State goes to `<file>.status` (JSON) so Dart can read it even when the
 * service ran while the app was closed: state recording / done / failed /
 * interrupted / stopped, bytes, startedAt, endedAt, error.
 */
class RecorderService : Service() {
    companion object {
        const val TAG = "VesperRecorder"
        const val ACTION_START = "com.nox.nox_iptv.RECORD_START"
        const val ACTION_STOP = "com.nox.nox_iptv.RECORD_STOP"
        private const val CHANNEL_ID = "vespertv_recording"
        private const val NOTIFICATION_ID = 4711

        /** Running recordings by id — read by RecorderBridge. */
        val active = ConcurrentHashMap<String, Recording>()

        fun start(context: Context, item: JSONObject) {
            val intent = Intent(context, RecorderService::class.java)
                .setAction(ACTION_START)
                .putExtra("item", item.toString())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context, id: String) {
            if (!active.containsKey(id)) return
            context.startService(
                Intent(context, RecorderService::class.java)
                    .setAction(ACTION_STOP).putExtra("id", id)
            )
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Foreground first: Android kills a service started with
        // startForegroundService that doesn't call this within 5 s.
        goForeground()
        when (intent?.action) {
            ACTION_START -> intent.getStringExtra("item")?.let { raw ->
                try {
                    begin(JSONObject(raw))
                } catch (e: Exception) {
                    Log.e(TAG, "bad start item: $e")
                }
            }
            ACTION_STOP -> intent.getStringExtra("id")?.let { active[it]?.stop("stopped") }
        }
        if (active.isEmpty()) finish()
        return START_NOT_STICKY
    }

    private fun begin(item: JSONObject) {
        val id = item.getString("id")
        if (active.containsKey(id)) return
        val endAt = item.optLong("endAt", 0L)
        if (endAt in 1..System.currentTimeMillis()) {
            Log.i(TAG, "$id: end time already passed, not starting")
            return
        }
        val rec = Recording(
            id = id,
            url = item.getString("url"),
            file = File(item.getString("path")),
            endAt = endAt,
            title = item.optString("title", "Recording"),
            minFreeBytes = item.optLong("minFreeBytes", 1L shl 30),
            maxBytes = item.optLong("maxBytes", 0L),
            onDone = { r ->
                active.remove(r.id)
                LiveTee.close(r.id)
                updateNotification()
                if (active.isEmpty()) finish()
            },
        )
        active[id] = rec
        acquireLocks()
        updateNotification()
        rec.thread.start()
    }

    private fun goForeground() {
        val n = buildNotification()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
    }

    private fun buildNotification(): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            nm.getNotificationChannel(CHANNEL_ID) == null
        ) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Recordings", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val titles = active.values.map { it.title }
        val text = when (titles.size) {
            0 -> "Starting…"
            1 -> titles[0]
            else -> "${titles.size} recordings"
        }
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(
                this, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
        return b.setContentTitle("VesperTV · Recording")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.presence_video_online)
            .setOngoing(true)
            .setContentIntent(open)
            .build()
    }

    private fun updateNotification() {
        if (active.isEmpty()) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun acquireLocks() {
        if (wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "VesperTV:recording")
                .apply { setReferenceCounted(false); acquire(12 * 3600 * 1000L) }
        }
        if (wifiLock == null) {
            try {
                val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                @Suppress("DEPRECATION")
                wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "VesperTV:recording")
                    .apply { setReferenceCounted(false); acquire() }
            } catch (e: Exception) {
                Log.w(TAG, "no wifi lock: $e")
            }
        }
    }

    private fun finish() {
        try { wakeLock?.release() } catch (_: Exception) {}
        try { wifiLock?.release() } catch (_: Exception) {}
        wakeLock = null
        wifiLock = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION") stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        // Killed with recordings still running (low memory, force stop).
        for (r in active.values) r.stop("interrupted")
        super.onDestroy()
    }
}

/** One recording: its own thread, writes [file] and `[file].status`. */
class Recording(
    val id: String,
    val url: String,
    val file: File,
    val endAt: Long,
    val title: String,
    private val minFreeBytes: Long,
    private val maxBytes: Long,
    private val onDone: (Recording) -> Unit,
) {
    @Volatile var bytes = 0L
    @Volatile private var stopReason: String? = null
    @Volatile private var conn: HttpURLConnection? = null
    private val startedAt = System.currentTimeMillis()
    private var lastStatusAt = 0L
    private var error = ""

    val thread = Thread({ run() }, "rec-$id")

    fun stop(reason: String) {
        if (stopReason == null) stopReason = reason
        try { conn?.disconnect() } catch (_: Exception) {}
        thread.interrupt()
    }

    private fun shouldStop(): Boolean {
        if (stopReason != null) return true
        if (endAt > 0 && System.currentTimeMillis() >= endAt) {
            stopReason = "done"
            return true
        }
        if (maxBytes in 1..bytes) {
            stopReason = "full"
            error = "Recording size cap reached"
            return true
        }
        return false
    }

    private fun run() {
        file.parentFile?.mkdirs()
        writeStatus("recording")
        var failures = 0
        try {
            FileOutputStream(file, true).use { out ->
                bytes = file.length()
                while (!shouldStop()) {
                    try {
                        copyOnce(out)
                        failures = 0
                    } catch (e: InterruptedException) {
                        break
                    } catch (e: Exception) {
                        if (shouldStop()) break
                        error = e.toString()
                        failures++
                        Log.w(RecorderService.TAG, "$id: ${e.message} (try $failures)")
                    }
                    if (shouldStop()) break
                    // A drop mid-game: reconnect quickly, then back off.
                    // Give up only after ~5 min of nothing.
                    if (failures > 40) {
                        stopReason = "failed"
                        break
                    }
                    try {
                        Thread.sleep(if (failures <= 3) 1000L else 8000L)
                    } catch (_: InterruptedException) {
                        break
                    }
                }
            }
        } catch (e: Exception) {
            error = e.toString()
            if (stopReason == null) stopReason = "failed"
        }
        val reason = stopReason ?: "done"
        val state = when (reason) {
            "full" -> "done"
            else -> reason
        }
        // Nothing ever arrived: not a recording, whatever the reason.
        writeStatus(if (bytes == 0L && state == "done") "failed" else state)
        onDone(this)
    }

    /** Opens [u] following redirects (also http <-> https). */
    private fun open(u: String): HttpURLConnection {
        var target = URL(u)
        repeat(6) {
            val c = target.openConnection() as HttpURLConnection
            c.instanceFollowRedirects = false
            c.connectTimeout = 15000
            c.readTimeout = 20000
            c.setRequestProperty("User-Agent", "VesperTV (Linux;Android ${Build.VERSION.RELEASE}) ExoPlayerLib/1.4.1")
            c.setRequestProperty("Accept", "*/*")
            val code = c.responseCode
            if (code in 300..399) {
                val loc = c.getHeaderField("Location") ?: throw java.io.IOException("redirect without Location")
                c.disconnect()
                target = URL(target, loc)
                return@repeat
            }
            if (code !in 200..299) {
                c.disconnect()
                throw java.io.IOException("HTTP $code")
            }
            return c
        }
        throw java.io.IOException("too many redirects")
    }

    private fun copyOnce(out: OutputStream) {
        val c = open(url)
        conn = c
        try {
            val input = java.io.BufferedInputStream(c.inputStream, 64 * 1024)
            input.mark(16)
            val head = ByteArray(7)
            val n = input.read(head)
            input.reset()
            val type = c.contentType?.lowercase() ?: ""
            val isHls = (n == 7 && String(head, Charsets.US_ASCII) == "#EXTM3U") ||
                type.contains("mpegurl")
            if (isHls) {
                val playlist = input.readBytes().toString(Charsets.UTF_8)
                recordHls(c.url, playlist, out)
            } else {
                pump(input, out)
            }
        } finally {
            try { c.disconnect() } catch (_: Exception) {}
            conn = null
        }
    }

    private fun pump(input: InputStream, out: OutputStream) {
        val buf = ByteArray(64 * 1024)
        while (!shouldStop()) {
            val n = input.read(buf)
            if (n < 0) throw java.io.IOException("stream ended")
            if (n == 0) continue
            write(out, buf, n)
        }
    }

    private fun write(out: OutputStream, buf: ByteArray, n: Int) {
        out.write(buf, 0, n)
        bytes += n
        LiveTee.feed(id, buf, n)
        val now = System.currentTimeMillis()
        if (now - lastStatusAt > 5000) {
            lastStatusAt = now
            if (file.parentFile?.usableSpace ?: Long.MAX_VALUE < minFreeBytes) {
                stopReason = "full"
                error = "Storage almost full"
            }
            writeStatus("recording")
        }
    }

    /** Live HLS: poll the media playlist, append new segments in order. */
    private fun recordHls(base: URL, first: String, out: OutputStream) {
        var playlistUrl = base
        var text = first
        // Master playlist: take the highest-bandwidth variant.
        if (text.contains("#EXT-X-STREAM-INF")) {
            var best = -1L
            var bestUri: String? = null
            val lines = text.lines()
            for (i in lines.indices) {
                val l = lines[i]
                if (l.startsWith("#EXT-X-STREAM-INF")) {
                    val bw = Regex("BANDWIDTH=(\\d+)").find(l)?.groupValues?.get(1)?.toLongOrNull() ?: 0
                    val uri = lines.drop(i + 1).firstOrNull { it.isNotBlank() && !it.startsWith("#") }
                    if (uri != null && bw > best) { best = bw; bestUri = uri.trim() }
                }
            }
            playlistUrl = URL(base, bestUri ?: throw java.io.IOException("empty master playlist"))
            text = fetchText(playlistUrl)
        }
        var lastSeq = -1L
        val buf = ByteArray(64 * 1024)
        while (!shouldStop()) {
            val lines = text.lines()
            var seq = lines.firstOrNull { it.startsWith("#EXT-X-MEDIA-SEQUENCE:") }
                ?.substringAfter(':')?.trim()?.toLongOrNull() ?: 0L
            var target = lines.firstOrNull { it.startsWith("#EXT-X-TARGETDURATION:") }
                ?.substringAfter(':')?.trim()?.toLongOrNull() ?: 6L
            if (target <= 0) target = 6
            val segments = lines.filter { it.isNotBlank() && !it.startsWith("#") }
            if (lines.any { it.startsWith("#EXT-X-KEY") && !it.contains("METHOD=NONE") }) {
                throw java.io.IOException("encrypted HLS is not supported")
            }
            // First load: start at the live edge (last 3 segments), like a player.
            val startIndex = if (lastSeq < 0) maxOf(0, segments.size - 3) else 0
            for ((i, s) in segments.withIndex()) {
                val thisSeq = seq + i
                if (i < startIndex || thisSeq <= lastSeq) continue
                if (shouldStop()) return
                val sc = open(URL(playlistUrl, s.trim()).toString())
                conn = sc
                try {
                    sc.inputStream.use { input ->
                        while (true) {
                            val n = input.read(buf)
                            if (n < 0) break
                            if (n > 0) write(out, buf, n)
                        }
                    }
                } finally {
                    sc.disconnect()
                }
                lastSeq = thisSeq
            }
            if (lines.any { it.startsWith("#EXT-X-ENDLIST") }) throw java.io.IOException("stream ended")
            Thread.sleep(target * 1000L / 2)
            text = fetchText(playlistUrl)
        }
    }

    private fun fetchText(u: URL): String {
        val c = open(u.toString())
        conn = c
        try {
            return c.inputStream.use { it.readBytes().toString(Charsets.UTF_8) }
        } finally {
            c.disconnect()
        }
    }

    private fun writeStatus(state: String) {
        try {
            val now = System.currentTimeMillis()
            val o = JSONObject()
                .put("state", state)
                .put("bytes", bytes)
                .put("startedAt", startedAt)
                .put("updatedAt", now)
                .put("error", error)
            if (state != "recording") o.put("endedAt", now)
            val f = File(file.path + ".status")
            val tmp = File(file.path + ".status.tmp")
            tmp.writeText(o.toString())
            tmp.renameTo(f)
        } catch (e: Exception) {
            Log.w(RecorderService.TAG, "$id: status write failed: $e")
        }
    }
}

/**
 * The "watch while recording" tap: `http://127.0.0.1:<port>/rec/<id>.ts`
 * streams whatever [Recording.write] feeds from the moment the player
 * connects (a live TS, like the provider's own). One server for the app,
 * started on first use; nothing listens on other interfaces.
 */
object LiveTee {
    private var server: ServerSocket? = null
    private val listeners = ConcurrentHashMap<String, CopyOnWriteArrayList<Viewer>>()

    /** One player connection. The recorder only queues ([offer] never
     *  blocks): a player that stops reading (paused, buffer full) must not
     *  stall the recording. Past ~32 MB queued, chunks are dropped. */
    private class Viewer(val out: OutputStream) {
        val queue = java.util.concurrent.LinkedBlockingQueue<ByteArray>(512)
        @Volatile var closed = false
        fun offer(b: ByteArray) { if (!closed) queue.offer(b) }
        fun close() {
            closed = true
            queue.offer(ByteArray(0))
        }
        fun drain() {
            try {
                while (!closed) {
                    val b = queue.take()
                    if (b.isEmpty()) break
                    out.write(b)
                    if (queue.isEmpty()) out.flush()
                }
            } catch (_: Exception) {
            } finally {
                closed = true
                try { out.close() } catch (_: Exception) {}
            }
        }
    }

    @Synchronized
    fun port(): Int {
        server?.let { return it.localPort }
        val s = ServerSocket(0, 8, InetAddress.getByName("127.0.0.1"))
        server = s
        Thread({ acceptLoop(s) }, "rec-tee").apply { isDaemon = true; start() }
        return s.localPort
    }

    private fun acceptLoop(s: ServerSocket) {
        while (!s.isClosed) {
            val sock = try { s.accept() } catch (_: Exception) { return }
            Thread({ serve(sock) }, "rec-tee-client").apply { isDaemon = true; start() }
        }
    }

    private fun serve(sock: Socket) {
        try {
            sock.soTimeout = 10000
            val reader = sock.getInputStream().bufferedReader(Charsets.US_ASCII)
            val requestLine = reader.readLine() ?: return sock.close()
            while (true) {
                val l = reader.readLine() ?: break
                if (l.isEmpty()) break
            }
            val id = Regex("^GET /rec/([A-Za-z0-9_-]+)\\.ts").find(requestLine)?.groupValues?.get(1)
            val out = java.io.BufferedOutputStream(sock.getOutputStream(), 64 * 1024)
            if (id == null || !RecorderService.active.containsKey(id)) {
                out.write("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".toByteArray())
                out.flush()
                sock.close()
                return
            }
            out.write("HTTP/1.1 200 OK\r\nContent-Type: video/mp2t\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n".toByteArray())
            out.flush()
            sock.soTimeout = 0
            val viewer = Viewer(out)
            val list = listeners.getOrPut(id) { CopyOnWriteArrayList() }
            list.add(viewer)
            viewer.drain()
            list.remove(viewer)
            sock.close()
        } catch (_: Exception) {
            try { sock.close() } catch (_: Exception) {}
        }
    }

    fun feed(id: String, buf: ByteArray, n: Int) {
        val list = listeners[id] ?: return
        if (list.isEmpty()) return
        val chunk = buf.copyOf(n)
        for (v in list) {
            if (v.closed) list.remove(v) else v.offer(chunk)
        }
    }

    fun close(id: String) {
        listeners.remove(id)?.forEach { it.close() }
    }
}
