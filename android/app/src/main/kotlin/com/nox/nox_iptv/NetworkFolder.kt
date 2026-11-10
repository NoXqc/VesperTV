package com.nox.nox_iptv

import android.content.Context
import android.util.Log
import com.hierynomus.msdtyp.AccessMask
import com.hierynomus.msfscc.FileAttributes
import com.hierynomus.mssmb2.SMB2CreateDisposition
import com.hierynomus.mssmb2.SMB2CreateOptions
import com.hierynomus.mssmb2.SMB2ShareAccess
import com.hierynomus.security.bc.BCSecurityProvider
import com.hierynomus.smbj.SMBClient
import com.hierynomus.smbj.SmbConfig
import com.hierynomus.smbj.auth.AuthenticationContext
import com.hierynomus.smbj.auth.NtlmAuthenticator
import com.hierynomus.smbj.connection.Connection
import com.hierynomus.smbj.session.Session
import com.hierynomus.smbj.share.DiskShare
import com.hierynomus.smbj.share.File as SmbFile
import org.json.JSONObject
import java.io.Closeable
import java.io.File
import java.io.FileOutputStream
import java.io.FilterOutputStream
import java.io.OutputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.EnumSet
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

/**
 * The network folder (Settings > Recordings): a Windows / NAS share that
 * recordings and downloads can be written to instead of the box's own
 * storage — Fire Sticks have a few GB free. SMB 2/3 through smbj (NTLM,
 * BouncyCastle; smbj skips Kerberos on Android by itself).
 *
 * A recording's path is `smb://host[:port]/share/folder/file.ts`; the
 * credentials are not in it, they live here (app-private prefs, this device
 * only — Transfer / Backup never carry them). Dart sends them on every
 * change because a timed recording may start with the app closed.
 */
object NetworkFolder {
    private const val TAG = "VesperNetFolder"
    private const val PREFS = "vesper_network_folder"
    const val SCHEME = "smb://"

    data class Config(
        val host: String,
        val share: String,
        val folder: String,
        val user: String,
        val password: String,
        val domain: String,
    ) {
        /** Where files go, as a recording path prefix. */
        val base: String
            get() = SCHEME + host + "/" + share + (if (folder.isEmpty()) "" else "/$folder")
    }

    /** A parsed `smb://` path: the share and the path inside it (SMB form). */
    data class Location(val host: String, val port: Int, val share: String, val path: String)

    fun isSmb(path: String) = path.startsWith(SCHEME)

    fun load(context: Context): Config? {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = p.getString("config", null) ?: return null
        return try {
            fromJson(JSONObject(raw))
        } catch (_: Exception) {
            null
        }
    }

    fun save(context: Context, config: Config?) {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        if (config == null) p.remove("config") else p.putString("config", toJson(config).toString())
        p.apply()
    }

    fun fromJson(o: JSONObject): Config? {
        val host = o.optString("host").trim()
        val share = o.optString("share").trim().trim('/', '\\')
        if (host.isEmpty() || share.isEmpty()) return null
        return Config(
            host = host,
            share = share,
            folder = o.optString("folder").trim().trim('/', '\\').replace('\\', '/'),
            user = o.optString("user").trim(),
            password = o.optString("password"),
            domain = o.optString("domain").trim(),
        )
    }

    private fun toJson(c: Config) = JSONObject()
        .put("host", c.host).put("share", c.share).put("folder", c.folder)
        .put("user", c.user).put("password", c.password).put("domain", c.domain)

    fun parse(url: String): Location? {
        if (!isSmb(url)) return null
        val rest = url.removePrefix(SCHEME)
        val parts = rest.split('/').filter { it.isNotEmpty() }
        if (parts.size < 2) return null
        val hostPort = parts[0]
        val colon = hostPort.lastIndexOf(':')
        val (host, port) = if (colon > 0 && hostPort.substring(colon + 1).all { it.isDigit() }) {
            hostPort.substring(0, colon) to hostPort.substring(colon + 1).toInt()
        } else {
            hostPort to SMBClient.DEFAULT_PORT
        }
        return Location(host, port, parts[1], parts.drop(2).joinToString("\\"))
    }

    private fun client() = SMBClient(
        SmbConfig.builder()
            .withSecurityProvider(BCSecurityProvider())
            .withAuthenticators(NtlmAuthenticator.Factory())
            .withTimeout(30, TimeUnit.SECONDS)
            .withSoTimeout(45, TimeUnit.SECONDS)
            .build()
    )

