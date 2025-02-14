import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../utils/clipboard_util.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:highlight/languages/json.dart' as highlight;
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/vs.dart';

class JsonPage extends StatefulWidget {
  const JsonPage({super.key});

  @override
  State<JsonPage> createState() => _JsonPageState();
}

class _JsonPageState extends State<JsonPage> {
  late CodeController _codeController;
  String _result = '';
  String? _errorText;
  bool _isDarkMode = false;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _codeController = CodeController(
      text: '',
      language: highlight.json,
      params: const EditorParams(
        tabSpaces: 2,
      ),
    );
    _codeController.addListener(_validateJson);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _editorFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _validateJson() {
    final text = _codeController.text;
    if (text.trim().isEmpty) {
      setState(() {
        _errorText = null;
      });
      return;
    }

    try {
      jsonDecode(text);
      setState(() {
        _errorText = null;
      });
    } catch (e) {
      setState(() {
        _errorText = e.toString();
      });
    }
  }

  void _formatJson() {
    try {
      final dynamic parsed = jsonDecode(_codeController.text);
      final String formatted =
          const JsonEncoder.withIndent('  ').convert(parsed);
      setState(() {
        _codeController.text = formatted;
        _errorText = null;
      });
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _codeController.selection = const TextSelection.collapsed(offset: 0);
          _codeController.text = _codeController.text;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('格式化成功'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      setState(() {
        _errorText = '格式化失败: JSON 格式不合法';
      });
    }
  }

  void _compressJson() {
    try {
      final dynamic parsed = jsonDecode(_codeController.text);
      final String compressed = jsonEncode(parsed);
      setState(() {
        _result = compressed;
        _errorText = null;
      });
    } catch (e) {
      setState(() {
        _result = '错误: 无效的 JSON 格式\n${e.toString()}';
        _errorText = e.toString();
      });
    }
  }

  void _escapeJson() {
    final String escaped = _codeController.text
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
      final String unescaped = jsonDecode('"${_codeController.text}"');
      setState(() {
        _result = unescaped;
        _errorText = null;
      });
    } catch (e) {
      setState(() {
        _result = '错误: 无效的转义字符串\n${e.toString()}';
        _errorText = e.toString();
      });
    }
  }

  void _unicodeToString() {
    try {
      final String text = _codeController.text;
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
    final String text = _codeController.text;
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

  Widget _buildEditor() {
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade900;
    final backgroundColor =
        _isDarkMode ? const Color(0xFF272822) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _errorText != null ? Colors.red : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CodeField(
              controller: _codeController,
              textStyle: TextStyle(
                fontFamily: 'JetBrainsMono',
                color: textColor,
                fontSize: 14,
              ),
              lineNumberStyle: LineNumberStyle(
                textStyle: TextStyle(
                  color: _isDarkMode ? Colors.grey : Colors.grey.shade600,
                ),
              ),
              background: backgroundColor,
              minLines: 10,
              maxLines: null,
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: Tooltip(
                    message: '复制',
                    preferBelow: false,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => ClipboardUtil.copyToClipboard(
                          _codeController.text, context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.5),
                          ),
                        ),
                        child: Icon(
                          Icons.copy,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: Tooltip(
                    message: '格式化',
                    preferBelow: false,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: _formatJson,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.5),
                          ),
                        ),
                        child: Icon(
                          Icons.format_align_left,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: SingleChildScrollView(
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
                        _buildEditor(),
                        if (_errorText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _errorText!,
                              style: const TextStyle(color: Colors.red),
                            ),
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
                                      icon: const Icon(Icons.copy, size: 20),
                                      onPressed: () =>
                                          ClipboardUtil.copyToClipboard(
                                              _result, context),
                                      tooltip: '复制结果',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _codeController.text = _result;
                                          _result = '';
                                        });
                                      },
                                      tooltip: '应用到编辑器',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(_result),
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
                            _codeController.text = '';
                            _result = '';
                            _errorText = null;
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
      ),
    );
  }
}
