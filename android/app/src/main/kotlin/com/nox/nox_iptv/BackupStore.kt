package com.nox.nox_iptv

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

/**
 * Settings > Backup & restore (Dart side: `BackupService`). Backups are JSON
 * files in the public Download/VesperTV folder, so they survive an
 * uninstall or "Clear data" and any file manager can copy them off the box.
 *
 * Android 10+ writes through MediaStore (no permission needed); Android 9
 * and older (Fire OS 7 sticks) write the file directly, which needs
 * WRITE_EXTERNAL_STORAGE. Scoped storage only lets an app list the files
 * *it* created, so after a reinstall on Android 11+ the old backups are
 * invisible to [list] — "Restore from a file" ([pick], the system file
 * picker) is the way back in there.
 */
class BackupStore(private val activity: Activity) {
    companion object {
        const val FOLDER = "VesperTV"
        const val PERMISSION_REQUEST = 4711
        const val PICK_REQUEST = 4712
    }

    private var pendingPermission: MethodChannel.Result? = null
    private var pendingPick: MethodChannel.Result? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "hasPermission" -> result.success(missingPermissions(call.argument<Boolean>("write") ?: false).isEmpty())
                "ensurePermission" -> ensurePermission(call.argument<Boolean>("write") ?: false, result)
                "save" -> result.success(save(call.argument<String>("name")!!, call.argument<String>("content")!!))
                "list" -> result.success(list())
                "read" -> result.success(read(call.argument<String>("id")!!))
                "delete" -> result.success(delete(call.argument<String>("id")!!))
                "pick" -> pick(result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("BACKUP_FAILED", e.toString(), null)
        }
    }

    private fun legacyDir(): File =
        File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), FOLDER)

    /** Android 9-: writing (and reading) the folder directly. Android 10:
     *  reading another install's files via `requestLegacyExternalStorage`.
     *  Android 11+: nothing to ask — MediaStore for ours, the picker for others. */
    private fun missingPermissions(write: Boolean): List<String> {
        val needed = when {
            Build.VERSION.SDK_INT <= Build.VERSION_CODES.P -> listOf(Manifest.permission.WRITE_EXTERNAL_STORAGE)
            !write && Build.VERSION.SDK_INT == Build.VERSION_CODES.Q -> listOf(Manifest.permission.READ_EXTERNAL_STORAGE)
            else -> emptyList()
        }
        return needed.filter {
            ContextCompat.checkSelfPermission(activity, it) != PackageManager.PERMISSION_GRANTED
        }
    }

    private fun ensurePermission(write: Boolean, result: MethodChannel.Result) {
        val missing = missingPermissions(write)
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        if (pendingPermission != null) {
            result.success(false)
            return
        }
        pendingPermission = result
        ActivityCompat.requestPermissions(activity, missing.toTypedArray(), PERMISSION_REQUEST)
    }

    fun onPermissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        pendingPermission?.success(grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED })
        pendingPermission = null
        return true
    }

    private fun save(name: String, content: String): String {
        val bytes = content.toByteArray(Charsets.UTF_8)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = activity.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/" + FOLDER)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IOException("MediaStore insert failed")
            resolver.openOutputStream(uri)?.use { it.write(bytes) } ?: throw IOException("Cannot open $uri")
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri.toString()
        }
        val dir = legacyDir()
        if (!dir.exists() && !dir.mkdirs()) throw IOException("Cannot create ${dir.path}")
        val file = File(dir, name)
        file.writeBytes(bytes)
        MediaScannerConnection.scanFile(activity, arrayOf(file.path), null, null)
        return file.path
    }

    private fun list(): List<Map<String, Any>> {
        val byName = linkedMapOf<String, Map<String, Any>>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val projection = arrayOf(
                MediaStore.MediaColumns._ID,
                MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.MediaColumns.DATE_MODIFIED,
                MediaStore.MediaColumns.SIZE,
            )
            val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ? AND ${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ?"
            val args = arrayOf("${Environment.DIRECTORY_DOWNLOADS}/$FOLDER%", "vespertv-%")
            activity.contentResolver.query(MediaStore.Downloads.EXTERNAL_CONTENT_URI, projection, selection, args, null)?.use { c ->
                while (c.moveToNext()) {
                    val name = c.getString(1) ?: continue
                    val uri = ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, c.getLong(0))
                    byName[name] = mapOf(
                        "id" to uri.toString(),
                        "name" to name,
                        "modified" to c.getLong(2) * 1000,
                        "size" to c.getLong(3),
                    )
                }
            }
        }
        // Android 9- (and files another install left behind, where readable).
        try {
            legacyDir().listFiles()
                ?.filter { it.isFile && it.name.startsWith("vespertv-") && it.name.endsWith(".json") && it.canRead() }
                ?.forEach { f ->
                    if (!byName.containsKey(f.name)) {
                        byName[f.name] = mapOf(
                            "id" to f.path,
                            "name" to f.name,
                            "modified" to f.lastModified(),
                            "size" to f.length(),
                        )
                    }
                }
        } catch (_: SecurityException) {
        }
        return byName.values.toList()
    }

    private fun read(id: String): String =
        if (id.startsWith("content://")) {
            activity.contentResolver.openInputStream(Uri.parse(id))?.use { String(it.readBytes(), Charsets.UTF_8) }
                ?: throw IOException("Cannot open $id")
        } else {
            File(id).readText(Charsets.UTF_8)
        }

    private fun delete(id: String): Boolean =
        try {
            if (id.startsWith("content://")) {
                activity.contentResolver.delete(Uri.parse(id), null, null) > 0
            } else {
                File(id).delete()
            }
        } catch (_: SecurityException) {
            false
        }

    /** System file picker; null when cancelled, error NO_PICKER when the
     *  device has none (Fire TV, some Android TV boxes). */
    private fun pick(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.success(null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        pendingPick = result
        try {
            activity.startActivityForResult(intent, PICK_REQUEST)
        } catch (_: ActivityNotFoundException) {
            pendingPick = null
            result.error("NO_PICKER", "No file picker on this device", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_REQUEST) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        try {
            val text = activity.contentResolver.openInputStream(uri)?.use { String(it.readBytes(), Charsets.UTF_8) }
            result.success(text)
        } catch (e: Exception) {
            result.error("BACKUP_FAILED", e.toString(), null)
        }
        return true
    }
}
