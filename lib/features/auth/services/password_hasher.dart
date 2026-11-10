import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class PasswordHashResult {
  const PasswordHashResult({required this.hash, required this.salt});

  final String hash;
  final String salt;
}

class PasswordHasher {
  PasswordHasher({Argon2id? algorithm})
    : _algorithm =
          algorithm ??
          Argon2id(
            parallelism: 1,
            memory: 19 * 1024,
            iterations: 2,
            hashLength: 32,
          );

  final Argon2id _algorithm;

  static const int _saltLength = 16;

  // Membuat hash password dengan salt acak.
  Future<PasswordHashResult> hashPassword(String password) async {
    if (password.isEmpty) {
      throw ArgumentError('Password tidak boleh kosong.');
    }

    final random = Random.secure();

    final salt = List<int>.generate(_saltLength, (_) => random.nextInt(256));

    final secretKey = await _algorithm.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    final hashBytes = await secretKey.extractBytes();

    return PasswordHashResult(
      hash: base64Encode(hashBytes),
      salt: base64Encode(salt),
    );
  }

  // Memverifikasi password dengan hash dan salt yang tersimpan.
  Future<bool> verifyPassword({
    required String password,
    required String storedHash,
    required String storedSalt,
  }) async {
    if (password.isEmpty || storedHash.isEmpty || storedSalt.isEmpty) {
      return false;
    }

    try {
      final expectedHash = base64Decode(storedHash);
      final salt = base64Decode(storedSalt);

      if (salt.length != _saltLength || expectedHash.length != 32) {
        return false;
      }

      final secretKey = await _algorithm.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );

      final actualHash = await secretKey.extractBytes();

      return _constantTimeEquals(actualHash, expectedHash);
    } on FormatException {
      // Data hash atau salt yang rusak dianggap tidak valid.
      return false;
    }
  }

  // Membandingkan dua byte array tanpa berhenti pada perbedaan pertama.
  bool _constantTimeEquals(List<int> first, List<int> second) {
    if (first.length != second.length) {
      return false;
    }

    var difference = 0;

    for (var i = 0; i < first.length; i++) {
      difference |= first[i] ^ second[i];
    }

    return difference == 0;
  }
}
