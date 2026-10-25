package com.nox.nox_iptv

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Browse user-selected storage and copy import definitions into private storage. */
class LocalImportStore(private val activity: Activity) {
    companion object { const val PICK_FOLDER = 4713 }
    private var pending: MethodChannel.Result? = null
    private val worker = Executors.newSingleThreadExecutor()

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "pickFolder") {
            if (pending != null) { result.error("BUSY", "Storage picker is open", null); return }
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            }
            pending = result
            try { activity.startActivityForResult(intent, PICK_FOLDER) }
            catch (_: ActivityNotFoundException) {
                pending = null
                result.error("NO_PICKER", "No folder picker on this device", null)
            }
            return
        }
        worker.execute {
            try {
                val value: Any? = when (call.method) {
                    "roots" -> {
                        val roots = linkedSetOf(Environment.getExternalStorageDirectory().absolutePath)
                        activity.getExternalFilesDirs(null).filterNotNull().forEach {
                            roots.add(it.absolutePath.substringBefore("/Android/"))
                        }
                        roots.map { mapOf("uri" to File(it).toURI().toString(), "name" to it, "folder" to true) }
                    }
                    "children" -> children(Uri.parse(call.argument<String>("uri")!!))
                    "copyImportFile" -> {
                        val target = File(call.argument<String>("target")!!).canonicalFile
                        require(target.path.startsWith(activity.filesDir.canonicalPath + File.separator))
                        target.parentFile?.mkdirs()
                        activity.contentResolver.openInputStream(Uri.parse(call.argument<String>("uri")!!))!!.use { input ->
                            target.outputStream().use { input.copyTo(it) }
                        }
                        target.path
                    }
                    else -> { activity.runOnUiThread { result.notImplemented() }; return@execute }
                }
                activity.runOnUiThread { result.success(value) }
            } catch (_: Exception) {
                activity.runOnUiThread { result.error("STORAGE_FAILED", "Could not read this storage location", null) }
            }
        }
    }

    fun close() { pending?.success(null); pending = null; worker.shutdown() }

    private fun documentId(uri: Uri): String =
        if (uri.pathSegments.contains("document")) DocumentsContract.getDocumentId(uri)
        else DocumentsContract.getTreeDocumentId(uri)

    private fun children(uri: Uri): List<Map<String, Any>> {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(uri, documentId(uri))
        val fields = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE)
        val out = mutableListOf<Map<String, Any>>()
        activity.contentResolver.query(children, fields, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getString(0)
                out.add(mapOf("uri" to DocumentsContract.buildDocumentUriUsingTree(uri, id).toString(),
                    "name" to (cursor.getString(1) ?: ""),
                    "folder" to (cursor.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR)))
            }
        } ?: error("Storage is unavailable")
        return out
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_FOLDER) return false
        val result = pending ?: return true
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return true }
        try {
            activity.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            val doc = DocumentsContract.buildDocumentUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri))
            var name = ""
            activity.contentResolver.query(doc, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) name = it.getString(0) ?: ""
            }
            result.success(mapOf("uri" to uri.toString(), "name" to name, "folder" to true))
        } catch (_: Exception) { result.error("STORAGE_FAILED", "Could not access this storage location", null) }
        return true
    }
}