    /** One open share: everything closes together. */
    class Mount(
        private val client: SMBClient,
        private val connection: Connection,
        private val session: Session,
        val share: DiskShare,
    ) : Closeable {
        override fun close() {
            try { share.close() } catch (_: Exception) {}
            try { session.close() } catch (_: Exception) {}
            try { connection.close() } catch (_: Exception) {}
            try { client.close() } catch (_: Exception) {}
        }
    }

    /** Opens [loc]'s share with the saved login ([config] when testing). */
    fun mount(context: Context, loc: Location, config: Config? = null): Mount {
        val c = config ?: load(context)
        val client = client()
        try {
            val connection = client.connect(loc.host, loc.port)
            val auth = when {
                c == null || c.user.isEmpty() -> AuthenticationContext.guest()
                else -> AuthenticationContext(c.user, c.password.toCharArray(), c.domain.ifEmpty { null })
            }
            val session = try {
                connection.authenticate(auth)
            } catch (e: Exception) {
                // A share open to everyone: some NAS refuse "guest" but take
                // an anonymous login (and the reverse).
                if (c != null && c.user.isNotEmpty()) throw e
                connection.authenticate(AuthenticationContext.anonymous())
            }
            val share = session.connectShare(loc.share) as? DiskShare
                ?: throw java.io.IOException("${loc.share} is not a shared folder")
            return Mount(client, connection, session, share)
        } catch (e: Throwable) {
            try { client.close() } catch (_: Exception) {}
            throw e
        }
    }

    /** Creates every missing folder of [dir] (SMB form, `a\b\c`). */
    fun mkdirs(share: DiskShare, dir: String) {
        var at = ""
        for (part in dir.split('\\').filter { it.isNotEmpty() }) {
            at = if (at.isEmpty()) part else "$at\\$part"
            if (!share.folderExists(at)) share.mkdir(at)
        }
    }

    private fun openForWrite(share: DiskShare, path: String, append: Boolean): SmbFile {
        val parent = path.substringBeforeLast('\\', "")
        if (parent.isNotEmpty()) mkdirs(share, parent)
        return share.openFile(
            path,
            EnumSet.of(AccessMask.GENERIC_READ, AccessMask.GENERIC_WRITE),
            EnumSet.of(FileAttributes.FILE_ATTRIBUTE_NORMAL),
            SMB2ShareAccess.ALL,
            if (append) SMB2CreateDisposition.FILE_OPEN_IF else SMB2CreateDisposition.FILE_OVERWRITE_IF,
            EnumSet.of(SMB2CreateOptions.FILE_NON_DIRECTORY_FILE),
        )
    }

    private fun openForRead(share: DiskShare, path: String): SmbFile = share.openFile(
        path,
        EnumSet.of(AccessMask.GENERIC_READ),
        null,
        SMB2ShareAccess.ALL,
        SMB2CreateDisposition.FILE_OPEN,
        EnumSet.of(SMB2CreateOptions.FILE_NON_DIRECTORY_FILE),
    )

    fun length(context: Context, url: String): Long {
        val loc = parse(url) ?: throw java.io.IOException("bad network path")
        mount(context, loc).use { m ->
            if (!m.share.fileExists(loc.path)) return 0L
            return m.share.getFileInformation(loc.path).standardInformation.endOfFile
        }
    }

    /** Free space on [url]'s share. */
    fun free(context: Context, url: String): Long {
        val loc = parse(url) ?: throw java.io.IOException("bad network path")
        mount(context, loc).use { m -> return m.share.shareInformation.callerFreeSpace }
    }

    fun delete(context: Context, url: String) {
        val loc = parse(url) ?: return
        mount(context, loc).use { m ->
            if (m.share.fileExists(loc.path)) m.share.rm(loc.path)
        }
    }

    /**
     * An output stream on [url] (appending, or truncating when not
     * [append]). Closing it closes the file and the connection.
     */
    fun output(context: Context, url: String, append: Boolean): OutputStream {
        val loc = parse(url) ?: throw java.io.IOException("bad network path")
        val m = mount(context, loc)
        try {
            val f = openForWrite(m.share, loc.path, append)
            val out = f.getOutputStream(append)
            return object : FilterOutputStream(out) {
                override fun write(b: ByteArray, off: Int, len: Int) = out.write(b, off, len)
                override fun close() {
                    try { super.close() } catch (_: Exception) {}
                    try { f.close() } catch (_: Exception) {}
                    m.close()
                }
            }
        } catch (e: Throwable) {
            m.close()
            throw e
        }
    }

