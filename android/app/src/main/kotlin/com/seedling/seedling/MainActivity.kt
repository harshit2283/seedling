package com.twotwoeightthreelabs.seedling

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val screenProtectionChannelName = "com.seedling.app/screen_protection"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register ML Text Analyzer plugin for on-device NLP
        flutterEngine.plugins.add(MLTextAnalyzerPlugin())
        // Register Speech Transcription plugin for on-device voice-to-text
        flutterEngine.plugins.add(SpeechTranscriptionPlugin())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, screenProtectionChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                            result.success(null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
