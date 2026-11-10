import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mini_pos/features/auth/services/session_service.dart';

void main() {
  late SessionService sessionService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    final preferences = await SharedPreferences.getInstance();

    sessionService = SessionService(preferences);
  });

  group('SessionService', () {
    test('returns null when no session exists', () {
      expect(sessionService.getUserId(), isNull);
      expect(sessionService.hasSession, isFalse);
    });

    test('saves and retrieves a user ID', () async {
      await sessionService.saveUserId(1);

      expect(sessionService.getUserId(), 1);
      expect(sessionService.hasSession, isTrue);
    });

    test('rejects an invalid user ID', () async {
      await expectLater(sessionService.saveUserId(0), throwsArgumentError);

      await expectLater(sessionService.saveUserId(-1), throwsArgumentError);

      expect(sessionService.hasSession, isFalse);
    });

    test('overwrites an existing session', () async {
      await sessionService.saveUserId(1);
      await sessionService.saveUserId(2);

      expect(sessionService.getUserId(), 2);
    });

    test('clears an existing session', () async {
      await sessionService.saveUserId(1);

      await sessionService.clearSession();

      expect(sessionService.getUserId(), isNull);
      expect(sessionService.hasSession, isFalse);
    });

    test('preserves session when service is recreated', () async {
      await sessionService.saveUserId(25);

      final preferences = await SharedPreferences.getInstance();

      final restoredSessionService = SessionService(preferences);

      expect(restoredSessionService.getUserId(), 25);
      expect(restoredSessionService.hasSession, isTrue);
    });
  });
}
