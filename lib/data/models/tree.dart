import 'package:objectbox/objectbox.dart';

/// Growth stages for the tree visualization
/// Each stage has meaning in the metaphor of memory-keeping
enum TreeState {
  seed, // 0-10 entries - Just planted, potential
  sprout, // 11-30 entries - Breaking ground, beginning
  sapling, // 31-100 entries - Growing stronger
  youngTree, // 101-250 entries - Taking shape
  matureTree, // 251-500 entries - Full and flourishing
  ancientTree, // 500+ entries - Deep roots, rich history
}

/// A tree represents a year of memories
///
/// Core philosophy: Growth is measured by count, not frequency
/// No gamification - the tree grows naturally as you capture
/// memories without pressure for daily streaks.
@Entity()
class Tree {
  @Id()
  int id = 0;

  /// The year this tree represents
  int year;

  /// Total number of entries in this tree
  int entryCount;

  /// When this tree was created (first entry of the year)
  @Property(type: PropertyType.date)
  DateTime createdAt;

  /// Cached state index for quick lookup
  int stateIndex;

  /// Get the current TreeState enum value
  TreeState get state => TreeState.values[stateIndex];

  /// Set the TreeState enum value
  set state(TreeState value) => stateIndex = value.index;

  Tree({
    this.id = 0,
    required this.year,
    this.entryCount = 0,
    DateTime? createdAt,
    this.stateIndex = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create a tree for the current year
  factory Tree.currentYear() {
    return Tree(year: DateTime.now().year);
  }

  /// Growth thresholds - intentionally generous
  /// Philosophy: Growth should feel natural, not pressured
  static const Map<TreeState, int> thresholds = {
    TreeState.seed: 0,
    TreeState.sprout: 11, // ~2 weeks of occasional entries
    TreeState.sapling: 31, // ~1 month
    TreeState.youngTree: 101, // ~3 months
    TreeState.matureTree: 251, // ~8 months
    TreeState.ancientTree: 501, // Full year of rich memories
  };

  /// Update the visual state based on entry count
  /// Returns true if state changed
  bool updateVisualState() {
    final previousState = state;

    if (entryCount >= thresholds[TreeState.ancientTree]!) {
      state = TreeState.ancientTree;
    } else if (entryCount >= thresholds[TreeState.matureTree]!) {
      state = TreeState.matureTree;
    } else if (entryCount >= thresholds[TreeState.youngTree]!) {
      state = TreeState.youngTree;
    } else if (entryCount >= thresholds[TreeState.sapling]!) {
      state = TreeState.sapling;
    } else if (entryCount >= thresholds[TreeState.sprout]!) {
      state = TreeState.sprout;
    } else {
      state = TreeState.seed;
    }

    return previousState != state;
  }

  /// Increment entry count and update state
  /// Returns true if state changed (for celebration animation)
  bool addEntry() {
    entryCount++;
    return updateVisualState();
  }

  /// Decrement entry count and update state
  bool removeEntry() {
    if (entryCount > 0) {
      entryCount--;
      return updateVisualState();
    }
    return false;
  }

  /// Get progress towards next growth stage (0.0 - 1.0)
  double get progressToNextStage {
    final currentThreshold = thresholds[state]!;
    final stateIndex = TreeState.values.indexOf(state);

    if (stateIndex >= TreeState.values.length - 1) {
      // Already at max stage
      return 1.0;
    }

    final nextState = TreeState.values[stateIndex + 1];
    final nextThreshold = thresholds[nextState]!;
    final range = nextThreshold - currentThreshold;
    final progress = entryCount - currentThreshold;

    return (progress / range).clamp(0.0, 1.0);
  }

  /// Get entries needed for next growth stage
  int get entriesUntilNextStage {
    final stateIndex = TreeState.values.indexOf(state);

    if (stateIndex >= TreeState.values.length - 1) {
      return 0; // Already at max stage
    }

    final nextState = TreeState.values[stateIndex + 1];
    final nextThreshold = thresholds[nextState]!;

    return nextThreshold - entryCount;
  }

  /// Get display name for current state
  String get stateName {
    switch (state) {
      case TreeState.seed:
        return 'Seed';
      case TreeState.sprout:
        return 'Sprout';
      case TreeState.sapling:
        return 'Sapling';
      case TreeState.youngTree:
        return 'Young Tree';
      case TreeState.matureTree:
        return 'Mature Tree';
      case TreeState.ancientTree:
        return 'Ancient Tree';
    }
  }

  /// Get a poetic description for the current state
  String get stateDescription {
    switch (state) {
      case TreeState.seed:
        return 'Every memory starts as a seed';
      case TreeState.sprout:
        return 'Your memories are taking root';
      case TreeState.sapling:
        return 'Growing stronger with each moment';
      case TreeState.youngTree:
        return 'Your tree is finding its shape';
      case TreeState.matureTree:
        return 'A flourishing collection of memories';
      case TreeState.ancientTree:
        return 'Deep roots, rich with stories';
    }
  }
}
