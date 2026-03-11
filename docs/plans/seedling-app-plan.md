# Seedling: A Memory-Keeping App That Honors Living

## Executive Summary

**App Name:** Seedling (working title - alternatives: Grove, Tendril, Traces)

**Core Philosophy:** Memory-keeping that feels like breathing, not documenting. Inspired by the essay "Capturing your life while living it" by Allie, this app embodies the principle that the best memories are captured in fragments, after the moment, or not at all.

**Visual Metaphor:** Seeds → Trees → Forest. Each memory is a seed. Seeds grow into trees over time (typically one tree per year). Multiple trees form your personal forest of memories.

**Target Platforms:** iOS 17+, Android 12+ (cross-platform via Flutter)

**Monetization:** None. Optimize purely for experience. No ads, no premium tiers, no data harvesting.

---

## Part 1: Design Philosophy & Psychology

### 1.1 Core Principles (From Source Material)

| Principle | Implementation |
|-----------|----------------|
| One line at the end of day | Primary entry mode - single text field, no prompts |
| Photos after the moment | "Capture Later" feature with gentle reminders |
| Meaningful objects over images | Object tagging, physical artifact log |
| Fragments without explanation | No forced context, no required fields |
| Repetition does the work | Auto-detect recurring themes, rituals |
| Voice notes for yourself | Private audio entries, never transcribed by default |
| Letting moments go | "Release" feature - intentional non-capture |

### 1.2 Anti-Patterns to Avoid

**Never include:**
- Streaks or daily logging pressure
- Social sharing or comparison
- Notifications that induce guilt ("You haven't logged in 3 days!")
- Required fields or structured templates
- AI-generated summaries without explicit consent
- Calendar integration that feels like scheduling
- Word counts or character limits that feel restrictive
- "Memories from this day last year" notifications (unless explicitly enabled)

### 1.3 Psychology Framework

#### Intrinsic Motivation (Self-Determination Theory)
- **Autonomy:** User controls everything - what to capture, when, how, whether to look back
- **Competence:** Gentle growth visualization shows "progress" without gamification
- **Relatedness:** The tree is *your* companion, not a social graph

#### Reducing Cognitive Load
- One-tap entry from lock screen/widget
- No decisions required: just capture
- Auto-categorization happens silently in background
- Review is optional, never prompted

#### Endowment Effect
- Watching your tree grow creates emotional attachment
- The longer you use it, the more valuable your forest becomes
- Physical backup exports feel like "saving something precious"

#### Avoiding Zeigarnik Effect (Incomplete Task Anxiety)
- No "incomplete" states - every entry is complete
- Skipping days is invisible - trees grow at their own pace
- No empty states that make the app feel neglected

#### Variable Reward Schedule
- Seasonal themes change subtly
- Trees bloom unpredictably based on entry richness
- Occasional "growth spurts" when looking back

---

## Part 2: Feature Specification

### 2.1 Entry Types

```
┌─────────────────────────────────────────────────────────┐
│                     ENTRY TYPES                         │
├─────────────────────────────────────────────────────────┤
│ 1. LINE        → One sentence, the primary mode         │
│ 2. PHOTO       → Image with optional whisper caption    │
│ 3. VOICE       → Audio note (max 2 min by default)      │
│ 4. OBJECT      → Photo of physical item + story         │
│ 5. FRAGMENT    → Disconnected words, phrases, feelings  │
│ 6. RITUAL      → Recurring moment (auto-detected)       │
│ 7. RELEASE     → Intentional non-capture marker         │
└─────────────────────────────────────────────────────────┘
```

#### 2.1.1 LINE Entry
```yaml
fields:
  - text: string (max 280 chars, soft limit)
  - timestamp: datetime (auto)
  - mood_color: optional hex (user can tap to add subtle color)
  - weather: optional (auto-fetched if permitted)
  - location_hint: optional string (never GPS, just "home", "café", etc.)
```

**UX Flow:**
1. Open app → keyboard immediately visible
2. Type one line
3. Swipe down or tap away to save
4. No confirmation needed

#### 2.1.2 PHOTO Entry
```yaml
fields:
  - image: binary
  - whisper: optional string (max 100 chars) 
  - taken_after: boolean (flag if captured after moment)
  - timestamp: datetime
```

**"Capture Later" Feature:**
- User can set a silent reminder: "Remind me to photograph the table after dinner"
- Reminder is a quiet badge, not a notification
- Creates "intent to capture" that feels different from live-shooting

