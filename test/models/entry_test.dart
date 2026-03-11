import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/data/models/entry.dart';

void main() {
  group('Entry model', () {
    group('Factory constructors', () {
      test('Entry.line creates LINE type with text', () {
        final entry = Entry.line(text: 'A beautiful sunset');

        expect(entry.type, EntryType.line);
        expect(entry.text, 'A beautiful sunset');
        expect(entry.hasText, true);
        expect(entry.hasMedia, false);
        expect(entry.typeName, 'Line');
      });

      test('Entry.line with optional fields', () {
        final entry = Entry.line(
          text: 'Test',
          context: 'At the park',
          mood: 'peaceful',
        );

        expect(entry.context, 'At the park');
        expect(entry.mood, 'peaceful');
      });

      test('Entry.fragment creates FRAGMENT type', () {
        final entry = Entry.fragment(text: 'half a thought');

        expect(entry.type, EntryType.fragment);
        expect(entry.text, 'half a thought');
        expect(entry.typeName, 'Fragment');
      });

      test('Entry.fragment allows null text', () {
        final entry = Entry.fragment();

        expect(entry.type, EntryType.fragment);
        expect(entry.text, isNull);
        expect(entry.hasText, false);
      });

      test('Entry.release creates RELEASE type with isReleased true', () {
        final entry = Entry.release(text: 'Letting go of worry');

        expect(entry.type, EntryType.release);
        expect(entry.text, 'Letting go of worry');
        expect(entry.isReleased, true);
        expect(entry.typeName, 'Released');
      });

      test('Entry.release allows null text', () {
        final entry = Entry.release();

        expect(entry.type, EntryType.release);
        expect(entry.text, isNull);
        expect(entry.isReleased, true);
      });

      test('Entry.photo creates PHOTO type with required mediaPath', () {
        final entry = Entry.photo(mediaPath: '/path/to/photo.jpg');

        expect(entry.type, EntryType.photo);
        expect(entry.mediaPath, '/path/to/photo.jpg');
        expect(entry.hasMedia, true);
        expect(entry.typeName, 'Photo');
      });

      test('Entry.photo with optional text and title', () {
        final entry = Entry.photo(
          mediaPath: '/path/to/photo.jpg',
          text: 'A note about the photo',
          title: 'Sunset',
          context: 'Beach vacation',
        );

        expect(entry.mediaPath, '/path/to/photo.jpg');
        expect(entry.text, 'A note about the photo');
        expect(entry.title, 'Sunset');
        expect(entry.context, 'Beach vacation');
        expect(entry.hasText, true);
        expect(entry.hasMedia, true);
      });

      test('Entry.voice creates VOICE type with required mediaPath', () {
        final entry = Entry.voice(mediaPath: '/path/to/voice.m4a');

        expect(entry.type, EntryType.voice);
        expect(entry.mediaPath, '/path/to/voice.m4a');
        expect(entry.hasMedia, true);
        expect(entry.typeName, 'Voice');
      });

      test('Entry.voice with optional text and title', () {
        final entry = Entry.voice(
          mediaPath: '/path/to/voice.m4a',
          text: 'A transcription',
          title: 'Morning thoughts',
        );

        expect(entry.mediaPath, '/path/to/voice.m4a');
        expect(entry.text, 'A transcription');
        expect(entry.title, 'Morning thoughts');
      });

      test('Entry.object creates OBJECT type with required title', () {
        final entry = Entry.object(title: 'Grandma\'s ring');

        expect(entry.type, EntryType.object);
        expect(entry.title, 'Grandma\'s ring');
        expect(entry.typeName, 'Object');
      });

      test('Entry.object with optional mediaPath and text', () {
        final entry = Entry.object(
          title: 'Old photograph',
          mediaPath: '/path/to/object.jpg',
          text: 'Found in the attic',
          context: 'Cleaning day',
        );

        expect(entry.title, 'Old photograph');
        expect(entry.mediaPath, '/path/to/object.jpg');
        expect(entry.text, 'Found in the attic');
        expect(entry.context, 'Cleaning day');
        expect(entry.hasMedia, true);
        expect(entry.hasText, true);
      });

      test('Entry.ritual creates RITUAL type with required title', () {
        final entry = Entry.ritual(title: 'Morning coffee');

        expect(entry.type, EntryType.ritual);
        expect(entry.title, 'Morning coffee');
        expect(entry.typeName, 'Ritual');
      });

      test('Entry.ritual with optional text and context', () {
        final entry = Entry.ritual(
          title: 'Evening walk',
          text: 'Around the neighborhood',
          context: 'After dinner',
        );

        expect(entry.title, 'Evening walk');
        expect(entry.text, 'Around the neighborhood');
        expect(entry.context, 'After dinner');
      });
    });

    group('Properties', () {
      test('createdAt defaults to now', () {
        final before = DateTime.now();
        final entry = Entry.line(text: 'Test');
        final after = DateTime.now();

        expect(
          entry.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
          true,
        );
        expect(
          entry.createdAt.isBefore(after.add(const Duration(seconds: 1))),
          true,
        );
      });

      test('id defaults to 0', () {
        final entry = Entry.line(text: 'Test');
        expect(entry.id, 0);
      });

      test('hasText returns false for empty string', () {
        final entry = Entry(text: '');
        expect(entry.hasText, false);
      });

      test('hasText returns true for non-empty string', () {
        final entry = Entry(text: 'content');
        expect(entry.hasText, true);
      });

      test('hasMedia returns false for null mediaPath', () {
        final entry = Entry();
        expect(entry.hasMedia, false);
      });

      test('hasMedia returns false for empty mediaPath', () {
        final entry = Entry(mediaPath: '');
        expect(entry.hasMedia, false);
      });

      test('hasMedia returns true for non-empty mediaPath', () {
        final entry = Entry(mediaPath: '/path/to/file.jpg');
        expect(entry.hasMedia, true);
      });
    });

    group('displayContent', () {
      test('returns text when available', () {
        final entry = Entry.line(text: 'My text');
        expect(entry.displayContent, 'My text');
      });

      test('returns title when text is empty but title exists', () {
        final entry = Entry.object(title: 'My Object');
        expect(entry.displayContent, 'My Object');
      });

      test('returns typeName when both text and title are empty', () {
        final entry = Entry.fragment();
        expect(entry.displayContent, 'Fragment');
      });
    });

    group('type getter and setter', () {
      test('type getter returns correct enum', () {
        final entry = Entry(typeIndex: EntryType.photo.index);
        expect(entry.type, EntryType.photo);
      });

      test('type setter updates typeIndex', () {
        final entry = Entry();
        entry.type = EntryType.voice;
        expect(entry.typeIndex, EntryType.voice.index);
        expect(entry.type, EntryType.voice);
      });
    });

    group('EntryType enum', () {
      test('all entry types have unique indices', () {
        final indices = EntryType.values.map((e) => e.index).toSet();
        expect(indices.length, EntryType.values.length);
      });

      test('entry types are in expected order', () {
        expect(EntryType.line.index, 0);
        expect(EntryType.photo.index, 1);
        expect(EntryType.voice.index, 2);
        expect(EntryType.object.index, 3);
        expect(EntryType.fragment.index, 4);
        expect(EntryType.ritual.index, 5);
        expect(EntryType.release.index, 6);
      });
    });
  });
}
