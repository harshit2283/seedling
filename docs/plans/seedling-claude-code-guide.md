# Seedling: Claude Code Implementation Guide

> **Feed this to Claude Code along with seedling-app-plan.md**

## Quick Start Commands

```bash
# Create Flutter project
flutter create seedling --org com.seedling --platforms ios,android

# Navigate and setup
cd seedling

# Add core dependencies
flutter pub add \
  isar isar_flutter_libs \
  riverpod flutter_riverpod \
  go_router \
  rive \
  flutter_sodium \
  path_provider \
  permission_handler \
  image_picker \
  record \
  share_plus \
  url_launcher

# Add dev dependencies  
flutter pub add --dev \
  isar_generator \
  build_runner \
  flutter_lints \
  mocktail

# Generate Isar models (after creating them)
dart run build_runner build
```

---

## Implementation Order

### Step 1: Project Structure

Create this folder structure first:

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
│       ├── seedling_theme.dart
│       ├── colors.dart
│       └── typography.dart
├── features/
│   ├── capture/
│   ├── tree/
│   ├── memories/
│   └── settings/
├── data/
│   ├── models/
│   ├── repositories/
│   └── datasources/
├── core/
│   └── services/
└── platform/
```

### Step 2: Theme First

**Create `lib/app/theme/colors.dart`:**

```dart
import 'package:flutter/material.dart';

class SeedlingColors {
  // Core palette
  static const forest = Color(0xFF4A5D23);
  static const bark = Color(0xFF8B7355);
  static const paper = Color(0xFFFAF8F5);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2C2C2C);
  static const muted = Color(0xFFA0A0A0);
  
  // Seasonal accents
  static const spring = Color(0xFFF2C4CE);
  static const summer = Color(0xFF7CB342);
  static const autumn = Color(0xFFD4A84B);
  static const winter = Color(0xFFB8C5D6);
  
  // Mood colors (user can pick these)
  static const moods = [
    Color(0xFFE8F5E9), // Calm green
    Color(0xFFFFF3E0), // Warm orange
    Color(0xFFE3F2FD), // Soft blue
    Color(0xFFFCE4EC), // Gentle pink
    Color(0xFFF3E5F5), // Light purple
  ];
}
```

**Create `lib/app/theme/seedling_theme.dart`:**

```dart
import 'package:flutter/material.dart';
import 'colors.dart';

class SeedlingTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: SeedlingColors.forest,
      secondary: SeedlingColors.bark,
      surface: SeedlingColors.surface,
      background: SeedlingColors.paper,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: SeedlingColors.ink,
      onBackground: SeedlingColors.ink,
    ),
    scaffoldBackgroundColor: SeedlingColors.paper,
    
    // Typography - warm, organic feel
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Georgia', // Fallback serif
        fontSize: 32,
        fontWeight: FontWeight.w400,
        color: SeedlingColors.ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'System',
        fontSize: 16,
        height: 1.6,
        color: SeedlingColors.ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'System',
        fontSize: 14,
        height: 1.5,
        color: SeedlingColors.ink,
      ),
      // "Whisper" style for captions
      labelSmall: TextStyle(
        fontFamily: 'System',
        fontSize: 12,
        fontStyle: FontStyle.italic,
        color: SeedlingColors.muted,
      ),
    ),
    
    // Minimal elevation throughout
    cardTheme: const CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    
    // Soft buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    ),
  );
}
```

### Step 3: Data Models

**Create `lib/data/models/entry.dart`:**

```dart
import 'package:isar/isar.dart';

part 'entry.g.dart';

@Collection()
class Entry {
  Id? id;
  
  @Enumerated(EnumType.name)
  late EntryType type;
  
  @Index()
  late DateTime createdAt;
  
  DateTime? modifiedAt;
  
  // For LINE entries
  String? text;
  
  // For PHOTO entries
  String? photoPath;
  String? whisper;
  bool capturedAfter = false;
  
  // For VOICE entries
  String? audioPath;
  int? audioDuration; // seconds
  String? transcription;
  
  // For OBJECT entries
  String? objectName;
  String? objectStory;
  
