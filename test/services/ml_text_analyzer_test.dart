import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/ai/ml_text_analyzer.dart';

void main() {
  group('FallbackTextAnalyzer', () {
    final analyzer = FallbackTextAnalyzer();

    test('analyzeSentiment returns positive score for positive text', () async {
      final text = 'I am so happy and excited about this wonderful day!';
      // happy (+0.1), excited (+0.1), wonderful (+0.1) -> 0.3
      final score = await analyzer.analyzeSentiment(text);
      expect(score, closeTo(0.3, 0.001));
    });

    test('analyzeSentiment returns negative score for negative text', () async {
      final text = 'I feel sad and angry about the bad news.';
      // sad (-0.1), angry (-0.1), bad (-0.1) -> -0.3
      final score = await analyzer.analyzeSentiment(text);
      expect(score, closeTo(-0.3, 0.001));
    });

    test('analyzeSentiment returns 0.0 for neutral text', () async {
      final text = 'I am going to the store.';
      final score = await analyzer.analyzeSentiment(text);
      expect(score, 0.0);
    });

    test('analyzeSentiment handles mixed sentiment', () async {
      final text = 'I am happy but also sad.';
      // happy (+0.1) + sad (-0.1) = 0.0
      final score = await analyzer.analyzeSentiment(text);
      expect(score, closeTo(0.0, 0.001));
    });

    test('analyzeSentiment clamps score', () async {
      // 11 positive words
      final text =
          'happy joy love great wonderful amazing beautiful grateful thankful excited fun';
      final score = await analyzer.analyzeSentiment(text);
      expect(score, 1.0);
    });

    test('isAvailable returns true', () async {
      expect(await analyzer.isAvailable(), isTrue);
    });

    test('analyzeSentiment ignores substring matches (tokens only)', () async {
      // "unhappy" contains "happy".
      // Original code would find "happy" in "unhappy".
      // Optimized code tokenizes. "unhappy" is a token. "happy" is not in {unhappy}.
      // So score should be 0.0 (assuming unhappy is not in negative list).
      // "unhappy" is NOT in the negativeWords list in the code.
      // So score should be 0.0.
      final text = 'unhappy';
      final score = await analyzer.analyzeSentiment(text);
      expect(score, 0.0);
    });
  });
}