    // ------------------------------------------- browsing, details, copying

    private val VIDEO = setOf("mkv", "mp4", "m4v", "avi", "ts", "webm", "mov")
    const val DETAILS_DIR = ".vespertv"

    /**
     * The details file of [url] (title, poster…, written by the device that
     * saved it): `dir/.vespertv/<name>.json` beside the video, so another
     * device browsing the folder shows a real card.
     */
    fun detailsUrl(url: String): String {
        val slash = url.lastIndexOf('/')
        return url.substring(0, slash) + "/" + DETAILS_DIR + "/" + url.substring(slash + 1) + ".json"
    }

    /** Writes [text] to [url] (replacing it), creating its folders. */
    fun writeText(context: Context, url: String, text: String) {
        val loc = parse(url) ?: throw java.io.IOException("bad network path")
        mount(context, loc).use { m ->
            openForWrite(m.share, loc.path, false).use { f ->
                f.write(text.toByteArray(Charsets.UTF_8), 0)
            }
        }
    }

    /** Writes [details] beside a finished file; never fails the caller. */
    fun writeDetails(context: Context, url: String, details: String?) {
        if (details.isNullOrEmpty() || !isSmb(url)) return
        try {
            writeText(context, detailsUrl(url), details)
        } catch (e: Throwable) {
            Log.w(TAG, "details not written: ${e.javaClass.simpleName}")
        }
    }

    /**
     * Every video in the saved folder (and its subfolders, 3 deep), as JSON:
     * `[{path, name, size, modified, details}]`, details = the `.vespertv`
     * file's text or absent. Throws when the folder can't be reached.
     */
    fun list(context: Context): String {
        val config = load(context) ?: throw java.io.IOException("No network folder")
        val loc = parse(config.base) ?: throw java.io.IOException("bad network path")
        val out = org.json.JSONArray()
        mount(context, loc).use { m ->
            fun walk(dir: String, url: String, depth: Int) {
                if (dir.isNotEmpty() && !m.share.folderExists(dir)) return
                val entries = m.share.list(dir).filter { it.fileName != "." && it.fileName != ".." }
                val isDir = { e: com.hierynomus.msfscc.fileinformation.FileIdBothDirectoryInformation ->
                    (e.fileAttributes and FileAttributes.FILE_ATTRIBUTE_DIRECTORY.value) != 0L
                }
                val details = HashMap<String, String>()
                if (entries.any { isDir(it) && it.fileName == DETAILS_DIR }) {
                    val dd = if (dir.isEmpty()) DETAILS_DIR else "$dir\\$DETAILS_DIR"
                    for (d in m.share.list(dd)) {
                        if (!d.fileName.endsWith(".json") || d.endOfFile > 64 * 1024) continue
                        try {
                            openForRead(m.share, "$dd\\${d.fileName}").use { f ->
                                val buf = ByteArray(d.endOfFile.toInt())
                                var at = 0
                                while (at < buf.size) {
                                    val n = f.read(buf, at.toLong(), at, buf.size - at)
                                    if (n <= 0) break
                                    at += n
                                }
                                details[d.fileName.removeSuffix(".json")] = String(buf, 0, at, Charsets.UTF_8)
                            }
                        } catch (_: Exception) {}
                    }
                }
                for (e in entries) {
                    val name = e.fileName
                    if (name.startsWith(".")) continue
                    val childUrl = "$url/$name"
                    if (isDir(e)) {
                        if (depth < 3) walk(if (dir.isEmpty()) name else "$dir\\$name", childUrl, depth + 1)
                        continue
                    }
                    if (name.substringAfterLast('.', "").lowercase() !in VIDEO) continue
                    val o = JSONObject()
                        .put("path", childUrl)
                        .put("name", name)
                        .put("size", e.endOfFile)
                        .put("modified", e.lastWriteTime.toEpochMillis())
                    details[name]?.let { o.put("details", it) }
                    out.put(o)
                }
            }
            walk(loc.path, config.base, 0)
        }
        return out.toString()
    }