  // For FRAGMENT entries
  List<String>? fragments;
  
  // Soft metadata
  String? moodColor;
  String? locationHint;
  String? weather;
  
  // For RELEASE entries
  bool isReleased = false;
  String? releaseIntention;
  
  // Tree relationship
  int? treeId;
  
  // Connections to other entries
  List<int> connectionIds = [];
  
  Entry();
  
  factory Entry.line(String text) {
    return Entry()
      ..type = EntryType.line
      ..text = text
      ..createdAt = DateTime.now();
  }
  
  factory Entry.photo({
    required String path,
    String? whisper,
    bool capturedAfter = false,
  }) {
    return Entry()
      ..type = EntryType.photo
      ..photoPath = path
      ..whisper = whisper
      ..capturedAfter = capturedAfter
      ..createdAt = DateTime.now();
  }
  
  factory Entry.voice({
    required String path,
    required int duration,
  }) {
    return Entry()
      ..type = EntryType.voice
      ..audioPath = path
      ..audioDuration = duration
      ..createdAt = DateTime.now();
  }
  
  factory Entry.object({
    required String name,
    required String photoPath,
    String? story,
  }) {
    return Entry()
      ..type = EntryType.object
      ..objectName = name
      ..photoPath = photoPath
      ..objectStory = story
      ..createdAt = DateTime.now();
  }
  
  factory Entry.fragment(List<String> fragments) {
    return Entry()
      ..type = EntryType.fragment
      ..fragments = fragments
      ..createdAt = DateTime.now();
  }
  
  factory Entry.release({String? intention}) {
    return Entry()
      ..type = EntryType.release
      ..isReleased = true
      ..releaseIntention = intention
      ..createdAt = DateTime.now();
  }
}

enum EntryType {
  line,
  photo,
  voice,
  object,
  fragment,
  ritual,
  release,
}
```

**Create `lib/data/models/tree.dart`:**

```dart
import 'package:isar/isar.dart';

part 'tree.g.dart';

@Collection()
class Tree {
  Id? id;
  
  late DateTime startDate;
  DateTime? endDate;
  
  @Enumerated(EnumType.name)
  late TreePeriod period;
  
  String? customName;
  
  double growthLevel = 0;
  
  @Enumerated(EnumType.name)
  TreeState visualState = TreeState.seed;
  
  int entryCount = 0;
  
  Tree();
  
  factory Tree.forYear(int year) {
    return Tree()
      ..startDate = DateTime(year, 1, 1)
      ..endDate = DateTime(year, 12, 31)
      ..period = TreePeriod.year
      ..customName = year.toString();
  }
  
  factory Tree.current() {
    final now = DateTime.now();
    return Tree.forYear(now.year);
  }
}

enum TreePeriod {
  year,
  quarter,
  custom,
}

enum TreeState {
  seed,      // 0-10 entries
  sprout,    // 11-30 entries
  sapling,   // 31-100 entries
  youngTree, // 101-250 entries
  matureTree, // 251-500 entries
  ancientTree, // 500+ entries
}
```

**Create `lib/data/models/time_capsule.dart`:**

```dart
import 'package:isar/isar.dart';

part 'time_capsule.g.dart';

@Collection()
class TimeCapsule {
  Id? id;
  
  late DateTime createdAt;
  late DateTime unlockAt;
  
  List<int> entryIds = [];
  
  String? messageToFuture;
  
  bool isUnlocked = false;
  DateTime? unlockedAt;
  
  TimeCapsule();
  
  factory TimeCapsule.create({
    required DateTime unlockAt,
    required List<int> entryIds,
    String? message,
  }) {
    return TimeCapsule()
      ..createdAt = DateTime.now()
      ..unlockAt = unlockAt
      ..entryIds = entryIds
      ..messageToFuture = message;
  }
}
```

### Step 4: Database Setup

**Create `lib/data/datasources/local/database.dart`:**

```dart
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/entry.dart';
import '../../models/tree.dart';
import '../../models/time_capsule.dart';

class SeedlingDatabase {
  late Isar _isar;
  
