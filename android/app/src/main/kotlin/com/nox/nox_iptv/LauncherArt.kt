package com.nox.nox_iptv

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.text.TextPaint
import android.text.TextUtils
import android.util.Log
import android.util.LruCache
import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/**
 * The pictures on the launcher's "Live now in Sports" cards: both teams' logos, the score, the
 * game clock, LIVE and the channel, drawn here (16:9) because no feed has a matchup picture.
 * Dart sends what to draw (`art`) and a hash of it (`v`); the PNG is `files/launcher_art/<v>.png`,
 * drawn once, and the card points at it through [LauncherArtProvider]. A new score = a new hash
 * = a new address, so the launcher loads the new picture instead of its cached one.
 */
object LauncherArt {
    private const val TAG = "VesperLauncherArt"
    private const val W = 640
    private const val H = 360
    private const val WHITE = Color.WHITE
    private val VERSION = Regex("^[0-9a-f]{12,40}$")
    private val NAME = Regex("^[0-9a-f]{12,40}\\.png$")

    /** Team logos decoded this run, by address (they're drawn again at each score). */
    private val logos = object : LruCache<String, Bitmap>(4 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }

    /** Logo addresses that failed (none, too big, not a picture): not tried again for 30 min. */
    private val failed = HashMap<String, Long>()

    fun dir(context: Context) = File(context.filesDir, "launcher_art")

    fun isArtName(name: String) = NAME.matches(name)

    /**
     * [m] with its "image" pointing at its drawn picture when it has one to draw ("art" + "v");
     * the file's name goes into [used]. On any failure [m] as it was (the channel's logo).
     */
    fun withArt(context: Context, m: Map<String, Any?>, used: MutableSet<String>): Map<String, Any?> {
        val art = m["art"] as? Map<*, *> ?: return m
        val version = m["v"] as? String ?: return m
        if (!VERSION.matches(version)) return m
        val name = "$version.png"
        val file = File(dir(context), name)
        try {
            if (!file.isFile) draw(context, art, file)
        } catch (e: Exception) {
            Log.w(TAG, "draw failed", e)
            return m
        }
        used.add(name)
        val uri = Uri.Builder().scheme("content").authority("${context.packageName}.launcherart")
            .appendPath(name).build()
        return m + ("image" to uri.toString())
    }

    /**
     * Pictures no card uses any more. Kept 10 minutes: a launcher may still be loading the
     * previous score's picture. Logos unused for 30 days go too.
     */
    fun prune(context: Context, used: Set<String>) {
        val now = System.currentTimeMillis()
        dir(context).listFiles()?.forEach {
            if (it.name !in used && now - it.lastModified() > 10 * 60_000L) it.delete()
        }
        File(context.cacheDir, "launcher_logos").listFiles()?.forEach {
            if (now - it.lastModified() > 30L * 24 * 3600_000L) it.delete()
        }
    }

    private fun draw(context: Context, art: Map<*, *>, out: File) {
        val bmp = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
        try {
            paint(context, Canvas(bmp), art)
            out.parentFile?.mkdirs()
            val tmp = File(out.parentFile, "${out.name}.tmp")
            FileOutputStream(tmp).use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
            if (!tmp.renameTo(out)) {
                tmp.delete()
                throw IOException("rename failed")
            }
        } finally {
            bmp.recycle()
        }
    }

