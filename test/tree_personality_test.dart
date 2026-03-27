import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/models/memory_theme.dart';
import 'package:seedling/features/tree/domain/tree_personality.dart';

void main() {
  group('TreePersonality', () {
    group('fromDistribution', () {
      test('family-dominant produces pink blossom color', () {
        final distribution = {
          MemoryTheme.family: 10,
          MemoryTheme.nature: 2,
          MemoryTheme.work: 1,
        };

        final personality = TreePersonality.fromDistribution(distribution);

        expect(personality.dominantTheme, MemoryTheme.family);
        expect(personality.blossomColor, const Color(0xFFE8A0B0));
        expect(personality.showFruit, false);
        expect(personality.showBirds, false);
      });

      test('nature-dominant produces high foliage density and showBirds true', () {
        final distribution = {
          MemoryTheme.nature: 15,
          MemoryTheme.family: 3,
        };

        final personality = TreePersonality.fromDistribution(distribution);

        expect(personality.dominantTheme, MemoryTheme.nature);
        expect(personality.foliageDensity, 1.3);
        expect(personality.showBirds, true);
        expect(personality.showFruit, false);
      });

      test('gratitude-dominant produces showFruit true with golden accent', () {
        final distribution = {
          MemoryTheme.gratitude: 8,
          MemoryTheme.work: 2,
        };

        final personality = TreePersonality.fromDistribution(distribution);

        expect(personality.dominantTheme, MemoryTheme.gratitude);
        expect(personality.showFruit, true);
        expect(personality.accentColor, const Color(0xFFD4A76A));
        expect(personality.showBirds, false);
      });

      test('empty distribution returns default personality', () {
        final personality = TreePersonality.fromDistribution({});

        expect(personality.dominantTheme, isNull);
        expect(personality.showFruit, false);
        expect(personality.showBirds, false);
        expect(personality.foliageDensity, 1.0);
        expect(personality.blossomColor, TreePersonality.defaults.blossomColor);
        expect(personality.accentColor, TreePersonality.defaults.accentColor);
      });

      test('even distribution (3+ tied themes) returns default personality', () {
        final distribution = {
          MemoryTheme.family: 5,
          MemoryTheme.nature: 5,
          MemoryTheme.work: 5,
          MemoryTheme.travel: 5,
        };

        final personality = TreePersonality.fromDistribution(distribution);

        expect(personality.dominantTheme, isNull);
        expect(personality.foliageDensity, 1.0);
        expect(personality.showFruit, false);
        expect(personality.showBirds, false);
      });

      test('only moments theme returns default personality', () {
        final distribution = {
          MemoryTheme.moments: 20,
        };

        final personality = TreePersonality.fromDistribution(distribution);

        expect(personality.dominantTheme, isNull);
        expect(personality.foliageDensity, 1.0);
      });

      test('travel-dominant produces teal accent', () {
        final distribution = {
          MemoryTheme.travel: 12,
          MemoryTheme.family: 3,
        };

        final personality = TreePersonality.fromDistribution(distribution);

        expect(personality.dominantTheme, MemoryTheme.travel);
        expect(personality.accentColor, const Color(0xFF6B9F9F));
      });

      test('creativity-dominant produces terracotta accent with higher density', () {
        final distribution = {
          MemoryTheme.creativity: 9,
          MemoryTheme.moments: 5,
        };

        final personality = TreePersonality.fromDistribution(distribution);

        expect(personality.dominantTheme, MemoryTheme.creativity);
        expect(personality.accentColor, const Color(0xFFB07D6B));
        expect(personality.foliageDensity, 1.2);
      });

      test('reflection-dominant produces purple tints', () {
        final distribution = {
          MemoryTheme.reflection: 7,
          MemoryTheme.nature: 2,
        };

        final personality = TreePersonality.fromDistribution(distribution);

        expect(personality.dominantTheme, MemoryTheme.reflection);
        expect(personality.blossomColor, const Color(0xFFC4A8D4));
        expect(personality.accentColor, const Color(0xFF8B6B9F));
      });

      test('work-dominant produces blue-tinted leaves', () {
        final distribution = {
          MemoryTheme.work: 11,
          MemoryTheme.gratitude: 4,
        };

        final personality = TreePersonality.fromDistribution(distribution);

        expect(personality.dominantTheme, MemoryTheme.work);
        expect(personality.accentColor, const Color(0xFF6B7D9F));
      });

      test('food-dominant shows fruit and warm orange accent', () {
        final distribution = {
          MemoryTheme.food: 10,
          MemoryTheme.health: 3,
        };

        final personality = TreePersonality.fromDistribution(distribution);

        expect(personality.dominantTheme, MemoryTheme.food);
        expect(personality.showFruit, true);
        expect(personality.accentColor, const Color(0xFFD49F6A));
      });

      test('health-dominant produces mint green accents', () {
        final distribution = {
          MemoryTheme.health: 8,
          MemoryTheme.food: 2,
        };

        final personality = TreePersonality.fromDistribution(distribution);

        expect(personality.dominantTheme, MemoryTheme.health);
        expect(personality.accentColor, const Color(0xFF6B9F7D));
        expect(personality.foliageDensity, 1.15);
      });

      test('friends-dominant produces soft green blossoms', () {
        final distribution = {
          MemoryTheme.friends: 14,
          MemoryTheme.family: 5,
        };

        final personality = TreePersonality.fromDistribution(distribution);

        expect(personality.dominantTheme, MemoryTheme.friends);
        expect(personality.accentColor, const Color(0xFF7D9F6B));
      });

      test('two-way tie picks first theme (not default)', () {
        final distribution = {
          MemoryTheme.family: 5,
          MemoryTheme.nature: 5,
        };

        final personality = TreePersonality.fromDistribution(distribution);

        // With two tied, it should still produce a personality (not default)
        expect(personality.dominantTheme, isNotNull);
      });
    });

    group('defaults', () {
      test('default personality has expected values', () {
        const defaults = TreePersonality.defaults;

        expect(defaults.foliageDensity, 1.0);
        expect(defaults.showFruit, false);
        expect(defaults.showBirds, false);
        expect(defaults.dominantTheme, isNull);
      });
    });
  });
}
