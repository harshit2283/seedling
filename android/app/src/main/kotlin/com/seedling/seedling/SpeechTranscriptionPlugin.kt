package com.twotwoeightthreelabs.seedling

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

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
        // Android's SpeechRecognizer transcribes the live microphone, not an
        // audio file, and may stream audio to a cloud service. Seedling only
        // transcribes saved memos on-device, so report unavailable rather than
        // silently recording the room.
        result.success(mapOf(
            "isAvailable" to false,
            "supportsOnDevice" to false,
            "authStatus" to 0
        ))
    }

    private fun transcribeFile(filePath: String, locale: String?, result: Result) {
        result.error(
            "UNAVAILABLE",
            "On-device file transcription is not supported on Android",
            null
        )
    }
}
