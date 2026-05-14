package com.example.flutter_application_aifit

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.SystemClock
import android.util.Log
import androidx.exifinterface.media.ExifInterface
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.ByteArrayInputStream

class MainActivity : FlutterActivity() {
    private val tag = "AIFITPose"
    private var poseLandmarker: PoseLandmarker? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "aifit/pose_landmarker"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "detectImage" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null) {
                        result.error("NO_IMAGE", "Image bytes are required.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        Log.d(tag, "detectImage called. bytes=${bytes.size}")
                        result.success(detectPoseFromImage(bytes))
                    } catch (e: Exception) {
                        Log.e(tag, "Pose detection failed", e)
                        result.error("POSE_ERROR", e.message, null)
                    }
                }

                "detectYuvFrame" -> {
                    try {
                        val width = call.argument<Int>("width")
                        val height = call.argument<Int>("height")
                        val rotationDegrees = call.argument<Int>("rotationDegrees") ?: 0
                        val planes = call.argument<List<ByteArray>>("planes")
                        val bytesPerRow = call.argument<List<Int>>("bytesPerRow")
                        val bytesPerPixel = call.argument<List<Int>>("bytesPerPixel")

                        if (
                            width == null ||
                            height == null ||
                            planes == null ||
                            bytesPerRow == null ||
                            bytesPerPixel == null ||
                            planes.size < 3 ||
                            bytesPerRow.size < 3 ||
                            bytesPerPixel.size < 3
                        ) {
                            result.error("NO_FRAME", "YUV frame data is invalid.", null)
                            return@setMethodCallHandler
                        }

                        result.success(
                            detectPoseFromYuvFrame(
                                width,
                                height,
                                rotationDegrees,
                                planes,
                                bytesPerRow,
                                bytesPerPixel
                            )
                        )
                    } catch (e: Exception) {
                        Log.e(tag, "Pose stream detection failed", e)
                        result.error("POSE_STREAM_ERROR", e.message, null)
                    }
                }

                "close" -> {
                    poseLandmarker?.close()
                    poseLandmarker = null
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun getPoseLandmarker(): PoseLandmarker {
        poseLandmarker?.let { return it }

        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("pose_landmarker_full.task")
            .build()

        val options = PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.VIDEO)
            .setNumPoses(1)
            .setMinPoseDetectionConfidence(0.6f)
            .setMinPosePresenceConfidence(0.6f)
            .setMinTrackingConfidence(0.6f)
            .build()

        return PoseLandmarker.createFromOptions(this, options).also {
            poseLandmarker = it
        }
    }

    private fun detectPoseFromImage(bytes: ByteArray): Map<String, Any> {
        val decoded = decodeBitmapWithExif(bytes)

        val resized = resizeBitmap(decoded, maxSize = 1024)
        val bitmap =
            if (resized.config == Bitmap.Config.ARGB_8888) {
                resized
            } else {
                resized.copy(Bitmap.Config.ARGB_8888, false)
            }

        Log.d(tag, "bitmap=${bitmap.width}x${bitmap.height}")

        val mpImage = BitmapImageBuilder(bitmap).build()
        val detection = getPoseLandmarker().detectForVideo(mpImage, SystemClock.uptimeMillis())

        val imageLandmarks = detection.landmarks().firstOrNull()
        val worldLandmarks = detection.worldLandmarks().firstOrNull()

        Log.d(
            tag,
            "poseFound=${imageLandmarks != null && worldLandmarks != null}, " +
                "image=${imageLandmarks?.size ?: 0}, world=${worldLandmarks?.size ?: 0}"
        )

        return mapOf(
            "poseFound" to (imageLandmarks != null && worldLandmarks != null),
            "imageWidth" to bitmap.width,
            "imageHeight" to bitmap.height,
            "imageLandmarks" to imageLandmarks.orEmpty().map { landmark ->
                mapOf(
                    "x" to landmark.x(),
                    "y" to landmark.y(),
                    "z" to landmark.z(),
                    "visibility" to landmark.visibility().orElse(0.0f)
                )
            },
            "worldLandmarks" to worldLandmarks.orEmpty().map { landmark ->
                mapOf(
                    "x" to landmark.x(),
                    "y" to landmark.y(),
                    "z" to landmark.z(),
                    "visibility" to landmark.visibility().orElse(0.0f)
                )
            }
        )
    }

    private fun detectPoseFromYuvFrame(
        width: Int,
        height: Int,
        rotationDegrees: Int,
        planes: List<ByteArray>,
        bytesPerRow: List<Int>,
        bytesPerPixel: List<Int>
    ): Map<String, Any> {
        val nv21 = yuv420ToNv21(width, height, planes, bytesPerRow, bytesPerPixel)
        val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
        val jpegStream = ByteArrayOutputStream()

        yuvImage.compressToJpeg(Rect(0, 0, width, height), 80, jpegStream)

        val decoded = BitmapFactory.decodeByteArray(
            jpegStream.toByteArray(),
            0,
            jpegStream.size()
        ) ?: throw IllegalArgumentException("Could not decode YUV frame.")

        val rotated = rotateBitmap(decoded, rotationDegrees)
        val resized = resizeBitmap(rotated, maxSize = 640)
        val bitmap =
            if (resized.config == Bitmap.Config.ARGB_8888) {
                resized
            } else {
                resized.copy(Bitmap.Config.ARGB_8888, false)
            }

        val mpImage = BitmapImageBuilder(bitmap).build()
        val detection = getPoseLandmarker().detectForVideo(mpImage, SystemClock.uptimeMillis())
        val imageLandmarks = detection.landmarks().firstOrNull()
        val worldLandmarks = detection.worldLandmarks().firstOrNull()

        return mapOf(
            "poseFound" to (imageLandmarks != null && worldLandmarks != null),
            "imageWidth" to bitmap.width,
            "imageHeight" to bitmap.height,
            "imageLandmarks" to imageLandmarks.orEmpty().map { landmark ->
                mapOf(
                    "x" to landmark.x(),
                    "y" to landmark.y(),
                    "z" to landmark.z(),
                    "visibility" to landmark.visibility().orElse(0.0f)
                )
            },
            "worldLandmarks" to worldLandmarks.orEmpty().map { landmark ->
                mapOf(
                    "x" to landmark.x(),
                    "y" to landmark.y(),
                    "z" to landmark.z(),
                    "visibility" to landmark.visibility().orElse(0.0f)
                )
            }
        )
    }

    private fun yuv420ToNv21(
        width: Int,
        height: Int,
        planes: List<ByteArray>,
        bytesPerRow: List<Int>,
        bytesPerPixel: List<Int>
    ): ByteArray {
        val ySize = width * height
        val nv21 = ByteArray(ySize + ySize / 2)

        val yPlane = planes[0]
        val uPlane = planes[1]
        val vPlane = planes[2]

        val yRowStride = bytesPerRow[0]
        var outputOffset = 0
        for (row in 0 until height) {
            val inputOffset = row * yRowStride
            System.arraycopy(yPlane, inputOffset, nv21, outputOffset, width)
            outputOffset += width
        }

        val chromaHeight = height / 2
        val chromaWidth = width / 2
        val uRowStride = bytesPerRow[1]
        val vRowStride = bytesPerRow[2]
        val uPixelStride = bytesPerPixel[1].coerceAtLeast(1)
        val vPixelStride = bytesPerPixel[2].coerceAtLeast(1)

        var chromaOutputOffset = ySize
        for (row in 0 until chromaHeight) {
            for (col in 0 until chromaWidth) {
                val uIndex = row * uRowStride + col * uPixelStride
                val vIndex = row * vRowStride + col * vPixelStride
                nv21[chromaOutputOffset++] = vPlane[vIndex]
                nv21[chromaOutputOffset++] = uPlane[uIndex]
            }
        }

        return nv21
    }

    private fun rotateBitmap(bitmap: Bitmap, rotationDegrees: Int): Bitmap {
        val normalizedRotation = ((rotationDegrees % 360) + 360) % 360
        if (normalizedRotation == 0) return bitmap

        val matrix = Matrix()
        matrix.postRotate(normalizedRotation.toFloat())
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun decodeBitmapWithExif(bytes: ByteArray): Bitmap {
        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw IllegalArgumentException("Could not decode image.")

        val orientation = ExifInterface(ByteArrayInputStream(bytes)).getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL
        )

        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.preScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.preScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.postRotate(90f)
                matrix.preScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.postRotate(270f)
                matrix.preScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
        }

        return if (matrix.isIdentity) {
            decoded
        } else {
            Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        }
    }

    private fun resizeBitmap(bitmap: Bitmap, maxSize: Int): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        val longSide = maxOf(width, height)

        if (longSide <= maxSize) {
            return bitmap
        }

        val scale = maxSize.toFloat() / longSide.toFloat()
        val resizedWidth = (width * scale).toInt().coerceAtLeast(1)
        val resizedHeight = (height * scale).toInt().coerceAtLeast(1)

        return Bitmap.createScaledBitmap(bitmap, resizedWidth, resizedHeight, false)
    }

    override fun onDestroy() {
        poseLandmarker?.close()
        poseLandmarker = null
        super.onDestroy()
    }
}
