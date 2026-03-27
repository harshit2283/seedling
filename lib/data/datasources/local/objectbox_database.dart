import 'dart:async';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/security/at_rest_encryption_service.dart';
import '../../../objectbox.g.dart';
import '../../models/entry.dart';
import '../../models/ritual.dart';
import '../../models/tree.dart';

/// ObjectBox database singleton for local storage
/// Handles all CRUD operations for entries and trees
class ObjectBoxDatabase {
  late final Store _store;
  late final Box<Entry> _entryBox;
  late final Box<Tree> _treeBox;
  late final Box<Ritual> _ritualBox;
  late final AtRestEncryptionService _encryptionService;

  // Stream controllers for reactive updates
  final _treeController = StreamController<Tree?>.broadcast();
  final _entriesController = StreamController<List<Entry>>.broadcast();
  final _capsulesController = StreamController<List<Entry>>.broadcast();

  static ObjectBoxDatabase? _instance;

  ObjectBoxDatabase._();

  /// Get the singleton instance
  static ObjectBoxDatabase get instance {
    if (_instance == null) {
      throw StateError(
        'ObjectBoxDatabase not initialized. Call ObjectBoxDatabase.create() first.',
      );
    }
    return _instance!;
  }

  /// Initialize the database (call once at app startup)
  static Future<ObjectBoxDatabase> create() async {
    if (_instance != null) {
      return _instance!;
    }

    final db = ObjectBoxDatabase._();
    final dir = await getApplicationDocumentsDirectory();
    db._store = await openStore(directory: '${dir.path}/objectbox');
    db._entryBox = db._store.box<Entry>();
    db._treeBox = db._store.box<Tree>();
    db._ritualBox = db._store.box<Ritual>();
    db._encryptionService = AtRestEncryptionService();
    await db._encryptionService.init();

    // Ensure current year's tree exists
    await db._ensureCurrentYearTree();

    // Emit initial values
    db._emitCurrentTree();
    db._emitEntries();

    _instance = db;
    return db;
  }

  /// Close the database
  void close() {
    _treeController.close();
    _entriesController.close();
    _capsulesController.close();
    _store.close();
    _instance = null;
  }

  void _emitCurrentTree() {
    _treeController.add(currentTree);
  }

  void _emitEntries() {
    _entriesController.add(getVisibleEntries());
  }

  // ============== Tree Operations ==============

  /// Get or create tree for current year
  Future<Tree> _ensureCurrentYearTree() async {
    return _ensureTreeForYear(DateTime.now().year);
  }

  /// Get or create tree for a specific year.
  Future<Tree> _ensureTreeForYear(int year) async {
    var tree = getTreeForYear(year);
    if (tree == null) {
      tree = Tree(year: year);
      _treeBox.put(tree);
    }
    return tree;
  }