#### 2.1.3 VOICE Entry
```yaml
fields:
  - audio: binary (compressed opus)
  - duration: int (seconds)
  - timestamp: datetime
  - transcription: optional string (only if user explicitly requests)
```

**UX Notes:**
- Hold-to-record, release to save
- No playback preview by default (reduces self-editing)
- Transcription is opt-in, uses on-device AI only

#### 2.1.4 OBJECT Entry
```yaml
fields:
  - photo: binary
  - name: string (e.g., "ticket stub", "pressed leaf")
  - story: optional string (why it matters)
  - date_acquired: optional date
```

#### 2.1.5 FRAGMENT Entry
```yaml
fields:
  - fragments: list<string> (disconnected pieces)
  - timestamp: datetime
```

**UX:** 
- Special keyboard mode with quick "next fragment" button
- Entries appear as scattered leaves, not a list
- Example: "cold hands", "coffee shop music", "she laughed"

#### 2.1.6 RITUAL Entry
```yaml
fields:
  - name: string (auto-suggested or user-named)
  - first_occurrence: datetime
  - occurrences: list<datetime>
  - notes: optional string
```

**Auto-Detection:**
- On-device AI detects patterns: "morning walk", "Sunday calls with mom"
- Gently suggests: "This seems like a ritual. Want to name it?"
- Never forces categorization

#### 2.1.7 RELEASE Entry
```yaml
fields:
  - timestamp: datetime
  - intention: optional string ("I'm letting this moment stay unlived in memory")
```

**Philosophy:** 
- Intentional non-capture is itself meaningful
- User can mark: "Today had a moment I'm choosing not to keep"
- Appears as a small, unobtrusive marker in timeline

---

### 2.2 The Tree System

#### 2.2.1 Metaphor Mapping

```
MEMORY ELEMENT          →    TREE ELEMENT
─────────────────────────────────────────
Single entry            →    Seed
Entry with connections  →    Sprouted seed
Theme cluster           →    Branch
Rich entry (long/media) →    Leaf
Ritual                  →    Root system
Time period (year)      →    Complete tree
All trees               →    Your forest
```

#### 2.2.2 Tree Growth Rules

```python
# Pseudocode for tree growth calculation
def calculate_tree_state(entries_this_period):
    base_growth = len(entries) * GROWTH_PER_ENTRY
    
    # Richness bonus (not frequency)
    richness_bonus = sum([
        entry.has_photo * 0.5,
        entry.has_voice * 0.7,
        entry.has_object * 1.0,
        len(entry.connections) * 0.3
    ])
    
    # Consistency is NOT rewarded - avoid streak psychology
    # Instead, variety is gently rewarded
    variety_bonus = len(unique_entry_types) * 0.2
    
    return base_growth + richness_bonus + variety_bonus
```

**Visual States:**
1. **Seed** (0-10 entries): Small seed in soil
2. **Sprout** (11-30 entries): Tiny green shoot
3. **Sapling** (31-100 entries): Small tree with few leaves
4. **Young Tree** (101-250 entries): Growing tree
5. **Mature Tree** (251-500 entries): Full tree
6. **Ancient Tree** (500+ entries): Grand, detailed tree

**Seasonal Variations:**
- Trees reflect actual seasons in user's hemisphere
- Spring: Blossoms appear
- Summer: Full foliage
- Autumn: Color changes
- Winter: Bare branches (memories still visible as ornaments)

#### 2.2.3 Tree Interaction

**Tap Behaviors:**
- Tap leaf → See the memory
- Tap branch → See theme cluster
- Tap roots → See rituals
- Long-press trunk → Tree overview stats (gentle, not gamified)
- Pinch out → See forest view

**Forest View:**
- All completed trees arranged in a serene landscape
- Older trees have more character/detail
- Tapping a tree enters that time period

---

### 2.3 AI Features (On-Device Only)

#### 2.3.1 Apple Intelligence Integration (iOS)

**Writing Tools Integration:**
```swift
// Use Apple's Writing Tools for:
- Gentle rewording suggestions (never automatic)
- "Help me express this differently"
- Summarization of voice notes (opt-in)
```

**Semantic Search:**
```swift
// On-device embeddings for:
- "Find memories about the beach"
- "Show me moments with [person]"
- "What did I feel in October?"
```

**Image Intelligence:**
```swift
// Visual understanding:
- Auto-suggest object names
- Detect similar scenes across time
- "Find photos of sunsets"
```

#### 2.3.2 Android ML Kit Integration

