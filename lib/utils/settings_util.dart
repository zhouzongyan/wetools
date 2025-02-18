import 'package:shared_preferences/shared_preferences.dart';

class SettingsUtil {
  static const String _maxHistoryItemsKey = 'clipboard_max_history';
  static const String _maxFavoriteItemsKey = 'clipboard_max_favorites';
  static const String _maxTextLengthKey = 'clipboard_max_text_length';
  static const String _cleanupIntervalKey = 'clipboard_cleanup_interval';
  static const String _updateCheckIntervalKey = 'update_check_interval';
  static const String _autoUpdateCheckKey = 'auto_update_check';
  static const String _ftpPortKey = 'ftp_port';
  static const String _ftpUsernameKey = 'ftp_username';
  static const String _ftpPasswordKey = 'ftp_password';

  // 默认值
  static const int defaultMaxHistoryItems = 100;
  static const int defaultMaxFavoriteItems = 50;
  static const int defaultMaxTextLength = 10000;
  static const int defaultCleanupInterval = 24; // 小时
  static const int defaultUpdateCheckInterval = 12; // 小时
  static const bool defaultAutoUpdateCheck = true;
  static const int defaultFtpPort = 2121;
  static const String defaultFtpUsername = 'wetools';
  static const String defaultFtpPassword = '123456';

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

  static Future<int> getUpdateCheckInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_updateCheckIntervalKey) ?? defaultUpdateCheckInterval;
  }

  static Future<bool> getAutoUpdateCheck() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoUpdateCheckKey) ?? defaultAutoUpdateCheck;
  }

  static Future<int> getFtpPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_ftpPortKey) ?? defaultFtpPort;
  }

  static Future<String> getFtpUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ftpUsernameKey) ?? defaultFtpUsername;
  }

  static Future<String> getFtpPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ftpPasswordKey) ?? defaultFtpPassword;
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

  static Future<void> setUpdateCheckInterval(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_updateCheckIntervalKey, value);
  }

  static Future<void> setAutoUpdateCheck(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoUpdateCheckKey, value);
  }

  static Future<void> setFtpPort(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_ftpPortKey, value);
  }

  static Future<void> setFtpUsername(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ftpUsernameKey, value);
  }

  static Future<void> setFtpPassword(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ftpPasswordKey, value);
  }
}
