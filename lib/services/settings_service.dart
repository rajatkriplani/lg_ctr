import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String ipKey = 'lg_ip';
  static const String usernameKey = 'lg_username';
  static const String passwordKey = 'lg_password';
  static const String portKey = 'lg_port';

  late final SharedPreferences _prefs;

  // Initialize SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Save connection settings
  Future<void> saveConnectionSettings({
    required String ip,
    required String username,
    required String password,
    required int port,
  }) async {
    await _prefs.setString(ipKey, ip);
    await _prefs.setString(usernameKey, username);
    await _prefs.setString(passwordKey, password);
    await _prefs.setInt(portKey, port);
  }

  // Get connection settings
  Map<String, dynamic> getConnectionSettings() {
    return {
      'ip': _prefs.getString(ipKey) ?? '',
      'username': _prefs.getString(usernameKey) ?? '',
      'password': _prefs.getString(passwordKey) ?? '',
      'port': _prefs.getInt(portKey) ?? 22,
    };
  }

  // Check if settings are configured
  bool hasConnectionSettings() {
    return _prefs.getString(ipKey)?.isNotEmpty ?? false;
  }
}