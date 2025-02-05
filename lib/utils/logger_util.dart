import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class LoggerUtil {
  static const String _logFileName = 'wetools.log';
  static File? _logFile;
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  // 初始化日志文件
  static Future<void> init() async {
    if (_logFile != null) return;

    try {
      final directory = await _getLogDirectory();
      _logFile =
          File('${directory.path}${Platform.pathSeparator}$_logFileName');

      // 如果文件不存在或大于10MB，创建新文件并写入 UTF-8 BOM
      if (!await _logFile!.exists() ||
          (await _logFile!.stat()).size > 10 * 1024 * 1024) {
        // 写入 UTF-8 BOM 标记
        await _logFile!.writeAsBytes([0xEF, 0xBB, 0xBF], mode: FileMode.write);
      }

      await info('日志系统初始化成功: ${_logFile!.path}');
    } catch (e, stackTrace) {
      debugPrint('日志系统初始化失败: $e\n$stackTrace');
    }
  }

  // 获取日志目录
  static Future<Directory> _getLogDirectory() async {
    Directory directory;
    if (Platform.isWindows) {
      // Windows: %APPDATA%\WeTools\logs
      final appData = Platform.environment['APPDATA'];
      directory = Directory('$appData\\WeTools');
    } else if (Platform.isMacOS) {
      // macOS: ~/Library/Application Support/WeTools/logs
      directory = await getApplicationSupportDirectory();
      directory = Directory('${directory.path}/WeTools');
    } else if (Platform.isLinux) {
      // Linux: ~/.local/share/WeTools/logs
      directory = await getApplicationSupportDirectory();
      directory = Directory('${directory.path}/WeTools');
    } else {
      directory = await getApplicationDocumentsDirectory();
      directory = Directory('${directory.path}/WeTools');
    }

    final logDir = Directory('${directory.path}${Platform.pathSeparator}logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    return logDir;
  }

  // 写入日志
  static Future<void> _writeLog(String level, String message) async {
    if (_logFile == null) return;

    try {
      final now = _dateFormat.format(DateTime.now());
      final log = '[$now][$level] $message\n';

      // 追加写入 UTF-8 编码的日志
      await _logFile!.writeAsBytes(
        utf8.encode(log),
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint('写入日志失败: $e');
    }
  }

  // 记录信息日志
  static Future<void> info(String message) async {
    await _writeLog('INFO', message);
  }

  // 记录警告日志
  static Future<void> warning(String message) async {
    await _writeLog('WARN', message);
  }

  // 记录错误日志
  static Future<void> error(String message,
      [dynamic error, StackTrace? stackTrace]) async {
    String logMessage = message;
    if (error != null) {
      logMessage += '\nError: $error';
    }
    if (stackTrace != null) {
      logMessage += '\nStackTrace:\n$stackTrace';
    }
    await _writeLog('ERROR', logMessage);
  }

  // 获取日志内容
  static Future<String> getLogs() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return '暂无日志';
    }
    return await _logFile!.readAsString();
  }

  // 清空日志
  static Future<void> clearLogs() async {
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
      await info('日志已清空');
    }
  }

  // 获取日志文件路径
  static Future<String?> getLogFilePath() async {
    if (_logFile != null) {
      return _logFile!.path;
    }
    try {
      final directory = await _getLogDirectory();
      return '${directory.path}${Platform.pathSeparator}$_logFileName';
    } catch (e) {
      debugPrint('获取日志文件路径失败: $e');
      return null;
    }
  }
}
