# Seedling - Claude Project Guide

## Project Overview

Seedling is a memory-keeping app that feels like breathing, not documenting. It uses the "Seeds → Trees → Forest" metaphor where memories grow into a visual tree over time.

**Core Philosophy:**
- No gamification (no streaks, badges, or daily reminders)
- No social features (completely private)
- Offline-first (must work without internet)
- No required fields (every field optional except timestamp)
- Haptic feedback on interactions
- Soft, organic animations

## Quick Commands

```bash
# Run on iOS simulator
flutter run -d iphone

# Run on Android emulator
flutter run -d android

# Run tests
flutter test

# Analyze code
flutter analyze

# Regenerate ObjectBox models after changes
dart run build_runner build --delete-conflicting-outputs
```

## Architecture

### Directory Structure
```
lib/
├── main.dart                 # App entry point, database + media + prefs init
├── app/
│   ├── app.dart              # Root MaterialApp widget
│   ├── router.dart           # GoRouter configuration (includes /entry/:id, /settings/deleted)
│   └── theme/
│       ├── colors.dart       # SeedlingColors palette
│       ├── typography.dart   # SeedlingTypography
│       └── seedling_theme.dart # Complete ThemeData
├── features/
│   ├── tree/presentation/    # Home screen with tree + prompts
│   │   ├── tree_screen.dart              # Main home screen
│   │   └── animated_tree_visualization.dart  # Procedural animated tree (Phase 5)
│   ├── capture/presentation/ # Quick capture bottom sheet
│   │   ├── quick_capture_sheet.dart  # Main capture UI with CaptureMode
│   │   └── widgets/
│   │       ├── entry_type_button.dart
│   │       ├── photo_capture_content.dart   # Camera/gallery capture
│   │       ├── voice_capture_content.dart   # Hold-to-record UI
│   │       └── object_capture_content.dart  # Photo + title + story
│   ├── memories/presentation/
│   │   ├── memories_screen.dart       # List with search, filter, sort
│   │   ├── memories_filter_state.dart # Filter/sort state provider
│   │   ├── memory_card.dart           # Cards with media thumbnails
│   │   ├── entry_detail_screen.dart   # Full detail view with edit mode
│   │   └── widgets/
│   │       ├── photo_viewer.dart      # Full-screen pinch-to-zoom
│   │       └── voice_player.dart      # Audio playback UI
│   ├── prompts/                       # Gentle prompt system (Phase 3)
│   │   ├── data/
│   │   │   ├── prompt_repository.dart     # Curated prompts by time/season
│   │   │   └── prompt_preferences.dart    # SharedPreferences storage
│   │   ├── domain/
│   │   │   └── prompt_selector.dart       # Selection logic with cooldown
│   │   └── presentation/
│   │       └── prompt_card.dart           # Glass card UI
│   ├── settings/presentation/
│   │   ├── settings_screen.dart           # Export, storage, prompts toggle
│   │   ├── deleted_entries_screen.dart    # Soft-delete recovery
│   │   └── theme_insights_screen.dart     # Theme distribution visualization
│   └── capsules/presentation/             # Memory Capsules (Phase 4.5)
│       ├── capsules_screen.dart           # List locked/unlocked capsules
│       └── widgets/
│           ├── capsule_card.dart          # Locked/unlocked capsule display
│           └── capsule_unlock_animation.dart
├── data/
│   ├── models/
│   │   ├── entry.dart        # Memory entry model (ObjectBox) + soft delete fields
│   │   └── tree.dart         # Tree growth model (ObjectBox)
│   └── datasources/local/
│       └── objectbox_database.dart  # CRUD + soft delete/restore
└── core/
    ├── platform/
    │   ├── platform_utils.dart   # isIOS, platform helpers
    │   └── adaptive_icons.dart   # Platform-specific icons
    ├── widgets/glass/
    │   └── glass_container.dart  # iOS blur effects
    └── services/
        ├── providers.dart        # Riverpod providers (database + media + prompts + AI)
        ├── media/
        │   ├── permission_service.dart       # Runtime permissions
        │   ├── file_storage_service.dart     # UUID file storage
        │   ├── photo_capture_service.dart    # Camera/gallery
        │   ├── voice_recording_service.dart  # Hold-to-record
        │   ├── media_compression_service.dart # Image compression
        │   └── audio_playback_service.dart   # Voice playback
        ├── export/
        │   └── export_service.dart           # JSON/ZIP export (Phase 3)
        ├── storage/
        │   └── storage_usage_service.dart    # Calculate storage breakdown (Phase 3)
        ├── ai/                               # On-device AI services (Phase 4)
        │   ├── theme_detector_service.dart   # Keyword-based theme detection
        │   ├── connection_finder_service.dart # Jaccard similarity + temporal
        │   ├── suggestion_engine.dart        # Smart prompts based on patterns
        │   ├── ml_text_analyzer.dart         # Platform ML channel interface
        │   └── models/
        │       ├── memory_theme.dart         # 11 theme categories
        │       ├── memory_connection.dart    # Connection with factors
        │       ├── smart_suggestion.dart     # Suggestion types
        │       └── analysis_result.dart      # Collection stats
        ├── share/                            # Share Extension (Phase 4.5)
        │   └── share_receiver_service.dart   # Handle shared content from other apps
        ├── widget/                           # Home Widgets (Phase 4.5)
        │   └── widget_data_service.dart      # Sync data to iOS/Android widgets
        ├── haptic_service.dart               # Theme-based haptic patterns (Phase 4.5)
        └── entry_type_usage_service.dart    # Smart button ordering by usage (Phase 5)
```

