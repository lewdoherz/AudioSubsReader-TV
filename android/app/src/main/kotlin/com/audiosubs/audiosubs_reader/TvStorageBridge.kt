package com.audiosubs.audiosubs_reader.tv

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

/** All enumeration/copy/stat operations run away from the platform UI thread. */
class TvStorageBridge(private val activity: Activity, private val channel: MethodChannel) {
    private val io = Executors.newSingleThreadExecutor()
    private val cacheRoot = File(activity.cacheDir, "reading-book-import")
    private var documentResult: MethodChannel.Result? = null
    private var permissionResult: MethodChannel.Result? = null
    private var detached = false

    init { channel.setMethodCallHandler(::handle) }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickDocument" -> pickDocument(result)
            "requestDownloadPermission" -> {
                if (activity.checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED) {
                    result.success(true)
                } else if (permissionResult != null) {
                    result.error("busy", "A storage permission request is already open.", null)
                } else {
                    permissionResult = result
                    activity.requestPermissions(arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE), PERMISSION_REQUEST)
                }
            }
            "listDownloads" -> background(result) {
                val relative = call.argument<String>("relativePath") ?: ""
                val folder = downloadFile(relative)
                if (!folder.isDirectory) throw IOException("Download folder is unavailable.")
                val entries = folder.listFiles() ?: throw IOException("Cannot read this Download folder.")
                entries.filter { file ->
                    file.canonicalFile == file.absoluteFile &&
                        (file.isDirectory || (file.isFile && file.name.endsWith(".abook", true)))
                }.sortedWith(compareBy<File>({ !it.isDirectory }, { it.name.lowercase() })).map { file ->
                    mapOf("name" to file.name,
                        "relativePath" to if (relative.isEmpty()) file.name else "$relative/${file.name}",
                        "directory" to file.isDirectory)
                }
            }
            "downloadSource" -> background(result) {
                val file = downloadFile(call.argument<String>("relativePath") ?: "")
                if (!file.isFile || !file.name.endsWith(".abook", true)) throw IOException("Select an .abook file.")
                file.path
            }
            "freeBytes" -> background(result) {
                val file = File(call.argument<String>("path") ?: throw IOException("Missing storage path.")).canonicalFile
                val appRoot = activity.filesDir.parentFile!!.canonicalFile
                if (!inside(file, appRoot)) throw IOException("Storage path is outside this application.")
                StatFs(file.path).availableBytes
            }
            "releaseSource" -> background(result) {
                val file = File(call.argument<String>("path") ?: throw IOException("Missing cached source.")).canonicalFile
                if (!inside(file, cacheRoot.canonicalFile) || file == cacheRoot.canonicalFile) {
                    throw IOException("Source is not an app-owned import copy.")
                }
                if (file.exists() && !file.delete()) throw IOException("Cannot remove temporary import copy.")
                null
            }
            "recoverCache" -> background(result) {
                if (cacheRoot.exists() && !cacheRoot.deleteRecursively()) throw IOException("Cannot clear abandoned import copies.")
                if (!cacheRoot.mkdirs() && !cacheRoot.isDirectory) throw IOException("Cannot create import cache.")
                null
            }
            else -> result.notImplemented()
        }
    }

    private fun inside(file: File, root: File) = file == root || file.path.startsWith(root.path + File.separator)

    private fun downloadFile(relative: String): File {
        if (activity.checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            throw IOException("Download access was denied. Choose the system document picker or allow storage access.")
        }
        if (relative.startsWith("/") || relative.contains('\\') ||
            relative.split('/').any { it == ".." || it == "." }) throw IOException("Invalid Download path.")
        val root = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).canonicalFile
        val requested = if (relative.isEmpty()) root else File(root, relative)
        val canonical = requested.canonicalFile
        if (!inside(canonical, root) || canonical != requested.absoluteFile) throw IOException("Download links are not supported.")
        return canonical
    }

    private fun pickDocument(result: MethodChannel.Result) {
        if (documentResult != null) { result.error("busy", "A document picker is already open.", null); return }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            documentResult = result
            activity.startActivityForResult(intent, DOCUMENT_REQUEST)
        } catch (_: ActivityNotFoundException) {
            documentResult = null
            result.error("no_document_provider", "No system document picker is installed. Use Browse Download folder instead.", null)
        } catch (error: Exception) {
            documentResult = null
            result.error("document_picker", error.message ?: "Cannot open document picker.", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != DOCUMENT_REQUEST) return false
        val result = documentResult ?: return true
        documentResult = null
        if (resultCode != Activity.RESULT_OK) { result.success(null); return true }
        val uri = data?.data
        if (uri == null || uri.scheme != "content") {
            result.error("invalid_document", "The document provider did not return a readable content URI.", null)
            return true
        }
        background(result) { copyDocument(uri) }
        return true
    }

    private fun copyDocument(uri: Uri): String {
        if (!cacheRoot.mkdirs() && !cacheRoot.isDirectory) throw IOException("Cannot create import cache.")
        var size: Long? = null
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.SIZE)
            if (cursor.moveToFirst() && index >= 0 && !cursor.isNull(index)) size = cursor.getLong(index).takeIf { it >= 0 }
        }
        if ((size ?: 0L) > MAX_PACKAGE_BYTES) throw IOException("Compressed package exceeds 64 GiB.")
        requireSpace(size ?: 0L)
        val target = File.createTempFile("source-", ".abook", cacheRoot)
        try {
            activity.contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    var copied = 0L
                    var checkedAt = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        copied += count
                        if (copied > MAX_PACKAGE_BYTES) throw IOException("Compressed package exceeds 64 GiB.")
                        // Recheck actual free space for unknown/misreported provider lengths too.
                        if (copied - checkedAt >= 1024 * 1024 || checkedAt == 0L) {
                            requireSpace(count.toLong())
                            checkedAt = copied
                        }
                        output.write(buffer, 0, count)
                    }
                    output.flush()
                    if (size != null && copied != size) throw IOException("The document copy was truncated or changed during import.")
                }
            } ?: throw IOException("The document provider could not open this book.")
            return target.path
        } catch (error: Exception) {
            target.delete()
            throw error
        }
    }

    private fun requireSpace(remaining: Long) {
        if (StatFs(cacheRoot.path).availableBytes < remaining + RESERVE_BYTES) {
            throw IOException("Not enough storage to copy this book. Space for the compressed copy plus 64 MiB is required.")
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        permissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
        permissionResult = null
        return true
    }

    private fun background(result: MethodChannel.Result, operation: () -> Any?) {
        io.execute {
            try {
                val value = operation()
                activity.runOnUiThread { if (!detached) result.success(value) }
            } catch (error: Exception) {
                activity.runOnUiThread {
                    if (!detached) result.error("storage_error", error.message ?: "Storage operation failed.", null)
                }
            }
        }
    }

    fun detach() {
        detached = true
        channel.setMethodCallHandler(null)
        documentResult?.error("activity_detached", "Document picker was closed.", null)
        permissionResult?.error("activity_detached", "Storage permission request was closed.", null)
        documentResult = null
        permissionResult = null
        io.shutdown()
    }

    companion object {
        private const val DOCUMENT_REQUEST = 4101
        private const val PERMISSION_REQUEST = 4102
        private const val RESERVE_BYTES = 64L * 1024 * 1024
        private const val MAX_PACKAGE_BYTES = 64L * 1024 * 1024 * 1024
    }
}