    private fun paint(context: Context, c: Canvas, art: Map<*, *>) {
        val w = W.toFloat()
        val h = H.toFloat()
        val teams = (art["teams"] as? List<*>)?.filterIsInstance<Map<*, *>>()?.takeIf { it.size == 2 }
        // Each side in its team's colour, dark, meeting in the middle; the brand's dark gold
        // when a team has none (and for events).
        val base = 0xFF121216.toInt()
        val gold = 0xFF3B2F12.toInt()
        val left = teams?.let { teamColour(it[0]["color"]) } ?: gold
        val right = teams?.let { teamColour(it[1]["color"]) } ?: gold
        c.drawRect(0f, 0f, w, h, Paint().apply {
            shader = LinearGradient(
                0f, 0f, w, 0f, intArrayOf(left, base, right), floatArrayOf(0f, 0.5f, 1f),
                Shader.TileMode.CLAMP
            )
        })
        c.drawRect(0f, h * 0.6f, w, h, Paint().apply {
            shader = LinearGradient(
                0f, h * 0.6f, 0f, h, 0x00000000, 0xB0000000.toInt(), Shader.TileMode.CLAMP
            )
        })

        // LIVE, broadcast red (as Home's pill), top left; the league top right.
        val live = (art["live"] as? String)?.takeIf { it.isNotBlank() } ?: "LIVE"
        val pill = text(22f, true, WHITE)
        val pillWidth = pill.measureText(live) + 24f
        c.drawRoundRect(RectF(24f, 22f, 24f + pillWidth, 56f), 7f, 7f,
            Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFFE50914.toInt() })
        c.drawText(live, 36f, 47f, pill)
        (art["league"] as? String)?.takeIf { it.isNotBlank() }?.let { league ->
            val p = text(24f, true, 0xDDFFFFFF.toInt()).apply { textAlign = Paint.Align.RIGHT }
            c.drawText(fit(league, p, w - pillWidth - 80f), w - 24f, 48f, p)
        }

