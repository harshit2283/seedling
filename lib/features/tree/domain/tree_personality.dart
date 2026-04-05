import 'package:flutter/material.dart';
import '../../../core/services/ai/models/memory_theme.dart';

/// Visual personality for the tree based on the user's dominant memory themes.
///
/// Maps the distribution of memory themes to visual parameters that
/// subtly tint the tree, add decorative elements, and adjust foliage density.
/// The effect is gentle — a 30% blend with seasonal colors — so the tree
/// always feels like *their* tree rather than a themed skin.
class TreePersonality {
  /// Tint color for blossoms and flower elements.
  final Color blossomColor;

  /// Secondary accent used for leaf tinting and particle colors.
  final Color accentColor;

  /// Multiplier for foliage density (0.8 - 1.5). Values above 1.0
  /// produce lusher canopies; below 1.0 produce sparser ones.
  final double foliageDensity;

  /// Whether to draw small golden fruit on branches (gratitude theme).
  final bool showFruit;

  /// Whether to draw tiny bird silhouettes near the canopy (nature theme).
  final bool showBirds;

  /// The dominant theme that produced this personality, if any.
  final MemoryTheme? dominantTheme;

  const TreePersonality({
    required this.blossomColor,
    required this.accentColor,
    required this.foliageDensity,
    required this.showFruit,
    required this.showBirds,
    this.dominantTheme,
  });

  /// Default personality with no theme-driven overrides.
  static const TreePersonality defaults = TreePersonality(
    blossomColor: Color(0xFFF8BBD0), // Default soft pink
    accentColor: Color(0xFF7CB083), // freshSprout
    foliageDensity: 1.0,
    showFruit: false,
    showBirds: false,
    dominantTheme: null,
  );

  /// Build a personality from the user's theme distribution.
  ///
  /// Finds the dominant theme (highest count, ignoring `moments` unless
  /// it is the only theme) and maps it to visual parameters.
  /// Returns the default personality when the distribution is empty or
  /// evenly spread with no clear winner.
  factory TreePersonality.fromDistribution(Map<MemoryTheme, int> distribution) {
    if (distribution.isEmpty) return defaults;

    // Find dominant theme (exclude moments as it is the fallback)
    final nonMoments = Map<MemoryTheme, int>.from(distribution)
      ..remove(MemoryTheme.moments);

    if (nonMoments.isEmpty) return defaults;

    final maxCount = nonMoments.values.fold<int>(0, (a, b) => a > b ? a : b);
    if (maxCount == 0) return defaults;

    // Check for a tie — if more than one theme shares the max, treat as even
    final topThemes = nonMoments.entries
        .where((e) => e.value == maxCount)
        .toList();
    if (topThemes.length > 2) return defaults; // Too even, no personality

    final dominant = topThemes.first.key;

    return switch (dominant) {
      MemoryTheme.family => TreePersonality(
        blossomColor: const Color(0xFFE8A0B0), // warm pink / rose
        accentColor: const Color(0xFF9F6B7D), // dusty rose
        foliageDensity: 1.1,
        showFruit: false,
        showBirds: false,
        dominantTheme: dominant,
      ),
      MemoryTheme.nature => TreePersonality(
        blossomColor: const Color(0xFFA8D5A0), // soft green blossoms
        accentColor: const Color(0xFF3D6B4D), // deeper green
        foliageDensity: 1.3,
        showFruit: false,
        showBirds: true,
        dominantTheme: dominant,
      ),
      MemoryTheme.gratitude => TreePersonality(
        blossomColor: const Color(0xFFE8D4A0), // warm golden
        accentColor: const Color(0xFFD4A76A), // warm gold
        foliageDensity: 1.1,
        showFruit: true,
        showBirds: false,
        dominantTheme: dominant,
      ),
      MemoryTheme.travel => TreePersonality(
        blossomColor: const Color(0xFFA0D4D4), // light teal
        accentColor: const Color(0xFF6B9F9F), // teal
        foliageDensity: 1.0,
        showFruit: false,
        showBirds: false,
        dominantTheme: dominant,
      ),
      MemoryTheme.creativity => TreePersonality(
        blossomColor: const Color(0xFFD4A890), // warm terracotta blossom
        accentColor: const Color(0xFFB07D6B), // terracotta
        foliageDensity: 1.2,
        showFruit: false,
        showBirds: false,
        dominantTheme: dominant,
      ),
      MemoryTheme.friends => TreePersonality(
        blossomColor: const Color(0xFFC0DCA0), // soft green blossoms
        accentColor: const Color(0xFF7D9F6B), // soft green
        foliageDensity: 1.1,
        showFruit: false,
        showBirds: false,
        dominantTheme: dominant,
      ),
      MemoryTheme.reflection => TreePersonality(
        blossomColor: const Color(0xFFC4A8D4), // soft purple
        accentColor: const Color(0xFF8B6B9F), // soft purple
        foliageDensity: 1.0,
        showFruit: false,
        showBirds: false,
        dominantTheme: dominant,
      ),
      MemoryTheme.work => TreePersonality(
        blossomColor: const Color(0xFFA8C4D4), // soft blue
        accentColor: const Color(0xFF6B7D9F), // muted blue
        foliageDensity: 1.0,
        showFruit: false,
        showBirds: false,
        dominantTheme: dominant,
      ),
      MemoryTheme.health => TreePersonality(
        blossomColor: const Color(0xFFA8D4C0), // mint green
        accentColor: const Color(0xFF6B9F7D), // fresh mint
        foliageDensity: 1.15,
        showFruit: false,
        showBirds: false,
        dominantTheme: dominant,
      ),
      MemoryTheme.food => TreePersonality(
        blossomColor: const Color(0xFFE8C4A0), // warm orange
        accentColor: const Color(0xFFD49F6A), // warm orange
        foliageDensity: 1.1,
        showFruit: true,
        showBirds: false,
        dominantTheme: dominant,
      ),
      MemoryTheme.moments => defaults,
    };
  }
}
