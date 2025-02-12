import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _githubApi =
      'https://api.github.com/repos/ayuayue/wetools/releases/latest';

  static Future<
      ({
        bool hasUpdate,
        String latestVersion,
        String? downloadUrl,
        String? releaseNotes
      })> checkUpdate() async {
    try {
      // 获取当前版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 获取最新版本信息
      final response = await http.get(Uri.parse(_githubApi));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = (data['tag_name'] as String).replaceAll('v', '');
        final downloadUrl =
            data['assets'][0]['browser_download_url'] as String?;
        final releaseNotes = data['body'] as String?;

        // 比较版本号
        final hasUpdate = _compareVersions(currentVersion, latestVersion) < 0;
        return (
          hasUpdate: hasUpdate,
          latestVersion: latestVersion,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
        );
      }
      return (
        hasUpdate: false,
        latestVersion: currentVersion,
        downloadUrl: null,
        releaseNotes: null
      );
    } catch (e) {
      return (
        hasUpdate: false,
        latestVersion: '',
        downloadUrl: null,
        releaseNotes: null
      );
    }
  }

  static int _compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map(int.parse).toList();
    final v2Parts = v2.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      final v1Part = v1Parts.length > i ? v1Parts[i] : 0;
      final v2Part = v2Parts.length > i ? v2Parts[i] : 0;
      if (v1Part != v2Part) {
        return v1Part.compareTo(v2Part);
      }
    }
    return 0;
  }

  static Future<void> downloadUpdate(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
