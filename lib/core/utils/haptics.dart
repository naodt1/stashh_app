import 'package:flutter/services.dart';
import '../services/settings_service.dart';

/// Centralized, user-toggleable haptics. The enabled flag is cached so
/// every tap doesn't hit SharedPreferences. Call [load] once at startup;
/// the Settings toggle updates [enabled] live.
class Haptics {
  static bool enabled = true;

  static Future<void> load() async {
    enabled = await SettingsService.getHaptics();
  }

  /// Light tick for taps / selections (nav, cards, chips, toggles).
  static void tap() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// Slightly firmer — primary buttons (save, create).
  static void impact() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// Success — a completed save / action.
  static void success() {
    if (enabled) HapticFeedback.mediumImpact();
  }
}