### Tech Stack
- **Database:** ObjectBox 5.1 (local, reactive)
- **State Management:** Riverpod 3.2
- **Routing:** GoRouter 17
- **Media:** image_picker, record, audioplayers, flutter_image_compress
- **Export:** share_plus, archive (Phase 3)
- **Preferences:** shared_preferences (Phase 3)
- **AI/ML:** Apple NaturalLanguage (iOS), Google ML Kit (Android) - Phase 4
- **Share Extension:** receive_sharing_intent (Phase 4.5)
- **Home Widgets:** home_widget, WidgetKit (iOS), AppWidgetProvider (Android) - Phase 4.5
- **Platforms:** iOS 15+, Android

### Key Patterns

**Database Access:**
```dart
// Always access via provider
final db = ref.read(databaseProvider);
await db.saveEntry(entry);
```

**Creating Entries:**
```dart
// Use factory constructors
Entry.line(text: "A thought")
Entry.fragment(text: null)  // Empty is valid
Entry.release(text: "Letting go")

// Media entries (Phase 2)
Entry.photo(mediaPath: "/path/to/photo.jpg", text: "Optional note")
Entry.voice(mediaPath: "/path/to/voice.m4a", text: "Optional note")
Entry.object(title: "Grandma's ring", mediaPath: "/path/to/object.jpg", text: "Story")
```

**Soft Delete (Phase 3):**
```dart
// Soft delete (recoverable for 30 days)
await db.softDeleteEntry(entryId);

// Restore from trash
await db.restoreEntry(entryId);

// Get deleted entries for recovery screen
final deleted = db.getDeletedEntries();

// Purge expired entries (30+ days old)
await db.purgeExpiredEntries();
```

**Media Capture:**
```dart
// Photo capture via service
final photoService = ref.read(photoCaptureServiceProvider);
final result = await photoService.captureFromCamera();
if (result.isSuccess) {
  await creator.createPhotoEntry(result.path!, text: optionalText);
}

// Voice recording (hold-to-record)
final voiceService = ref.read(voiceRecordingServiceProvider);
await voiceService.startRecording();  // On press
final result = await voiceService.stopRecording();  // On release
```

**Tree Growth Thresholds:**
- Seed: 0-10 entries
- Sprout: 11-30 entries
- Sapling: 31-100 entries
- Young Tree: 101-250 entries
- Mature Tree: 251-500 entries
- Ancient Tree: 501+ entries

## Data Models

