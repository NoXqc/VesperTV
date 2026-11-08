package com.nox.nox_iptv

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.tvprovider.media.tv.BasePreviewProgram
import androidx.tvprovider.media.tv.PreviewChannel
import androidx.tvprovider.media.tv.PreviewChannelHelper
import androidx.tvprovider.media.tv.PreviewProgram
import androidx.tvprovider.media.tv.TvContractCompat
import androidx.tvprovider.media.tv.WatchNextProgram
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Settings > Interface > TV home screen: the launcher's Watch Next row (Continue watching,
 * next episodes, Watch list) and our "Favourites" app channel, through Android TV's
 * TvProvider. That is what Projectivy and the stock Android TV home read; Fire OS has it too.
 * Dart (lib/services/launcher_channels.dart) sends the whole wanted set each time; this diffs
 * it against our own rows by internal provider id, so unchanged cards are not rewritten
 * (every write makes the launcher reload). Channel `vespertv/launcher`.
 *
 * A card opens MainActivity with vespertv://launcher/open?k=<key>. Each card has its own
 * link: Projectivy tells cards apart by it (spocky/miproja1#521, an episode card that kept
 * the show's link never changed to the next episode).
 */
class LauncherChannels(activity: Activity) {
    companion object {
        private const val TAG = "VesperLauncher"
        private const val SCHEME = "vespertv"
        private const val HOST = "launcher"
    }

    private val context: Context = activity.applicationContext
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var pendingLink: String? = null

    fun connect(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "vespertv/launcher").also {
            it.setMethodCallHandler(::handle)
        }
    }

    /** The app was opened (or brought back) from one of our cards. */
    fun onIntent(intent: Intent?) {
        val data = intent?.data ?: return
        if (data.scheme != SCHEME || data.host != HOST) return
        pendingLink = data.toString()
        // Once: recreating the activity must not open the card again.
        intent.data = null
        channel?.invokeMethod("link", null)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "supported" -> result.success(supported())
            "hasLink" -> result.success(pendingLink != null)
            "takeLink" -> {
                result.success(pendingLink)
                pendingLink = null
            }
            "publish" -> {
                if (!supported()) {
                    result.success(mapOf("supported" to false))
                    return
                }
                val watchNext = call.argument<List<Map<String, Any?>>>("watchNext")
                val channels = call.argument<List<Map<String, Any?>>>("channels")
                worker.execute {
                    val report: Map<String, Any?> = try {
                        publish(watchNext, channels)
                    } catch (e: Exception) {
                        // No TvProvider on this device ("Unknown URL"), or it refused us.
                        Log.w(TAG, "publish failed", e)
                        mapOf("error" to "${e.javaClass.simpleName}: ${e.message}")
                    }
                    main.post { result.success(report) }
                }
            }
            else -> result.notImplemented()
        }
    }

    /** Preview channels and Watch Next exist from Android 8 on TV devices. */
    private fun supported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val pm = context.packageManager
        return pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            pm.hasSystemFeature(PackageManager.FEATURE_TELEVISION)
    }

    private fun publish(
        watchNext: List<Map<String, Any?>>?,
        channels: List<Map<String, Any?>>?
    ): Map<String, Any?> {
        val report = mutableMapOf<String, Any?>("supported" to true)
        // Null = leave that part as it is (Dart's data for it isn't loaded yet).
        if (watchNext != null) report["watchNext"] = syncWatchNext(watchNext)
        if (channels != null) report["channels"] = syncChannels(channels)
        return report
    }

    private fun syncWatchNext(items: List<Map<String, Any?>>): String {
        val resolver = context.contentResolver
        val existing = HashMap<String, WatchNextProgram>()
        val hidden = HashSet<String>()
        var removed = 0
        resolver.query(
            TvContractCompat.WatchNextPrograms.CONTENT_URI,
            WatchNextProgram.PROJECTION, null, null, null
        )?.use { c ->
            val browsable = c.getColumnIndex(TvContractCompat.PreviewProgramColumns.COLUMN_BROWSABLE)
            while (c.moveToNext()) {
                val p = WatchNextProgram.fromCursor(c)
                val key = p.internalProviderId
                if (key == null || existing.containsKey(key)) {
                    deleteWatchNext(p.id)
                    removed++
                    continue
                }
                existing[key] = p
                // Not readable on some devices: then it counts as shown.
                if (browsable >= 0 && !c.isNull(browsable) && c.getInt(browsable) == 0) {
                    hidden.add(key)
                }
            }
        }
        var added = 0
        var updated = 0
        for (m in items) {
            val key = m["key"] as? String ?: continue
            val wanted = watchNextProgram(m, key)
            val old = existing.remove(key)
            when {
                old == null -> if (insertWatchNext(wanted)) added++
                key in hidden -> {
                    // The viewer removed it in the launcher: it comes back only
                    // once it was watched again since.
                    if (wanted.lastEngagementTimeUtcMillis > old.lastEngagementTimeUtcMillis) {
                        deleteWatchNext(old.id)
                        if (insertWatchNext(wanted)) added++
                    }
                }
                old.hasAnyUpdatedValues(wanted) -> {
                    resolver.update(
                        TvContractCompat.buildWatchNextProgramUri(old.id),
                        wanted.toContentValues(), null, null
                    )
                    updated++
                }
            }
        }
        for (p in existing.values) {
            deleteWatchNext(p.id)
            removed++
        }
        return "${items.size} (+$added ~$updated -$removed)"
    }

    private fun insertWatchNext(program: WatchNextProgram): Boolean =
        context.contentResolver.insert(
            TvContractCompat.WatchNextPrograms.CONTENT_URI, program.toContentValues()
        ) != null

    private fun deleteWatchNext(id: Long) {
        context.contentResolver.delete(TvContractCompat.buildWatchNextProgramUri(id), null, null)
    }

    private fun watchNextProgram(m: Map<String, Any?>, key: String): WatchNextProgram {
        val b = WatchNextProgram.Builder()
            .setWatchNextType(
                when (m["kind"]) {
                    "next" -> TvContractCompat.WatchNextPrograms.WATCH_NEXT_TYPE_NEXT
                    "watchlist" -> TvContractCompat.WatchNextPrograms.WATCH_NEXT_TYPE_WATCHLIST
                    "new" -> TvContractCompat.WatchNextPrograms.WATCH_NEXT_TYPE_NEW
                    else -> TvContractCompat.WatchNextPrograms.WATCH_NEXT_TYPE_CONTINUE
                }
            )
            .setLastEngagementTimeUtcMillis(long(m["engaged"]) ?: System.currentTimeMillis())
        fill(b, m, key)
        return b.build()
    }

    /**
     * What Watch Next and Favourites cards share. Every field is set, null included, so a
     * value that went away (a description, an episode title) is cleared on update.
     */
    private fun fill(b: BasePreviewProgram.Builder<*>, m: Map<String, Any?>, key: String) {
        b.setType(
            when (m["type"]) {
                "episode" -> TvContractCompat.PreviewProgramColumns.TYPE_TV_EPISODE
                "series" -> TvContractCompat.PreviewProgramColumns.TYPE_TV_SERIES
                "channel" -> TvContractCompat.PreviewProgramColumns.TYPE_CHANNEL
                else -> TvContractCompat.PreviewProgramColumns.TYPE_MOVIE
            }
        )
        b.setTitle(m["title"] as? String ?: "")
        b.setDescription(m["description"] as? String)
        b.setEpisodeTitle(m["episodeTitle"] as? String)
        int(m["season"])?.let { b.setSeasonNumber(it) }
        int(m["episode"])?.let { b.setEpisodeNumber(it) }
        b.setPosterArtUri((m["image"] as? String)?.let(Uri::parse))
        b.setPosterArtAspectRatio(
            when (m["aspect"]) {
                "poster" -> TvContractCompat.PreviewProgramColumns.ASPECT_RATIO_MOVIE_POSTER
                "square" -> TvContractCompat.PreviewProgramColumns.ASPECT_RATIO_1_1
                else -> TvContractCompat.PreviewProgramColumns.ASPECT_RATIO_16_9
            }
        )
        int(m["position"])?.let { b.setLastPlaybackPositionMillis(it) }
        int(m["duration"])?.let { b.setDurationMillis(it) }
        b.setInternalProviderId(key)
        b.setIntentUri(cardLink(key))
    }

    private fun syncChannels(specs: List<Map<String, Any?>>): String {
        val helper = PreviewChannelHelper(context)
        val mine = HashMap<String, PreviewChannel>()
        for (c in helper.allChannels) {
            val id = c.internalProviderId ?: continue
            if (c.packageName == null || c.packageName == context.packageName) mine[id] = c
        }
        val out = StringBuilder()
        for (spec in specs) {
            val id = spec["id"] as? String ?: continue
            val name = spec["name"] as? String ?: "VesperTV"
            val items = (spec["items"] as? List<*>)?.filterIsInstance<Map<String, Any?>>()
                ?: emptyList()
            val old = mine.remove(id)
            val channelId: Long
            if (old == null) {
                channelId = helper.publishChannel(
                    PreviewChannel.Builder()
                        .setDisplayName(name)
                        .setInternalProviderId(id)
                        .setAppLinkIntentUri(appLink())
                        .setLogo(appLogo())
                        .build()
                )
                if (channelId <= 0) {
                    out.append("$id not created; ")
                    continue
                }
                // Our first channel: the system shows it without asking.
                try {
                    TvContractCompat.requestChannelBrowsable(context, channelId)
                } catch (e: Exception) {
                    Log.w(TAG, "requestChannelBrowsable", e)
                }
            } else {
                channelId = old.id
                // Logo untouched (not set here); only a new name is written.
                helper.updatePreviewChannel(
                    channelId,
                    PreviewChannel.Builder()
                        .setDisplayName(name)
                        .setInternalProviderId(id)
                        .setAppLinkIntentUri(appLink())
                        .build()
                )
            }
            out.append("$id ").append(syncPrograms(helper, channelId, items)).append("; ")
        }
        // A channel Dart no longer sends (the setting was turned off) leaves the launcher.
        for (c in mine.values) helper.deletePreviewChannel(c.id)
        if (mine.isNotEmpty()) out.append("deleted ${mine.size}")
        return out.toString().trimEnd(' ', ';')
    }

    private fun syncPrograms(
        helper: PreviewChannelHelper,
        channelId: Long,
        items: List<Map<String, Any?>>
    ): String {
        val resolver = context.contentResolver
        val existing = HashMap<String, PreviewProgram>()
        var removed = 0
        resolver.query(
            TvContractCompat.buildPreviewProgramsUriForChannel(channelId),
            PreviewProgram.PROJECTION, null, null, null
        )?.use { c ->
            while (c.moveToNext()) {
                val p = PreviewProgram.fromCursor(c)
                val key = p.internalProviderId
                if (key == null || existing.containsKey(key)) {
                    helper.deletePreviewProgram(p.id)
                    removed++
                } else {
                    existing[key] = p
                }
            }
        }
        var added = 0
        var updated = 0
        items.forEachIndexed { i, m ->
            val key = m["key"] as? String ?: return@forEachIndexed
            // Higher weight = earlier in the row: the app's own order.
            val b = PreviewProgram.Builder().setChannelId(channelId).setWeight(items.size - i)
            fill(b, m, key)
            val wanted = b.build()
            val old = existing.remove(key)
            if (old == null) {
                if (helper.publishPreviewProgram(wanted) > 0) added++
            } else if (old.hasAnyUpdatedValues(wanted)) {
                resolver.update(
                    TvContractCompat.buildPreviewProgramUri(old.id),
                    wanted.toContentValues(), null, null
                )
                updated++
            }
        }
        for (p in existing.values) {
            helper.deletePreviewProgram(p.id)
            removed++
        }
        return "${items.size} (+$added ~$updated -$removed)"
    }

    private fun cardLink(key: String): Uri {
        val data = Uri.Builder().scheme(SCHEME).authority(HOST).path("open")
            .appendQueryParameter("k", key).build()
        val intent = Intent(Intent.ACTION_VIEW, data)
            .setComponent(ComponentName(context, MainActivity::class.java))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME))
    }

    /** The channel row's own link: just opens the app. */
    private fun appLink(): Uri {
        val intent = Intent(Intent.ACTION_MAIN)
            .setComponent(ComponentName(context, MainActivity::class.java))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME))
    }

    private fun appLogo(): Bitmap {
        val icon = context.packageManager.getApplicationIcon(context.packageName)
        val size = 256
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        icon.setBounds(0, 0, size, size)
        icon.draw(Canvas(bitmap))
        return bitmap
    }

    private fun long(v: Any?): Long? = (v as? Number)?.toLong()
    private fun int(v: Any?): Int? = (v as? Number)?.toInt()
}
