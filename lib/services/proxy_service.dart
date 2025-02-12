import 'package:shared_preferences/shared_preferences.dart';

class ProxyService {
  static const String _useSystemProxyKey = 'use_system_proxy';
  static const String _proxyHostKey = 'proxy_host';
  static const String _proxyPortKey = 'proxy_port';
  
  static Future<bool> getUseSystemProxy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useSystemProxyKey) ?? true;
  }
  
  static Future<void> setUseSystemProxy(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useSystemProxyKey, value);
  }
  
  static Future<String?> getProxyHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_proxyHostKey);
  }
  
  static Future<void> setProxyHost(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value != null) {
      await prefs.setString(_proxyHostKey, value);
    } else {
      await prefs.remove(_proxyHostKey);
    }
  }
  
  static Future<int?> getProxyPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_proxyPortKey);
  }
  
  static Future<void> setProxyPort(int? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value != null) {
      await prefs.setInt(_proxyPortKey, value);
    } else {
      await prefs.remove(_proxyPortKey);
    }
  }
} 