### Entry Types
| Type | Purpose | Required Fields |
|------|---------|-----------------|
| LINE | Text that stayed with you | None (text optional) |
| PHOTO | Image capture | mediaPath |
| VOICE | Voice memo | mediaPath |
| OBJECT | Physical object | title |
| FRAGMENT | Incomplete thought | None |
| RITUAL | Recurring moment | title |
| RELEASE | Letting go | None |

### Entry Soft Delete Fields (Phase 3)
| Field | Type | Purpose |
|-------|------|---------|
| isDeleted | bool | Whether entry is in trash |
| deletedAt | DateTime? | When entry was deleted (for 30-day expiry) |

### Media Storage Structure
```
<app_documents>/media/
├── photos/       # Photo entries (UUID.jpg)
├── voices/       # Voice memos (UUID.m4a)
└── objects/      # Object photos (UUID.jpg)
```

### Tree States
Trees represent a calendar year. Growth is based on **count**, not frequency (no pressure for daily entries).

## Design Guidelines

### Platform-Adaptive UI (IMPORTANT)

The app should feel native on each platform. **iOS should use glass/translucent effects** following Apple's modern design language.

#### iOS-Specific (Cupertino)
- Use `CupertinoNavigationBar` with translucent backgrounds
- Glass effect sheets with `BackdropFilter` and `ImageFilter.blur(sigmaX: 30, sigmaY: 30)`
- SF Pro font (system default on iOS)
- Large title navigation style
- Translucent tab bars and toolbars
- iOS-style sliding page transitions

```dart
// Glass effect container for iOS
ClipRRect(
  borderRadius: BorderRadius.circular(20),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
    child: Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CupertinoColors.separator.withOpacity(0.2),
        ),
      ),
      child: content,
    ),
  ),
)
```

#### Platform Detection
```dart
import 'dart:io' show Platform;

// Use throughout UI
if (Platform.isIOS) {
  // Cupertino widgets, glass effects
} else {
  // Material widgets
}
```

#### iOS Components to Use
| Instead of (Material) | Use (iOS) |
|----------------------|-----------|
| `AppBar` | `CupertinoNavigationBar` with `backgroundColor: Colors.transparent` |
| `BottomSheet` | `CupertinoPopupSurface` with blur |
| `AlertDialog` | `CupertinoAlertDialog` |
| `TextField` | `CupertinoTextField` |
| `Switch` | `CupertinoSwitch` |
| `Slider` | `CupertinoSlider` |
| `CircularProgressIndicator` | `CupertinoActivityIndicator` |
| `ListTile` | `CupertinoListTile` |
| `SearchBar` | `CupertinoSearchTextField` |

#### Glass Sheet Pattern (iOS)
```dart
showCupertinoModalPopup(
  context: context,
  builder: (context) => BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
    child: CupertinoPopupSurface(
      isSurfacePainted: false,
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.darkColor.withOpacity(0.6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: sheetContent,
      ),
    ),
  ),
);
```

