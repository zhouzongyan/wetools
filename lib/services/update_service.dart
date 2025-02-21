import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

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
        final assets = data['assets'] as List;
        String? downloadUrl;

        // 根据平台选择对应的安装包
        if (Platform.isWindows) {
          for (var asset in assets) {
            if (asset['name'].toString().toLowerCase().contains('windows')) {
              downloadUrl = asset['browser_download_url'] as String?;
              break;
            }
          }
        } else if (Platform.isMacOS) {
          for (var asset in assets) {
            if (asset['name'].toString().toLowerCase().contains('macos')) {
              downloadUrl = asset['browser_download_url'] as String?;
              break;
            }
          }
        } else if (Platform.isLinux) {
          for (var asset in assets) {
            if (asset['name'].toString().toLowerCase().contains('linux')) {
              downloadUrl = asset['browser_download_url'] as String?;
              break;
            }
          }
        }

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

  static Future<({bool success, String message})> downloadAndUpdate(
      String url, void Function(double) onProgress) async {
    try {
      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final downloadDir = Directory(path.join(tempDir.path, 'update'));
      if (!downloadDir.existsSync()) {
        downloadDir.createSync(recursive: true);
      }

      // 下载文件
      final zipPath = path.join(downloadDir.path, 'update.zip');
      final file = File(zipPath);

      // 发起 HTTP 请求
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url));
        final response = await client.send(request);
        final contentLength = response.contentLength ?? 0;
        var receivedBytes = 0;

        final sink = file.openWrite();
        await response.stream.listen(
          (chunk) {
            sink.add(chunk);
            receivedBytes += chunk.length;
            if (contentLength > 0) {
              onProgress(receivedBytes / contentLength);
            }
          },
          onDone: () async {
            await sink.flush();
            await sink.close();
          },
        ).asFuture();
      } finally {
        client.close();
      }

      // 解压文件
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final extractPath = path.join(downloadDir.path, 'extracted');

      // 清理旧的解压目录
      final extractDir = Directory(extractPath);
      if (extractDir.existsSync()) {
        extractDir.deleteSync(recursive: true);
      }
      extractDir.createSync(recursive: true);

      // 解压文件
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          File(path.join(extractPath, filename))
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory(path.join(extractPath, filename))
              .createSync(recursive: true);
        }
      }

      // 获取当前应用路径
      final currentExePath = Platform.resolvedExecutable;
      final currentDir = path.dirname(currentExePath);

      // 创建更新脚本
      String scriptContent;
      String scriptPath;

      if (Platform.isWindows) {
        scriptContent = '''
@echo off
timeout /t 2 /nobreak
xcopy /s /y "${extractPath.replaceAll('/', '\\\\')}\\*" "${currentDir.replaceAll('/', '\\\\')}\\*"
start "" "${currentExePath.replaceAll('/', '\\\\')}"
del "%~f0"
''';
        scriptPath = path.join(downloadDir.path, 'update.bat');
      } else {
        scriptContent = '''
#!/bin/bash
sleep 2
cp -R "$extractPath/"* "$currentDir/"
"$currentExePath" &
rm "\$0"
''';
        scriptPath = path.join(downloadDir.path, 'update.sh');
      }

      final scriptFile = File(scriptPath);
      await scriptFile.writeAsString(scriptContent);

      if (!Platform.isWindows) {
        // 设置脚本可执行权限
        await Process.run('chmod', ['+x', scriptPath]);
      }

      return (success: true, message: '下载完成，准备更新');
    } catch (e) {
      return (success: false, message: '更新失败: $e');
    }
  }

  static Future<void> applyUpdate() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final scriptPath = path.join(tempDir.path, 'update',
          Platform.isWindows ? 'update.bat' : 'update.sh');

      // 运行更新脚本
      if (Platform.isWindows) {
        await Process.start('cmd', ['/c', 'start', '/b', scriptPath]);
      } else {
        await Process.start('bash', [scriptPath]);
      }

      // 退出当前应用
      exit(0);
    } catch (e) {
      rethrow;
    }
  }
}