  /// Get tree for a specific year
  Tree? getTreeForYear(int year) {
    final query = _treeBox.query(Tree_.year.equals(year)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  /// Get the current year's tree
  Tree? get currentTree => getTreeForYear(DateTime.now().year);

  /// Get all trees
  List<Tree> getAllTrees() {
    return _treeBox.getAll();
  }

  /// Update a tree
  void updateTree(Tree tree) {
    _treeBox.put(tree);
    _emitCurrentTree();
  }

  /// Watch current tree for changes
  Stream<Tree?> watchCurrentTree() {
    return Stream<Tree?>.multi((controller) {
      controller.add(currentTree);
      final subscription = _treeController.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  // ============== Entry Operations ==============

  /// Save a new entry and update tree count
  Future<Entry> saveEntry(Entry entry) async {
    entry.modifiedAt = DateTime.now();
    _encryptEntryFields(entry);
    final id = _entryBox.put(entry);
    entry.id = id;

    // Update tree count
    await _adjustTreeCountForEntryYear(entry, increment: true);

    // Notify listeners
    _emitCurrentTree();
    _emitEntries();
    if (entry.isCapsule) {
      _emitCapsules();
    }

    _decryptEntryFields(entry);
    return entry;
  }

  /// Get an entry by ID
  Entry? getEntry(int id) {
    final entry = _entryBox.get(id);
    if (entry == null) return null;
    _decryptEntryFields(entry);
    return entry;
  }

  /// Get all entries for current year, newest first (excludes soft-deleted)
  List<Entry> getCurrentYearEntries() {
    final startOfYear = DateTime(DateTime.now().year);
    final query = _entryBox
        .query(
          Entry_.createdAt
              .greaterOrEqual(startOfYear.millisecondsSinceEpoch)
              .and(Entry_.isDeleted.equals(false)),
        )
        .order(Entry_.createdAt, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    _decryptEntries(results);
    return results.where((entry) => !entry.isLocked).toList();
  }

  /// Get recent entries (limit, excludes soft-deleted)
  List<Entry> getRecentEntries({int limit = 10}) {
    final query = _entryBox
        .query(Entry_.isDeleted.equals(false))
        .order(Entry_.createdAt, flags: Order.descending)
        .build();
    query.limit = limit;
    final results = query.find();
    query.close();
    _decryptEntries(results);
    return results.where((entry) => !entry.isLocked).take(limit).toList();
  }

  /// Get all entries (excludes soft-deleted)
  List<Entry> getAllEntries() {
    final query = _entryBox
        .query(Entry_.isDeleted.equals(false))
        .order(Entry_.createdAt, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    _decryptEntries(results);
    return results;
  }

  /// Get entries in pages to avoid loading full history in memory.
  List<Entry> getEntriesPage({
    required int limit,
    required int offset,
    int? year,
    bool includeDeleted = false,
    bool descending = true,
    bool includeLockedCapsules = false,
  }) {
    final query = _buildEntriesQuery(
      year: year,
      includeDeleted: includeDeleted,
      descending: descending,
      excludeLockedCapsules: !includeLockedCapsules,
    );
    query.offset = offset;
    query.limit = limit;
    final results = query.find();
    query.close();
    _decryptEntries(results);
    return results;
  }

  /// Count entries with optional year and deletion filters.
  int getEntriesCount({
    int? year,
    bool includeDeleted = false,
    bool includeLockedCapsules = false,
  }) {
    final query = _buildEntriesQuery(
      year: year,
      includeDeleted: includeDeleted,
      excludeLockedCapsules: !includeLockedCapsules,
    );
    final count = query.count();
    query.close();
    return count;
  }

  /// Soft delete an entry (recoverable for 30 days) and update tree count
  Future<bool> softDeleteEntry(int id) async {
    final entry = _entryBox.get(id);
    if (entry == null || entry.isDeleted) return false;

    entry.isDeleted = true;
    entry.deletedAt = DateTime.now();
    _entryBox.put(entry);

    // Update tree count
    await _adjustTreeCountForEntryYear(entry, increment: false);

    // Notify listeners
    _emitCurrentTree();
    _emitEntries();

    return true;
  }

  /// Hard delete an entry permanently
  Future<bool> deleteEntry(int id) async {
    final entry = _entryBox.get(id);
    if (entry != null && !entry.isDeleted) {
      await _adjustTreeCountForEntryYear(entry, increment: false);
    }

    final removed = _entryBox.remove(id);

    // Notify listeners
    _emitCurrentTree();
    _emitEntries();
    _emitCapsules();

    return removed;
  }

  /// Restore a soft-deleted entry
  Future<bool> restoreEntry(int id) async {
    final entry = _entryBox.get(id);
    if (entry == null || !entry.isDeleted) return false;

    entry.isDeleted = false;
    entry.deletedAt = null;
    _entryBox.put(entry);

    // Update tree count
    await _adjustTreeCountForEntryYear(entry, increment: true);

    // Notify listeners
    _emitCurrentTree();
    _emitEntries();

    return true;
  }

  /// Get all soft-deleted entries (for recovery screen)
  List<Entry> getDeletedEntries() {
    final query = _entryBox
        .query(Entry_.isDeleted.equals(true))
        .order(Entry_.deletedAt, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    _decryptEntries(results);
    return results;
  }

  /// Purge entries deleted more than 30 days ago
  Future<int> purgeExpiredEntries() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final query = _entryBox
        .query(
          Entry_.isDeleted
              .equals(true)
              .and(
                Entry_.deletedAt.lessThan(thirtyDaysAgo.millisecondsSinceEpoch),
              ),
        )
        .build();
    final expiredEntries = query.find();
    query.close();

    if (expiredEntries.isEmpty) return 0;

    final ids = expiredEntries.map((e) => e.id).toList();
    final removed = _entryBox.removeMany(ids);

    return removed;
  }

  /// Update an entry
  void updateEntry(Entry entry) {
    entry.modifiedAt = DateTime.now();
    _encryptEntryFields(entry);
    _entryBox.put(entry);
    _emitEntries();
  }

  /// Watch entries for changes (current year, newest first)
  Stream<List<Entry>> watchEntries() {
    return Stream<List<Entry>>.multi((controller) {
      controller.add(getCurrentYearEntries());
      final subscription = _entriesController.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  /// Watch all entries
  Stream<List<Entry>> watchAllEntries() {
    return Stream<List<Entry>>.multi((controller) {
      controller.add(getAllEntries());
      final subscription = _entriesController.stream.listen(
        (_) => controller.add(getAllEntries()),
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  /// Get entry count for current year
  int get currentYearEntryCount {
    final tree = currentTree;
    return tree?.entryCount ?? 0;
  }

  // ============== Capsule Operations (Phase 4.5) ==============

  /// Get all visible entries (excludes locked capsules and deleted)
  /// This is the main query for displaying memories
  List<Entry> getVisibleEntries() {
    return getCurrentYearEntries();
  }

  /// Get all capsules (locked and unlocked)
  List<Entry> getAllCapsules() {
    // Get entries that have a capsule unlock date set
    final query = _entryBox
        .query(
          Entry_.capsuleUnlockDate.notNull().and(
            Entry_.isDeleted.equals(false),
          ),
        )
        .order(Entry_.capsuleUnlockDate)
        .build();
    final results = query.find();
    query.close();
    _decryptEntries(results);
    return results;
  }

  /// Get only locked capsules
  List<Entry> getLockedCapsules() {
    return getAllCapsules().where((e) => e.isLocked).toList();
  }

  /// Get only unlocked capsules
  List<Entry> getUnlockedCapsules() {
    return getAllCapsules().where((e) => e.isUnlocked).toList();
  }

  /// Get capsules that unlock today
  List<Entry> getCapsulesToUnlockToday() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final query = _entryBox
        .query(
          Entry_.capsuleUnlockDate
              .between(
                startOfDay.millisecondsSinceEpoch,
                endOfDay.millisecondsSinceEpoch - 1,
              )
              .and(Entry_.isDeleted.equals(false)),
        )
        .order(Entry_.capsuleUnlockDate)
        .build();
    final results = query.find();
    query.close();
    _decryptEntries(results);
    return results;
  }

  /// Get entries from previous years that match today's month and day.
  ///
  /// Excludes the current year at the query level to avoid decrypting
  /// entries that will never match.
  List<Entry> getEntriesOnThisDay() {
    final today = DateTime.now();
    final startOfYear =
        DateTime(today.year).millisecondsSinceEpoch;

    // Only fetch entries before the current year to minimise decryption work.
    final query = _entryBox
        .query(
          Entry_.isDeleted.equals(false).and(
            Entry_.createdAt.lessThan(startOfYear),
          ),
        )
        .order(Entry_.createdAt, flags: Order.descending)
        .build();
    final pastEntries = query.find();
    query.close();
    _decryptEntries(pastEntries);

    return pastEntries.where((entry) {
      if (entry.isLocked) return false;
      return entry.createdAt.month == today.month &&
          entry.createdAt.day == today.day;
    }).toList();
  }

  /// Save a capsule entry (same as saveEntry but with semantic naming)
  Future<Entry> saveCapsule(Entry entry) async {
    return saveEntry(entry);
  }

  /// Emit capsule updates
  void _emitCapsules() {
    _capsulesController.add(getAllCapsules());
  }

  /// Watch capsules for changes
  Stream<List<Entry>> watchCapsules() {
    return Stream<List<Entry>>.multi((controller) {
      controller.add(getAllCapsules());
      final subscription = _capsulesController.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  /// Rebuild tree counts and growth stages from entries.
  Future<void> recountTrees({int? year}) async {
    final entries = _entryBox.getAll();
    final yearsToRecount = <int>{};
    final entryCountsByYear = <int, int>{};

    for (final entry in entries) {
      final entryYear = entry.createdAt.year;
      if (!entry.isDeleted) {
        entryCountsByYear.update(
          entryYear,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      if (year == null || year == entryYear) {
        yearsToRecount.add(entryYear);
      }
    }

    if (year != null) {
      yearsToRecount.add(year);
    }

    // Ensure at least current year exists, even if empty.
    yearsToRecount.add(DateTime.now().year);

    for (final targetYear in yearsToRecount) {
      final tree = await _ensureTreeForYear(targetYear);
      final count = entryCountsByYear[targetYear] ?? 0;
      tree.entryCount = count;
      tree.updateVisualState();
      _treeBox.put(tree);
    }

    _emitCurrentTree();
    _emitEntries();
    _emitCapsules();
  }

  /// Permanently clears all entries and tree growth data.
  Future<void> clearAllData() async {
    _entryBox.removeAll();
    _treeBox.removeAll();
    await _ensureCurrentYearTree();
    _emitCurrentTree();
    _emitEntries();
    _emitCapsules();
  }

  Future<void> _adjustTreeCountForEntryYear(
    Entry entry, {
    required bool increment,
  }) async {
    final tree = await _ensureTreeForYear(entry.createdAt.year);
    if (increment) {
      tree.addEntry();
    } else {
      tree.removeEntry();
    }
    _treeBox.put(tree);
  }

  // ============== Sync Operations (Phase 5) ==============

  /// Find an entry by its sync UUID (for cloud sync merge)
  Entry? getEntryBySyncUUID(String syncUUID) {
    final query = _entryBox.query(Entry_.syncUUID.equals(syncUUID)).build();
    final result = query.findFirst();
    query.close();
    if (result != null) _decryptEntryFields(result);
    return result;
  }

  /// Get all entries modified since a given timestamp (for sync push)
  List<Entry> getEntriesModifiedSince(DateTime since) {
    final query = _entryBox
        .query(Entry_.modifiedAt.greaterThan(since.millisecondsSinceEpoch))
        .order(Entry_.modifiedAt)
        .build();
    final results = query.find();
    query.close();
    _decryptEntries(results);
    return results;
  }

  Query<Entry> _buildEntriesQuery({
    int? year,
    bool includeDeleted = false,
    bool descending = true,
    bool excludeLockedCapsules = false,
  }) {
    Condition<Entry>? condition;

    if (year != null) {
      final startOfYear = DateTime(year);
      final endOfYear = DateTime(year + 1);
      condition = Entry_.createdAt.between(
        startOfYear.millisecondsSinceEpoch,
        endOfYear.millisecondsSinceEpoch - 1,
      );
    }

    if (!includeDeleted) {
      final notDeleted = Entry_.isDeleted.equals(false);
      condition = condition != null ? condition.and(notDeleted) : notDeleted;
    }

    if (excludeLockedCapsules) {
      // Exclude entries with capsuleUnlockDate in the future (locked capsules).
      // capsuleUnlockDate is stored unencrypted, so this is query-level filtering.
      final now = DateTime.now().millisecondsSinceEpoch;
      final notLocked = Entry_.capsuleUnlockDate.isNull().or(
        Entry_.capsuleUnlockDate.lessThan(now),
      );
      condition = condition != null ? condition.and(notLocked) : notLocked;
    }

    final queryBuilder = condition != null
        ? _entryBox.query(condition)
        : _entryBox.query();

    return queryBuilder
        .order(Entry_.createdAt, flags: descending ? Order.descending : 0)
        .build();
  }

  void _encryptEntryFields(Entry entry) {
    entry.text = _encryptionService.encryptField(entry.text);
    entry.title = _encryptionService.encryptField(entry.title);
    entry.context = _encryptionService.encryptField(entry.context);
    entry.mood = _encryptionService.encryptField(entry.mood);
    entry.tags = _encryptionService.encryptField(entry.tags);
    entry.detectedTheme = _encryptionService.encryptField(entry.detectedTheme);
    entry.connectionIds = _encryptionService.encryptField(entry.connectionIds);
    entry.manualLinkIds = _encryptionService.encryptField(entry.manualLinkIds);
    entry.transcription = _encryptionService.encryptField(entry.transcription);
  }

  void _decryptEntries(List<Entry> entries) {
    for (final entry in entries) {
      _decryptEntryFields(entry);
    }
  }

  void _decryptEntryFields(Entry entry) {
    entry.decryptionFailed = false;

    String? decryptOrPreserve(String? value) {
      final decrypted = _encryptionService.decryptField(value);
      if (decrypted == null && _encryptionService.isEncryptedValue(value)) {
        entry.decryptionFailed = true;
        return value;
      }
      return decrypted;
    }

    entry.text = decryptOrPreserve(entry.text);
    entry.title = decryptOrPreserve(entry.title);
    entry.context = decryptOrPreserve(entry.context);
    entry.mood = decryptOrPreserve(entry.mood);
    entry.tags = decryptOrPreserve(entry.tags);
    entry.detectedTheme = decryptOrPreserve(entry.detectedTheme);
    entry.connectionIds = decryptOrPreserve(entry.connectionIds);
    entry.manualLinkIds = decryptOrPreserve(entry.manualLinkIds);
    entry.transcription = decryptOrPreserve(entry.transcription);
  }

  // ============ Ritual Operations ============

  Future<void> saveRitual(Ritual ritual) async {
    _ritualBox.put(ritual);
  }

  Ritual? getRitual(int id) => _ritualBox.get(id);

  List<Ritual> getAllRituals() {
    return _ritualBox.getAll()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> deleteRitual(int id) async {
    _ritualBox.remove(id);
  }

  Stream<List<Ritual>> watchRituals() {
    return _ritualBox
        .query()
        .watch(triggerImmediately: true)
        .map((q) => q.find());
  }

  // ============ Object Collection Operations ============

  /// Get all object-type entries (non-deleted), sorted by createdAt descending
  List<Entry> getObjectEntries() {
    final query = _entryBox
        .query(
          Entry_.typeIndex
              .equals(EntryType.object.index)
              .and(Entry_.isDeleted.equals(false)),
        )
        .order(Entry_.createdAt, flags: Order.descending)
        .build();
    final results = query.find();
    query.close();
    _decryptEntries(results);
    return results;
  }

  // ============ Manual Link Operations ============

  /// Load entries by their syncUUIDs (for manual linking)
  List<Entry> getEntriesBySyncUUIDs(List<String> uuids) {
    if (uuids.isEmpty) return [];
    // Filter all visible entries by syncUUID match
    return getVisibleEntries()
        .where((e) => e.syncUUID != null && uuids.contains(e.syncUUID!))
        .toList();
  }
}
