import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight app preferences backed by SharedPreferences.
class SettingsService {
  static const _kAutoSaveShares = 'auto_save_shares';

  /// When true, links shared into the app are saved automatically after
  /// AI categorization — the user never has to tap "Save".
  static Future<bool> getAutoSaveShares() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutoSaveShares) ?? false;
  }

  static Future<void> setAutoSaveShares(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoSaveShares, value);
  }
}
