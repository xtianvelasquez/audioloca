package com.example.audioloca

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull

import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.support.common.FileUtil

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors

import kotlin.math.exp

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.audioloca/emotion"
    
    // Emotion labels
    private val emotionLabels = arrayOf(
        "Anger", "Disgust", "Fear", "Happiness", "Neutral", "Sadness", "Surprise",
    )
    
    // Native components
    private lateinit var tfliteInterpreter: Interpreter
    private lateinit var faceDetector: FaceDetector
    private val executor = Executors.newSingleThreadExecutor()
    private var isInitialized = false
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initEmotionDetector" -> {
                    executor.execute {
                        try {
                            initNativeDetectors()
                            isInitialized = true
                            activity?.runOnUiThread {
                                result.success(true)
                            }
                            Log.d("NativeEmotion", "Detectors initialized successfully")
                        } catch (e: Exception) {
                            Log.e("NativeEmotion", "Initialization failed: ${e.message}")
                            activity?.runOnUiThread {
                                result.error("INIT_ERROR", e.message, null)
                            }
                        }
                    }
                }
                
                "processFrame" -> {
                    if (!isInitialized) {
                        result.error("NOT_INITIALIZED", "Detector not initialized", null)
                        return@setMethodCallHandler
                    }
                    
                    executor.execute {
                        try {
                            val params = call.arguments as Map<String, Any>
                            val processingResult = processFrameNative(params)
                            
                            activity?.runOnUiThread {
                                result.success(processingResult)
                            }
                        } catch (e: Exception) {
                            Log.e("NativeEmotion", "Processing failed: ${e.message}")
                            activity?.runOnUiThread {
                                result.error("PROCESSING_ERROR", e.message, null)
                            }
                        }
                    }
                }
                
                "disposeEmotionDetector" -> {
                    executor.execute {
                        disposeNativeDetectors()
                        activity?.runOnUiThread {
                            result.success(true)
                        }
                    }
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun initNativeDetectors() {
        // 1. Initialize TensorFlow Lite interpreter
        try {
            val model = FileUtil.loadMappedFile(this, "mobilenetv2_rafdb_finetuned.tflite")
            val options = Interpreter.Options()
            options.setNumThreads(4)
            options.setUseNNAPI(true)
            
            tfliteInterpreter = Interpreter(model, options)
            Log.d("NativeEmotion", "TFLite model loaded successfully.")
        } catch (e: Exception) {
            Log.e("NativeEmotion", "Failed to load TFLite model: ${e.message}")
            throw e
        }
        
        // 2. Initialize ML Kit Face Detector
        val faceDetectorOptions = FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
            .setContourMode(FaceDetectorOptions.CONTOUR_MODE_ALL)
            .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
            .build()

        faceDetector = FaceDetection.getClient(faceDetectorOptions)
    }
    
    private fun processFrameNative(params: Map<String, Any>): Map<String, Any> {
        // Extract parameters
        val yPlane = params["yPlane"] as ByteArray
        val uPlane = params["uPlane"] as ByteArray
        val vPlane = params["vPlane"] as ByteArray
        val width = params["width"] as Int
        val height = params["height"] as Int
        val yRowStride = params["yRowStride"] as Int
        val uRowStride = params["uRowStride"] as Int
        val vRowStride = params["vRowStride"] as Int
        val uPixelStride = params["uPixelStride"] as Int
        val vPixelStride = params["vPixelStride"] as Int
        val sensorOrientation = params["sensorOrientation"] as Int
        
        // 1. Convert YUV to NV21
        val nv21Data = convertYUV420ToNV21(
            yPlane, uPlane, vPlane,
            width, height,
            yRowStride, uRowStride, vRowStride,
            uPixelStride, vPixelStride
        )
        
        // 2. Create InputImage for ML Kit
        val inputImage = InputImage.fromByteArray(
            nv21Data,
            width,
            height,
            sensorOrientation,
            InputImage.IMAGE_FORMAT_NV21
        )
        
        // 3. Detect faces using ML Kit (synchronously)
        val faceTask: Task<List<Face>> = faceDetector.process(inputImage)
        
        try {
            // Wait for face detection to complete (with timeout)
            val faces = Tasks.await(faceTask, 500, java.util.concurrent.TimeUnit.MILLISECONDS)
            
            if (faces.isEmpty()) {
                return mapOf(
                    "hasFace" to false,
                    "multipleFaces" to false,
                    "emotion" to "No face detected",
                    "confidence" to 0.0
                )
            } else if (faces.size > 1) {
                return mapOf(
                    "hasFace" to false,
                    "multipleFaces" to true,
                    "emotion" to "Multiple faces detected",
                    "confidence" to 0.0
                )
            }
            
            // Get the largest face
            val largestFace = faces.maxByOrNull { 
                it.boundingBox.width() * it.boundingBox.height()
            } ?: faces[0]
            
            val faceBox = largestFace.boundingBox
            
            // 4. Convert YUV to RGB Bitmap for cropping
            val rgbBitmap = convertYUV420ToRGBBitmap(
                yPlane, uPlane, vPlane,
                width, height,
                yRowStride, uRowStride, vRowStride,
                uPixelStride, vPixelStride
            )

            val matrix = Matrix()
            matrix.postRotate(sensorOrientation.toFloat())
            val rotatedBitmap = Bitmap.createBitmap(
                rgbBitmap, 0, 0, rgbBitmap.width, rgbBitmap.height, matrix, true
            )
            
            // 5. Crop face with padding
            val cropLeft = faceBox.left.coerceAtLeast(0)
            val cropTop = faceBox.top.coerceAtLeast(0)
            val cropRight = faceBox.right.coerceAtMost(rotatedBitmap.width)
            val cropBottom = faceBox.bottom.coerceAtMost(rotatedBitmap.height)

            val croppedBitmap = Bitmap.createBitmap(
                rotatedBitmap,
                cropLeft,
                cropTop,
                cropRight - cropLeft,
                cropBottom - cropTop
            )
            
            // 6. Preprocess for TFLite
            val inputBuffer = preprocessBitmapForTFLite(croppedBitmap)
            
            // 7. Run emotion inference
            val output = Array(1) { FloatArray(emotionLabels.size) }
            tfliteInterpreter.run(inputBuffer, output)
            
            // 8. Process results
            val predictions = output[0]
            val maxIndex = predictions.indices.maxByOrNull { predictions[it] } ?: 0
            val maxValue = predictions[maxIndex]
            
            // Apply softmax
            var sumExp = 0.0f
            for (value in predictions) {
                sumExp += exp(value.toDouble()).toFloat()
            }
            val confidence = exp(predictions[maxIndex].toDouble()).toFloat() / sumExp
            
            // 9. Clean up
            rgbBitmap.recycle()
            croppedBitmap.recycle()
            rotatedBitmap.recycle()
            
            Log.d("NativeEmotion", "Detected: ${emotionLabels[maxIndex]} ($confidence)")
            
            return mapOf(
                "hasFace" to true,
                "multipleFaces" to false,
                "emotion" to emotionLabels[maxIndex],
                "confidence" to confidence.toDouble(),
                "debugInfo" to "Native processing complete"
            )
            
        } catch (e: Exception) {
            Log.e("NativeEmotion", "Face detection failed: ${e.message}")
            return mapOf(
                "hasFace" to false,
                "multipleFaces" to false,
                "emotion" to "Detection error",
                "confidence" to 0.0,
                "debugInfo" to "Error: ${e.message}"
            )
        }
    }
    
    private fun convertYUV420ToNV21(
        yPlane: ByteArray, uPlane: ByteArray, vPlane: ByteArray,
        width: Int, height: Int,
        yRowStride: Int, uRowStride: Int, vRowStride: Int,
        uPixelStride: Int, vPixelStride: Int
    ): ByteArray {
        val ySize = width * height
        val nv21 = ByteArray(ySize + ySize / 2)
        
        // Copy Y plane
        var yIndex = 0
        for (i in 0 until height) {
            System.arraycopy(yPlane, i * yRowStride, nv21, i * width, width)
        }
        
        // Interleave V and U planes (NV21 format: Y + VU)
        var uvIndex = ySize
        for (row in 0 until height / 2) {
            for (col in 0 until width / 2) {
                val uIndex = row * uRowStride + col * uPixelStride
                val vIndex = row * vRowStride + col * vPixelStride
                
                // V then U
                if (vIndex < vPlane.size) nv21[uvIndex++] = vPlane[vIndex]
                if (uIndex < uPlane.size) nv21[uvIndex++] = uPlane[uIndex]
            }
        }
        
        return nv21
    }
    
    private fun convertYUV420ToRGBBitmap(
        yPlane: ByteArray, uPlane: ByteArray, vPlane: ByteArray,
        width: Int, height: Int,
        yRowStride: Int, uRowStride: Int, vRowStride: Int,
        uPixelStride: Int, vPixelStride: Int
    ): Bitmap {
        // First convert to NV21
        val nv21 = convertYUV420ToNV21(
            yPlane, uPlane, vPlane,
            width, height,
            yRowStride, uRowStride, vRowStride,
            uPixelStride, vPixelStride
        )
        
        // Convert NV21 to JPEG bytes
        val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, width, height), 100, out)
        val imageBytes = out.toByteArray()
        
        // Decode JPEG to Bitmap
        return BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
    }
    
    private fun preprocessBitmapForTFLite(bitmap: Bitmap): ByteBuffer {
        val resizedBitmap = Bitmap.createScaledBitmap(bitmap, 224, 224, true)
        val inputBuffer = ByteBuffer.allocateDirect(224 * 224 * 3 * 4)
        inputBuffer.order(ByteOrder.nativeOrder())
        
        val pixels = IntArray(224 * 224)
        resizedBitmap.getPixels(pixels, 0, 224, 0, 0, 224, 224)
        
        for (pixel in pixels) {
            val r = (pixel shr 16) and 0xFF
            val g = (pixel shr 8) and 0xFF
            val b = pixel and 0xFF
            
            inputBuffer.putFloat(r / 127.5f - 1.0f)
            inputBuffer.putFloat(g / 127.5f - 1.0f)
            inputBuffer.putFloat(b / 127.5f - 1.0f)
        }
        
        resizedBitmap.recycle()
        return inputBuffer
    }
    
    private fun disposeNativeDetectors() {
        try {
            tfliteInterpreter.close()
            faceDetector.close()
            isInitialized = false
            Log.d("NativeEmotion", "Native detectors disposed")
        } catch (e: Exception) {
            Log.e("NativeEmotion", "Error disposing detectors: ${e.message}")
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        disposeNativeDetectors()
        executor.shutdown()
    }
}
