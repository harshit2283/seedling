import Flutter
import Foundation

final class MediaFileProtectionPlugin: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.seedling.media/file_protection",
            binaryMessenger: registrar.messenger()
        )
        let instance = MediaFileProtectionPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "protectPath" else {
            result(FlutterMethodNotImplemented)
            return
        }

        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String,
              !path.isEmpty else {
            result(
                FlutterError(
                    code: "INVALID_ARGS",
                    message: "path is required",
                    details: nil
                )
            )
            return
        }

        do {
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: path
            )
            result(nil)
        } catch {
            result(
                FlutterError(
                    code: "FILE_PROTECTION_FAILED",
                    message: error.localizedDescription,
                    details: nil
                )
            )
        }
    }
}
