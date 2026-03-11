import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seedling/features/onboarding/data/onboarding_preferences.dart';

void main() {
  group('OnboardingPreferences', () {
    test('default is not completed', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final onboarding = OnboardingPreferences(prefs);

      expect(onboarding.isCompleted, false);
    });

    test('can set completed', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final onboarding = OnboardingPreferences(prefs);

      expect(onboarding.isCompleted, false);

      await onboarding.setCompleted();

      expect(onboarding.isCompleted, true);
    });

    test('can reset', () async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      final prefs = await SharedPreferences.getInstance();
      final onboarding = OnboardingPreferences(prefs);

      expect(onboarding.isCompleted, true);

      await onboarding.reset();

      expect(onboarding.isCompleted, false);
    });
  });
}
