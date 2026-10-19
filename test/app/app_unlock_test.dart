import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:seedling/app/app_unlock.dart';
import 'package:seedling/core/services/security/app_lock_service.dart';

class _MockLockService extends Mock implements AppLockService {}

void main() {
  group('unlockWithDeviceSecurity', () {
    late _MockLockService service;
    late int lockTurnedOff;

    setUp(() {
      service = _MockLockService();
      lockTurnedOff = 0;
    });

    Future<UnlockOutcome> unlock() => unlockWithDeviceSecurity(
      service: service,
      turnLockOff: () async => lockTurnedOff++,
    );

    test('a device that can no longer authenticate never locks '
        'the person out: the lock is lifted and turned off', () async {
      when(() => service.canAuthenticate()).thenAnswer((_) async => false);

      expect(await unlock(), UnlockOutcome.lockTurnedOff);
      expect(lockTurnedOff, 1);
      verifyNever(() => service.authenticate(reason: any(named: 'reason')));
    });

    test('a confirmed check unlocks and keeps the lock on', () async {
      when(() => service.canAuthenticate()).thenAnswer((_) async => true);
      when(
        () => service.authenticate(reason: any(named: 'reason')),
      ).thenAnswer((_) async => true);

      expect(await unlock(), UnlockOutcome.unlocked);
      expect(lockTurnedOff, 0);
    });

    test('a cancelled check stays locked', () async {
      when(() => service.canAuthenticate()).thenAnswer((_) async => true);
      when(
        () => service.authenticate(reason: any(named: 'reason')),
      ).thenAnswer((_) async => false);

      expect(await unlock(), UnlockOutcome.stillLocked);
      expect(lockTurnedOff, 0);
    });
  });

  group('UnlockDeferredAction', () {
    test('runs straight away when unlocked', () {
      var runs = 0;
      UnlockDeferredAction().run(locked: false, action: () => runs++);
      expect(runs, 1);
    });

    test('waits for the unlock while locked, then runs once', () {
      var runs = 0;
      final deferred = UnlockDeferredAction()
        ..run(locked: true, action: () => runs++)
        ..run(locked: true, action: () => runs++);
      expect(runs, 0);
      expect(deferred.hasPending, isTrue);

      deferred.unlocked();
      expect(runs, 1);
      deferred.unlocked();
      expect(runs, 1);
    });
  });
}
