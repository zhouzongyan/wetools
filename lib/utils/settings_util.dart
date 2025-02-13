import 'package:shared_preferences/shared_preferences.dart';

class SettingsUtil {
  static const String _maxHistoryItemsKey = 'clipboard_max_history';
  static const String _maxFavoriteItemsKey = 'clipboard_max_favorites';
  static const String _maxTextLengthKey = 'clipboard_max_text_length';
  static const String _cleanupIntervalKey = 'clipboard_cleanup_interval';

  // 默认值
  static const int defaultMaxHistoryItems = 500;
  static const int defaultMaxFavoriteItems = 20;
  static const int defaultMaxTextLength = 10000;
  static const int defaultCleanupInterval = 24; // 小时

  static Future<int> getMaxHistoryItems() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_maxHistoryItemsKey) ?? defaultMaxHistoryItems;
  }

  static Future<int> getMaxFavoriteItems() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_maxFavoriteItemsKey) ?? defaultMaxFavoriteItems;
  }

  static Future<int> getMaxTextLength() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_maxTextLengthKey) ?? defaultMaxTextLength;
  }

  static Future<int> getCleanupInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cleanupIntervalKey) ?? defaultCleanupInterval;
  }

  static Future<void> setMaxHistoryItems(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxHistoryItemsKey, value);
  }

  static Future<void> setMaxFavoriteItems(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxFavoriteItemsKey, value);
  }

  static Future<void> setMaxTextLength(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxTextLengthKey, value);
  }

  static Future<void> setCleanupInterval(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cleanupIntervalKey, value);
  }
} 