```kotlin
// Equivalent features via:
- ML Kit for text/image understanding
- On-device Gemini Nano (Pixel 8+)
- TensorFlow Lite for older devices
```

#### 2.3.3 AI-Powered Features

| Feature | Trigger | Behavior |
|---------|---------|----------|
| Theme detection | Automatic, background | Silently clusters related memories |
| Ritual suggestion | After 3+ similar entries | Gentle prompt to name pattern |
| Seed connections | On entry | "This feels related to [memory]" |
| Time capsule suggestions | Seasonal | "Want to seal these for future you?" |
| Writing prompts | Only if enabled | Subtle prompt from your own words |

**Critical Rule:** AI never modifies, summarizes, or presents memories without explicit consent. It only helps find and connect.

---

### 2.4 Time Capsules

**Concept:** Seal a collection of memories to be "opened" at a future date.

```yaml
time_capsule:
  created: datetime
  unlock_date: datetime
  memories: list<entry_id>
  message_to_future_self: optional string
  status: sealed | unlocked
```

**UX:**
- Creating a capsule feels like wrapping a gift
- Sealed capsules appear as glowing orbs at tree base
- On unlock date: gentle notification, capsule "opens" with animation
- Can set capsules for: 1 month, 6 months, 1 year, 5 years, custom

---

### 2.5 Backup & Export

#### 2.5.1 Automatic Backups

