import 'package:flutter/material.dart';

/// Seedling color palette - organic, warm, and calming
/// Inspired by nature: forests, paper, and growth
class SeedlingColors {
  SeedlingColors._();

  // Primary - Forest greens (growth, life)
  static const Color forestGreen = Color(0xFF2D5A3D);
  static const Color leafGreen = Color(0xFF4A7C59);
  static const Color freshSprout = Color(0xFF7CB083);
  static const Color paleGreen = Color(0xFFB8D4BE);

  // Secondary - Bark browns (stability, roots)
  static const Color barkBrown = Color(0xFF5D4E3C);
  static const Color warmBrown = Color(0xFF8B7355);
  static const Color lightBark = Color(0xFFB8A88A);

  // Background - Cream paper (warmth, comfort)
  static const Color creamPaper = Color(0xFFFAF8F5);
  static const Color warmWhite = Color(0xFFFFFDF9);
  static const Color softCream = Color(0xFFF5F0E8);

  // Text colors
  static const Color textPrimary = Color(0xFF2C2C2C);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFF9B9B9B);

  // Accent colors for entry types
  static const Color accentLine = Color(
    0xFF4A7C59,
  ); // Text entries - leaf green
  static const Color accentPhoto = Color(0xFF6B8E9F); // Photos - muted blue
  static const Color accentVoice = Color(0xFF9F8B6B); // Voice - warm amber
  static const Color accentObject = Color(0xFF8B6B9F); // Objects - soft purple
  static const Color accentFragment = Color(0xFF6B9F8B); // Fragments - sage
  static const Color accentRitual = Color(0xFF9F6B7D); // Rituals - dusty rose
  static const Color accentRelease = Color(0xFFA69F8B); // Released - faded

  // Semantic colors
  static const Color success = Color(0xFF4A7C59);
  static const Color warning = Color(0xFFC4A35A);
  static const Color error = Color(0xFFC45A5A);

  // Tree growth stage colors
  static const Color seed = Color(0xFF8B7355);
  static const Color sprout = Color(0xFF7CB083);
  static const Color sapling = Color(0xFF4A7C59);
  static const Color youngTree = Color(0xFF3D6B4D);
  static const Color matureTree = Color(0xFF2D5A3D);
  static const Color ancientTree = Color(0xFF1E4A2D);

  // Theme colors (Phase 4)
  static const Color themeFamily = Color(0xFF9F6B7D); // Dusty rose
  static const Color themeFriends = Color(0xFF7D9F6B); // Soft green
  static const Color themeWork = Color(0xFF6B7D9F); // Muted blue
  static const Color themeNature = Color(0xFF4A7C59); // Leaf green
  static const Color themeGratitude = Color(0xFFD4A76A); // Warm gold
  static const Color themeReflection = Color(0xFF8B6B9F); // Soft purple
  static const Color themeTravel = Color(0xFF6B9F9F); // Teal
  static const Color themeCreativity = Color(0xFFB07D6B); // Terracotta
  static const Color themeHealth = Color(0xFF6B9F7D); // Fresh mint
  static const Color themeFood = Color(0xFFD49F6A); // Warm orange
  static const Color themeMoments = Color(0xFF9B9B9B); // Neutral gray

  // ─────────────────────────────────────────────────────────────────
  // Dark Mode Colors (Phase 4.5)
  // Maintains warmth with forest/twilight feel, not cold/clinical
  // ─────────────────────────────────────────────────────────────────

  // Dark backgrounds - warm charcoal with slight green tint
  static const Color backgroundDark = Color(
    0xFF1A1C1A,
  ); // Near black with warmth
  static const Color surfaceDark = Color(0xFF242624); // Elevated surface
  static const Color cardDark = Color(0xFF2E302E); // Card background
  static const Color surfaceContainerDark = Color(
    0xFF383A38,
  ); // Higher elevation

  // Dark text colors - warm whites, not pure white
  static const Color textPrimaryDark = Color(0xFFF5F5F3); // Warm off-white
  static const Color textSecondaryDark = Color(0xFFB5B5B3); // Muted warm gray
  static const Color textMutedDark = Color(0xFF757573); // Subtle text

  // Dark borders and dividers
  static const Color dividerDark = Color(0xFF3A3C3A); // Subtle separation
  static const Color borderDark = Color(0xFF454745); // Input borders

  // Primary colors adjusted for dark backgrounds (lighter variants)
  static const Color forestGreenDark = Color(0xFF4A8A5F); // Brighter green
  static const Color leafGreenDark = Color(0xFF6BA87A); // Lighter leaf
  static const Color paleGreenDark = Color(0xFF3D5A44); // Muted container

  // Secondary colors for dark mode
  static const Color warmBrownDark = Color(0xFFA89070); // Lighter bark
  static const Color lightBarkDark = Color(0xFF5A4A3A); // Darker light bark

  // Accent colors adjusted for dark mode visibility
  static const Color accentLineDark = Color(0xFF6BA87A); // Brighter green
  static const Color accentPhotoDark = Color(0xFF8AB4C5); // Brighter blue
  static const Color accentVoiceDark = Color(0xFFC5B08A); // Brighter amber
  static const Color accentObjectDark = Color(0xFFB08AC5); // Brighter purple
  static const Color accentFragmentDark = Color(0xFF8AC5B0); // Brighter sage
  static const Color accentRitualDark = Color(0xFFC58A9D); // Brighter rose
  static const Color accentReleaseDark = Color(0xFFC5C0B0); // Brighter faded

  // Theme colors adjusted for dark mode (lighter for contrast)
  static const Color themeFamilyDark = Color(0xFFC58AA0); // Lighter rose
  static const Color themeFriendsDark = Color(0xFFA0C58A); // Lighter green
  static const Color themeWorkDark = Color(0xFF8AA0C5); // Lighter blue
  static const Color themeNatureDark = Color(0xFF6BA87A); // Lighter leaf
  static const Color themeGratitudeDark = Color(0xFFE8C08A); // Lighter gold
  static const Color themeReflectionDark = Color(0xFFB08AC5); // Lighter purple
  static const Color themeTravelDark = Color(0xFF8AC5C5); // Lighter teal
  static const Color themeCreativityDark = Color(
    0xFFD0A08A,
  ); // Lighter terracotta
  static const Color themeHealthDark = Color(0xFF8AC5A0); // Lighter mint
  static const Color themeFoodDark = Color(0xFFE8B08A); // Lighter orange
  static const Color themeMomentsDark = Color(0xFFB5B5B5); // Lighter gray

  // Semantic colors for dark mode
  static const Color successDark = Color(0xFF6BA87A);
  static const Color warningDark = Color(0xFFE0C07A);
  static const Color errorDark = Color(0xFFE07A7A);
}
