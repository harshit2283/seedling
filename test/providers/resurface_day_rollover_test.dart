import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/services/providers/resurfacing_providers.dart';

void main() {
  testWidgets('day key rolls over at midnight without any save', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 19, 23, 59);
    final container = ProviderContainer(
      overrides: [resurfaceClockProvider.overrideWithValue(() => now)],
    );
    final seen = <String>[];
    container.listen<String>(
      resurfaceDayProvider,
      (_, next) => seen.add(next),
      fireImmediately: true,
    );

    expect(seen, ['2026-10-19']);

    now = DateTime(2026, 10, 20, 0, 0, 2);
    await tester.pump(const Duration(seconds: 62));

    expect(seen, ['2026-10-19', '2026-10-20']);
    // Cancels the next midnight timer before the test binding checks for
    // pending timers.
    container.dispose();
  });
}
