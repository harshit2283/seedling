import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/models/memory_theme.dart';
import 'package:seedling/core/services/ai/theme_detector_service.dart';
import 'package:seedling/data/models/entry.dart';

void main() {
  final detector = ThemeDetectorService();
  MemoryTheme of(String text) => detector.detectThemeForContent(text);
  ThemeAnalysis analyze(String text) =>
      detector.analyze(ThemeInput(text: text));

  group('short real-world memories', () {
    test('a single defining word is enough', () {
      expect(of('coffee with mum on the porch'), MemoryTheme.family);
      expect(of('first frost on the car'), MemoryTheme.nature);
      expect(of('six months sober today'), MemoryTheme.health);
      expect(of('Got the promotion!!!'), MemoryTheme.work);
      expect(of('made sourdough'), MemoryTheme.food);
    });

    test('genuinely unthemed memories stay moments', () {
      expect(
        of('the kettle clicked off right as the song ended'),
        isNot(MemoryTheme.family),
      );
      expect(of('Ordinary Tuesday.'), MemoryTheme.moments);
      expect(of('here.'), MemoryTheme.moments);
      expect(of('the lift got stuck between floors'), MemoryTheme.moments);
    });
  });

  group('normalisation', () {
    test('relationship words across languages', () {
      for (final word in ['nan', 'abuela', 'appa', 'oma', 'nonna', 'babcia']) {
        expect(
          of('sat with $word all afternoon'),
          MemoryTheme.family,
          reason: word,
        );
      }
    });

    test('inflections and irregular forms', () {
      expect(of('hiked for hours'), MemoryTheme.nature);
      expect(of('we ran our first race'), MemoryTheme.health);
      expect(of('baked bread'), MemoryTheme.food);
      expect(of('wrote a poem'), MemoryTheme.creativity);
    });

    test('British and American spelling fold together', () {
      expect(of('first watercolour'), of('first watercolor'));
      expect(of('travelled abroad'), MemoryTheme.travel);
      expect(of('realised something'), of('realized something'));
    });

    test('accents and typos', () {
      expect(of('Bàba sang off-key'), MemoryTheme.family);
      expect(of('my freinds came round'), MemoryTheme.friends);
    });

    test('contractions are not theme words', () {
      // "I'll" must not read as "ill", nor "morning" as "mourning".
      expect(analyze("I'll never get it").scoreOf(MemoryTheme.health), 0);
      expect(analyze('a regular morning').scoreOf(MemoryTheme.reflection), 0);
    });

    test('blocker phrases consume their tokens', () {
      expect(analyze('running late again').scoreOf(MemoryTheme.health), 0);
    });
  });

  group('signals', () {
    test('emoji carry themes', () {
      expect(of('🍜🍜'), MemoryTheme.food);
      expect(of('✈️'), MemoryTheme.travel);
      expect(of('👶 she is here'), MemoryTheme.family);
    });

    test('capitalised names after "with" are people', () {
      final a = analyze('Lunch with Ana, mostly listened');
      expect(a.scoreOf(MemoryTheme.friends), greaterThan(0));
      expect(a.primary, MemoryTheme.friends);
    });

    test('destinations signal travel', () {
      expect(of('three days in Lisbon'), MemoryTheme.travel);
    });

    test('negation halves evidence but keeps the topic', () {
      final plain = analyze('went for a run').scoreOf(MemoryTheme.health);
      final negated = analyze("didn't run today").scoreOf(MemoryTheme.health);
      expect(negated, closeTo(plain / 2, 1e-9));
    });

    test('company after "with" weighs less than the activity', () {
      expect(
        of('Painted with my daughter all afternoon'),
        MemoryTheme.creativity,
      );
    });

    test('titles weigh more than body text', () {
      final entry = Entry.object(title: "Grandma's ring", text: 'gold, worn');
      expect(detector.detectTheme(entry), MemoryTheme.family);
    });

    test('release entries lean to reflection when nothing else is said', () {
      final release = Entry.release(text: 'letting go');
      expect(detector.detectTheme(release), MemoryTheme.reflection);
      final job = Entry.release(text: "Releasing the job I didn't get");
      expect(detector.detectTheme(job), MemoryTheme.work);
    });
  });

  group('analysis', () {
    test('secondary theme when two are well supported', () {
      final a = analyze(
        'Sunday pancakes, the kids flipped them onto the ceiling',
      );
      expect(a.primary, MemoryTheme.family);
      expect(a.secondary, MemoryTheme.food);
    });

    test('confidence is in 0..1 and higher with more evidence', () {
      final weak = analyze('walk');
      final strong = analyze('hiked the forest trail by the river at sunrise');
      for (final a in [weak, strong]) {
        expect(a.confidence, inInclusiveRange(0, 1));
      }
      expect(strong.primary, MemoryTheme.nature);
      expect(strong.confidence, greaterThan(0.6));
    });

    test('empty input is moments with zero confidence', () {
      final a = detector.analyze(const ThemeInput());
      expect(a.primary, MemoryTheme.moments);
      expect(a.confidence, 0);
    });

    test('getConfidence agrees with analyze', () {
      final entry = Entry.line(text: 'grateful for clean sheets');
      expect(
        detector.getConfidence(entry, MemoryTheme.gratitude),
        detector.analyze(ThemeInput.fromEntry(entry)).confidence,
      );
    });
  });
}