**Options:**
1. iCloud (iOS) / Google Drive (Android)
2. Local encrypted backup
3. Self-hosted (WebDAV, Nextcloud)
4. No backup (user's choice, respected)

**Backup Format:**
```
seedling_backup_2026-01-26/
├── manifest.json          # Metadata, version, checksum
├── entries/
│   ├── lines.json
│   ├── photos/
│   ├── voice/
│   └── objects/
├── trees/
│   └── tree_states.json
├── settings.json
└── encryption_test.enc    # Verifies password correctness
```

#### 2.5.2 Export Formats

| Format | Use Case |
|--------|----------|
| JSON | Full data, reimportable |
| PDF | Beautiful printed memory book |
| Markdown | Plain text archive |
| Static HTML | Self-hosted memory website |
| Physical Book | Integration with print services |

#### 2.5.3 Import

**Support importing from:**
- Day One
- Journey
- Notion exports
- Plain text/markdown files
- Photo libraries (with date metadata)

---

### 2.6 Widgets & Quick Capture

#### 2.6.1 iOS Widgets

**Lock Screen Widget:**
- Single tap → opens to LINE entry
- Shows gentle prompt from user's own past words (optional)

**Home Screen Widgets:**
- Small: Today's tree growth
- Medium: Recent memories peek
- Large: Tree visualization

**Live Activities:**
- "Capture Later" reminder as subtle island

#### 2.6.2 Android Widgets

- Same functionality
- Material You theming
- Glance widgets for Wear OS

#### 2.6.3 Quick Actions

**iOS:**
- 3D Touch / Haptic Touch shortcuts
- Siri Shortcuts integration
- "Hey Siri, add to Seedling: [text]"

**Android:**
- App shortcuts
- Google Assistant integration
- Quick settings tile

---

## Part 3: Technical Architecture

### 3.1 Technology Stack

```
┌─────────────────────────────────────────────────────────┐
│                    FRONTEND                              │
├─────────────────────────────────────────────────────────┤
│ Framework: Flutter 3.x                                   │
│ State: Riverpod 2.x                                      │
│ Routing: GoRouter                                        │
│ Animations: Rive (tree animations)                       │
│ Design: Custom design system, no Material/Cupertino     │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                    DATA LAYER                            │
├─────────────────────────────────────────────────────────┤
│ Local DB: Isar (fast, Flutter-native)                   │
│ File Storage: Platform file system                       │
│ Encryption: libsodium (via flutter_sodium)              │
│ Sync: Custom CRDT-based sync engine                     │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                    PLATFORM LAYER                        │
├─────────────────────────────────────────────────────────┤
│ iOS: Swift modules for Apple Intelligence               │
│ Android: Kotlin modules for ML Kit                      │
│ Method Channels: Platform-specific features             │
└─────────────────────────────────────────────────────────┘
```

### 3.2 Data Models

```dart
// Core entry model
@Collection()
class Entry {
  Id? id;
  
  @Enumerated(EnumType.name)
  late EntryType type;
  
  late DateTime createdAt;
  DateTime? modifiedAt;
  
  String? text;
  String? whisper;
  
  List<String>? fragments;
  
  @Backlink(to: 'entries')
  final tree = IsarLink<Tree>();
  
  final connections = IsarLinks<Entry>();
  
  final media = IsarLinks<MediaAsset>();
  
  // Soft metadata
  String? moodColor;
  String? locationHint;
  String? weather;
  
  bool isReleased = false; // For RELEASE type
  bool capturedAfter = false; // For PHOTO type
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

@Collection()
class Tree {
  Id? id;
  
  late DateTime startDate;
  DateTime? endDate;
  
  late TreePeriod period; // year, custom
  
  @Backlink(to: 'tree')
  final entries = IsarLinks<Entry>();
  
  double growthLevel = 0;
  TreeState visualState = TreeState.seed;
  
  String? customName; // "2025" or user's name
}

enum TreeState {
  seed,
  sprout,
  sapling,
  youngTree,
  matureTree,
  ancientTree,
}

@Collection()
class MediaAsset {
  Id? id;
  
  late String localPath;
  late MediaType type;
  late int sizeBytes;
  
  String? cloudBackupId;
  DateTime? lastBackup;
}

@Collection()
class Ritual {
  Id? id;
  
  late String name;
  String? description;
  
  late DateTime firstOccurrence;
  List<DateTime> occurrences = [];
  
  bool autoDetected = true;
  bool userConfirmed = false;
}

@Collection()
class TimeCapsule {
  Id? id;
  
  late DateTime createdAt;
  late DateTime unlockAt;
  
  final memories = IsarLinks<Entry>();
  
  String? messageToFuture;
  
  bool isUnlocked = false;
  DateTime? unlockedAt;
}
```

### 3.3 Offline-First Sync Architecture

```
┌────────────────────────────────────────────────────────┐
│                    SYNC ENGINE                          │
├────────────────────────────────────────────────────────┤
│                                                         │
│  Local Write ──► CRDT Log ──► Conflict Resolution      │
│       │              │               │                  │
│       ▼              ▼               ▼                  │
│  Isar DB        Version Vector   Merge Strategy        │
│                                                         │
│  On Connectivity:                                       │
│  ─────────────────                                      │
│  1. Push local changes to cloud                        │
│  2. Pull remote changes                                 │
│  3. Apply CRDT merge                                    │
│  4. Update local state                                  │
│                                                         │
│  Conflict Resolution:                                   │
│  ────────────────────                                   │
│  - Last-write-wins for simple fields                   │
│  - Union merge for connections/links                   │
│  - User prompt for text conflicts (rare)               │
│                                                         │
└────────────────────────────────────────────────────────┘
```

### 3.4 Apple Intelligence Integration (iOS)

```swift
// SeedlingAI.swift - iOS Native Module

import Foundation
import NaturalLanguage
import CoreML

@objc class SeedlingAI: NSObject {
    
    // MARK: - Semantic Search
    @objc func findRelatedMemories(
        query: String,
        entries: [EntryBridge],
        completion: @escaping ([String]) -> Void
    ) {
        // Use Apple's on-device embeddings
        let embedding = NLEmbedding.sentenceEmbedding(for: .english)
        
        guard let queryVector = embedding?.vector(for: query) else {
            completion([])
            return
        }
        
        var scored: [(id: String, score: Double)] = []
        
        for entry in entries {
            if let entryVector = embedding?.vector(for: entry.text) {
                let similarity = cosineSimilarity(queryVector, entryVector)
                scored.append((entry.id, similarity))
            }
        }
        
        let results = scored
            .sorted { $0.score > $1.score }
            .prefix(10)
            .map { $0.id }
        
        completion(Array(results))
    }
    
    // MARK: - Theme Detection
    @objc func detectThemes(
        entries: [EntryBridge],
        completion: @escaping ([ThemeCluster]) -> Void
    ) {
        // Use on-device NL processing
        let tagger = NLTagger(tagSchemes: [.lemma, .nameType])
        
        // Extract key concepts from each entry
        // Cluster using simple algorithms (no cloud needed)
        // Return theme suggestions
    }
    
    // MARK: - Ritual Detection
    @objc func detectRituals(
        entries: [EntryBridge],
        completion: @escaping ([RitualSuggestion]) -> Void
    ) {
        // Pattern matching for:
        // - Similar times of day
        // - Similar locations
        // - Similar phrases/words
        // - Weekly/monthly patterns
    }
    
    // MARK: - Writing Assistance (Opt-in)
    @objc func suggestAlternateExpression(
        text: String,
        completion: @escaping (String?) -> Void
    ) {
        // Only called if user explicitly requests
        // Uses Apple's Writing Tools API
    }
}
```

### 3.5 Android ML Kit Integration

```kotlin
// SeedlingAI.kt - Android Native Module

class SeedlingAI(private val context: Context) {
    
    private val entityExtractor = EntityExtraction.getClient(
        EntityExtractorOptions.Builder(EntityExtractorOptions.ENGLISH)
            .build()
    )
    
    // Semantic search using TFLite sentence embeddings
    suspend fun findRelatedMemories(
        query: String,
        entries: List<EntryBridge>
    ): List<String> {
        val interpreter = Interpreter(loadModel())
        
        val queryEmbedding = embed(query, interpreter)
        
        return entries
            .map { entry -> 
                entry.id to cosineSimilarity(
                    queryEmbedding, 
                    embed(entry.text, interpreter)
                )
            }
            .sortedByDescending { it.second }
            .take(10)
            .map { it.first }
    }
    
    // Entity extraction for auto-tagging
    suspend fun extractEntities(text: String): List<Entity> {
        return suspendCoroutine { cont ->
            entityExtractor.annotate(text)
                .addOnSuccessListener { result ->
                    cont.resume(result.flatMap { it.entities })
                }
        }
    }
}
```

### 3.6 File Structure

```
seedling/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart
│   │   └── theme/
│   │       ├── seedling_theme.dart
│   │       ├── colors.dart
│   │       ├── typography.dart
│   │       └── animations.dart
│   │
│   ├── features/
│   │   ├── capture/
│   │   │   ├── capture_screen.dart
│   │   │   ├── line_entry.dart
│   │   │   ├── photo_entry.dart
│   │   │   ├── voice_entry.dart
│   │   │   ├── object_entry.dart
│   │   │   ├── fragment_entry.dart
│   │   │   └── widgets/
│   │   │
│   │   ├── tree/
│   │   │   ├── tree_screen.dart
│   │   │   ├── tree_visualization.dart
│   │   │   ├── forest_view.dart
│   │   │   └── growth_calculator.dart
│   │   │
│   │   ├── memories/
│   │   │   ├── memories_screen.dart
│   │   │   ├── memory_detail.dart
│   │   │   ├── search_screen.dart
│   │   │   └── timeline_view.dart
│   │   │
│   │   ├── rituals/
│   │   │   ├── rituals_screen.dart
│   │   │   └── ritual_detail.dart
│   │   │
│   │   ├── capsules/
│   │   │   ├── capsules_screen.dart
│   │   │   ├── create_capsule.dart
│   │   │   └── open_capsule.dart
│   │   │
│   │   └── settings/
│   │       ├── settings_screen.dart
│   │       ├── backup_settings.dart
│   │       ├── privacy_settings.dart
│   │       └── export_screen.dart
│   │
│   ├── data/
│   │   ├── models/
│   │   ├── repositories/
│   │   └── datasources/
│   │       ├── local/
│   │       │   ├── isar_database.dart
│   │       │   └── file_storage.dart
│   │       └── remote/
│   │           ├── cloud_backup.dart
│   │           └── sync_engine.dart
│   │
│   ├── core/
│   │   ├── utils/
│   │   ├── extensions/
│   │   ├── constants/
│   │   └── services/
│   │       ├── encryption_service.dart
│   │       ├── notification_service.dart
│   │       └── ai_service.dart
│   │
│   └── platform/
│       ├── method_channels.dart
│       └── platform_ai.dart
│
├── ios/
│   └── Runner/
│       ├── SeedlingAI.swift
│       └── AppleIntelligenceBridge.swift
│
├── android/
│   └── app/src/main/kotlin/
│       ├── SeedlingAI.kt
│       └── MLKitBridge.kt
│
├── assets/
│   ├── rive/
│   │   ├── tree_seed.riv
│   │   ├── tree_sprout.riv
│   │   ├── tree_sapling.riv
│   │   ├── tree_young.riv
│   │   ├── tree_mature.riv
│   │   └── tree_ancient.riv
│   │
│   ├── fonts/
│   └── images/
│
└── test/
```

---

## Part 4: UX Specifications

### 4.1 Design Language

**Visual Tone:** Warm, organic, paper-like. Not sterile or digital.

**Color Palette:**
```
Primary:     #4A5D23 (Forest green)
Secondary:   #8B7355 (Warm brown)
Background:  #FAF8F5 (Cream paper)
Surface:     #FFFFFF
Text:        #2C2C2C (Soft black)
Subtle:      #A0A0A0 (Muted gray)

Seasonal accents:
Spring:      #F2C4CE (Blossom pink)
Summer:      #7CB342 (Leaf green)
Autumn:      #D4A84B (Golden)
Winter:      #B8C5D6 (Frost blue)
```

**Typography:**
```
Headlines:   Freight Text Pro (or similar serif)
Body:        Source Sans Pro
Handwritten: Caveat (for whispers/fragments)
```

**Motion Principles:**
- Organic, never mechanical
- Growth animations are slow, satisfying
- Transitions feel like turning pages
- Haptics are gentle, affirming

### 4.2 Key Screens

#### 4.2.1 Home Screen

```
┌─────────────────────────────────────┐
│                                     │
│         [Your Tree Here]            │
│                                     │
│    Animated tree visualization      │
│    Tappable leaves = memories       │
│                                     │
│                                     │
├─────────────────────────────────────┤
│                                     │
│    "Evening light through trees"    │
│    (Most recent entry preview)      │
│                                     │
├─────────────────────────────────────┤
│                                     │
│         [ + Add Memory ]            │
│    (Prominent but not pushy)        │
│                                     │
└─────────────────────────────────────┘
```

#### 4.2.2 Quick Capture Sheet

```
┌─────────────────────────────────────┐
│  ─────  (Drag handle)               │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ What stayed with you today? │    │
│  │ ___________________________ │    │
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  [📷] [🎤] [📦] [✨] [💨]           │
│  Photo Voice Object Fragment Let Go │
│                                     │
└─────────────────────────────────────┘

Swipe down or tap outside = save & close
No "Save" button needed
```

#### 4.2.3 Memory Detail

```
┌─────────────────────────────────────┐
│ ← Back                    ⋮ More    │
├─────────────────────────────────────┤
│                                     │
│  January 15, 2026                   │
│  Tuesday afternoon                  │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  "The way the rain sounded on the   │
│   café window"                      │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  ☁️ Overcast  •  Coffee shop        │
│                                     │
│  Connected to:                      │
│  ┌──────────────────────────┐       │
│  │ "First rain of winter"   │       │
│  │ December 3               │       │
│  └──────────────────────────┘       │
│                                     │
└─────────────────────────────────────┘
```

#### 4.2.4 Forest View

```
┌─────────────────────────────────────┐
│  My Forest              [⚙️]        │
├─────────────────────────────────────┤
│                                     │
│     🌳        🌲                    │
│        🌴            🌳             │
│  2023    2024           2025        │
│              🌱                     │
│             (current)               │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  4 trees • 1,247 memories           │
│  First seed: March 2023             │
│                                     │
└─────────────────────────────────────┘
```

### 4.3 Interaction Patterns

#### Gesture Language
| Gesture | Action |
|---------|--------|
| Swipe down on capture | Save and close |
| Swipe right on memory | Archive/hide |
| Long press on tree | Open tree stats |
| Pinch out on tree | See forest |
| Double tap | Quick line entry |
| Shake (optional) | Random memory |

#### Haptic Feedback
| Event | Haptic |
|-------|--------|
| Memory saved | Light success tap |
| Tree grows | Slow, satisfying pulse |
| Capsule opens | Series of light taps |
| Connection made | Double light tap |
| Release moment | Soft fade tap |

### 4.4 Onboarding

**Philosophy:** Minimal. The app should be self-evident.

**Flow:**
1. **Welcome** (1 screen): "A gentle place for your memories"
2. **First seed** (interactive): Invite to plant first memory
3. **Done**: No tutorial, no feature tour

**Deferred explanations:**
- Features reveal themselves contextually
- Tooltips appear once, gently, when relevant
- Full guide available in settings (never pushed)

### 4.5 Empty States

**Instead of:** "No memories yet! Start capturing!"

**Use:** 
- A peaceful seed waiting in soil
- Soft text: "Your first seed is waiting"
- No urgency, no exclamation marks

---

## Part 5: Privacy & Data

### 5.1 Privacy Principles

1. **Local by default**: All data stays on device unless backup enabled
2. **No analytics**: Zero tracking, zero telemetry
3. **No cloud AI**: All AI processing on-device only
4. **Encryption**: AES-256 for backups, ChaCha20 for local
5. **No account required**: App works fully offline forever
6. **User owns data**: Export everything, anytime, any format

### 5.2 Data Storage

```
Local storage structure:
───────────────────────
App Documents/
├── seedling.isar       # Main database
├── media/
│   ├── photos/
│   ├── voice/
│   └── objects/
├── exports/            # Temporary export staging
└── .seedling_key       # Encrypted master key
```

### 5.3 Backup Security

**Encryption flow:**
```
User password
     │
     ▼
Argon2id (memory-hard KDF)
     │
     ▼
Master key
     │
     ├──► AES-256-GCM for database
     │
     └──► ChaCha20-Poly1305 for media files
```

**Backup destinations:**
- iCloud (iOS) - encrypted before upload
- Google Drive (Android) - encrypted before upload
- Local file - encrypted
- WebDAV/Nextcloud - encrypted

### 5.4 Permissions

| Permission | Required | Justification |
|------------|----------|---------------|
| Camera | Optional | Photo/object capture |
| Microphone | Optional | Voice notes |
| Photo Library | Optional | Import existing photos |
| Location | Never | Only manual location hints |
| Notifications | Optional | Time capsule opens, capture reminders |
| Background Refresh | Optional | Backup sync |

---

## Part 6: Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4)

**Goals:** Core architecture, basic capture, local storage

- [ ] Flutter project setup with architecture
- [ ] Isar database models and migrations
- [ ] Basic LINE entry capture
- [ ] Local file storage for media
- [ ] Simple tree visualization (static)
- [ ] Theme and design system
- [ ] Basic home screen

### Phase 2: Rich Capture (Weeks 5-8)

**Goals:** All entry types, media handling

- [ ] PHOTO entry with "capture later" feature
- [ ] VOICE entry with recording
- [ ] OBJECT entry
- [ ] FRAGMENT entry
- [ ] RELEASE entry
- [ ] Media compression and optimization
- [ ] Entry detail views

### Phase 3: Tree System (Weeks 9-12)

**Goals:** Dynamic tree, forest view, growth mechanics

- [ ] Rive animations for tree states
- [ ] Growth calculation engine
- [ ] Tree interaction (tap to explore)
- [ ] Forest view with multiple trees
- [ ] Seasonal theming
- [ ] Tree statistics

### Phase 4: AI & Intelligence (Weeks 13-16)

**Goals:** On-device AI features

- [ ] iOS: Apple Intelligence integration
- [ ] Android: ML Kit integration
- [ ] Semantic search
- [ ] Theme detection
- [ ] Ritual auto-detection
- [ ] Memory connections

### Phase 5: Time & Backup (Weeks 17-20)

**Goals:** Time capsules, sync, export

- [ ] Time capsule creation and unlocking
- [ ] Encrypted backup system
- [ ] iCloud/Google Drive sync
- [ ] Export formats (JSON, PDF, Markdown, HTML)
- [ ] Import from other apps

### Phase 6: Polish & Platform (Weeks 21-24)

**Goals:** Widgets, quick actions, refinement

- [ ] iOS widgets (all sizes)
- [ ] Android widgets
- [ ] Lock screen widget
- [ ] Siri/Assistant shortcuts
- [ ] Haptic refinement
- [ ] Animation polish
- [ ] Performance optimization
- [ ] Accessibility audit

---

## Part 7: Testing Strategy

### 7.1 Unit Tests

```dart
// Example: Growth calculator tests
void main() {
  group('GrowthCalculator', () {
    test('empty entries return seed state', () {
      final calc = GrowthCalculator([]);
      expect(calc.state, TreeState.seed);
    });
    
    test('photo entries add richness bonus', () {
      final entries = [
        Entry.line('Test'),
        Entry.photo(path: 'test.jpg'),
      ];
      final calc = GrowthCalculator(entries);
      expect(calc.richness, greaterThan(0));
    });
    
    test('variety is rewarded over frequency', () {
      // 10 lines vs 5 mixed types
      final allLines = List.generate(10, (_) => Entry.line('Test'));
      final mixed = [
        Entry.line('Test'),
        Entry.photo(path: 'a.jpg'),
        Entry.voice(path: 'b.m4a'),
        Entry.fragment(['a', 'b']),
        Entry.object(name: 'leaf'),
      ];
      
      final linesCalc = GrowthCalculator(allLines);
      final mixedCalc = GrowthCalculator(mixed);
      
      expect(mixedCalc.variety, greaterThan(linesCalc.variety));
    });
  });
}
```

### 7.2 Widget Tests

```dart
void main() {
  group('QuickCaptureSheet', () {
    testWidgets('swipe down saves entry', (tester) async {
      // Test that swiping saves without explicit button
    });
    
    testWidgets('empty entry is not saved', (tester) async {
      // Test that blank entries don't create records
    });
  });
}
```

### 7.3 Integration Tests

- Full capture → storage → display flow
- Backup → restore → verify
- Sync conflict resolution
- Time capsule lifecycle

### 7.4 User Testing Focus

**Key questions:**
1. Does capture feel effortless?
2. Does the tree feel like "mine"?
3. Is there any guilt or pressure?
4. Does looking back feel good?
5. Would you use this daily without prompting?

---

## Part 8: Accessibility

### 8.1 Requirements

- VoiceOver (iOS) / TalkBack (Android) full support
- Dynamic Type / Font scaling
- Reduce Motion support
- Color contrast AAA compliance
- Alternative text for all visual elements

### 8.2 Tree Accessibility

```dart
// Tree visualization accessibility
Semantics(
  label: 'Your memory tree for 2025. '
         'Currently at sapling stage with 47 memories. '
         'Tap to explore memories.',
  child: TreeVisualization(),
)
```

### 8.3 Voice Input

- Full voice control for capture
- "Add a line: [text]" 
- "Take a photo for later"
- Navigate tree with voice

---

## Part 9: Localization

### 9.1 Supported Languages (Initial)

- English (US, UK)
- Spanish
- French
- German
- Japanese
- Simplified Chinese
- Hindi

### 9.2 Localization Notes

- Tree metaphors may need cultural adaptation
- Date/time formatting per locale
- Right-to-left support for future Arabic/Hebrew
- Seasonal themes adapt to hemisphere

---

## Part 10: Success Metrics (Non-Commercial)

Since this app isn't monetized, success is measured differently:

### 10.1 Quality Metrics

| Metric | Target |
|--------|--------|
| App Store rating | 4.8+ |
| Crash-free sessions | 99.9% |
| Cold start time | <1.5s |
| Memory usage | <100MB typical |

### 10.2 User Experience Metrics (Self-Reported)

- "Does this app make you feel good about your memories?"
- "Do you feel pressure to use this app?"
- "Would you recommend this to a friend?"

### 10.3 Usage Patterns (Privacy-Respecting)

If user opts in to anonymous usage data:
- Average entries per week (not daily to avoid streak thinking)
- Most used entry types
- Feature discovery rate

---

## Appendix A: Claude Code Instructions

When implementing this app, follow these priorities:

### A.1 Critical Rules

1. **Never add gamification** - No badges, achievements, streaks, or points
2. **Never add social features** - This is private space
3. **Never require internet** - Must work fully offline
4. **Never send data anywhere** - Unless explicit backup enabled
5. **Never auto-modify memories** - AI suggestions only

### A.2 Code Quality

```dart
// Follow these patterns:

// ✅ Good: Explicit, readable
Future<void> saveEntry(Entry entry) async {
  await _database.entries.put(entry);
  await _updateTreeGrowth(entry.tree.value!);
  await _detectConnections(entry);
}

// ❌ Bad: Clever but unclear
Future<void> save(e) async => _db.put(e)..then(_update)..then(_detect);

// ✅ Good: User-centric naming
class QuickCaptureSheet extends StatelessWidget {}

// ❌ Bad: Technical naming
class EntryCreationModalBottomSheet extends StatelessWidget {}
```

### A.3 Testing Requirements

- Every feature must have unit tests
- Every screen must have widget tests
- Integration tests for critical paths
- No PR without tests

### A.4 Documentation

- Every public method needs dartdoc
- Complex algorithms need explanatory comments
- README must stay updated

---

## Appendix B: Design Assets Needed

### B.1 Illustrations

- Tree states (6 stages) - Rive animations
- Seasonal variations (4 seasons × 6 states = 24 variants)
- Forest background
- Seed planting animation
- Capsule opening animation

### B.2 Icons

- Entry type icons (7 types)
- Navigation icons
- Action icons
- Weather icons (optional feature)

### B.3 Fonts

- License Freight Text Pro or find open alternative
- Include Caveat for handwritten feel
- Source Sans Pro (open source)

---

## Appendix C: Open Questions

1. **Tree period flexibility**: Should users be able to choose tree duration (year, quarter, custom)?

2. **Shared capsules**: Should there be an option to create capsules for others? (E.g., "Open when you graduate")

3. **Physical print**: Partner with print service for memory books?

4. **Watch apps**: Apple Watch / Wear OS companion for quick capture?

5. **Desktop apps**: macOS/Windows for deeper exploration?

---

*This document serves as the north star for Seedling development. Every feature should be evaluated against the core philosophy: memory-keeping that feels like living, not documenting.*
