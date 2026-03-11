import Flutter
import CloudKit

/// Native iOS CloudKit sync plugin for Seedling
///
/// Provides iCloud Private Database sync using the default record zone.
/// All sensitive text fields are expected to be encrypted by the Dart layer
/// before reaching this plugin. This plugin handles CloudKit record CRUD,
/// change token management, and CKAsset upload/download.
///
/// Method channel: com.seedling.cloudkit_sync
public class CloudKitSyncPlugin: NSObject, FlutterPlugin {

    // MARK: - Properties

    private let privateDB = CKContainer.default().privateCloudDatabase
    private let recordType = "SeedlingEntry"

    /// All entry fields stored in CloudKit records
    private static let entryFieldKeys: [String] = [
        "syncUUID", "typeIndex", "createdAt", "modifiedAt",
        "text", "title", "context", "mood", "tags",
        "isDeleted", "deletedAt", "detectedTheme", "sentimentScore",
        "capsuleUnlockDate", "transcription", "mediaPath", "deviceId"
    ]
    private static let assetFieldAllowlist: Set<String> = ["mediaAsset"]

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
        switch call.method {
        case "isAvailable":
            checkAvailability(result: result)

        case "getAccountStatus":
            getAccountStatus(result: result)

        case "saveRecord":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "saveRecord requires a Map argument",
                    details: nil
                ))
                return
            }
            saveRecord(args: args, result: result)

        case "deleteRecord":
            guard let args = call.arguments as? [String: Any],
                  let syncUUID = args["syncUUID"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "deleteRecord requires syncUUID",
                    details: nil
                ))
                return
            }
            deleteRecord(syncUUID: syncUUID, result: result)

        case "fetchChanges":
            let args = call.arguments as? [String: Any]
            let changeTokenBase64 = args?["changeToken"] as? String
            fetchChanges(changeTokenBase64: changeTokenBase64, result: result)

        case "uploadAsset":
            guard let args = call.arguments as? [String: Any],
                  let syncUUID = args["syncUUID"] as? String,
                  let filePath = args["filePath"] as? String,
                  let fieldName = args["fieldName"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "uploadAsset requires syncUUID, filePath, and fieldName",
                    details: nil
                ))
                return
            }
            uploadAsset(syncUUID: syncUUID, filePath: filePath, fieldName: fieldName, result: result)

        case "downloadAsset":
            guard let args = call.arguments as? [String: Any],
                  let syncUUID = args["syncUUID"] as? String,
                  let fieldName = args["fieldName"] as? String,
                  let destinationPath = args["destinationPath"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "downloadAsset requires syncUUID, fieldName, and destinationPath",
                    details: nil
                ))
                return
            }
            downloadAsset(
                syncUUID: syncUUID,
                fieldName: fieldName,
                destinationPath: destinationPath,
                result: result
            )

        default:
            result(FlutterMethodNotImplemented)
        }
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

    // MARK: - saveRecord

    /// Save or update a CKRecord in the private database.
    /// Uses syncUUID as the CKRecord.ID name for deterministic lookups.
    private func saveRecord(args: [String: Any], result: @escaping FlutterResult) {
        guard let syncUUID = args["syncUUID"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "syncUUID is required",
                details: nil
            ))
            return
        }

        let recordID = CKRecord.ID(recordName: syncUUID)

        // First fetch the existing record so we can update it (preserving the
        // server change tag), or create a new one if it does not exist.
        privateDB.fetch(withRecordID: recordID) { [weak self] existingRecord, fetchError in
            guard let self = self else { return }

            let record: CKRecord
            if let existing = existingRecord {
                record = existing
            } else {
                // If the fetch failed because the record doesn't exist, create new
                record = CKRecord(recordType: self.recordType, recordID: recordID)
            }

            // Populate fields from args
            self.populateRecord(record, from: args)

            self.privateDB.save(record) { savedRecord, saveError in
                DispatchQueue.main.async {
                    if let saveError = saveError {
                        self.handleCKError(saveError, result: result)
                        return
                    }
                    guard let savedRecord = savedRecord else {
                        result(FlutterError(
                            code: "SAVE_FAILED",
                            message: "Record saved but returned nil",
                            details: nil
                        ))
                        return
                    }
                    result(self.recordToDict(savedRecord))
                }
            }
        }
    }

    // MARK: - deleteRecord

    /// Delete a CKRecord by syncUUID from the private database
    private func deleteRecord(syncUUID: String, result: @escaping FlutterResult) {
        let recordID = CKRecord.ID(recordName: syncUUID)

        privateDB.delete(withRecordID: recordID) { deletedRecordID, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.handleCKError(error, result: result)
                    return
                }
                result(true)
            }
        }
    }

    // MARK: - fetchChanges

    /// Fetch changes from CloudKit.
    ///
    /// If a changeToken is provided (base64-encoded), uses CKFetchDatabaseChangesOperation
    /// and CKFetchRecordZoneChangesOperation to get incremental changes.
    /// If no changeToken is provided, performs a full fetch using CKQuery.
    private func fetchChanges(changeTokenBase64: String?, result: @escaping FlutterResult) {
        if let tokenBase64 = changeTokenBase64,
           let tokenData = Data(base64Encoded: tokenBase64),
           let token = try? NSKeyedUnarchiver.unarchivedObject(
               ofClass: CKServerChangeToken.self,
               from: tokenData
           ) {
            fetchIncrementalChanges(previousToken: token, result: result)
        } else {
            fetchAllRecords(result: result)
        }
    }

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

    /// Incremental fetch using database and record zone change tokens
    private func fetchIncrementalChanges(
        previousToken: CKServerChangeToken,
        result: @escaping FlutterResult
    ) {
        var changedZoneIDs: [CKRecordZone.ID] = []
        var fetchedRecords: [[String: Any]] = []
        var deletedUUIDs: [String] = []
        var newDatabaseToken: CKServerChangeToken?

        // Step 1: Fetch database-level changes to find which zones changed
        let dbChangesOp = CKFetchDatabaseChangesOperation(
            previousServerChangeToken: previousToken
        )
        dbChangesOp.fetchAllChanges = true

        dbChangesOp.recordZoneWithIDChangedBlock = { zoneID in
            changedZoneIDs.append(zoneID)
        }

        dbChangesOp.recordZoneWithIDWasDeletedBlock = { _ in
            // Zone deleted - unlikely for default zone but handle gracefully
        }

        dbChangesOp.recordZoneWithIDWasPurgedBlock = { _ in
            // Zone purged
        }

        dbChangesOp.fetchDatabaseChangesResultBlock = { [weak self] operationResult in
            guard let self = self else { return }

            switch operationResult {
            case .success(let (serverChangeToken, _)):
                newDatabaseToken = serverChangeToken

                if changedZoneIDs.isEmpty {
                    // No changes in any zone
                    DispatchQueue.main.async {
                        let tokenBase64 = self.encodeChangeToken(serverChangeToken)
                        result([
                            "records": [] as [[String: Any]],
                            "deletedUUIDs": [] as [String],
                            "changeToken": tokenBase64 ?? NSNull()
                        ] as [String: Any])
                    }
                    return
                }

                // Step 2: Fetch record-level changes from changed zones
                self.fetchRecordZoneChanges(
                    zoneIDs: changedZoneIDs,
                    databaseToken: serverChangeToken,
                    result: result
                )

            case .failure(let error):
                DispatchQueue.main.async {
                    self.handleCKError(error, result: result)
                }
            }
        }

        privateDB.add(dbChangesOp)
    }

    /// Fetch record-level changes from the specified zones
    private func fetchRecordZoneChanges(
        zoneIDs: [CKRecordZone.ID],
        databaseToken: CKServerChangeToken,
        result: @escaping FlutterResult
    ) {
        var fetchedRecords: [[String: Any]] = []
        var deletedUUIDs: [String] = []

        // Build per-zone configurations (no per-zone tokens for default zone)
        var zoneConfigurations: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration] = [:]
        for zoneID in zoneIDs {
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = nil // We track at database level
            zoneConfigurations[zoneID] = config
        }

        let zoneChangesOp = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: zoneIDs,
            configurationsByRecordZoneID: zoneConfigurations
        )
        zoneChangesOp.fetchAllChanges = true

        zoneChangesOp.recordWasChangedBlock = { [weak self] recordID, recordResult in
            guard let self = self else { return }
            switch recordResult {
            case .success(let record):
                if record.recordType == self.recordType {
                    fetchedRecords.append(self.recordToDict(record))
                }
            case .failure(_):
                break
            }
        }

        zoneChangesOp.recordWithIDWasDeletedBlock = { recordID, recordType in
            if recordType == self.recordType {
                deletedUUIDs.append(recordID.recordName)
            }
        }

        zoneChangesOp.fetchRecordZoneChangesResultBlock = { [weak self] operationResult in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch operationResult {
                case .success:
                    let tokenBase64 = self.encodeChangeToken(databaseToken)
                    result([
                        "records": fetchedRecords,
                        "deletedUUIDs": deletedUUIDs,
                        "changeToken": tokenBase64 ?? NSNull()
                    ] as [String: Any])

                case .failure(let error):
                    self.handleCKError(error, result: result)
                }
            }
        }

        privateDB.add(zoneChangesOp)
    }

    // MARK: - uploadAsset

    /// Attach a CKAsset from a local file to an existing record
    private func uploadAsset(
        syncUUID: String,
        filePath: String,
        fieldName: String,
        result: @escaping FlutterResult
    ) {
        guard Self.assetFieldAllowlist.contains(fieldName) else {
            result(FlutterError(
                code: "INVALID_FIELD",
                message: "Field '\(fieldName)' is not allowed for asset upload",
                details: nil
            ))
            return
        }

        let fileURL = URL(fileURLWithPath: filePath)

        guard FileManager.default.fileExists(atPath: filePath) else {
            result(FlutterError(
                code: "FILE_NOT_FOUND",
                message: "File does not exist at path: \(filePath)",
                details: nil
            ))
            return
        }

        let recordID = CKRecord.ID(recordName: syncUUID)

        privateDB.fetch(withRecordID: recordID) { [weak self] existingRecord, fetchError in
            guard let self = self else { return }

            if let fetchError = fetchError {
                DispatchQueue.main.async {
                    self.handleCKError(fetchError, result: result)
                }
                return
            }

            guard let record = existingRecord else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "RECORD_NOT_FOUND",
                        message: "No record found with syncUUID: \(syncUUID)",
                        details: nil
                    ))
                }
                return
            }

            let asset = CKAsset(fileURL: fileURL)
            record[fieldName] = asset

            self.privateDB.save(record) { savedRecord, saveError in
                DispatchQueue.main.async {
                    if let saveError = saveError {
                        self.handleCKError(saveError, result: result)
                        return
                    }
                    result(true)
                }
            }
        }
    }

    // MARK: - downloadAsset

    /// Download a CKAsset from a record to a local file path
    private func downloadAsset(
        syncUUID: String,
        fieldName: String,
        destinationPath: String,
        result: @escaping FlutterResult
    ) {
        guard Self.assetFieldAllowlist.contains(fieldName) else {
            result(FlutterError(
                code: "INVALID_FIELD",
                message: "Field '\(fieldName)' is not allowed for asset download",
                details: nil
            ))
            return
        }

        guard isPathWithinAllowedSandbox(destinationPath) else {
            result(FlutterError(
                code: "INVALID_DESTINATION",
                message: "destinationPath is outside the app sandbox allowlist",
                details: nil
            ))
            return
        }

        let recordID = CKRecord.ID(recordName: syncUUID)

        privateDB.fetch(withRecordID: recordID) { existingRecord, fetchError in
            DispatchQueue.main.async {
                if let fetchError = fetchError {
                    self.handleCKError(fetchError, result: result)
                    return
                }

                guard let record = existingRecord else {
                    result(FlutterError(
                        code: "RECORD_NOT_FOUND",
                        message: "No record found with syncUUID: \(syncUUID)",
                        details: nil
                    ))
                    return
                }

                guard let asset = record[fieldName] as? CKAsset,
                      let assetURL = asset.fileURL else {
                    result(FlutterError(
                        code: "ASSET_NOT_FOUND",
                        message: "No asset found in field '\(fieldName)' for record \(syncUUID)",
                        details: nil
                    ))
                    return
                }

                let destinationURL = URL(fileURLWithPath: destinationPath)

                // Ensure the parent directory exists
                let parentDir = destinationURL.deletingLastPathComponent()
                do {
                    try FileManager.default.createDirectory(
                        at: parentDir,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                } catch {
                    result(FlutterError(
                        code: "DIR_ERROR",
                        message: "Failed to create directory: \(error.localizedDescription)",
                        details: nil
                    ))
                    return
                }

                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destinationPath) {
                    try? FileManager.default.removeItem(atPath: destinationPath)
                }

                do {
                    try FileManager.default.copyItem(at: assetURL, to: destinationURL)
                    result(destinationPath)
                } catch {
                    result(FlutterError(
                        code: "COPY_ERROR",
                        message: "Failed to copy asset to destination: \(error.localizedDescription)",
                        details: nil
                    ))
                }
            }
        }
    }

    // MARK: - Record Field Mapping

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

    /// Populate a CKRecord's fields from the Dart-side dictionary
    private func populateRecord(_ record: CKRecord, from args: [String: Any]) {
        // String fields
        if let v = args["syncUUID"] as? String { record["syncUUID"] = v as CKRecordValue }
        if let v = args["text"] as? String { record["text"] = v as CKRecordValue }
        else { record["text"] = nil }

        if let v = args["title"] as? String { record["title"] = v as CKRecordValue }
        else { record["title"] = nil }

        if let v = args["context"] as? String { record["context"] = v as CKRecordValue }
        else { record["context"] = nil }

        if let v = args["mood"] as? String { record["mood"] = v as CKRecordValue }
        else { record["mood"] = nil }

        if let v = args["tags"] as? String { record["tags"] = v as CKRecordValue }
        else { record["tags"] = nil }

        if let v = args["detectedTheme"] as? String { record["detectedTheme"] = v as CKRecordValue }
        else { record["detectedTheme"] = nil }

        if let v = args["transcription"] as? String { record["transcription"] = v as CKRecordValue }
        else { record["transcription"] = nil }

        if let v = args["mediaPath"] as? String { record["mediaPath"] = v as CKRecordValue }
        else { record["mediaPath"] = nil }

        if let v = args["deviceId"] as? String { record["deviceId"] = v as CKRecordValue }
        else { record["deviceId"] = nil }

        // Int fields
        if let v = args["typeIndex"] as? Int { record["typeIndex"] = v as CKRecordValue }

        // Bool fields (Flutter sends bool as int sometimes)
        if let v = args["isDeleted"] {
            if let boolVal = v as? Bool {
                record["isDeleted"] = (boolVal ? 1 : 0) as CKRecordValue
            } else if let intVal = v as? Int {
                record["isDeleted"] = intVal as CKRecordValue
            }
        }

        // Double fields
        if let v = args["sentimentScore"] as? Double { record["sentimentScore"] = v as CKRecordValue }
        else { record["sentimentScore"] = nil }

        // DateTime fields (passed as milliseconds since epoch from Dart)
        if let v = args["createdAt"] as? Int64 {
            record["createdAt"] = Date(timeIntervalSince1970: Double(v) / 1000.0) as CKRecordValue
        } else if let v = args["createdAt"] as? Int {
            record["createdAt"] = Date(timeIntervalSince1970: Double(v) / 1000.0) as CKRecordValue
        }

        if let v = args["modifiedAt"] as? Int64 {
            record["modifiedAt"] = Date(timeIntervalSince1970: Double(v) / 1000.0) as CKRecordValue
        } else if let v = args["modifiedAt"] as? Int {
            record["modifiedAt"] = Date(timeIntervalSince1970: Double(v) / 1000.0) as CKRecordValue
        }

        if let v = args["deletedAt"] as? Int64 {
            record["deletedAt"] = Date(timeIntervalSince1970: Double(v) / 1000.0) as CKRecordValue
        } else if let v = args["deletedAt"] as? Int {
            record["deletedAt"] = Date(timeIntervalSince1970: Double(v) / 1000.0) as CKRecordValue
        } else {
            record["deletedAt"] = nil
        }

        if let v = args["capsuleUnlockDate"] as? Int64 {
            record["capsuleUnlockDate"] = Date(timeIntervalSince1970: Double(v) / 1000.0) as CKRecordValue
        } else if let v = args["capsuleUnlockDate"] as? Int {
            record["capsuleUnlockDate"] = Date(timeIntervalSince1970: Double(v) / 1000.0) as CKRecordValue
        } else {
            record["capsuleUnlockDate"] = nil
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

    // MARK: - Change Token Encoding

    /// Encode a CKServerChangeToken to a base64 string for storage in SharedPreferences
    private func encodeChangeToken(_ token: CKServerChangeToken) -> String? {
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: token,
                requiringSecureCoding: true
            )
            return data.base64EncodedString()
        } catch {
            NSLog("[CloudKitSync] Failed to encode change token: \(error)")
            return nil
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
