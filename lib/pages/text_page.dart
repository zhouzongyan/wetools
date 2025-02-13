import 'package:flutter/material.dart';
import 'package:wetools/widgets/windows_text_field.dart';
import '../utils/clipboard_util.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'dart:convert';
import '../widgets/custom_text_field.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:uuid/uuid.dart';

class TextPage extends StatefulWidget {
  const TextPage({super.key});

  @override
  State<TextPage> createState() => _TextPageState();
}

class _TextPageState extends State<TextPage> {
  final TextEditingController _inputController = TextEditingController();
  String _result = '';
  String _stats = '';
  Uint8List? _qrImage;
  final _uuid = const Uuid();

  final Map<String, String> _punctuationMap = {
    '，': ',',
    '。': '.',
    '！': '!',
    '？': '?',
    '；': ';',
    '：': ':',
    '"': '"',
    ''': '\'',
    ''': '\'',
    '（': '(',
    '）': ')',
    '【': '[',
    '】': ']',
    '《': '<',
    '》': '>',
    '、': ',',
    '～': '~',
  };

  void _trimText() {
    setState(() {
      _result = _inputController.text.trim();
      _updateStats();
    });
  }

  void _toUpperCase() {
    setState(() {
      _result = _inputController.text.toUpperCase();
      _updateStats();
    });
  }

  void _toLowerCase() {
    setState(() {
      _result = _inputController.text.toLowerCase();
      _updateStats();
    });
  }

  void _chineseToPunctuation() {
    String text = _inputController.text;
    _punctuationMap.forEach((cn, en) {
      text = text.replaceAll(cn, en);
    });
    setState(() {
      _result = text;
      _updateStats();
    });
  }

  void _punctuationToChinese() {
    String text = _inputController.text;
    _punctuationMap.forEach((cn, en) {
      text = text.replaceAll(en, cn);
    });
    setState(() {
      _result = text;
      _updateStats();
    });
  }

  void _updateStats() {
    if (_result.isEmpty) {
      _stats = '';
      return;
    }

    int chars = _result.length;
    int chineseChars = _result.runes
        .where((rune) => (rune >= 0x4e00 && rune <= 0x9fff))
        .length;
    int words = _result.trim().split(RegExp(r'\s+')).length;
    int lines = _result.trim().split('\n').length;
    int spaces = _result.split(' ').length - 1;
    int utf8Bytes = utf8.encode(_result).length;
    int gbkBytes = gbk.encode(_result).length;

    _stats = '''总字符数: $chars
中文字符: $chineseChars
单词数: $words
行数: $lines
空格数: $spaces
UTF-8字节数: $utf8Bytes
GBK字节数: $gbkBytes''';
  }

  Future<void> _generateQRCode() async {
    if (_inputController.text.isEmpty) {
      ClipboardUtil.showSnackBar(
        '请先输入要生成二维码的文本',
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 80,
          right: 200,
          left: 200,
        ),
      );
      return;
    }

    try {
      // 显示生成中提示
      ClipboardUtil.showSnackBar(
        '生成二维码中...',
        duration: const Duration(seconds: 10),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 80,
          right: 200,
          left: 200,
        ),
      );

      // 创建二维码
      final qrPainter = QrPainter(
        data: _inputController.text,
        version: QrVersions.auto,
        gapless: true,
      );

      // 生成图片
      final qrImage = await qrPainter.toImage(400);
      final byteData =
          await qrImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        setState(() {
          _qrImage = byteData.buffer.asUint8List();
        });