  Isar get isar => _isar;
  
  Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    
    _isar = await Isar.open(
      [EntrySchema, TreeSchema, TimeCapsuleSchema],
      directory: dir.path,
      name: 'seedling',
    );
    
    // Ensure current tree exists
    await _ensureCurrentTree();
  }
  
  Future<void> _ensureCurrentTree() async {
    final currentYear = DateTime.now().year;
    final existing = await _isar.trees
        .filter()
        .customNameEqualTo(currentYear.toString())
        .findFirst();
    
    if (existing == null) {
      await _isar.writeTxn(() async {
        await _isar.trees.put(Tree.forYear(currentYear));
      });
    }
  }
  
  // Entry operations
  Future<int> saveEntry(Entry entry) async {
    return await _isar.writeTxn(() async {
      return await _isar.entrys.put(entry);
    });
  }
  
  Future<List<Entry>> getEntriesForTree(int treeId) async {
    return await _isar.entrys
        .filter()
        .treeIdEqualTo(treeId)
        .sortByCreatedAtDesc()
        .findAll();
  }
  
  Future<Tree?> getCurrentTree() async {
    final currentYear = DateTime.now().year;
    return await _isar.trees
        .filter()
        .customNameEqualTo(currentYear.toString())
        .findFirst();
  }
  
  Stream<List<Entry>> watchEntries(int treeId) {
    return _isar.entrys
        .filter()
        .treeIdEqualTo(treeId)
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }
}
```

### Step 5: State Management

**Create `lib/core/services/seedling_service.dart`:**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/database.dart';
import '../../data/models/entry.dart';
import '../../data/models/tree.dart';

// Database provider
final databaseProvider = Provider<SeedlingDatabase>((ref) {
  throw UnimplementedError('Initialize in main.dart');
});

// Current tree provider
final currentTreeProvider = FutureProvider<Tree?>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getCurrentTree();
});

// Entries for current tree
final entriesProvider = StreamProvider<List<Entry>>((ref) async* {
  final db = ref.watch(databaseProvider);
  final tree = await ref.watch(currentTreeProvider.future);
  
  if (tree?.id != null) {
    yield* db.watchEntries(tree!.id!);
  } else {
    yield [];
  }
});

// Tree state calculator
final treeStateProvider = Provider<TreeState>((ref) {
  final entriesAsync = ref.watch(entriesProvider);
  
  return entriesAsync.when(
    data: (entries) => _calculateTreeState(entries.length),
    loading: () => TreeState.seed,
    error: (_, __) => TreeState.seed,
  );
});

TreeState _calculateTreeState(int entryCount) {
  if (entryCount <= 10) return TreeState.seed;
  if (entryCount <= 30) return TreeState.sprout;
  if (entryCount <= 100) return TreeState.sapling;
  if (entryCount <= 250) return TreeState.youngTree;
  if (entryCount <= 500) return TreeState.matureTree;
  return TreeState.ancientTree;
}

// Entry creation notifier
final entryCreatorProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return EntryCreator(db, ref);
});

class EntryCreator {
  final SeedlingDatabase _db;
  final Ref _ref;
  
  EntryCreator(this._db, this._ref);
  
  Future<void> saveLine(String text) async {
    if (text.trim().isEmpty) return;
    
    final tree = await _ref.read(currentTreeProvider.future);
    final entry = Entry.line(text.trim())..treeId = tree?.id;
    
    await _db.saveEntry(entry);
  }
  
  Future<void> savePhoto({
    required String path,
    String? whisper,
    bool capturedAfter = false,
  }) async {
    final tree = await _ref.read(currentTreeProvider.future);
    final entry = Entry.photo(
      path: path,
      whisper: whisper,
      capturedAfter: capturedAfter,
    )..treeId = tree?.id;
    
    await _db.saveEntry(entry);
  }
  
  Future<void> saveVoice({
    required String path,
    required int duration,
  }) async {
    final tree = await _ref.read(currentTreeProvider.future);
    final entry = Entry.voice(path: path, duration: duration)
      ..treeId = tree?.id;
    
    await _db.saveEntry(entry);
  }
  
  Future<void> saveFragments(List<String> fragments) async {
    if (fragments.isEmpty) return;
    
    final tree = await _ref.read(currentTreeProvider.future);
    final entry = Entry.fragment(fragments)..treeId = tree?.id;
    
    await _db.saveEntry(entry);
  }
  
  Future<void> saveRelease({String? intention}) async {
    final tree = await _ref.read(currentTreeProvider.future);
    final entry = Entry.release(intention: intention)..treeId = tree?.id;
    
    await _db.saveEntry(entry);
  }
}
```

