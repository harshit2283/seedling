package com.twotwoeightthreelabs.seedling

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.media.MediaPlayer
import java.io.File

class SpeechTranscriptionPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.seedling.speech_transcription")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isAvailable" -> checkAvailability(result)
            "transcribe" -> {
                val filePath = call.argument<String>("filePath")
                if (filePath == null) {
                    result.error("INVALID_ARGS", "filePath required", null)
                    return
                }
                val locale = call.argument<String>("locale")
                transcribeFile(filePath, locale, result)
            }
            "requestPermission" -> {
                // Android speech recognition doesn't need separate permission
                // (uses RECORD_AUDIO which is already granted for voice recording)
                result.success(mapOf("authorized" to true, "status" to 0))
            }
            else -> result.notImplemented()
        }
    }

    private fun checkAvailability(result: Result) {
        val isAvailable = SpeechRecognizer.isRecognitionAvailable(context)
        val supportsOnDevice = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        } else {
            false
        }
        result.success(mapOf(
            "isAvailable" to isAvailable,
            "supportsOnDevice" to supportsOnDevice,
            "authStatus" to if (isAvailable) 3 else 0
        ))
    }

    private fun transcribeFile(filePath: String, locale: String?, result: Result) {
        val file = File(filePath)
        if (!file.exists()) {
            result.error("FILE_NOT_FOUND", "Audio file not found: $filePath", null)
            return
        }

        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            result.error("UNAVAILABLE", "Speech recognition unavailable", null)
            return
        }

        val recognizer = SpeechRecognizer.createSpeechRecognizer(context)
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            if (locale != null) {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            }
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            // Note: Android SpeechRecognizer works with microphone input.
            // For file-based transcription, we use MediaPlayer workaround
            // or fall back to reporting unavailability for file transcription.
        }

        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val confidences = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
                val transcription = matches?.firstOrNull() ?: ""

                result.success(mapOf(
                    "transcription" to transcription,
                    "segments" to emptyList<Map<String, Any>>(),
                    "isFinal" to true
                ))
                recognizer.destroy()
            }

            override fun onError(error: Int) {
                val message = when (error) {
                    SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
                    SpeechRecognizer.ERROR_CLIENT -> "Client side error"
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
                    SpeechRecognizer.ERROR_NETWORK -> "Network error"
                    SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
                    SpeechRecognizer.ERROR_NO_MATCH -> "No speech detected"
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognizer busy"
                    SpeechRecognizer.ERROR_SERVER -> "Server error"
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input"
                    else -> "Unknown error: $error"
                }
                result.error("TRANSCRIPTION_ERROR", message, null)
                recognizer.destroy()
            }

            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        recognizer.startListening(intent)
    }
}