        if (context.mounted) {
          ClipboardUtil.rootScaffoldMessengerKey.currentState
              ?.hideCurrentSnackBar();
          ClipboardUtil.showSnackBar(
            '二维码生成完成',
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 80,
              right: 200,
              left: 200,
            ),
          );
        }
      }
        } catch (e) {
      if (context.mounted) {
        ClipboardUtil.showSnackBar(
          '生成二维码失败',
          backgroundColor: Colors.red,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 80,
            right: 200,
            left: 200,
          ),
        );
      }
    }
  }

  Future<void> _downloadQRCode() async {
    if (_qrImage == null) return;

    try {
      final now = DateTime.now();
      final fileName = 'qrcode_${now.millisecondsSinceEpoch}.png';

      String? savePath;

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final directory = await getDownloadsDirectory();
        if (directory != null) {
          savePath = '${directory.path}${Platform.pathSeparator}$fileName';
        }
      }

      if (savePath == null) {
        final directory = await getApplicationDocumentsDirectory();
        savePath = '${directory.path}${Platform.pathSeparator}$fileName';
      }

      final file = File(savePath);
      await file.writeAsBytes(_qrImage!);

      if (context.mounted) {
        ClipboardUtil.showSnackBar(
          '二维码保存成功！\n保存路径: $savePath',
          duration: const Duration(seconds: 5),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 80,
            right: 200,
            left: 200,
          ),
          action: SnackBarAction(
            label: '知道了',
            onPressed: () {
              ClipboardUtil.rootScaffoldMessengerKey.currentState
                  ?.hideCurrentSnackBar();
            },
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ClipboardUtil.showSnackBar(
          '保存二维码失败，请重试',
          backgroundColor: Colors.red,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 80,
            right: 200,
            left: 200,
          ),
        );
      }
    }
  }

  String _generateRandomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  void _generateRandomStrings() {
    final randomStrings =
        List.generate(10, (index) => _generateRandomString(32));
    setState(() {
      _result = randomStrings.join('\n');
      _updateStats();
    });
  }

  void _generateUUIDs() {
    // 生成5个大写和5个小写的UUID
    final upperUUIDs = List.generate(5, (index) => _uuid.v4().toUpperCase());
    final lowerUUIDs = List.generate(5, (index) => _uuid.v4().toLowerCase());

    setState(() {
      _result = [...upperUUIDs, ...lowerUUIDs].join('\n');
      _updateStats();
    });
  }

  Future<void> _saveToFile(String content, {String? prefix}) async {
    try {
      final now = DateTime.now();
      final fileName = '${prefix ?? 'text'}_${now.millisecondsSinceEpoch}.txt';

      String? savePath;

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final directory = await getDownloadsDirectory();
        if (directory != null) {
          savePath = '${directory.path}${Platform.pathSeparator}$fileName';
        }
      }

      if (savePath == null) {
        final directory = await getApplicationDocumentsDirectory();
        savePath = '${directory.path}${Platform.pathSeparator}$fileName';
      }

      final file = File(savePath);
      await file.writeAsString(content);

      if (context.mounted) {
        ClipboardUtil.showSnackBar(
          '文件保存成功！\n保存路径: $savePath',
          duration: const Duration(seconds: 5),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 80,
            right: 200,
            left: 200,
          ),
          action: SnackBarAction(
            label: '知道了',
            onPressed: () {
              ClipboardUtil.rootScaffoldMessengerKey.currentState
                  ?.hideCurrentSnackBar();
            },
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ClipboardUtil.showSnackBar(
          '保存文件失败，请重试',
          backgroundColor: Colors.red,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 80,
            right: 200,
            left: 200,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '文本工具',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '文本格式化、统计及标点符号转换工具,结果中包含统计信息',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              color: Theme.of(context).cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '输入文本',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: WindowsTextField(
                            controller: _inputController,
                            hintText: '输入要处理的文本',
                            maxLines: 15,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            width: 60,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ElevatedButton(
                                  onPressed: _trimText,
                                  child: const Text('去除首尾空白'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _toUpperCase,
                                  child: const Text('转大写'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _toLowerCase,
                                  child: const Text('转小写'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _chineseToPunctuation,
                                  child: const Text('中文标点转英文'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _punctuationToChinese,
                                  child: const Text('英文标点转中文'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _generateQRCode,
                                  child: const Text('生成二维码'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _generateRandomStrings,
                                  child: const Text('生成随机字符串'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _generateUUIDs,
                                  child: const Text('生成UUID'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () => _saveToFile(_inputController.text, prefix: 'input'),
                                  child: const Text('保存为文件'),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _inputController.clear();
                                      _result = '';
                                      _stats = '';
                                    });
                                  },
                                  child: const Text('清除'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_result.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.withOpacity(0.1),
                              Colors.deepPurple.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('结果:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.save_alt, size: 20),
                                  onPressed: () => _saveToFile(_result, prefix: 'result'),
                                  tooltip: '保存为文件',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  onPressed: () => ClipboardUtil.copyToClipboard(_result, context),
                                  tooltip: '复制结果',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(_result),
                            if (_stats.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text('统计信息:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Text(_stats),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                    if (_qrImage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.withOpacity(0.1),
                              Colors.deepPurple.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('二维码:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.download, size: 20),
                                  onPressed: _downloadQRCode,
                                  tooltip: '下载二维码',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Image.memory(
                                _qrImage!,
                                width: 200,
                                height: 200,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
