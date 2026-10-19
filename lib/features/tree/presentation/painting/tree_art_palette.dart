import 'dart:ui' show Color;

import '../../../../core/models/season.dart';
import '../../domain/tree_personality.dart';

/// Four tonal values of one foliage colour, from the shaded underside to the
/// sunlit tips. Clusters are painted shadow → mid → light → highlight.
class LeafTone {
  const LeafTone(this.shadow, this.mid, this.light, this.highlight);

  final Color shadow;
  final Color mid;
  final Color light;
  final Color highlight;

  LeafTone tinted(Color accent, double amount) => LeafTone(
    Color.lerp(shadow, accent, amount * 0.6)!,
    Color.lerp(mid, accent, amount)!,
    Color.lerp(light, accent, amount)!,
    Color.lerp(highlight, accent, amount * 0.6)!,
  );
}

/// Every colour the tree illustration uses for one season and time of day.
///
/// The day palette is built around the app's forest greens and bark browns;
/// the night palette ("forest twilight") is the same scene under moonlight:
/// darker, cooler, with silvery highlights and warm glowing memory lights.
class TreeArtPalette {
  const TreeArtPalette({
    required this.night,
    required this.barkShadow,
    required this.bark,
    required this.barkLight,
    required this.leafTones,
    required this.backLeaf,
    required this.blossom,
    required this.blossomCenter,
    required this.soil,
    required this.soilShadow,
    required this.grass,
    required this.grassLight,
    required this.snow,
    required this.snowShade,
    required this.glow,
    required this.memoryLight,
    required this.memoryCore,
    required this.fallenLeaves,
    required this.stem,
    required this.stemLight,
    required this.seed,
    required this.seedLight,
  });

  final bool night;
  final Color barkShadow;
  final Color bark;
  final Color barkLight;

  /// Foliage tone sets; clusters pick one deterministically.
  final List<LeafTone> leafTones;

  /// Deep foliage behind the branches (gives the crown depth).
  final Color backLeaf;
  final Color blossom;
  final Color blossomCenter;
  final Color soil;
  final Color soilShadow;
  final Color grass;
  final Color grassLight;
  final Color snow;

  /// Cool shadow under snow so it reads on a pale background.
  final Color snowShade;
  final Color glow;
  final Color memoryLight;
  final Color memoryCore;

  /// Leaves on the ground and drifting down (autumn).
  final List<Color> fallenLeaves;
  final Color stem;
  final Color stemLight;
  final Color seed;
  final Color seedLight;

  /// Resolve the palette for a season and brightness, gently tinted by the
  /// tree's personality accent so every tree still belongs to its owner.
  factory TreeArtPalette.resolve({
    required Season season,
    required bool night,
    TreePersonality? personality,
  }) {
    final base = night ? _night(season) : _day(season);
    final accent = personality?.accentColor;
    if (accent == null || season == Season.winter) return base;
    final amount = season == Season.autumn ? 0.08 : 0.16;
    return base._withTones([
      for (final t in base.leafTones) t.tinted(accent, amount),
    ]);
  }

  TreeArtPalette _withTones(List<LeafTone> tones) => TreeArtPalette(
    night: night,
    barkShadow: barkShadow,
    bark: bark,
    barkLight: barkLight,
    leafTones: tones,
    backLeaf: backLeaf,
    blossom: blossom,
    blossomCenter: blossomCenter,
    soil: soil,
    soilShadow: soilShadow,
    grass: grass,
    grassLight: grassLight,
    snow: snow,
    snowShade: snowShade,
    glow: glow,
    memoryLight: memoryLight,
    memoryCore: memoryCore,
    fallenLeaves: fallenLeaves,
    stem: stem,
    stemLight: stemLight,
    seed: seed,
    seedLight: seedLight,
  );

