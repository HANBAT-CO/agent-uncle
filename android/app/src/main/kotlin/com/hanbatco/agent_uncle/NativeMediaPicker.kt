package com.hanbatco.agent_uncle

import android.content.ActivityNotFoundException
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class NativeMediaPicker(
    private val activity: ComponentActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, DefaultLifecycleObserver {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val galleryLauncher: ActivityResultLauncher<PickVisualMediaRequest>
    private val cameraLauncher: ActivityResultLauncher<Uri>

    private var disposed = false
    private var requestSerial = 0L
    private var activeRequestId: Long? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingCameraFile: File? = null

    init {
        channel.setMethodCallHandler(this)
        activity.lifecycle.addObserver(this)
        galleryLauncher = activity.registerForActivityResult(
            ActivityResultContracts.PickVisualMedia(),
        ) { uri ->
            val requestId = activeRequestId ?: return@registerForActivityResult
            if (uri == null) {
                finishCancelled(requestId)
            } else {
                loadSelectionAsync(uri, requestId = requestId)
            }
        }
        cameraLauncher = activity.registerForActivityResult(
            ActivityResultContracts.TakePicture(),
        ) { success ->
            val requestId = activeRequestId ?: return@registerForActivityResult
            val file = pendingCameraFile
            pendingCameraFile = null
            if (!success || file == null) {
                file?.delete()
                finishCancelled(requestId)
                return@registerForActivityResult
            }
            val uri = FileProvider.getUriForFile(activity, fileProviderAuthority(activity), file)
            loadSelectionAsync(
                uri,
                fallbackName = file.name,
                cleanupFile = file,
                requestId = requestId,
            )
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) {
            result.error("unavailable", "사진 선택기를 더 이상 사용할 수 없어요.", null)
            return
        }
        if (pendingResult != null) {
            result.error("busy", "사진 선택이 이미 진행 중이에요. 잠시 후 다시 시도해 주세요.", null)
            return
        }

        when (call.method) {
            "pickGalleryImage" -> {
                val requestId = beginRequest(result)
                try {
                    galleryLauncher.launch(
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                    )
                } catch (error: Exception) {
                    finishError(
                        requestId,
                        "unavailable",
                        error.message ?: "사진 보관함을 열지 못했어요. 다시 시도해 주세요.",
                    )
                }
            }
            "pickCameraImage" -> {
                val requestId = beginRequest(result)
                launchCamera(requestId)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDestroy(owner: LifecycleOwner) {
        dispose()
    }

    fun dispose() {
        if (disposed) return
        activity.lifecycle.removeObserver(this)
        channel.setMethodCallHandler(null)
        clearPendingCameraFile(delete = true)
        finishCancelled(activeRequestId)
        disposed = true
        galleryLauncher.unregister()
        cameraLauncher.unregister()
        ioExecutor.shutdownNow()
    }

    private fun beginRequest(result: MethodChannel.Result): Long {
        requestSerial += 1
        activeRequestId = requestSerial
        pendingResult = result
        return requestSerial
    }

    private fun launchCamera(requestId: Long) {
        val captureFile = try {
            createCaptureFile(activity)
        } catch (_: IOException) {
            finishError(requestId, "io_error", "카메라용 임시 파일을 만들지 못했어요. 다시 시도해 주세요.")
            return
        }
        pendingCameraFile = captureFile
        val uri = FileProvider.getUriForFile(activity, fileProviderAuthority(activity), captureFile)
        try {
            cameraLauncher.launch(uri)
        } catch (error: ActivityNotFoundException) {
            pendingCameraFile = null
            captureFile.delete()
            finishError(requestId, "unavailable", error.message ?: "이 기기에서는 카메라를 사용할 수 없어요.")
        } catch (error: Exception) {
            pendingCameraFile = null
            captureFile.delete()
            finishError(
                requestId,
                "unavailable",
                error.message ?: "카메라를 열지 못했어요. 다시 시도해 주세요.",
            )
        }
    }

    private fun loadSelectionAsync(
        uri: Uri,
        fallbackName: String? = null,
        cleanupFile: File? = null,
        requestId: Long,
    ) {
        ioExecutor.execute {
            val outcome = try {
                readSelection(uri, fallbackName)
            } catch (_: IOException) {
                ReadOutcome.Error("read_failed", "사진을 불러오지 못했어요. 다시 시도해 주세요.")
            } catch (_: SecurityException) {
                ReadOutcome.Error("read_failed", "사진 접근 권한을 확인한 뒤 다시 시도해 주세요.")
            } catch (_: OutOfMemoryError) {
                ReadOutcome.Error("invalid_size", "10MB 이하 사진을 선택해 주세요.")
            } finally {
                cleanupFile?.delete()
            }

            mainHandler.post {
                when (outcome) {
                    is ReadOutcome.Success -> finishSuccess(requestId, outcome.payload)
                    is ReadOutcome.Error -> finishError(requestId, outcome.code, outcome.message)
                }
            }
        }
    }

    private fun readSelection(uri: Uri, fallbackName: String?): ReadOutcome {
        val contentType = activity.contentResolver.getType(uri)
        val header = readHeader(uri)
        if (header.isEmpty()) {
            return ReadOutcome.Error("read_failed", "사진을 불러오지 못했어요. 다시 시도해 주세요.")
        }

        val detectedMime = detectMimeFromSignature(header)
        if (detectedMime != null) {
            val original = readLimitedBytes(uri)
            if (original.tooLarge) {
                return ReadOutcome.Error("invalid_size", "10MB 이하 사진을 선택해 주세요.")
            }
            if (original.bytes.isEmpty()) {
                return ReadOutcome.Error("read_failed", "사진을 불러오지 못했어요. 다시 시도해 주세요.")
            }
            return ReadOutcome.Success(
                mapOf(
                    "name" to resolveName(uri, fallbackName, detectedMime),
                    "mime" to detectedMime,
                    "bytes" to original.bytes,
                ),
            )
        }

        if (contentType?.startsWith("image/") != true && !looksLikeHeif(header)) {
            return ReadOutcome.Error("unsupported_type", "지원하는 사진 형식을 선택해 주세요.")
        }

        val jpegBytes = transcodeToJpeg(uri)
            ?: return ReadOutcome.Error("unsupported_type", "지원하는 사진 형식을 선택해 주세요.")
        if (jpegBytes.isEmpty() || jpegBytes.size > MAX_BYTES) {
            return ReadOutcome.Error("invalid_size", "10MB 이하 사진을 선택해 주세요.")
        }
        return ReadOutcome.Success(
            mapOf(
                "name" to resolveName(uri, fallbackName, JPEG_MIME),
                "mime" to JPEG_MIME,
                "bytes" to jpegBytes,
            ),
        )
    }

    private fun readHeader(uri: Uri): ByteArray {
        activity.contentResolver.openInputStream(uri)?.use { input ->
            val buffer = ByteArray(HEADER_BYTES)
            val byteCount = input.read(buffer)
            if (byteCount <= 0) return ByteArray(0)
            return buffer.copyOf(byteCount)
        }
        return ByteArray(0)
    }

    private fun readLimitedBytes(uri: Uri): LimitedBytes {
        activity.contentResolver.openInputStream(uri)?.use { input ->
            return readLimitedBytes(input)
        }
        throw IOException("input_stream_unavailable")
    }

    private fun readLimitedBytes(input: InputStream): LimitedBytes {
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        val output = ByteArrayOutputStream()
        var total = 0
        while (true) {
            val readCount = input.read(buffer)
            if (readCount == -1) {
                return LimitedBytes(output.toByteArray(), tooLarge = false)
            }
            total += readCount
            if (total > MAX_BYTES) {
                return LimitedBytes(ByteArray(0), tooLarge = true)
            }
            output.write(buffer, 0, readCount)
        }
    }

    private fun transcodeToJpeg(uri: Uri): ByteArray? {
        val bounds = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        activity.contentResolver.openInputStream(uri)?.use { input ->
            BitmapFactory.decodeStream(input, null, bounds)
            // 크기 조회는 정상적으로도 Bitmap 대신 null을 반환한다.
            Unit
        } ?: return null

        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        val decodeOptions = BitmapFactory.Options().apply {
            inSampleSize = calculateInSampleSize(bounds.outWidth, bounds.outHeight)
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val bitmap = activity.contentResolver.openInputStream(uri)?.use { input ->
            BitmapFactory.decodeStream(input, null, decodeOptions)
        } ?: return null

        return bitmap.useBitmap { image ->
            JPEG_QUALITIES.firstNotNullOfOrNull { quality ->
                val output = ByteArrayOutputStream()
                if (!image.compress(Bitmap.CompressFormat.JPEG, quality, output)) {
                    return@firstNotNullOfOrNull null
                }
                val bytes = output.toByteArray()
                if (bytes.size <= MAX_BYTES) bytes else null
            }
        }
    }

    private fun calculateInSampleSize(width: Int, height: Int): Int {
        var sampleSize = 1
        var sampledWidth = width.toLong()
        var sampledHeight = height.toLong()
        while (
            sampledWidth > MAX_DECODE_DIMENSION ||
                sampledHeight > MAX_DECODE_DIMENSION ||
                sampledWidth * sampledHeight > MAX_DECODE_PIXELS
        ) {
            sampleSize *= 2
            sampledWidth = width / sampleSize.toLong()
            sampledHeight = height / sampleSize.toLong()
        }
        return sampleSize.coerceAtLeast(1)
    }

    private fun detectMimeFromSignature(header: ByteArray): String? =
        when {
            isPng(header) -> PNG_MIME
            isJpeg(header) -> JPEG_MIME
            else -> null
        }

    private fun looksLikeHeif(header: ByteArray): Boolean {
        if (header.size < 12) return false
        if (
            header[4] != 'f'.code.toByte() ||
                header[5] != 't'.code.toByte() ||
                header[6] != 'y'.code.toByte() ||
                header[7] != 'p'.code.toByte()
        ) {
            return false
        }
        val brand = String(header, 8, 4, Charsets.US_ASCII).lowercase(Locale.US)
        return brand in HEIF_BRANDS
    }

    private fun resolveName(uri: Uri, fallbackName: String?, mime: String): String {
        val provided = activity.contentResolver.query(
            uri,
            arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else null
        }
        val candidate = (provided ?: fallbackName ?: "photo").trim().ifEmpty { "photo" }
        val baseName = candidate.substringBeforeLast('.', candidate).ifEmpty { "photo" }
        return "$baseName.${extensionForMime(mime)}"
    }

    private fun extensionForMime(mime: String): String = when (mime) {
        PNG_MIME -> "png"
        else -> "jpg"
    }

    private fun finishSuccess(requestId: Long, payload: Map<String, Any>) {
        if (!isActiveRequest(requestId)) return
        pendingResult?.success(payload)
        clearRequestState()
    }

    private fun finishCancelled(requestId: Long?) {
        if (requestId == null || !isActiveRequest(requestId)) return
        clearPendingCameraFile(delete = true)
        pendingResult?.success(null)
        clearRequestState()
    }

    private fun finishError(requestId: Long, code: String, message: String) {
        if (!isActiveRequest(requestId)) return
        clearPendingCameraFile(delete = true)
        pendingResult?.error(code, message, null)
        clearRequestState()
    }

    private fun isActiveRequest(requestId: Long): Boolean =
        activeRequestId == requestId && pendingResult != null

    private fun clearRequestState() {
        clearPendingCameraFile(delete = true)
        activeRequestId = null
        pendingResult = null
    }

    private fun clearPendingCameraFile(delete: Boolean) {
        val file = pendingCameraFile
        pendingCameraFile = null
        if (delete) {
            file?.delete()
        }
    }

    private sealed interface ReadOutcome {
        data class Success(val payload: Map<String, Any>) : ReadOutcome

        data class Error(val code: String, val message: String) : ReadOutcome
    }

    private data class LimitedBytes(
        val bytes: ByteArray,
        val tooLarge: Boolean,
    )

    companion object {
        private const val CHANNEL = "agent_uncle/native_media_picker"
        private const val MAX_BYTES = 10 * 1024 * 1024
        private const val HEADER_BYTES = 32
        private const val JPEG_MIME = "image/jpeg"
        private const val PNG_MIME = "image/png"
        private const val MAX_DECODE_DIMENSION = 4096L
        private const val MAX_DECODE_PIXELS = 12_000_000L
        private val JPEG_QUALITIES = listOf(92, 84, 76, 68, 60)
        private val HEIF_BRANDS = setOf("heic", "heix", "hevc", "hevx", "mif1", "msf1")

        private fun createCaptureFile(context: Context): File {
            val directory = File(context.cacheDir, "camera").apply { mkdirs() }
            return File.createTempFile("chat-photo-", ".jpg", directory)
        }

        private fun fileProviderAuthority(context: Context): String =
            "${context.packageName}.native_media_picker.fileprovider"

        private fun isPng(header: ByteArray): Boolean =
            header.size >= 8 &&
                header[0] == 0x89.toByte() &&
                header[1] == 0x50.toByte() &&
                header[2] == 0x4E.toByte() &&
                header[3] == 0x47.toByte() &&
                header[4] == 0x0D.toByte() &&
                header[5] == 0x0A.toByte() &&
                header[6] == 0x1A.toByte() &&
                header[7] == 0x0A.toByte()

        private fun isJpeg(header: ByteArray): Boolean =
            header.size >= 3 &&
                header[0] == 0xFF.toByte() &&
                header[1] == 0xD8.toByte() &&
                header[2] == 0xFF.toByte()
    }
}

private inline fun <T> Bitmap.useBitmap(block: (Bitmap) -> T): T =
    try {
        block(this)
    } finally {
        recycle()
    }
