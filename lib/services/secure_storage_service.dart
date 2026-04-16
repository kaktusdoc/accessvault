import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const _serverUrlKey = 'accessvault_server_url';
  static const _vaultTokenKey = 'accessvault_vault_token';

  static Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey);
  }

  static Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
  }

  static Future<String?> getVaultToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_vaultTokenKey);
  }

  static Future<void> setVaultToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vaultTokenKey, token);
  }
}
