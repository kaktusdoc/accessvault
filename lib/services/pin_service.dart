import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  static const _pinKey = 'accessvault_pin';

  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_pinKey);
    return value != null && value.isNotEmpty;
  }

  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
  }

  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) == pin;
  }

  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
  }
}
