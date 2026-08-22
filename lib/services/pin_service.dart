import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'crypto_service.dart';
import 'document_service.dart';

class PinService {
  static const _hashKey = 'accessvault_pin_hash';
  static const _saltKey = 'accessvault_pin_salt';

  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_hashKey);
    return value != null && value.isNotEmpty;
  }

  /// Sets a brand-new PIN: generates a fresh salt, stores the salt and a
  /// SHA-256 hash of the PIN (never the raw PIN), and derives the AES key
  /// for this session.
  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = CryptoService.generateSalt();
    final hash = CryptoService.hashPin(pin, salt);

    await prefs.setString(_saltKey, base64Encode(salt));
    await prefs.setString(_hashKey, hash);

    CryptoService.setSessionKey(CryptoService.deriveKey(pin, salt));
  }

  /// Verifies [pin] against the stored hash and, on success, derives the
  /// AES key for this session.
  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_hashKey);
    final storedSaltB64 = prefs.getString(_saltKey);
    if (storedHash == null || storedSaltB64 == null) return false;

    final salt = base64Decode(storedSaltB64);
    if (CryptoService.hashPin(pin, salt) != storedHash) return false;

    CryptoService.setSessionKey(CryptoService.deriveKey(pin, salt));
    return true;
  }

  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hashKey);
    await prefs.remove(_saltKey);
    CryptoService.clearSessionKey();
  }

  /// Changes the PIN: verifies [oldPin], derives the old and new AES keys,
  /// re-encrypts every document with the new key, then persists the new
  /// salt/hash. If [oldPin] is wrong or re-encryption fails, nothing on
  /// disk or in preferences is changed.
  static Future<void> changePin(String oldPin, String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_hashKey);
    final storedSaltB64 = prefs.getString(_saltKey);
    if (storedHash == null || storedSaltB64 == null) {
      throw CryptoException('No PIN is set.');
    }

    final oldSalt = base64Decode(storedSaltB64);
    if (CryptoService.hashPin(oldPin, oldSalt) != storedHash) {
      throw CryptoException('Current PIN is incorrect.');
    }

    final oldKey = CryptoService.deriveKey(oldPin, oldSalt);
    final newSalt = CryptoService.generateSalt();
    final newKey = CryptoService.deriveKey(newPin, newSalt);

    // Re-encrypt everything before touching the stored salt/hash, so a
    // failure here leaves the vault fully readable with the old PIN.
    await DocumentService.reencryptAll(oldKey, newKey);

    final newHash = CryptoService.hashPin(newPin, newSalt);
    await prefs.setString(_saltKey, base64Encode(newSalt));
    await prefs.setString(_hashKey, newHash);

    CryptoService.setSessionKey(newKey);
  }
}
