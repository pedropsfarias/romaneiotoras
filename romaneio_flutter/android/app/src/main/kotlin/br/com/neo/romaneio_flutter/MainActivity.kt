package br.com.neo.romaneio_flutter

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.DocumentsContract
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "romaneio_flutter/downloads"
    private val filesChannelName = "romaneio_flutter/files"
    private var folderResult: MethodChannel.Result? = null
    private var selectedTreeUri: Uri? = null
    private val folderRequestCode = 7401

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "writeMasterFile") {
                    val filename = call.argument<String>("filename")
                    val bytes = call.argument<ByteArray>("bytes")
                    val treeUri = selectedTreeUri
                    if (filename.isNullOrBlank() || bytes == null || treeUri == null) {
                        result.error("PERMISSION_DENIED", "A pasta não está disponível para gravação.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val treeId = DocumentsContract.getTreeDocumentId(treeUri)
                        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, treeId)
                        var target: Uri? = null
                        contentResolver.query(
                            childrenUri,
                            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                            null, null, null
                        )?.use { cursor ->
                            val idIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                            val nameIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                            while (cursor.moveToNext()) {
                                if (filename == cursor.getString(nameIndex)) {
                                    target = DocumentsContract.buildDocumentUriUsingTree(treeUri, cursor.getString(idIndex))
                                    break
                                }
                            }
                        }
                        if (target == null) {
                            target = DocumentsContract.createDocument(
                                contentResolver, treeUri,
                                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", filename
                            )
                        }
                        val output = target ?: throw SecurityException("Não foi possível criar o arquivo mestre")
                        contentResolver.openOutputStream(output, "wt")?.use { it.write(bytes) }
                            ?: throw SecurityException("Não foi possível gravar o arquivo mestre")
                        result.success(null)
                    } catch (error: SecurityException) {
                        result.error("PERMISSION_DENIED", error.message, null)
                    } catch (error: Exception) {
                        result.error("MASTER_WRITE_FAILED", error.message, null)
                    }
                    return@setMethodCallHandler
                }
                if (call.method != "saveToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val filename = call.argument<String>("filename")
                val bytes = call.argument<ByteArray>("bytes")
                if (filename.isNullOrBlank() || bytes == null) {
                    result.error("INVALID_ARGUMENT", "Arquivo inválido", null)
                    return@setMethodCallHandler
                }
                try {
                    if (bytes.isEmpty()) throw IllegalArgumentException("Arquivo vazio")
                    val resolver = contentResolver
                    val values = ContentValues().apply {
                        put(MediaStore.Downloads.DISPLAY_NAME, filename)
                        put(MediaStore.Downloads.MIME_TYPE, if (filename.endsWith(".pdf")) "application/pdf" else "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                            put(MediaStore.Downloads.IS_PENDING, 1)
                        }
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        resolver.query(MediaStore.Downloads.EXTERNAL_CONTENT_URI, arrayOf(MediaStore.Downloads._ID), "${MediaStore.Downloads.DISPLAY_NAME}=? AND ${MediaStore.Downloads.RELATIVE_PATH}=?", arrayOf(filename, Environment.DIRECTORY_DOWNLOADS + "/"), null)?.use { cursor ->
                            while (cursor.moveToNext()) resolver.delete(MediaStore.Downloads.EXTERNAL_CONTENT_URI, "${MediaStore.Downloads._ID}=?", arrayOf(cursor.getString(0)))
                        }
                    }
                    val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: throw IllegalStateException("Não foi possível criar o arquivo")
                    resolver.openOutputStream(uri)?.use { it.write(bytes) } ?: throw IllegalStateException("Não foi possível gravar o arquivo")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        resolver.update(uri, ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }, null, null)
                    }
                    val savedBytes = resolver.openInputStream(uri)?.use { it.readBytes() }
                        ?: throw IllegalStateException("Não foi possível validar o arquivo salvo")
                    if (!savedBytes.contentEquals(bytes)) {
                        resolver.delete(uri, null, null)
                        throw IllegalStateException("O arquivo salvo não corresponde ao Excel gerado")
                    }
                    result.success(uri.toString())
                } catch (error: Exception) {
                    result.error("DOWNLOAD_FAILED", error.message, null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, filesChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "selectFolderFiles") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (folderResult != null) {
                    result.error("BUSY", "Já existe uma seleção em andamento.", null)
                    return@setMethodCallHandler
                }
                folderResult = result
                try {
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                        addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                        addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                    }
                    startActivityForResult(intent, folderRequestCode)
                } catch (error: Exception) {
                    folderResult = null
                    result.error("SELECT_FOLDER_FAILED", error.message, null)
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != folderRequestCode) return
        val result = folderResult ?: return
        folderResult = null
        if (resultCode != RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
                    val treeUri = data.data!!
        selectedTreeUri = treeUri
        try {
            val grantedFlags = data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            contentResolver.takePersistableUriPermission(
                treeUri,
                if (grantedFlags != 0) grantedFlags else Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
            val documentId = DocumentsContract.getTreeDocumentId(treeUri)
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, documentId)
            val files = mutableListOf<Map<String, Any>>()
            contentResolver.query(
                childrenUri,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE
                ),
                null,
                null,
                null
            )?.use { cursor ->
                val idIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                val nameIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                val mimeIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
                while (cursor.moveToNext()) {
                    val name = cursor.getString(nameIndex) ?: continue
                    val mimeType = cursor.getString(mimeIndex) ?: continue
                    if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR) continue
                    if (!name.lowercase().endsWith(".xlsx")) continue
                    if (name.startsWith("~$") || name.lowercase().startsWith("romaneio_r-")) continue
                    val childUri = DocumentsContract.buildDocumentUriUsingTree(
                        treeUri,
                        cursor.getString(idIndex)
                    )
                    val bytes = contentResolver.openInputStream(childUri)?.use { it.readBytes() }
                        ?: throw SecurityException("Não foi possível ler $name")
                    files.add(
                        mapOf(
                            "name" to name,
                            "mimeType" to mimeType,
                            "bytes" to bytes
                        )
                    )
                }
            } ?: throw SecurityException("Não foi possível listar a pasta")
            result.success(files)
        } catch (error: SecurityException) {
            result.error("PERMISSION_DENIED", error.message, null)
        } catch (error: Exception) {
            result.error("FOLDER_READ_FAILED", error.message, null)
        }
    }
}
