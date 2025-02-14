import 'package:shared_preferences/shared_preferences.dart';

class SettingsUtil {
  static const String _maxHistoryItemsKey = 'clipboard_max_history';
  static const String _maxFavoriteItemsKey = 'clipboard_max_favorites';
  static const String _maxTextLengthKey = 'clipboard_max_text_length';
  static const String _cleanupIntervalKey = 'clipboard_cleanup_interval';

  // 默认值
  static const int defaultMaxHistoryItems = 100;
  static const int defaultMaxFavoriteItems = 50;
  static const int defaultMaxTextLength = 10000;
  static const int defaultCleanupInterval = 24; // 小时

  // 设置变更监听器列表
  static final List<Function()> _listeners = [];

  // 添加监听器
  static void addListener(Function() listener) {
    _listeners.add(listener);
  }

  // 移除监听器
  static void removeListener(Function() listener) {
    _listeners.remove(listener);
  }

  // 通知所有监听器设置已更改
  static void notifySettingsChanged() {
    for (var listener in _listeners) {
      listener();
    }
  }

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