        val status = (art["status"] as? String)?.trim() ?: ""
        if (teams != null) {
            teams.forEachIndexed { i, t ->
                val cx = if (i == 0) w * 0.2f else w * 0.8f
                val cy = 150f
                // A faint disc behind the logo: dark logos stay visible on the dark side.
                c.drawCircle(cx, cy, 84f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x26FFFFFF })
                val name = (t["name"] as? String)?.trim() ?: ""
                val logo = (t["logo"] as? String)?.let { logo(context, it) }
                if (logo != null) {
                    drawFit(c, logo, RectF(cx - 66f, cy - 66f, cx + 66f, cy + 66f))
                } else if (name.isNotEmpty()) {
                    val p = centred(44f, true, WHITE)
                    c.drawText(fit(name, p, 150f), cx, cy + 16f, p)
                }
                if (name.isNotEmpty()) {
                    val p = centred(26f, true, 0xEEFFFFFF.toInt())
                    c.drawText(fit(name, p, 200f), cx, 272f, p)
                }
            }
            val a = teams[0]["score"] as? String
            val b = teams[1]["score"] as? String
            val scored = !a.isNullOrBlank() && !b.isNullOrBlank()
            val p = centred(if (scored) 68f else 44f, true, WHITE)
            c.drawText(fit(if (scored) "$a – $b" else "vs", p, 230f), w / 2f, 172f, p)
            if (status.isNotEmpty()) {
                val sp = centred(24f, false, 0xDDFFFFFF.toInt())
                c.drawText(fit(status, sp, 210f), w / 2f, 214f, sp)
            }
        } else {
            // Golf, racing, a fight card: the league's logo and the event's name.
            val logo = (art["logo"] as? String)?.let { logo(context, it) }
            if (logo != null) drawFit(c, logo, RectF(w / 2f - 70f, 72f, w / 2f + 70f, 206f))
            val title = (art["event"] as? String)?.trim() ?: ""
            val p = centred(32f, true, WHITE)
            c.drawText(fit(title, p, w - 64f), w / 2f, if (logo != null) 250f else 170f, p)
            if (status.isNotEmpty()) {
                val sp = centred(24f, false, 0xDDFFFFFF.toInt())
                c.drawText(fit(status, sp, w - 96f), w / 2f, if (logo != null) 286f else 212f, sp)
            }
        }
        (art["channel"] as? String)?.trim()?.takeIf { it.isNotEmpty() }?.let { channel ->
            val p = centred(24f, false, 0xE6FFFFFF.toInt())
            c.drawText(fit(channel, p, w - 48f), w / 2f, 336f, p)
        }
    }

    private fun text(size: Float, bold: Boolean, colour: Int) = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = size
        color = colour
        typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
    }

    private fun centred(size: Float, bold: Boolean, colour: Int) =
        text(size, bold, colour).apply { textAlign = Paint.Align.CENTER }

    private fun fit(s: String, p: TextPaint, width: Float) =
        TextUtils.ellipsize(s, p, width, TextUtils.TruncateAt.END).toString()

    /** A team's colour ("e30526"), darkened so white text stays readable on it. */
    private fun teamColour(v: Any?): Int? {
        val hex = (v as? String)?.trim()?.removePrefix("#") ?: return null
        if (hex.length != 6) return null
        val rgb = hex.toIntOrNull(16) ?: return null
        fun dark(x: Int) = (x * 0.5f).toInt()
        return Color.rgb(dark(rgb shr 16 and 0xFF), dark(rgb shr 8 and 0xFF), dark(rgb and 0xFF))
    }

    private fun drawFit(c: Canvas, bmp: Bitmap, box: RectF) {
        val scale = minOf(box.width() / bmp.width, box.height() / bmp.height)
        val dw = bmp.width * scale
        val dh = bmp.height * scale
        val dst = RectF(box.centerX() - dw / 2, box.centerY() - dh / 2, box.centerX() + dw / 2, box.centerY() + dh / 2)
        c.drawBitmap(bmp, null, dst, Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
    }

    /** A team / league logo (public ESPN / TheSportsDB pictures), kept on disk for 30 days. */
    private fun logo(context: Context, url: String): Bitmap? {
        if (!url.startsWith("https://") && !url.startsWith("http://")) return null
        logos.get(url)?.let { return it }
        val now = System.currentTimeMillis()
        failed[url]?.let { if (now - it < 30 * 60_000L) return null }
        val dir = File(context.cacheDir, "launcher_logos").apply { mkdirs() }
        val file = File(dir, sha1(url))
        try {
            if (!file.isFile || file.length() == 0L) download(url, file)
            val bmp = decode(file) ?: throw IOException("not a picture")
            file.setLastModified(now)
            logos.put(url, bmp)
            return bmp
        } catch (e: Exception) {
            // SVG logos (BitmapFactory can't read them) end here too: the abbreviation instead.
            failed[url] = now
            file.delete()
            return null
        }
    }

    private fun download(url: String, file: File) {
        val conn = URL(url).openConnection() as HttpURLConnection
        try {
            conn.connectTimeout = 4000
            conn.readTimeout = 5000
            conn.instanceFollowRedirects = true
            if (conn.responseCode != 200) throw IOException("HTTP ${conn.responseCode}")
            val tmp = File(file.parentFile, "${file.name}.tmp")
            conn.inputStream.use { input ->
                FileOutputStream(tmp).use { output ->
                    val buf = ByteArray(16 * 1024)
                    var total = 0
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        total += n
                        if (total > 3 * 1024 * 1024) throw IOException("logo too big")
                        output.write(buf, 0, n)
                    }
                }
            }
            if (!tmp.renameTo(file)) {
                tmp.delete()
                throw IOException("rename failed")
            }
        } finally {
            conn.disconnect()
        }
    }

    /** At most 256 px a side (ESPN's are 500). */
    private fun decode(file: File): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 256) sample *= 2
        return BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample })
    }

    private fun sha1(s: String): String =
        MessageDigest.getInstance("SHA-1").digest(s.toByteArray()).joinToString("") { "%02x".format(it) }
}

/**
 * Serves [LauncherArt]'s pictures to the launcher: `content://<package>.launcherart/<hash>.png`,
 * read only, nothing else (no paths, no other files).
 */
class LauncherArtProvider : ContentProvider() {
    override fun onCreate() = true

    override fun getType(uri: Uri) = "image/png"

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw SecurityException("read only")
        val name = uri.lastPathSegment
        if (uri.pathSegments.size != 1 || name == null || !LauncherArt.isArtName(name)) {
            throw FileNotFoundException("not a card picture")
        }
        val ctx = context ?: throw FileNotFoundException(name)
        val file = File(LauncherArt.dir(ctx), name)
        if (!file.isFile) throw FileNotFoundException(name)
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun query(
        uri: Uri, projection: Array<out String>?, selection: String?,
        selectionArgs: Array<out String>?, sortOrder: String?
    ): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0

    override fun update(
        uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?
    ) = 0
}
