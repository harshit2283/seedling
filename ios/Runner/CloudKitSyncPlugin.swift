import Flutter
import CloudKit

/// Native iOS CloudKit sync plugin for Seedling.
///
/// CloudKit is used as a small private file store, exactly like Google
/// Drive's appData folder: the Dart layer (DriveSyncLogStore) keeps one
/// change log per device, a keyring and encrypted media blobs as files. Every
/// file is a `SeedlingFile` record (field `name` + CKAsset `data`) in the
/// custom zone `SeedlingSync` of the private database. Everything the plugin
/// stores is already encrypted by Dart; deletions travel as tombstones inside
/// the logs, so no CloudKit change tokens are needed.
///
/// Method channel: com.seedling.cloudkit_sync
public class CloudKitSyncPlugin: NSObject, FlutterPlugin {

    // MARK: - Properties

    private let privateDB = CKContainer.default().privateCloudDatabase
    private let fileRecordType = "SeedlingFile"
    private let zoneID = CKRecordZone.ID(zoneName: "SeedlingSync", ownerName: CKCurrentUserDefaultName)

    /// Whether the custom zone is known to exist. Read and written from
    /// CloudKit callback queues, so guarded by a lock.
    private let zoneLock = NSLock()
    private var _zoneReady = false
    private var zoneReady: Bool {
        get { zoneLock.lock(); defer { zoneLock.unlock() }; return _zoneReady }
        set { zoneLock.lock(); _zoneReady = newValue; zoneLock.unlock() }
    }

    /// Per-request and whole-operation timeouts. CloudKit's default resource
    /// timeout is 7 days, which would outlive the Dart-side timeout and keep
    /// working on files Dart has already given up on.
    private let requestTimeout: TimeInterval = 60
    private let metadataTimeout: TimeInterval = 120
    private let transferTimeout: TimeInterval = 600

