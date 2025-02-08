import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/clipboard_util.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class JsonPage extends StatefulWidget {
  const JsonPage({super.key});

  @override
  State<JsonPage> createState() => _JsonPageState();
}

class _JsonPageState extends State<JsonPage> {
  final TextEditingController _jsonController = TextEditingController();
  String _result = '';

  void _formatJson() {
    try {
      final dynamic parsed = json.decode(_jsonController.text);
      final String formatted =
          const JsonEncoder.withIndent('  ').convert(parsed);
      setState(() {
        _result = formatted;
      });
    } catch (e) {
      setState(() {
        _result = '错误: 无效的 JSON 格式\n${e.toString()}';
      });
    }
  }

  void _compressJson() {
    try {
      final dynamic parsed = json.decode(_jsonController.text);
      final String compressed = json.encode(parsed);
      setState(() {
        _result = compressed;
      });
    } catch (e) {
      setState(() {
        _result = '错误: 无效的 JSON 格式\n${e.toString()}';
      });
    }
  }

  void _escapeJson() {
    final String escaped = _jsonController.text
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    setState(() {
      _result = escaped;
    });
  }

  void _unescapeJson() {
    try {
      final String unescaped = json.decode('"${_jsonController.text}"');
      setState(() {
        _result = unescaped;
      });
    } catch (e) {
      setState(() {
        _result = '错误: 无效的转义字符串\n${e.toString()}';
      });
    }
  }

  void _unicodeToString() {
    try {
      final String text = _jsonController.text;
      final String converted = text.replaceAllMapped(
        RegExp(r'\\u([0-9a-fA-F]{4})'),
        (match) => String.fromCharCode(
          int.parse(match.group(1)!, radix: 16),
        ),
      );
      setState(() {
        _result = converted;
      });
    } catch (e) {
      setState(() {
        _result = '错误: 转换失败\n${e.toString()}';
      });
    }
  }

  void _stringToUnicode() {
    final String text = _jsonController.text;
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) > 127) {
        buffer.write(
            '\\u${text.codeUnitAt(i).toRadixString(16).padLeft(4, '0')}');
      } else {
        buffer.write(text[i]);
      }
    }
    setState(() {
      _result = buffer.toString();
    });
  }

  Future<void> _saveToFile(String content, {String? prefix}) async {
    try {
      final now = DateTime.now();
      final fileName = '${prefix ?? 'json'}_${now.millisecondsSinceEpoch}.txt';

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
              ClipboardUtil.rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'JSON 工具',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'JSON 格式化、压缩、转义及 Unicode 转换工具',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _jsonController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '输入 JSON 数据',
                        ),
                        maxLines: 10,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        enableInteractiveSelection: true,
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
                                  const Text('结果:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.save_alt, size: 20),
                                    onPressed: () => _saveToFile(_result),
                                    tooltip: '保存为文件',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 20),
                                    onPressed: () =>
                                        ClipboardUtil.copyToClipboard(
                                            _result, context),
                                    tooltip: '复制结果',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(_result),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _formatJson,
                      child: const Text('格式化'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _compressJson,
                      child: const Text('压缩'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _escapeJson,
                      child: const Text('转义'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _unescapeJson,
                      child: const Text('去除转义'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _unicodeToString,
                      child: const Text('Unicode转中文'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _stringToUnicode,
                      child: const Text('中文转Unicode'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _jsonController.clear();
                          _result = '';
                        });
                      },
                      child: const Text('清除'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
