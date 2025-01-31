import 'package:flutter/material.dart';
import '../utils/clipboard_util.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'dart:convert';
import '../widgets/custom_text_field.dart';

class TextPage extends StatefulWidget {
  const TextPage({super.key});

  @override
  State<TextPage> createState() => _TextPageState();
}

class _TextPageState extends State<TextPage> {
  final TextEditingController _inputController = TextEditingController();
  String _result = '';
  String _stats = '';

  final Map<String, String> _punctuationMap = {
    '，': ',',
    '。': '.',
    '！': '!',
    '？': '?',
    '；': ';',
    '：': ':',
    '"': '"',
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
            const SizedBox(height: 24),
            Card(
              elevation: 2,
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
                          flex: 2,
                          child: CustomTextField(
                            controller: _inputController,
                            hintText: '输入要处理的文本',
                            maxLines: 8,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
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
                                const Text('结果:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
