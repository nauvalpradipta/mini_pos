import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mini_pos/features/auth/services/password_hasher.dart';

void main() {
  late PasswordHasher passwordHasher;

  setUp(() {
    // Parameter lebih ringan khusus pengujian agar test cepat.
    // Parameter produksi tetap menggunakan konfigurasi default.
    passwordHasher = PasswordHasher(
      algorithm: Argon2id(
        parallelism: 1,
        memory: 1024,
        iterations: 1,
        hashLength: 32,
      ),
    );
  });

  group('PasswordHasher', () {
    test('generates a valid hash and salt', () async {
      final result = await passwordHasher.hashPassword('password123');

      final hashBytes = base64Decode(result.hash);
      final saltBytes = base64Decode(result.salt);

      expect(hashBytes.length, 32);
      expect(saltBytes.length, 16);

      expect(result.hash, isNotEmpty);
      expect(result.salt, isNotEmpty);
    });

    test('generates different hashes for the same password', () async {
      final firstResult = await passwordHasher.hashPassword('password123');

      final secondResult = await passwordHasher.hashPassword('password123');

      expect(firstResult.salt, isNot(secondResult.salt));
      expect(firstResult.hash, isNot(secondResult.hash));
    });

    test('verifies the correct password', () async {
      final result = await passwordHasher.hashPassword('password123');

      final isValid = await passwordHasher.verifyPassword(
        password: 'password123',
        storedHash: result.hash,
        storedSalt: result.salt,
      );

      expect(isValid, isTrue);
    });

    test('rejects an incorrect password', () async {
      final result = await passwordHasher.hashPassword('password123');

      final isValid = await passwordHasher.verifyPassword(
        password: 'wrongpassword',
        storedHash: result.hash,
        storedSalt: result.salt,
      );

      expect(isValid, isFalse);
    });

    test('rejects an empty password', () async {
      await expectLater(passwordHasher.hashPassword(''), throwsArgumentError);
    });

    test('rejects empty verification values', () async {
      final isValid = await passwordHasher.verifyPassword(
        password: '',
        storedHash: '',
        storedSalt: '',
      );

      expect(isValid, isFalse);
    });

    test('rejects invalid stored hash and salt formats', () async {
      final invalidHash = await passwordHasher.verifyPassword(
        password: 'password123',
        storedHash: 'invalid-hash',
        storedSalt: base64Encode(List<int>.filled(16, 1)),
      );

      final invalidSalt = await passwordHasher.verifyPassword(
        password: 'password123',
        storedHash: base64Encode(List<int>.filled(32, 1)),
        storedSalt: 'invalid-salt',
      );

      expect(invalidHash, isFalse);
      expect(invalidSalt, isFalse);
    });
  });
}