    /**
     * Reads [url] from byte [from] (a copy to this device resuming): the
     * stream and the file's size. Closing the stream closes the connection.
     */
    fun input(context: Context, url: String, from: Long): Pair<java.io.InputStream, Long> {
        val loc = parse(url) ?: throw java.io.IOException("bad network path")
        val m = mount(context, loc)
        try {
            if (!m.share.fileExists(loc.path)) throw java.io.FileNotFoundException("gone")
            val f = openForRead(m.share, loc.path)
            val size = f.fileInformation.standardInformation.endOfFile
            val stream = object : java.io.InputStream() {
                var pos = from
                override fun read(): Int {
                    val one = ByteArray(1)
                    return if (read(one, 0, 1) <= 0) -1 else one[0].toInt() and 0xff
                }
                override fun read(b: ByteArray, off: Int, len: Int): Int {
                    if (pos >= size) return -1
                    val n = f.read(b, pos, off, minOf(len.toLong(), size - pos).toInt())
                    if (n > 0) pos += n
                    return n
                }
                override fun close() {
                    try { f.close() } catch (_: Exception) {}
                    m.close()
                }
            }
            return stream to size
        } catch (e: Throwable) {
            m.close()
            throw e
        }
    }

    /** Settings' Test button: connect, write a probe, report the space. */
    fun test(context: Context, config: Config): Map<String, Any> = try {
        val loc = parse(config.base) ?: throw java.io.IOException("bad address")
        mount(context, loc, config).use { m ->
            val probe = (if (loc.path.isEmpty()) "" else loc.path + "\\") + ".vespertv-test"
            val f = openForWrite(m.share, probe, false)
            f.use { it.write("ok".toByteArray(), 0) }
            m.share.rm(probe)
            val info = m.share.shareInformation
            mapOf("ok" to true, "free" to info.callerFreeSpace, "total" to info.totalSpace)
        }
    } catch (e: Throwable) {
        Log.w(TAG, "test failed: ${e.javaClass.simpleName}: ${e.message}")
        mapOf("ok" to false, "error" to describe(e))
    }

    /** A short reason for the user, never the password. */
    fun describe(e: Throwable): String {
        val msg = (e.message ?: "").lowercase()
        return when {
            e is NoClassDefFoundError || e is NoSuchMethodError || e is UnsatisfiedLinkError ->
                "Network folders don't work on this device"
            msg.contains("logon_failure") || msg.contains("access_denied") ->
                "Wrong user name or password, or no access to this folder"
            msg.contains("bad_network_name") -> "No shared folder with that name"
            msg.contains("timed out") || msg.contains("timeout") || e is java.net.SocketTimeoutException ->
                "The computer didn't answer"
            e is java.net.UnknownHostException -> "Address not found"
            e is java.net.ConnectException -> "Can't reach the computer (is it on, and sharing turned on?)"
            else -> e.javaClass.simpleName + (e.message?.let { ": " + it.take(120) } ?: "")
        }
    }

    // ------------------------------------------------------------ playback

    private var server: ServerSocket? = null
    private val served = ConcurrentHashMap<String, String>()
    private lateinit var appContext: Context

    /**
     * `http://127.0.0.1:<port>/smb/<token>.<ext>` serving [url] with Range
     * support: ExoPlayer plays and seeks it like any progressive file.
     */
    @Synchronized
    fun playUrl(context: Context, url: String): String {
        appContext = context.applicationContext
        val s = server ?: ServerSocket(0, 8, InetAddress.getByName("127.0.0.1")).also {
            server = it
            Thread({ acceptLoop(it) }, "smb-serve").apply { isDaemon = true; start() }
        }
        val token = Integer.toHexString(url.hashCode()) + Integer.toHexString(url.length)
        served[token] = url
        val ext = url.substringAfterLast('.', "ts").take(5)
        return "http://127.0.0.1:${s.localPort}/smb/$token.$ext"
    }

    private fun acceptLoop(s: ServerSocket) {
        while (!s.isClosed) {
            val sock = try { s.accept() } catch (_: Exception) { return }
            Thread({ serve(sock) }, "smb-serve-client").apply { isDaemon = true; start() }
        }
    }

    private fun mime(url: String) = when (url.substringAfterLast('.').lowercase()) {
        "mkv" -> "video/x-matroska"
        "mp4", "m4v" -> "video/mp4"
        "avi" -> "video/x-msvideo"
        "webm" -> "video/webm"
        else -> "video/mp2t"
    }

