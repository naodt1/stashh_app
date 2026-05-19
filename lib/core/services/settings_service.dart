import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight app preferences backed by SharedPreferences.
class SettingsService {
  static const _kAutoSaveShares = 'auto_save_shares';

  /// When true, links shared into the app are saved automatically after
  /// AI categorization — the user never has to tap "Save".
  static Future<bool> getAutoSaveShares() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutoSaveShares) ?? true; // on by default
  }

  static Future<void> setAutoSaveShares(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoSaveShares, value);
  }

  static const _kHaptics = 'haptics_enabled';

  static Future<bool> getHaptics() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kHaptics) ?? true; // on by default
  }

  static Future<void> setHaptics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHaptics, value);
  }

  static const _kDismissedClusters = 'dismissed_clusters';

  static Future<Set<String>> getDismissedClusters() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kDismissedClusters) ?? const []).toSet();
  }

  static Future<void> dismissCluster(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_kDismissedClusters) ?? const []).toSet()
      ..add(key);
    await prefs.setStringList(_kDismissedClusters, set.toList());
  }
}