### Step 6: Main Entry Point

**Create `lib/main.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/theme/seedling_theme.dart';
import 'core/services/seedling_service.dart';
import 'data/datasources/local/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Initialize database
  final database = SeedlingDatabase();
  await database.initialize();
  
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
      child: const SeedlingApp(),
    ),
  );
}
```

**Create `lib/app/app.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme/seedling_theme.dart';

class SeedlingApp extends ConsumerWidget {
  const SeedlingApp({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Seedling',
      theme: SeedlingTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

### Step 7: Routing

**Create `lib/app/router.dart`:**

```dart
import 'package:go_router/go_router.dart';
import '../features/capture/capture_screen.dart';
import '../features/tree/tree_screen.dart';
import '../features/memories/memories_screen.dart';
import '../features/settings/settings_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const TreeScreen(),
    ),
    GoRoute(
      path: '/capture',
      builder: (context, state) => const CaptureScreen(),
    ),
    GoRoute(
      path: '/memories',
      builder: (context, state) => const MemoriesScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
```

### Step 8: Core Screens

**Create `lib/features/tree/tree_screen.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/colors.dart';
import '../../core/services/seedling_service.dart';
import '../../data/models/tree.dart';

class TreeScreen extends ConsumerWidget {
  const TreeScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeState = ref.watch(treeStateProvider);
    final entriesAsync = ref.watch(entriesProvider);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Seedling',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 24,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
            
            // Tree visualization
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () => context.push('/memories'),
                child: _TreeVisualization(state: treeState),
              ),
            ),
            
            // Recent entry preview
            Expanded(
              flex: 1,
              child: entriesAsync.when(
                data: (entries) => entries.isNotEmpty
                    ? _RecentEntryPreview(entry: entries.first)
                    : const _EmptyState(),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
            ),
            
            // Add button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showCaptureSheet(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SeedlingColors.forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Add Memory'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showCaptureSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _QuickCaptureSheet(),
    );
  }
}

class _TreeVisualization extends StatelessWidget {
  final TreeState state;
  
  const _TreeVisualization({required this.state});
  
