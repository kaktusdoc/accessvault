import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Thrown for any crypto failure — locked vault, wrong key, corrupt data.
class CryptoException implements Exception {
  final String message;
  CryptoException(this.message);

  @override
  String toString() => message;
}

/// Handles PIN-derived AES-256 encryption at rest.
///
/// The AES key is derived from the user's PIN via PBKDF2-HMAC-SHA256 and
/// kept only in memory for the current session — it is never persisted.
/// Each encrypted blob on disk is `[16-byte random IV][AES-CBC ciphertext]`.
class CryptoService {
  static const int keyLengthBytes = 32; // AES-256
  static const int ivLengthBytes = 16;
  static const int defaultIterations = 100000;

  static Uint8List? _sessionKey;

  static bool get isUnlocked => _sessionKey != null;

  static void setSessionKey(Uint8List key) => _sessionKey = key;

  static void clearSessionKey() => _sessionKey = null;

  static Uint8List _requireSessionKey() {
    final key = _sessionKey;
    if (key == null) {
      throw CryptoException('Vault is locked.');
    }
    return key;
  }

  /// Cryptographically random salt, safe to store unencrypted.
  static Uint8List generateSalt([int length = 16]) {
    final random = Random.secure();
    return Uint8List.fromList(
        List.generate(length, (_) => random.nextInt(256)));
  }

  /// SHA-256 of `salt + pin`, as hex — used only to verify a PIN, never to
  /// derive the encryption key.
  static String hashPin(String pin, Uint8List salt) {
    final bytes = [...salt, ...utf8.encode(pin)];
    return sha256.convert(bytes).toString();
  }

  /// Derives a 256-bit AES key from [pin] and [salt] via PBKDF2-HMAC-SHA256.
  static Uint8List deriveKey(
    String pin,
    Uint8List salt, {
    int iterations = defaultIterations,
  }) {
    return _pbkdf2(
      password: pin,
      salt: salt,
      iterations: iterations,
      keyLengthBytes: keyLengthBytes,
    );
  }

  static Uint8List _pbkdf2({
    required String password,
    required Uint8List salt,
    required int iterations,
    required int keyLengthBytes,
  }) {
    final hmac = Hmac(sha256, utf8.encode(password));
    const hashLengthBytes = 32; // SHA-256 output size
    final blockCount = (keyLengthBytes / hashLengthBytes).ceil();
    final derived = BytesBuilder();

    for (var blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
      final blockIndexBytes = Uint8List(4)
        ..buffer.asByteData().setUint32(0, blockIndex, Endian.big);

      var u = Uint8List.fromList(
          hmac.convert([...salt, ...blockIndexBytes]).bytes);
      final t = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }

      derived.add(t);
    }

    return Uint8List.fromList(derived.toBytes().sublist(0, keyLengthBytes));
  }

  /// Encrypts [plain] with the in-memory session key.
  static Uint8List encryptBytes(Uint8List plain) =>
      encryptBytesWithKey(plain, _requireSessionKey());

  /// Decrypts data previously produced by [encryptBytes] using the in-memory
  /// session key.
  static Uint8List decryptBytes(Uint8List data) =>
      decryptBytesWithKey(data, _requireSessionKey());

  /// Encrypts [plain] with an explicit [key] (used during PIN change, where
  /// old/new keys are handled outside the session key).
  static Uint8List encryptBytesWithKey(Uint8List plain, Uint8List key) {
    final iv = enc.IV.fromSecureRandom(ivLengthBytes);
    final encrypter =
        enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plain, iv: iv);
    return Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
  }

  /// Decrypts data previously produced by [encryptBytesWithKey] with an
  /// explicit [key].
  static Uint8List decryptBytesWithKey(Uint8List data, Uint8List key) {
    if (data.length < ivLengthBytes) {
      throw CryptoException('Encrypted data is corrupt.');
    }
    final iv = enc.IV(Uint8List.sublistView(data, 0, ivLengthBytes));
    final cipherBytes = Uint8List.sublistView(data, ivLengthBytes);
    final encrypter =
        enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.cbc));
    try {
      return Uint8List.fromList(
        encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv),
      );
    } catch (_) {
      throw CryptoException('Could not decrypt — wrong key or corrupt data.');
    }
  }
}
