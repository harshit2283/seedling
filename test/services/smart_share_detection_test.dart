import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/share/share_receiver_service.dart';
import 'package:seedling/data/models/entry.dart';

void main() {
  group('SharedContent.inferEntryType', () {
    group('fragment detection', () {
      test('short vague text classifies as fragment', () {
        expect(SharedContent.inferEntryType('hmm'), EntryType.fragment);
      });

      test('very short text under 15 chars is fragment', () {
        expect(SharedContent.inferEntryType('just a thought'), EntryType.fragment);
      });

      test('empty-ish text is fragment', () {
        expect(SharedContent.inferEntryType('   ok   '), EntryType.fragment);
      });

      test('short text with release keyword is still release, not fragment', () {
        expect(SharedContent.inferEntryType('let go now'), EntryType.release);
      });

      test('short text with ritual keyword is still ritual, not fragment', () {
        expect(SharedContent.inferEntryType('daily walk'), EntryType.ritual);
      });
    });

    group('release detection', () {
      test('text with "letting go" classifies as release', () {
        expect(
          SharedContent.inferEntryType('I am letting go of old habits'),
          EntryType.release,
        );
      });

      test('text with "goodbye" classifies as release', () {
        expect(
          SharedContent.inferEntryType('Saying goodbye to the old apartment'),
          EntryType.release,
        );
      });

      test('text with "farewell" classifies as release', () {
        expect(
          SharedContent.inferEntryType('A farewell to a chapter of my life'),
          EntryType.release,
        );
      });

      test('text with "forgive" classifies as release', () {
        expect(
          SharedContent.inferEntryType('Learning to forgive myself for past mistakes'),
          EntryType.release,
        );
      });

      test('text with "moving on" classifies as release', () {
        expect(
          SharedContent.inferEntryType('Finally moving on from that job'),
          EntryType.release,
        );
      });

      test('text with "closure" classifies as release', () {
        expect(
          SharedContent.inferEntryType('Finding closure after the conversation'),
          EntryType.release,
        );
      });

      test('text with "surrender" classifies as release', () {
        expect(
          SharedContent.inferEntryType('Learning to surrender control'),
          EntryType.release,
        );
      });

      test('text with "let go" classifies as release', () {
        expect(
          SharedContent.inferEntryType('It is time to let go of regret'),
          EntryType.release,
        );
      });

      test('release keywords are case-insensitive', () {
        expect(
          SharedContent.inferEntryType('LETTING GO of everything'),
          EntryType.release,
        );
      });
    });

    group('ritual detection', () {
      test('text with "every morning" classifies as ritual', () {
        expect(
          SharedContent.inferEntryType('Every morning I walk to the park with the dog'),
          EntryType.ritual,
        );
      });

      test('text with "each day" classifies as ritual', () {
        expect(
          SharedContent.inferEntryType('Each day I write in my journal before bed'),
          EntryType.ritual,
        );
      });

      test('text with "weekly" classifies as ritual', () {
        expect(
          SharedContent.inferEntryType('Our weekly family dinner on Sundays'),
          EntryType.ritual,
        );
      });

      test('text with "routine" classifies as ritual', () {
        expect(
          SharedContent.inferEntryType('My morning routine has become sacred'),
          EntryType.ritual,
        );
      });

      test('text with "tradition" classifies as ritual', () {
        expect(
          SharedContent.inferEntryType('A tradition of baking cookies in December'),
          EntryType.ritual,
        );
      });

      test('text with "daily" classifies as ritual', () {
        expect(
          SharedContent.inferEntryType('My daily meditation practice'),
          EntryType.ritual,
        );
      });

      test('text with "every night" classifies as ritual', () {
        expect(
          SharedContent.inferEntryType('Every night we read stories together'),
          EntryType.ritual,
        );
      });

      test('text with "habit" classifies as ritual', () {
        expect(
          SharedContent.inferEntryType('The habit of journaling has changed my life'),
          EntryType.ritual,
        );
      });

      test('ritual patterns are case-insensitive', () {
        expect(
          SharedContent.inferEntryType('EVERY MORNING I stretch and breathe'),
          EntryType.ritual,
        );
      });
    });

    group('default line detection', () {
      test('normal text defaults to line', () {
        expect(
          SharedContent.inferEntryType('Saw a beautiful sunset today at the beach'),
          EntryType.line,
        );
      });

      test('quote-like text defaults to line', () {
        expect(
          SharedContent.inferEntryType('The only way out is through - Robert Frost'),
          EntryType.line,
        );
      });

      test('long descriptive text defaults to line', () {
        expect(
          SharedContent.inferEntryType(
            'Had coffee with Sarah this afternoon. We talked about the garden and the new seedlings.',
          ),
          EntryType.line,
        );
      });

      test('text with URL defaults to line', () {
        expect(
          SharedContent.inferEntryType(
            'Found this interesting article https://example.com/story',
          ),
          EntryType.line,
        );
      });
    });

    group('priority: release wins over ritual', () {
      test('text with both release and ritual keywords classifies as release', () {
        // Release keywords are checked first
        expect(
          SharedContent.inferEntryType(
            'Letting go of my daily routine that no longer serves me',
          ),
          EntryType.release,
        );
      });
    });

    group('edge cases', () {
      test('whitespace-only text is fragment', () {
        expect(SharedContent.inferEntryType('      '), EntryType.fragment);
      });

      test('exactly 15 chars without keywords is line', () {
        // 15 chars = "abcdefghijklmno" — not under 15, so not fragment
        expect(SharedContent.inferEntryType('abcdefghijklmno'), EntryType.line);
      });

      test('14 chars without keywords is fragment', () {
        expect(SharedContent.inferEntryType('abcdefghijklmn'), EntryType.fragment);
      });

      test('keyword embedded in longer word still matches', () {
        // "release" is a keyword, and "released" contains it
        expect(
          SharedContent.inferEntryType('I finally released all the tension'),
          EntryType.release,
        );
      });
    });
  });
}