    // MARK: - Plugin Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.seedling.cloudkit_sync",
            binaryMessenger: registrar.messenger()
        )
        let instance = CloudKitSyncPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // MARK: - Method Dispatch

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "isAvailable":
            checkAvailability(result: result)

        case "getAccountStatus":
            getAccountStatus(result: result)

        case "fsList":
            guard let prefix = args["prefix"] as? String else {
                invalidArgs(call.method, result)
                return
            }
            fsList(prefix: prefix, result: result)

        case "fsRead":
            guard let id = args["id"] as? String,
                  let destinationPath = args["destinationPath"] as? String else {
                invalidArgs(call.method, result)
                return
            }
            fsRead(id: id, destinationPath: destinationPath, result: result)

        case "fsWrite":
            guard let id = args["id"] as? String,
                  let name = args["name"] as? String,
                  let sourcePath = args["sourcePath"] as? String else {
                invalidArgs(call.method, result)
                return
            }
            fsWrite(id: id, name: name, sourcePath: sourcePath, result: result)

        case "fsExists":
            guard let id = args["id"] as? String else {
                invalidArgs(call.method, result)
                return
            }
            fsExists(id: id, result: result)

        case "fsDelete":
            guard let id = args["id"] as? String else {
                invalidArgs(call.method, result)
                return
            }
            fsDelete(id: id, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func invalidArgs(_ method: String, _ result: @escaping FlutterResult) {
        result(FlutterError(
            code: "INVALID_ARGS",
            message: "Missing or invalid arguments for \(method)",
            details: nil
        ))
    }

    // MARK: - isAvailable

    /// Check whether iCloud is available on this device
    private func checkAvailability(result: @escaping FlutterResult) {
        CKContainer.default().accountStatus { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(
                        code: "ACCOUNT_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                    return
                }
                result(status == .available)
            }
        }
    }

    // MARK: - getAccountStatus

    /// Return human-readable iCloud account status
    private func getAccountStatus(result: @escaping FlutterResult) {
        CKContainer.default().accountStatus { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(
                        code: "ACCOUNT_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                    return
                }
                let statusString: String
                switch status {
                case .available:
                    statusString = "available"
                case .noAccount:
                    statusString = "noAccount"
                case .restricted:
                    statusString = "restricted"
                case .couldNotDetermine:
                    statusString = "couldNotDetermine"
                case .temporarilyUnavailable:
                    statusString = "temporarilyUnavailable"
                @unknown default:
                    statusString = "unknown"
                }
                result(statusString)
            }
        }
    }

    // MARK: - File store (custom zone)

    private func configure(_ operation: CKOperation, resource: TimeInterval) {
        operation.configuration.timeoutIntervalForRequest = requestTimeout
        operation.configuration.timeoutIntervalForResource = resource
    }

    private func fileRecordID(_ id: String) -> CKRecord.ID {
        return CKRecord.ID(recordName: id, zoneID: zoneID)
    }

    private static let zoneGoneCodes: Set<CKError.Code> = [.zoneNotFound, .userDeletedZone]

    /// The CKError code for `id`, looking inside partial failures.
    private func errorCode(_ error: Error?, for id: CKRecord.ID? = nil) -> CKError.Code? {
        guard let ckError = error as? CKError else { return nil }
        if ckError.code == .partialFailure, let partial = ckError.partialErrorsByItemID {
            if let id = id, let itemError = partial[id] as? CKError {
                return itemError.code
            }
            if let first = partial.values.first as? CKError {
                return first.code
            }
        }
        return ckError.code
    }

    /// Forget that the zone exists when CloudKit says it is gone, so the next
    /// call recreates it.
    private func noteZoneError(_ error: Error?, for id: CKRecord.ID? = nil) {
        if let code = errorCode(error, for: id), Self.zoneGoneCodes.contains(code) {
            zoneReady = false
        }
    }

    private func isMissing(_ error: Error?, for id: CKRecord.ID) -> Bool {
        guard let code = errorCode(error, for: id) else { return false }
        return code == .unknownItem || Self.zoneGoneCodes.contains(code)
    }

    /// Creates the `SeedlingSync` zone if needed (saving an existing zone is
    /// a no-op).
    private func ensureZone(_ completion: @escaping (Error?) -> Void) {
        if zoneReady {
            completion(nil)
            return
        }
        let operation = CKModifyRecordZonesOperation(
            recordZonesToSave: [CKRecordZone(zoneID: zoneID)],
            recordZoneIDsToDelete: nil
        )
        configure(operation, resource: metadataTimeout)
        operation.modifyRecordZonesCompletionBlock = { [weak self] _, _, error in
            if error == nil {
                self?.zoneReady = true
            }
            completion(error)
        }
        privateDB.add(operation)
    }

    private func fileInfo(_ record: CKRecord) -> [String: Any]? {
        guard let name = record["name"] as? String else { return nil }
        var info: [String: Any] = ["id": record.recordID.recordName, "name": name]
        if let created = record.creationDate {
            info["createdAt"] = Int64(created.timeIntervalSince1970 * 1000)
        }
        return info
    }

    /// Lists `[{id, name, createdAt}]` for files whose name starts with
    /// `prefix`. A zone-changes fetch from no token returns every record in
    /// the zone without needing a queryable index; only `name` is
    /// downloaded. Used for pulls and maintenance only - single files are
    /// looked up by id (`fsExists`).
    private func fsList(prefix: String, result: @escaping FlutterResult) {
        ensureZone { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.noteZoneError(error)
                DispatchQueue.main.async { self.handleCKError(error, result: result) }
                return
            }
            let lock = NSLock()
            var files: [[String: Any]] = []
            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            configuration.previousServerChangeToken = nil
            configuration.desiredKeys = ["name"]
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [self.zoneID],
                configurationsByRecordZoneID: [self.zoneID: configuration]
            )
            self.configure(operation, resource: self.metadataTimeout)
            operation.fetchAllChanges = true
            operation.recordChangedBlock = { record in
                guard record.recordType == self.fileRecordType,
                      let info = self.fileInfo(record),
                      let name = info["name"] as? String,
                      name.hasPrefix(prefix) else { return }
                lock.lock()
                files.append(info)
                lock.unlock()
            }
            operation.fetchRecordZoneChangesCompletionBlock = { error in
                if let code = self.errorCode(error), Self.zoneGoneCodes.contains(code) {
                    // Zone gone: nothing to list; it is recreated on write.
                    self.zoneReady = false
                    DispatchQueue.main.async { result([] as [[String: Any]]) }
                    return
                }
                DispatchQueue.main.async {
                    if let error = error {
                        self.handleCKError(error, result: result)
                        return
                    }
                    lock.lock()
                    let snapshot = files
                    lock.unlock()
                    result(snapshot)
                }
            }
            self.privateDB.add(operation)
        }
    }

    /// `{id, name, createdAt}` for file `id`, or nil if it doesn't exist.
    private func fsExists(id: String, result: @escaping FlutterResult) {
        let recordID = fileRecordID(id)
        let operation = CKFetchRecordsOperation(recordIDs: [recordID])
        operation.desiredKeys = ["name"]
        configure(operation, resource: metadataTimeout)
        operation.fetchRecordsCompletionBlock = { [weak self] records, error in
            guard let self = self else { return }
            self.noteZoneError(error, for: recordID)
            if let record = records?[recordID] {
                let info = self.fileInfo(record)
                DispatchQueue.main.async { result(info) }
                return
            }
            if error == nil || self.isMissing(error, for: recordID) {
                DispatchQueue.main.async { result(nil) }
                return
            }
            DispatchQueue.main.async { self.handleCKError(error!, result: result) }
        }
        privateDB.add(operation)
    }

    /// Copies file `id` to `destinationPath`; returns false if it doesn't
    /// exist. The asset is copied inside the completion block: CloudKit only
    /// guarantees the downloaded file while the block runs, and copying on
    /// the main thread would block the UI for large files.
    private func fsRead(id: String, destinationPath: String, result: @escaping FlutterResult) {
        guard isPathWithinAllowedSandbox(destinationPath) else {
            invalidArgs("fsRead", result)
            return
        }
        let recordID = fileRecordID(id)
        let operation = CKFetchRecordsOperation(recordIDs: [recordID])
        configure(operation, resource: transferTimeout)
        operation.fetchRecordsCompletionBlock = { [weak self] records, error in
            guard let self = self else { return }
            self.noteZoneError(error, for: recordID)
            guard let record = records?[recordID] else {
                if error == nil || self.isMissing(error, for: recordID) {
                    DispatchQueue.main.async { result(false) }
                } else {
                    DispatchQueue.main.async { self.handleCKError(error!, result: result) }
                }
                return
            }
            guard let asset = record["data"] as? CKAsset, let assetURL = asset.fileURL else {
                DispatchQueue.main.async { result(false) }
                return
            }
            let destination = URL(fileURLWithPath: destinationPath)
            do {
                try FileManager.default.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                if FileManager.default.fileExists(atPath: destinationPath) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: assetURL, to: destination)
                DispatchQueue.main.async { result(true) }
            } catch {
                let message = error.localizedDescription
                DispatchQueue.main.async {
                    result(FlutterError(code: "COPY_ERROR", message: message, details: nil))
                }
            }
        }
        privateDB.add(operation)
    }

    /// Creates or replaces file `id`. Each file has a single writer (a
    /// device's own log) or is written once per id (media, keyring), so
    /// overwriting with `.allKeys` is safe and needs no change tag.
    private func fsWrite(id: String, name: String, sourcePath: String, result: @escaping FlutterResult) {
        guard isPathWithinAllowedSandbox(sourcePath),
              FileManager.default.fileExists(atPath: sourcePath) else {
            invalidArgs("fsWrite", result)
            return
        }
        ensureZone { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.noteZoneError(error)
                DispatchQueue.main.async { self.handleCKError(error, result: result) }
                return
            }
            let recordID = self.fileRecordID(id)
            let record = CKRecord(recordType: self.fileRecordType, recordID: recordID)
            record["name"] = name as CKRecordValue
            record["data"] = CKAsset(fileURL: URL(fileURLWithPath: sourcePath))
            let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            self.configure(operation, resource: self.transferTimeout)
            operation.modifyRecordsCompletionBlock = { _, _, error in
                self.noteZoneError(error, for: recordID)
                DispatchQueue.main.async {
                    if let error = error {
                        self.handleCKError(error, result: result)
                        return
                    }
                    result(true)
                }
            }
            self.privateDB.add(operation)
        }
    }

    /// Deletes file `id`; a file (or zone) that is already gone counts as
    /// deleted, so a retried delete can never jam the push queue.
    private func fsDelete(id: String, result: @escaping FlutterResult) {
        let recordID = fileRecordID(id)
        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordID])
        configure(operation, resource: metadataTimeout)
        operation.modifyRecordsCompletionBlock = { [weak self] _, _, error in
            guard let self = self else { return }
            self.noteZoneError(error, for: recordID)
            DispatchQueue.main.async {
                if error == nil || self.isMissing(error, for: recordID) {
                    result(true)
                    return
                }
                self.handleCKError(error!, result: result)
            }
        }
        privateDB.add(operation)
    }

    // MARK: - Helpers

    private func isPathWithinAllowedSandbox(_ path: String) -> Bool {
        let destinationURL = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let fileManager = FileManager.default

        var allowedRoots: [URL] = [fileManager.temporaryDirectory]
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            allowedRoots.append(documentsURL)
        }
        if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            allowedRoots.append(cachesURL)
        }
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            allowedRoots.append(appSupportURL)
        }

        let destinationPath = destinationURL.path
        return allowedRoots.contains { root in
            let rootPath = root.resolvingSymlinksInPath().path
            return destinationPath == rootPath || destinationPath.hasPrefix(rootPath + "/")
        }
    }

    // MARK: - Error Handling

    /// Handle CloudKit errors with specific error codes for the Dart layer
    private func handleCKError(_ error: Error, result: @escaping FlutterResult) {
        guard let ckError = error as? CKError else {
            result(FlutterError(
                code: "UNKNOWN_ERROR",
                message: error.localizedDescription,
                details: nil
            ))
            return
        }

        switch ckError.code {
        case .notAuthenticated:
            result(FlutterError(
                code: "NOT_AUTHENTICATED",
                message: "User is not signed into iCloud. Please sign in via Settings.",
                details: nil
            ))

        case .quotaExceeded:
            result(FlutterError(
                code: "QUOTA_EXCEEDED",
                message: "iCloud storage quota exceeded. Please free up iCloud space.",
                details: nil
            ))

        case .networkUnavailable, .networkFailure:
            result(FlutterError(
                code: "NETWORK_UNAVAILABLE",
                message: "Network is unavailable. Changes will sync when connectivity is restored.",
                details: nil
            ))

        case .serverRecordChanged:
            result(FlutterError(
                code: "CONFLICT",
                message: "Server record has changed.",
                details: nil
            ))

        case .unknownItem:
            result(FlutterError(
                code: "RECORD_NOT_FOUND",
                message: "Record does not exist in CloudKit.",
                details: nil
            ))

        case .requestRateLimited:
            // Extract retry-after if available
            let retryAfter = ckError.userInfo[CKErrorRetryAfterKey] as? Double
            result(FlutterError(
                code: "RATE_LIMITED",
                message: "Request rate limited. Retry after \(retryAfter ?? 30) seconds.",
                details: retryAfter != nil ? ["retryAfterSeconds": retryAfter!] : nil
            ))

        case .zoneBusy:
            let retryAfter = ckError.userInfo[CKErrorRetryAfterKey] as? Double
            result(FlutterError(
                code: "ZONE_BUSY",
                message: "CloudKit zone is busy. Retry after \(retryAfter ?? 30) seconds.",
                details: retryAfter != nil ? ["retryAfterSeconds": retryAfter!] : nil
            ))

        case .partialFailure:
            // Extract per-item errors for batch operations
            if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
                var errorDetails: [String: String] = [:]
                for (recordID, itemError) in partialErrors {
                    errorDetails[recordID.recordName] = itemError.localizedDescription
                }
                result(FlutterError(
                    code: "PARTIAL_FAILURE",
                    message: "Some records failed to sync.",
                    details: errorDetails
                ))
            } else {
                result(FlutterError(
                    code: "PARTIAL_FAILURE",
                    message: "Partial failure occurred.",
                    details: nil
                ))
            }

        case .serviceUnavailable:
            let retryAfter = ckError.userInfo[CKErrorRetryAfterKey] as? Double
            result(FlutterError(
                code: "SERVICE_UNAVAILABLE",
                message: "iCloud is temporarily unavailable.",
                details: retryAfter != nil ? ["retryAfterSeconds": retryAfter!] : nil
            ))

        case .changeTokenExpired:
            // The stored change token is no longer valid; Dart should do a full fetch
            result(FlutterError(
                code: "CHANGE_TOKEN_EXPIRED",
                message: "Change token expired. A full sync is required.",
                details: nil
            ))

        case .badContainer, .missingEntitlement:
            result(FlutterError(
                code: "CONFIGURATION_ERROR",
                message: "CloudKit container is misconfigured. Check entitlements and container ID.",
                details: nil
            ))

        case .incompatibleVersion:
            result(FlutterError(
                code: "INCOMPATIBLE_VERSION",
                message: "App version is incompatible with the CloudKit schema.",
                details: nil
            ))

        case .assetFileNotFound:
            result(FlutterError(
                code: "ASSET_NOT_FOUND",
                message: "Asset file not found in CloudKit.",
                details: nil
            ))

        case .assetNotAvailable:
            result(FlutterError(
                code: "ASSET_UNAVAILABLE",
                message: "Asset is not currently available for download.",
                details: nil
            ))

        default:
            result(FlutterError(
                code: "CLOUDKIT_ERROR",
                message: "CloudKit error (\(ckError.code.rawValue)): \(ckError.localizedDescription)",
                details: ["errorCode": ckError.code.rawValue]
            ))
        }
    }
}
