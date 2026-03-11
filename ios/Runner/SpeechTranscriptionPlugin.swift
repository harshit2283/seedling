import Flutter
import Speech

public class SpeechTranscriptionPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.seedling.speech_transcription",
            binaryMessenger: registrar.messenger()
        )
        let instance = SpeechTranscriptionPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            checkAvailability(result: result)
        case "transcribe":
            guard let args = call.arguments as? [String: Any],
                  let filePath = args["filePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "filePath required", details: nil))
                return
            }
            let locale = args["locale"] as? String
            transcribeFile(filePath: filePath, locale: locale, result: result)
        case "requestPermission":
            requestPermission(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func checkAvailability(result: @escaping FlutterResult) {
        let recognizer = SFSpeechRecognizer()
        let isAvailable = recognizer?.isAvailable ?? false
        let supportsOnDevice: Bool
        if #available(iOS 13.0, *) {
            supportsOnDevice = recognizer?.supportsOnDeviceRecognition ?? false
        } else {
            supportsOnDevice = false
        }
        result([
            "isAvailable": isAvailable,
            "supportsOnDevice": supportsOnDevice,
            "authStatus": SFSpeechRecognizer.authorizationStatus().rawValue
        ])
    }

    private func requestPermission(result: @escaping FlutterResult) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                result([
                    "authorized": status == .authorized,
                    "status": status.rawValue
                ])
            }
        }
    }

    private func transcribeFile(filePath: String, locale: String?, result: @escaping FlutterResult) {
        let recognizerLocale = locale != nil ? Locale(identifier: locale!) : nil
        let recognizer: SFSpeechRecognizer?
        if let loc = recognizerLocale {
            recognizer = SFSpeechRecognizer(locale: loc)
        } else {
            recognizer = SFSpeechRecognizer()
        }

        guard let speechRecognizer = recognizer, speechRecognizer.isAvailable else {
            result(FlutterError(code: "UNAVAILABLE", message: "Speech recognition unavailable", details: nil))
            return
        }

        let url = URL(fileURLWithPath: filePath)
        let request = SFSpeechURLRecognitionRequest(url: url)

        // Prefer on-device recognition for privacy
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
        }

        speechRecognizer.recognitionTask(with: request) { [weak self] taskResult, error in
            guard self != nil else { return }

            if let error = error {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "TRANSCRIPTION_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
                return
            }

            guard let taskResult = taskResult else { return }

            if taskResult.isFinal {
                let transcription = taskResult.bestTranscription.formattedString
                let segments = taskResult.bestTranscription.segments.map { segment -> [String: Any] in
                    return [
                        "substring": segment.substring,
                        "timestamp": segment.timestamp,
                        "duration": segment.duration,
                        "confidence": segment.confidence
                    ]
                }
                DispatchQueue.main.async {
                    result([
                        "transcription": transcription,
                        "segments": segments,
                        "isFinal": true
                    ])
                }
            }
        }
    }
}