  static TreeArtPalette _day(Season season) {
    final tones = switch (season) {
      Season.spring => const [
        LeafTone(
          Color(0xFF4F8656),
          Color(0xFF79B26C),
          Color(0xFFA2CF84),
          Color(0xFFD3EAA8),
        ),
        LeafTone(
          Color(0xFF46785A),
          Color(0xFF6FA87A),
          Color(0xFF98C994),
          Color(0xFFC9E5BC),
        ),
      ],
      Season.summer => const [
        LeafTone(
          Color(0xFF1F4730),
          Color(0xFF346A43),
          Color(0xFF52905A),
          Color(0xFF8CBF76),
        ),
        LeafTone(
          Color(0xFF244B38),
          Color(0xFF3D7350),
          Color(0xFF5E9A66),
          Color(0xFF9AC889),
        ),
      ],
      Season.autumn => const [
        // amber
        LeafTone(
          Color(0xFF9A5122),
          Color(0xFFD08534),
          Color(0xFFE6A84E),
          Color(0xFFF4CE82),
        ),
        // rust
        LeafTone(
          Color(0xFF7C3220),
          Color(0xFFB04C2C),
          Color(0xFFCF6E3E),
          Color(0xFFE9A273),
        ),
        // gold
        LeafTone(
          Color(0xFF94702A),
          Color(0xFFCC9F3E),
          Color(0xFFE2BF5C),
          Color(0xFFF2DD92),
        ),
        // the last of the green
        LeafTone(
          Color(0xFF55592E),
          Color(0xFF7F8740),
          Color(0xFFA3A754),
          Color(0xFFCCC67E),
        ),
      ],
      Season.winter => const [
        LeafTone(
          Color(0xFF2E4A3E),
          Color(0xFF41634F),
          Color(0xFF5E7F66),
          Color(0xFF93AE96),
        ),
      ],
    };
    return TreeArtPalette(
      night: false,
      barkShadow: const Color(0xFF3B2F24),
      bark: const Color(0xFF5D4E3C),
      barkLight: const Color(0xFF8E7656),
      leafTones: tones,
      backLeaf: switch (season) {
        Season.spring => const Color(0xFF3F6E49),
        Season.summer => const Color(0xFF173A26),
        Season.autumn => const Color(0xFF6E3A1E),
        Season.winter => const Color(0xFF2E4A3E),
      },
      blossom: const Color(0xFFF6C9D6),
      blossomCenter: const Color(0xFFF2D27A),
      soil: const Color(0xFFB9A585),
      soilShadow: const Color(0xFF5D4E3C),
      grass: switch (season) {
        Season.autumn => const Color(0xFF8A8A4A),
        Season.winter => const Color(0xFF8A9A88),
        _ => const Color(0xFF5E8F5A),
      },
      grassLight: switch (season) {
        Season.autumn => const Color(0xFFB8A660),
        Season.winter => const Color(0xFFB4C2B2),
        _ => const Color(0xFF8DBA74),
      },
      snow: const Color(0xFFFBFDFF),
      snowShade: const Color(0xFFB9C8D6),
      glow: const Color(0xFFB8D4BE),
      memoryLight: const Color(0xFFF7C66B),
      memoryCore: const Color(0xFFFFF4D6),
      fallenLeaves: const [
        Color(0xFFD08534),
        Color(0xFFB04C2C),
        Color(0xFFE2BF5C),
        Color(0xFFC46A30),
      ],
      stem: const Color(0xFF5E9A5E),
      stemLight: const Color(0xFF9CCB84),
      seed: const Color(0xFF8B6A48),
      seedLight: const Color(0xFFC9A57A),
    );
  }

  static TreeArtPalette _night(Season season) {
    final tones = switch (season) {
      Season.spring => const [
        LeafTone(
          Color(0xFF16302A),
          Color(0xFF26493A),
          Color(0xFF3C6A52),
          Color(0xFF8FB8AA),
        ),
        LeafTone(
          Color(0xFF1A3330),
          Color(0xFF2C5044),
          Color(0xFF44725E),
          Color(0xFF9CC0B6),
        ),
      ],
      Season.summer => const [
        LeafTone(
          Color(0xFF0F231D),
          Color(0xFF1B3A2E),
          Color(0xFF2C5944),
          Color(0xFF7BA597),
        ),
        LeafTone(
          Color(0xFF122722),
          Color(0xFF214235),
          Color(0xFF34624E),
          Color(0xFF86AEA2),
        ),
      ],
      Season.autumn => const [
        LeafTone(
          Color(0xFF3A2016),
          Color(0xFF6A3A22),
          Color(0xFF94592F),
          Color(0xFFC7A180),
        ),
        LeafTone(
          Color(0xFF331A17),
          Color(0xFF5C2B22),
          Color(0xFF834332),
          Color(0xFFBC8F84),
        ),
        LeafTone(
          Color(0xFF3A3018),
          Color(0xFF6A5A2C),
          Color(0xFF907A3C),
          Color(0xFFC6B588),
        ),
        LeafTone(
          Color(0xFF232A1C),
          Color(0xFF3C4A2C),
          Color(0xFF56663C),
          Color(0xFF9AA88A),
        ),
      ],
      Season.winter => const [
        LeafTone(
          Color(0xFF13241F),
          Color(0xFF1F3A31),
          Color(0xFF2E5245),
          Color(0xFF7E9E98),
        ),
      ],
    };
    return TreeArtPalette(
      night: true,
      barkShadow: const Color(0xFF2A2420),
      bark: const Color(0xFF51483F),
      barkLight: const Color(0xFF948E86),
      leafTones: tones,
      backLeaf: switch (season) {
        Season.autumn => const Color(0xFF26160F),
        _ => const Color(0xFF0B1A15),
      },
      blossom: const Color(0xFFD8BFD6),
      blossomCenter: const Color(0xFFE8D69A),
      soil: const Color(0xFF4A4A40),
      soilShadow: const Color(0xFF0E0F0D),
      grass: switch (season) {
        Season.autumn => const Color(0xFF3E3E28),
        Season.winter => const Color(0xFF3C4846),
        _ => const Color(0xFF243D30),
      },
      grassLight: switch (season) {
        Season.autumn => const Color(0xFF6A6440),
        Season.winter => const Color(0xFF7E8E8E),
        _ => const Color(0xFF4E7560),
      },
      snow: const Color(0xFFC6D4E6),
      snowShade: const Color(0xFF55606C),
      glow: const Color(0xFF8FC7B0),
      memoryLight: const Color(0xFFFFC970),
      memoryCore: const Color(0xFFFFF6DC),
      fallenLeaves: const [
        Color(0xFF8A4E2A),
        Color(0xFF6E3426),
        Color(0xFF9A8240),
        Color(0xFF7A4A28),
      ],
      stem: const Color(0xFF3E6A52),
      stemLight: const Color(0xFF7FA898),
      seed: const Color(0xFF6A5640),
      seedLight: const Color(0xFFA89A88),
    );
  }
}