    private fun serve(sock: Socket) {
        try {
            sock.soTimeout = 15000
            val reader = sock.getInputStream().bufferedReader(Charsets.US_ASCII)
            val request = reader.readLine() ?: return sock.close()
            var range: String? = null
            while (true) {
                val l = reader.readLine() ?: break
                if (l.isEmpty()) break
                if (l.startsWith("range:", ignoreCase = true)) range = l.substringAfter(':').trim()
            }
            val out = java.io.BufferedOutputStream(sock.getOutputStream(), 256 * 1024)
            val token = Regex("^(GET|HEAD) /smb/([0-9a-f]+)").find(request)?.groupValues?.get(2)
            val url = token?.let { served[it] }
            val loc = url?.let { parse(it) }
            if (loc == null) {
                out.write("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".toByteArray())
                out.flush()
                return sock.close()
            }
            mount(appContext, loc).use { m ->
                openForRead(m.share, loc.path).use { f ->
                    val size = f.fileInformation.standardInformation.endOfFile
                    var start = 0L
                    var end = size - 1
                    val r = range?.let { Regex("bytes=(\\d*)-(\\d*)").find(it) }
                    if (r != null) {
                        val a = r.groupValues[1]
                        val b = r.groupValues[2]
                        if (a.isNotEmpty()) {
                            start = a.toLong()
                            if (b.isNotEmpty()) end = minOf(b.toLong(), size - 1)
                        } else if (b.isNotEmpty()) {
                            start = maxOf(0L, size - b.toLong())
                        }
                    }
                    if (start >= size && size > 0) {
                        out.write("HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */$size\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".toByteArray())
                        out.flush()
                        return
                    }
                    val length = maxOf(0L, end - start + 1)
                    val head = StringBuilder()
                    head.append(if (r != null) "HTTP/1.1 206 Partial Content\r\n" else "HTTP/1.1 200 OK\r\n")
                    head.append("Content-Type: ").append(mime(url)).append("\r\n")
                    head.append("Accept-Ranges: bytes\r\n")
                    head.append("Content-Length: ").append(length).append("\r\n")
                    if (r != null) head.append("Content-Range: bytes $start-$end/$size\r\n")
                    head.append("Connection: close\r\n\r\n")
                    out.write(head.toString().toByteArray())
                    if (request.startsWith("GET")) {
                        sock.soTimeout = 0
                        val buf = ByteArray(256 * 1024)
                        var pos = start
                        while (pos <= end) {
                            val want = minOf(buf.size.toLong(), end - pos + 1).toInt()
                            val n = f.read(buf, pos, 0, want)
                            if (n <= 0) break
                            out.write(buf, 0, n)
                            pos += n
                        }
                    }
                    out.flush()
                }
            }
        } catch (_: Exception) {
            // Player closed the connection (seek, stop): nothing to do.
        } finally {
            try { sock.close() } catch (_: Exception) {}
        }
    }
}

/**
 * Where a recording or download is written: a local file, or a file in
 * the network folder. [freeBytes] for a network share is re-asked at most
 * once a minute (a round trip to the NAS).
 */
abstract class RecTarget(val path: String) {
    abstract fun length(): Long
    abstract fun open(append: Boolean): OutputStream
    abstract fun freeBytes(): Long

    companion object {
        fun of(context: Context, path: String): RecTarget =
            if (NetworkFolder.isSmb(path)) SmbTarget(context, path) else FileTarget(path)
    }
}

class FileTarget(path: String) : RecTarget(path) {
    private val file = File(path)
    override fun length() = file.length()
    override fun open(append: Boolean): OutputStream {
        file.parentFile?.mkdirs()
        return FileOutputStream(file, append)
    }
    override fun freeBytes() = file.parentFile?.usableSpace ?: Long.MAX_VALUE
}

class SmbTarget(private val context: Context, path: String) : RecTarget(path) {
    private var freeAt = 0L
    private var free = Long.MAX_VALUE
    override fun length() = NetworkFolder.length(context, path)
    override fun open(append: Boolean) = NetworkFolder.output(context, path, append)
    override fun freeBytes(): Long {
        val now = System.currentTimeMillis()
        if (now - freeAt > 60_000) {
            freeAt = now
            free = try { NetworkFolder.free(context, path) } catch (_: Exception) { free }
        }
        return free
    }
}
