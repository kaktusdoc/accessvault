import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinService {
  static const _storage = FlutterSecureStorage(
    wOptions: WindowsOptions(),
  );
  static const _pinKey = 'accessvault_pin';

  static Future<bool> hasPin() async {
    final value = await _storage.read(key: _pinKey);
    return value != null && value.isNotEmpty;
  }

  static Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  static Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    return stored == pin;
  }

  /// Clears the stored PIN (e.g. for a reset flow).
  static Future<void> clearPin() async {
    await _storage.delete(key: _pinKey);
  }
}