### Colors (SeedlingColors)
- **Primary:** forestGreen (#2D5A3D), leafGreen, freshSprout, paleGreen
- **Secondary:** barkBrown, warmBrown, lightBark
- **Background:** creamPaper (#FAF8F5), warmWhite, softCream
- **Text:** textPrimary, textSecondary, textMuted
- **Accents:** accentPhoto (#6B8E9F), accentVoice (#9F8B6B), accentObject (#8B6B9F)
- **Theme Colors (Phase 4):** themeFamily, themeFriends, themeWork, themeNature, themeGratitude, themeReflection, themeTravel, themeCreativity, themeHealth, themeFood, themeMoments
- **iOS Glass:** Use colors with 0.6-0.8 opacity over blur

### Typography
- **iOS:** SF Pro (system default) - clean, modern
- **Android:** Georgia (serif) for headlines, system sans for body
- **Border radius:** 20px on iOS (matches system), 12px on Android

### Interactions
- Light haptic on save: `HapticFeedback.lightImpact()`
- Selection click on buttons: `HapticFeedback.selectionClick()`
- Medium haptic on recording start: `HapticFeedback.mediumImpact()`
- Heavy haptic on max duration reached: `HapticFeedback.heavyImpact()`
- Soft transitions: `Curves.easeOutCubic`, 200-800ms duration
- iOS: Use spring animations where appropriate

## Development Guidelines

### Do
- Keep capture friction-free (swipe down to save)
- Use factory constructors for Entry creation
- Watch streams for reactive UI updates
- Test tree state boundaries (10, 30, 100, 250, 500)
- **Use platform-adaptive widgets** (Cupertino on iOS, Material on Android)
- **Apply glass/blur effects on iOS** for sheets, cards, and overlays
- Check `Platform.isIOS` for platform-specific UI decisions
- Use `CupertinoTheme` colors on iOS for system integration
- Compress images before saving (1920x1920 max, 85% quality)
- Use UUID for media filenames to prevent collisions
- Use soft delete for user data (30-day recovery window)

### Don't
- Add gamification features
- Require explanations for memories
- Call setState() during deactivate/dispose
- Use mechanical animations (prefer organic curves)
- **Use Material widgets on iOS** (looks out of place)
- Hard-code colors that don't adapt to iOS dark/light mode
- Auto-play voice memos (manual playback only)
- Record for more than 2 minutes (auto-stop with haptic)
- Hard delete user data without recovery option
- Auto-save in deactivate without bulletproof double-save guards (use `_wasExplicitlySaved` flag checked at top of save function)
- Cache provider values in local state when reactivity is needed (use `ref.watch()` in build instead)

## Phase Roadmap

- **Phase 1 (Complete):** Foundation - LINE, FRAGMENT, RELEASE capture, tree visualization
- **Phase 1.5 (Complete):** Platform-Adaptive UI - iOS glass effects, Cupertino components
- **Phase 2 (Complete):** Media - Photo, voice, object capture with full UI
- **Phase 3 (Complete):** Polish - Edit/delete, filters, export, gentle prompts
- **Phase 4 (Complete):** AI - Memory connections, themes, smart suggestions, on-device ML
- **Phase 4.5 (Complete):** Widgets & Capsules - Home widgets, share extension, dark mode, haptics, memory capsules
- **Phase 5 (In Progress):** Data & Animation - Procedural animated tree (complete), backup, cloud sync

## Phase 3 Features (Complete)

### 1. Edit & Soft Delete
- **Edit mode** in entry detail screen (pencil icon in nav bar)
- Edit text and title fields (CupertinoTextField on iOS)
- **Soft delete** moves entries to trash (recoverable for 30 days)
- **Recovery screen** at Settings > Recently Deleted
- Restore or permanently delete from recovery screen
- Tree count updates on delete/restore

### 2. Entry List Improvements
- **Search bar** at top of memories screen (CupertinoSearchTextField on iOS)
- **Filter chips** for entry types (horizontally scrollable)
- **Sort toggle** in nav bar (newest/oldest)
- Clear all filters button when filters active
- Empty state when no results match

### 3. Settings Enhancements
- **Export as JSON** - entries without media via share sheet
- **Export as ZIP** - full backup with all media files
- **Storage usage** - breakdown by database, photos, voices, objects
- **Prompts toggle** - enable/disable gentle prompts
- **Danger Zone** - recently deleted, clear all data (with double confirmation)

### 4. Gentle Prompts
- **Time-aware prompts** - morning, afternoon, evening suggestions
- **Seasonal prompts** - spring, summer, autumn, winter context
- **8-hour cooldown** - prevents prompt fatigue
- **Glass card UI** on tree screen with fade-in animation
- Tap prompt to open capture, X to dismiss
- **Fully optional** - disable in Settings > Prompts

## Phase 4 Features (Complete)

### 1. Memory Connections
- **Jaccard similarity** for text-based connection finding
- **Temporal proximity bonus** for entries within 7 days
- **Theme bonus** for entries sharing themes (full or partial match)
- **"Related Memories" section** in entry detail view
- Horizontal scrollable cards with tap-to-navigate

### 2. Theme Detection
- **11 theme categories:** family, friends, work, nature, gratitude, reflection, travel, creativity, health, food, moments
- **Keyword-based detection** with comprehensive word lists
- **Theme badges** on memory cards (colored emoji chips)
- **Theme filter chips** in memories list (alongside type filters)
- **Theme Insights screen** at Settings > Theme Insights
  - Distribution bar chart by theme
  - Dominant theme highlight
  - Underrepresented theme suggestions

### 3. Smart Suggestions
- **Time-aware:** "It's been a while since you captured a [theme] moment"
- **Pattern-based:** "You often reflect on [day] [time of day]"
- **Gap-filling:** Suggests underrepresented themes
- **Anniversary:** "A year ago today..." (when enabled)
- 24-hour cooldown between suggestions

### 4. On-Device ML Integration
- **iOS:** Apple NaturalLanguage framework (NLTagger, NLEmbedding)
  - Native Swift plugin at `ios/Runner/MLTextAnalyzerPlugin.swift`
  - Sentiment analysis, keyword extraction, semantic similarity
- **Android:** Google ML Kit Entity Extraction
  - Native Kotlin plugin at `android/app/.../MLTextAnalyzerPlugin.kt`
- **Hybrid analyzer:** Uses native ML when available, falls back to keyword-based

### Entry AI Fields
| Field | Type | Purpose |
|-------|------|---------|
| detectedTheme | String? | Primary theme category |
| connectionIds | String? | Comma-separated related entry IDs |
| sentimentScore | double? | -1.0 to 1.0 sentiment |
| lastAnalyzedAt | DateTime? | When AI last processed entry |

### AI Service Patterns
```dart
// Theme detection
final detector = ref.read(themeDetectorProvider);
final theme = detector.detectTheme(entry.searchableContent);

// Find connections
final finder = ref.read(connectionFinderProvider);
final connections = finder.findConnections(entry, allEntries);

// Collection statistics
final stats = ref.watch(collectionStatsProvider);
print(stats.dominantTheme);
print(stats.underrepresentedThemes);

// Native ML (when available)
final mlAnalyzer = ref.read(mlTextAnalyzerProvider);
if (await mlAnalyzer.isAvailable()) {
  final sentiment = await mlAnalyzer.analyzeSentiment(text);
  final keywords = await mlAnalyzer.extractKeywords(text);
}
```

## Phase 4.5 Features (Complete)

### 1. Dark Mode
- **System theme detection** - automatically follows iOS/Android dark mode
- **Warm "forest twilight" aesthetic** - not cold/clinical dark theme
- Dark variants for all colors in `SeedlingColors`
- Both `SeedlingTheme.dark` and `SeedlingCupertinoTheme.dark` available

### 2. Theme-Based Haptics
- **11 unique haptic patterns** for different memory themes
- Located in `lib/core/services/haptic_service.dart`
- Special patterns for capsule creation and unlock
- Example: gratitude = double tap, nature = gentle roll, creativity = playful triple

### 3. Memory Capsules
- **Time capsule entries** that unlock on a future date
- Entry fields: `capsuleUnlockDate`, `isCapsule`, `isLocked`, `isUnlocked`
- Factory: `Entry.capsule(text: "Message", unlockDate: futureDate)`
- Locked capsules show blurred preview with countdown
- Capsules screen at `/capsules` route
- Database queries: `getLockedCapsules()`, `getUnlockedCapsules()`, `getCapsulesToUnlockToday()`

### 4. Share Extension
- **Receive shared content** from other apps
- Package: `receive_sharing_intent`
- Service: `lib/core/services/share/share_receiver_service.dart`
- Supports: text → LINE, URL → LINE, image → PHOTO
- Android: Intent filters in AndroidManifest.xml
- iOS: URL scheme `seedling://` in Info.plist

### 5. Home Screen Widgets
- **iOS:** WidgetKit extension with small/medium/large sizes
- **Android:** AppWidgetProvider with small/medium sizes
- Display: tree emoji, entry count, progress bar, recent entries
- Service: `lib/core/services/widget/widget_data_service.dart`
- Package: `home_widget` for cross-platform data sync
- Deep links: `seedling://home`, `seedling://capture`

#### iOS Widget Manual Setup Required
The widget extension target is configured, but App Groups need manual setup:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** target → Signing & Capabilities → Add "App Groups"
3. Add: `group.com.seedling.seedling`
4. Select **SeedlingWidgetExtension** target → Signing & Capabilities → Add "App Groups"
5. Add: `group.com.seedling.seedling`

### Entry Capsule Fields
| Field | Type | Purpose |
|-------|------|---------|
| capsuleUnlockDate | DateTime? | When capsule becomes visible |
| isCapsule | bool (getter) | Whether entry is a time capsule |
| isLocked | bool (getter) | Capsule exists and unlock date is future |
| isUnlocked | bool (getter) | Capsule exists and unlock date has passed |

### Capsule Patterns
```dart
// Create a capsule
final entry = Entry.capsule(
  text: "Message to future self",
  unlockDate: DateTime.now().add(Duration(days: 365)),
);
await db.saveEntry(entry);

// Query capsules
final locked = db.getLockedCapsules();
final unlocked = db.getUnlockedCapsules();
final today = db.getCapsulesToUnlockToday();

// Check capsule state
if (entry.isLocked) {
  debugPrint("Unlocks in ${entry.daysUntilUnlock} days");
}
```

## Phase 5 Features (Implemented)

### 1. Animated Tree Visualization (Complete)

**Implementation Status:** Fully functional procedural animated tree using CustomPainter

**Files:**
- `lib/features/tree/presentation/animated_tree_visualization.dart` - Main animated tree widget
- `lib/core/services/providers.dart` - Added `treeGrowthEventProvider`, `treeGrowthDetectorProvider`

**Features:**
- **6 distinct tree states** - Seed, sprout, sapling, young tree, mature tree, ancient tree
- **Idle animation** - Continuous gentle sway (3-second cycle)
- **Growth transitions** - Smooth animated morphing between states with scale bounce
- **Seasonal colors** - Spring (fresh green + blossoms), Summer (full green), Autumn (orange + falling leaves), Winter (muted)
- **Celebration particles** - Sparkle burst when tree grows to new state
- **Haptic feedback** - Medium impact on growth, light impact on celebration
- **Organic visuals** - Procedural trunk, branches, leaves, canopy with natural wobble

**Tree Elements by State:**
| State | Visual |
|-------|--------|
| Seed | Glowing oval with ground line |
| Sprout | Curved stem with two leaves |
| Sapling | Small trunk with branch levels and leaf clusters |
| Young Tree | Multiple branch tiers with fuller canopy |
| Mature Tree | Thick trunk, roots, large organic canopy |
| Ancient Tree | Gnarled trunk, elaborate roots, massive layered canopy with glow |

**Usage:**
```dart
AnimatedTreeVisualization(
  state: treeState,           // TreeState enum
  progress: treeProgress,     // 0.0-1.0 progress to next state
  celebrateGrowth: shouldCelebrate, // Triggers particle celebration
  onTap: () => navigateToMemories(),
)
```

**Season Detection:**
```dart
// Automatically determined by current month
Season.spring  // March, April, May
Season.summer  // June, July, August
Season.autumn  // September, October, November
Season.winter  // December, January, February
```

### 2. UX Polish Pass (Implemented)

**Goal:** Make the app feel warm, comfortable, aligned with "breathing, not documenting"

**Files changed:**
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/features/capture/presentation/quick_capture_sheet.dart`
- `lib/features/capture/presentation/widgets/entry_type_button.dart`
- `lib/features/tree/presentation/tree_screen.dart`
- `lib/core/services/providers.dart`
- `lib/core/services/entry_type_usage_service.dart` (new)

**Completed:**
- **Settings headers** — ALL CAPS → sentence case ("Your tree" not "YOUR TREE")
- **Privacy section** — 3 inline tiles (On your device, No cloud sync, No tracking), dialog removed
- **Entry type button restyle** — Unselected: 0.5 opacity + muted color. Selected: full opacity + color bg. AnimatedOpacity for smooth transitions. Release/Capsule use same visual system.
- **Smart button ordering** — `EntryTypeUsageService` records usage on successful save, orders by frequency in rolling 7-day window (capped at 3 uses), stable fallback order for ties
- **"Plant" save button** — Text-only secondary action, appears when `_canSave()` is true, calls `_saveEntry()` directly
- **Prompt auto-dismiss provider** — `currentPromptProvider` returns null if any entry exists today
- **Prompt clipping fix** — Changed `SafeArea(top: false)` → `SafeArea(top: true)`, removed hardcoded padding
- **UI centering fix** — Added `crossAxisAlignment: CrossAxisAlignment.center` to main Column in tree screen
- **Reactive prompt** — Removed local state caching, now uses `ref.watch(currentPromptProvider)` directly in build for reactive updates
- **Double-save protection** — Added `if (_wasExplicitlySaved) return;` guard at top of `_saveEntry()` for bulletproof protection

**Known bugs to fix:**
(None remaining)

**Smart Ordering Patterns:**
```dart
// Record usage (call on successful save only)
final usageService = ref.read(entryTypeUsageServiceProvider);
await usageService.recordUsage(entryType, isCapsule: isCapsule);

// Get ordered types (call on sheet open)
final orderedTypes = ref.watch(orderedEntryTypesProvider);
// Returns: ['line', 'photo', 'voice', ...] ordered by recent usage
```

### 3. Cloud Backup & Sync (Implemented)
- Optional encrypted cloud backup
- Cross-device sync (iCloud for iOS, Google Drive for Android)
- Conflict resolution for offline edits
- Privacy-first: user controls what syncs

### 4. Year-in-Review (Implemented)
- Annual summary generation
- Theme trends over time
- Memory timeline visualization
- Shareable (optional) summary cards

## Testing

Unit tests cover (186 tests total):
- Entry factory constructors (all 7 types)
- Entry properties (hasText, hasMedia, displayContent)
- Entry AI fields (detectedTheme, connectionIds, sentimentScore)
- Tree state transitions at all boundaries
- Tree progress calculations
- Media service result types (success, error, cancelled, permissionDenied)
- Recording/playback state enums
- Capture mode switching
- Compression constants
- Theme detection keyword matching
- Connection similarity calculations
- Suggestion engine logic
- Memory theme enum properties
- Season enum and month mapping (Phase 5)
- Tree growth notifier provider behavior (Phase 5)

Run tests: `flutter test`

### Integration Testing Notes
The following require device/emulator testing:
- AudioPlaybackService (requires Flutter bindings)
- Actual camera/microphone permissions
- File storage operations
- Image compression
- Export/share functionality

## Troubleshooting

**ObjectBox generation fails:**
```bash
dart run build_runner build --delete-conflicting-outputs
```

**CocoaPods issues on iOS:**
```bash
cd ios && pod install
```

**iOS deployment target error:**
Ensure `ios/Podfile` has: `platform :ios, '15.0'`

**Permission denied on camera/mic:**
Check that Info.plist has NSCameraUsageDescription, NSMicrophoneUsageDescription, NSPhotoLibraryUsageDescription

**Audio not playing:**
Ensure the audio file exists at the path and the app has proper permissions.

**Export not working:**
Ensure share_plus and archive packages are installed. Check file permissions on device.

**iOS Widget not showing data:**
Ensure App Groups capability is enabled for both Runner and SeedlingWidgetExtension targets with `group.com.seedling.seedling`. See Phase 4.5 manual setup instructions.

**Android Widget not updating:**
Widget updates on entry save. Force update by removing and re-adding the widget. Check that `SeedlingWidgetProvider` is registered in AndroidManifest.xml.

## Rule: always use qmd before reading files

Before reading files or exploring directories, always use qmd to search for information in local projects.

Available tools:

- `qmd search “query”` — fast keyword search (BM25)

- `qmd query “query”` — hybrid search with reranking (best quality)

- `qmd vsearch “query”` — semantic vector search

- `qmd get <file>` — retrieve a specific document

Use qmd search for quick lookups and qmd query for complex questions.

Use Read/Glob only if qmd doesn’t return enough results.