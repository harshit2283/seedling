import Flutter
import Foundation

/// Hardens on-disk memory storage.
///
/// - `protectPath` sets NSFileProtectionCompleteUntilFirstUserAuthentication
///   on a file or directory (optionally on everything inside it, so existing
///   files are covered — new files inherit the directory's class).
/// - `excludeFromBackup` sets NSURLIsExcludedFromBackupKey so iCloud/iTunes
///   backups never contain the database or media.
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
        guard call.method == "protectPath" || call.method == "excludeFromBackup" else {
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

        if call.method == "excludeFromBackup" {
            excludeFromBackup(path: path, result: result)
            return
        }

        let recursive = args["recursive"] as? Bool ?? false
        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
        ]

        do {
            try FileManager.default.setAttributes(attributes, ofItemAtPath: path)
            if recursive, let enumerator = FileManager.default.enumerator(atPath: path) {
                for case let relative as String in enumerator {
                    let child = (path as NSString).appendingPathComponent(relative)
                    try? FileManager.default.setAttributes(attributes, ofItemAtPath: child)
                }
            }
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

    private func excludeFromBackup(path: String, result: @escaping FlutterResult) {
        var url = URL(fileURLWithPath: path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            try url.setResourceValues(values)
            result(nil)
        } catch {
            result(
                FlutterError(
                    code: "BACKUP_EXCLUSION_FAILED",
                    message: error.localizedDescription,
                    details: nil
                )
            )
        }
    }
}
