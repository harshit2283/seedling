import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/core/services/security/clock_guard_service.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('ClockGuardService', () {
    late _MockSecureStorage storage;

    setUp(() {
      storage = _MockSecureStorage();
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          wOptions: any(named: 'wOptions'),
          mOptions: any(named: 'mOptions'),
        ),
      ).thenAnswer((_) async {});
    });

    test('first init persists current UTC now', () async {
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);

      final service = ClockGuardService(storage: storage);
      await service.init();

      final cached = service.cachedTrustedNow();
      expect(cached, isNotNull);
      expect(cached!.isUtc, isTrue);
    });

    test('trustedNow returns the maximum of stored and system now', () async {
      final farFuture = DateTime.utc(2099, 1, 1);
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => farFuture.toIso8601String());

      final service = ClockGuardService(storage: storage);
      await service.init();

      final trusted = await service.trustedNow();
      expect(trusted, farFuture);
    });

    test('isLikelyClockTampered returns true when system clock is far behind '
        'the highest observed value', () async {
      final farFuture = DateTime.utc(2099, 1, 1);
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => farFuture.toIso8601String());

      final service = ClockGuardService(storage: storage);
      await service.init();

      expect(await service.isLikelyClockTampered(), isTrue);
    });

    test(
      'isLikelyClockTampered returns false when there is no stored history',
      () async {
        when(
          () => storage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => null);

        final service = ClockGuardService(storage: storage);
        // Note: not calling init() here, so cache is empty.

        expect(await service.isLikelyClockTampered(), isFalse);
      },
    );
  });
}
