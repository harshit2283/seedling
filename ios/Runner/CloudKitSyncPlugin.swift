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
/// The legacy `SeedlingEntry` records (default zone, written by earlier
/// builds) are only read, once, so their data migrates.
///
/// Method channel: com.seedling.cloudkit_sync
public class CloudKitSyncPlugin: NSObject, FlutterPlugin {

    // MARK: - Properties

    private let privateDB = CKContainer.default().privateCloudDatabase
    /// Legacy per-entry record type (read-only).
    private let recordType = "SeedlingEntry"
    private let fileRecordType = "SeedlingFile"
    private let zoneID = CKRecordZone.ID(zoneName: "SeedlingSync", ownerName: CKCurrentUserDefaultName)
    private var zoneReady = false

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

        case "fetchLegacyRecords":
            fetchAllRecords(result: result)

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

    // MARK: - Legacy records (read-only migration)

    /// Full fetch: query all SeedlingEntry records (used on first sync)
    private func fetchAllRecords(result: @escaping FlutterResult) {
        let query = CKQuery(
            recordType: recordType,
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]

        var allRecords: [[String: Any]] = []

        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = CKQueryOperation.maximumResults

        operation.recordMatchedBlock = { [weak self] recordID, recordResult in
            guard let self = self else { return }
            switch recordResult {
            case .success(let record):
                allRecords.append(self.recordToDict(record))
            case .failure(_):
                break
            }
        }

        operation.queryResultBlock = { [weak self] operationResult in
            guard let self = self else { return }
            switch operationResult {
            case .success(let cursor):
                if let cursor = cursor {
                    // More results available, fetch them
                    self.fetchRemainingRecords(
                        cursor: cursor,
                        accumulated: allRecords,
                        result: result
                    )
                } else {
                    // All records fetched
                    DispatchQueue.main.async {
                        result([
                            "records": allRecords,
                            "deletedUUIDs": [] as [String],
                            "changeToken": NSNull()
                        ] as [String: Any])
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.handleCKError(error, result: result)
                }
            }
        }

        privateDB.add(operation)
    }

    /// Continue fetching paginated query results
    private func fetchRemainingRecords(
        cursor: CKQueryOperation.Cursor,
        accumulated: [[String: Any]],
        result: @escaping FlutterResult
    ) {
        var allRecords = accumulated

        let operation = CKQueryOperation(cursor: cursor)
        operation.resultsLimit = CKQueryOperation.maximumResults

        operation.recordMatchedBlock = { [weak self] recordID, recordResult in
            guard let self = self else { return }
            switch recordResult {
            case .success(let record):
                allRecords.append(self.recordToDict(record))
            case .failure(_):
                break
            }
        }

        operation.queryResultBlock = { [weak self] operationResult in
            guard let self = self else { return }
            switch operationResult {
            case .success(let nextCursor):
                if let nextCursor = nextCursor {
                    self.fetchRemainingRecords(
                        cursor: nextCursor,
                        accumulated: allRecords,
                        result: result
                    )
                } else {
                    DispatchQueue.main.async {
                        result([
                            "records": allRecords,
                            "deletedUUIDs": [] as [String],
                            "changeToken": NSNull()
                        ] as [String: Any])
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.handleCKError(error, result: result)
                }
            }
        }

        privateDB.add(operation)
    }

    // MARK: - File store (custom zone)

    /// Creates the `SeedlingSync` zone once per launch (saving an existing
    /// zone is a no-op).
    private func ensureZone(_ completion: @escaping (Error?) -> Void) {
        if zoneReady {
            completion(nil)
            return
        }
        let operation = CKModifyRecordZonesOperation(
            recordZonesToSave: [CKRecordZone(zoneID: zoneID)],
            recordZoneIDsToDelete: nil
        )
        operation.modifyRecordZonesCompletionBlock = { [weak self] _, _, error in
            if error == nil {
                self?.zoneReady = true
            }
            completion(error)
        }
        privateDB.add(operation)
    }

    private func fileRecordID(_ id: String) -> CKRecord.ID {
        return CKRecord.ID(recordName: id, zoneID: zoneID)
    }

    /// Lists `[{id, name}]` for every file whose name starts with `prefix`.
    /// A zone-changes fetch from no token returns every record in the zone,
    /// so no queryable index is needed; only the `name` key is downloaded.
    private func fsList(prefix: String, result: @escaping FlutterResult) {
        ensureZone { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async { self.handleCKError(error, result: result) }
                return
            }
            var files: [[String: String]] = []
            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            configuration.previousServerChangeToken = nil
            configuration.desiredKeys = ["name"]
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [self.zoneID],
                configurationsByRecordZoneID: [self.zoneID: configuration]
            )
            operation.fetchAllChanges = true
            operation.recordChangedBlock = { record in
                if record.recordType == self.fileRecordType,
                   let name = record["name"] as? String,
                   name.hasPrefix(prefix) {
                    files.append(["id": record.recordID.recordName, "name": name])
                }
            }
            operation.fetchRecordZoneChangesCompletionBlock = { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.handleCKError(error, result: result)
                        return
                    }
                    result(files)
                }
            }
            self.privateDB.add(operation)
        }
    }

    /// Copies file `id` to `destinationPath`. Returns false if it doesn't exist.
    private func fsRead(id: String, destinationPath: String, result: @escaping FlutterResult) {
        guard isPathWithinAllowedSandbox(destinationPath) else {
            invalidArgs("fsRead", result)
            return
        }
        privateDB.fetch(withRecordID: fileRecordID(id)) { record, error in
            DispatchQueue.main.async {
                if let ckError = error as? CKError,
                   ckError.code == .unknownItem || ckError.code == .zoneNotFound {
                    result(false)
                    return
                }
                if let error = error {
                    self.handleCKError(error, result: result)
                    return
                }
                guard let asset = record?["data"] as? CKAsset,
                      let assetURL = asset.fileURL else {
                    result(false)
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
                    result(true)
                } catch {
                    result(FlutterError(
                        code: "COPY_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    /// Creates or replaces file `id`. Each file has a single writer (a
    /// device's own log) or is immutable (media, keyring), so overwriting
    /// with `.allKeys` is safe and needs no change tag.
    private func fsWrite(id: String, name: String, sourcePath: String, result: @escaping FlutterResult) {
        guard isPathWithinAllowedSandbox(sourcePath),
              FileManager.default.fileExists(atPath: sourcePath) else {
            invalidArgs("fsWrite", result)
            return
        }
        ensureZone { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async { self.handleCKError(error, result: result) }
                return
            }
            let record = CKRecord(recordType: self.fileRecordType, recordID: self.fileRecordID(id))
            record["name"] = name as CKRecordValue
            record["data"] = CKAsset(fileURL: URL(fileURLWithPath: sourcePath))
            let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            operation.modifyRecordsCompletionBlock = { _, _, error in
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

    /// Deletes file `id`; a file that is already gone counts as deleted, so a
    /// retried delete can never jam the push queue.
    private func fsDelete(id: String, result: @escaping FlutterResult) {
        privateDB.delete(withRecordID: fileRecordID(id)) { _, error in
            DispatchQueue.main.async {
                if let ckError = error as? CKError,
                   ckError.code == .unknownItem || ckError.code == .zoneNotFound {
                    result(true)
                    return
                }
                if let error = error {
                    self.handleCKError(error, result: result)
                    return
                }
                result(true)
            }
        }
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

    /// Convert a CKRecord to a dictionary for returning to Dart
    private func recordToDict(_ record: CKRecord) -> [String: Any] {
        var dict: [String: Any] = [:]

        dict["syncUUID"] = record.recordID.recordName

        // String fields
        dict["text"] = record["text"] as? String ?? NSNull()
        dict["title"] = record["title"] as? String ?? NSNull()
        dict["context"] = record["context"] as? String ?? NSNull()
        dict["mood"] = record["mood"] as? String ?? NSNull()
        dict["tags"] = record["tags"] as? String ?? NSNull()
        dict["detectedTheme"] = record["detectedTheme"] as? String ?? NSNull()
        dict["transcription"] = record["transcription"] as? String ?? NSNull()
        dict["mediaPath"] = record["mediaPath"] as? String ?? NSNull()
        dict["deviceId"] = record["deviceId"] as? String ?? NSNull()
        // Only present when the record carried it, so older records that never
        // synced links don't clear local ones.
        if let links = record["manualLinkIds"] as? String {
            dict["manualLinkIds"] = links
        }
        dict["syncEncryptionSalt"] = record["syncEncryptionSalt"] as? String ?? NSNull()
        // Absent (not null) when missing: Dart rejects unversioned records.
        if let version = record["syncEncryptionVersion"] as? Int {
            dict["syncEncryptionVersion"] = version
        }

        // Int fields
        dict["typeIndex"] = record["typeIndex"] as? Int ?? 0

        // Bool/Int fields
        if let isDeleted = record["isDeleted"] as? Int {
            dict["isDeleted"] = isDeleted != 0
        } else {
            dict["isDeleted"] = false
        }

        // Double fields
        dict["sentimentScore"] = record["sentimentScore"] as? Double ?? NSNull()

        // DateTime fields -> milliseconds since epoch for Dart
        if let date = record["createdAt"] as? Date {
            dict["createdAt"] = Int64(date.timeIntervalSince1970 * 1000)
        } else {
            dict["createdAt"] = NSNull()
        }

        if let date = record["modifiedAt"] as? Date {
            dict["modifiedAt"] = Int64(date.timeIntervalSince1970 * 1000)
        } else {
            dict["modifiedAt"] = NSNull()
        }

        if let date = record["deletedAt"] as? Date {
            dict["deletedAt"] = Int64(date.timeIntervalSince1970 * 1000)
        } else {
            dict["deletedAt"] = NSNull()
        }

        if let date = record["capsuleUnlockDate"] as? Date {
            dict["capsuleUnlockDate"] = Int64(date.timeIntervalSince1970 * 1000)
        } else {
            dict["capsuleUnlockDate"] = NSNull()
        }

        // CloudKit metadata: record change tag for conflict detection
        dict["recordChangeTag"] = record.recordChangeTag ?? NSNull()

        // Check for media asset presence
        dict["hasMediaAsset"] = record["mediaAsset"] is CKAsset

        return dict
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
            // Conflict: the server has a newer version of this record.
            // Extract the server record so the Dart layer can perform a merge.
            if let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                let serverDict = recordToDict(serverRecord)
                result(FlutterError(
                    code: "CONFLICT",
                    message: "Server record has changed. Merge required.",
                    details: serverDict
                ))
            } else {
                result(FlutterError(
                    code: "CONFLICT",
                    message: "Server record has changed but could not retrieve server version.",
                    details: nil
                ))
            }

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