  @override
  Widget build(BuildContext context) {
    // Placeholder - replace with Rive animation
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getTreeIcon(),
            size: 120,
            color: SeedlingColors.forest,
          ),
          const SizedBox(height: 16),
          Text(
            _getTreeLabel(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
  
  IconData _getTreeIcon() {
    switch (state) {
      case TreeState.seed:
        return Icons.spa_outlined;
      case TreeState.sprout:
        return Icons.grass;
      case TreeState.sapling:
        return Icons.park_outlined;
      case TreeState.youngTree:
      case TreeState.matureTree:
      case TreeState.ancientTree:
        return Icons.park;
    }
  }
  
  String _getTreeLabel() {
    switch (state) {
      case TreeState.seed:
        return 'Your seed is waiting';
      case TreeState.sprout:
        return 'A sprout emerges';
      case TreeState.sapling:
        return 'Growing steadily';
      case TreeState.youngTree:
        return 'Taking root';
      case TreeState.matureTree:
        return 'Full and flourishing';
      case TreeState.ancientTree:
        return 'A grand old friend';
    }
  }
}

class _RecentEntryPreview extends StatelessWidget {
  final dynamic entry;
  
  const _RecentEntryPreview({required this.entry});
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          entry.text ?? 'A memory',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Your first seed is waiting',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _QuickCaptureSheet extends ConsumerStatefulWidget {
  const _QuickCaptureSheet();
  
  @override
  ConsumerState<_QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends ConsumerState<_QuickCaptureSheet> {
  final _controller = TextEditingController();
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SeedlingColors.muted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Text input
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'What stayed with you today?',
                hintStyle: TextStyle(
                  color: SeedlingColors.muted,
                  fontStyle: FontStyle.italic,
                ),
                border: InputBorder.none,
              ),
              style: Theme.of(context).textTheme.bodyLarge,
              onSubmitted: (_) => _save(),
            ),
            
            const SizedBox(height: 16),
            
            // Entry type buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _EntryTypeButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Photo',
                  onTap: () {
                    // TODO: Implement photo capture
                  },
                ),
                _EntryTypeButton(
                  icon: Icons.mic_outlined,
                  label: 'Voice',
                  onTap: () {
                    // TODO: Implement voice recording
                  },
                ),
                _EntryTypeButton(
                  icon: Icons.inventory_2_outlined,
                  label: 'Object',
                  onTap: () {
                    // TODO: Implement object capture
                  },
                ),
                _EntryTypeButton(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Fragment',
                  onTap: () {
                    // TODO: Implement fragment entry
                  },
                ),
                _EntryTypeButton(
                  icon: Icons.air_outlined,
                  label: 'Let Go',
                  onTap: () => _saveRelease(),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    
    await ref.read(entryCreatorProvider).saveLine(text);
    HapticFeedback.lightImpact();
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
  
  Future<void> _saveRelease() async {
    await ref.read(entryCreatorProvider).saveRelease();
    HapticFeedback.lightImpact();
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _EntryTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  
  const _EntryTypeButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: SeedlingColors.forest,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: SeedlingColors.forest,
              fontStyle: FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Create placeholder screens:**

`lib/features/capture/capture_screen.dart`:
```dart
import 'package:flutter/material.dart';

class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Capture')),
    );
  }
}
```

`lib/features/memories/memories_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/seedling_service.dart';

class MemoriesScreen extends ConsumerWidget {
  const MemoriesScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(entriesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memories'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: entriesAsync.when(
        data: (entries) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.text ?? entry.type.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(entry.createdAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
```

`lib/features/settings/settings_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup'),
            subtitle: const Text('Manage your backups'),
            onTap: () {
              // TODO: Implement backup settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export'),
            subtitle: const Text('Export your memories'),
            onTap: () {
              // TODO: Implement export
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy'),
            subtitle: const Text('Your data stays on device'),
            onTap: () {
              // TODO: Show privacy info
            },
          ),
        ],
      ),
    );
  }
}
```

---

## Critical Implementation Notes

### DO:
- Use HapticFeedback for all interactions
- Keep all data local by default
- Make capture effortless (minimal taps)
- Use soft, organic animations
- Support dark mode eventually (but light first)

### DON'T:
- Add streaks or gamification
- Add social features
- Require network connectivity
- Auto-modify user content
- Add notifications by default

### Testing Every Feature:

```dart
// Always write tests like this pattern:
void main() {
  group('EntryCreator', () {
    test('saveLine with empty text does nothing', () async {
      // Arrange
      final mockDb = MockDatabase();
      final creator = EntryCreator(mockDb, mockRef);
      
      // Act
      await creator.saveLine('');
      
      // Assert
      verifyNever(() => mockDb.saveEntry(any()));
    });
  });
}
```

### Performance Targets:
- Cold start: < 1.5 seconds
- Memory usage: < 100MB typical
- Entry save: < 100ms
- Tree render: 60fps

---

## Next Implementation Steps

After completing the foundation above:

1. **Phase 2: Rich Media**
   - Photo picker integration
   - Voice recording with `record` package
   - Object capture flow
   - Fragment entry UI

2. **Phase 3: Tree Animation**
   - Create Rive animations for 6 tree states
   - Implement seasonal theming
   - Add growth animations

3. **Phase 4: AI Features**
   - iOS: Implement Apple Intelligence bridge
   - Android: Implement ML Kit bridge
   - Semantic search
   - Theme detection

4. **Phase 5: Backup & Export**
   - Encrypted backup to iCloud/Google Drive
   - JSON/PDF/Markdown export
   - Import from other apps

5. **Phase 6: Widgets**
   - iOS Lock Screen widget
   - Android Glance widgets
   - Quick actions
