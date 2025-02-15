import 'package:flutter/material.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:wetools/widgets/windows_text_field.dart';
import 'dart:convert';
import '../utils/clipboard_util.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:highlight/languages/json.dart' as highlight;

class JwtPage extends StatefulWidget {
  const JwtPage({super.key});

  @override
  State<JwtPage> createState() => _JwtPageState();
}

class _JwtPageState extends State<JwtPage> {
  late CodeController _encodeController;
  final TextEditingController _decodeController = TextEditingController();
  String _encodeResult = '';
  String _decodeResult = '';
  String? _errorText;
  bool _isDarkMode = false;

  // 用于测试的密钥，实际使用时应该是可配置的
  final String _secretKey = 'wetools';

  @override
  void initState() {
    super.initState();
    _encodeController = CodeController(
      text: '',
      language: highlight.json,
      params: const EditorParams(
        tabSpaces: 2,
      ),
    );
  }

  @override
  void dispose() {
    _encodeController.dispose();
    _decodeController.dispose();
    super.dispose();
  }

  void _formatJson() {
    try {
      final dynamic parsed = jsonDecode(_encodeController.text);
      final String formatted = const JsonEncoder.withIndent('  ').convert(parsed);
      setState(() {
        _encodeController.text = formatted;
        _errorText = null;
      });
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _encodeController.selection = const TextSelection.collapsed(offset: 0);
          _encodeController.text = _encodeController.text;
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

  void _encodeJWT() {
    try {
      // 解析输入的 JSON
      final Map<String, dynamic> payload = json.decode(_encodeController.text);

      // 创建 JWT
      final jwt = JWT(
        payload,
        issuer: 'wetools',
      );

      // 使用密钥签名
      final token = jwt.sign(SecretKey(_secretKey));

      setState(() {
        _encodeResult = token;
      });
    } catch (e) {
      setState(() {
        _encodeResult = '错误: ${e.toString()}';
      });
    }
  }

  void _decodeJWT() {
    try {
      final jwt = JWT.verify(_decodeController.text, SecretKey(_secretKey));
      final prettyJson =
          const JsonEncoder.withIndent('  ').convert(jwt.payload);
      setState(() {
        _decodeResult = prettyJson;
      });
    } on JWTExpiredException catch (e) {
      setState(() {
        _decodeResult = '错误: ${e.message}';
      });
    } on FormatException {
      setState(() {
        _decodeResult = '错误: 无效的 JWT 格式';
      });
    } on JWTException catch (e) {
      setState(() {
        _decodeResult = '错误: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _decodeResult = '错误: ${e.toString()}';
      });
    }
  }

  Widget _buildEditor() {
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade900;
    final backgroundColor = _isDarkMode ? const Color(0xFF272822) : Colors.white;

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
              controller: _encodeController,
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
                          _encodeController.text, context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
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
                              .surfaceContainerHighest
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
    return SelectionArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'JWT 工具',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'JSON Web Token 编码解码工具，支持签名验证',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              // 编码部分
              Text(
                'JWT 编码',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
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
                        if (_encodeResult.isNotEmpty) ...[
                          const SizedBox(height: 32),
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
                                              _encodeResult, context),
                                      tooltip: '复制结果',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(_encodeResult),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: _encodeJWT,
                        child: const Text('编码'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _encodeController.clear();
                            _encodeResult = '';
                          });
                        },
                        child: const Text('清除'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // 解码部分
              Text(
                'JWT 解码',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WindowsTextField(
                          controller: _decodeController,
                          hintText: '输入要解码的 JWT token',
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                        ),
                        if (_decodeResult.isNotEmpty) ...[
                          const SizedBox(height: 32),
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
                                              _decodeResult, context),
                                      tooltip: '复制结果',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(_decodeResult),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: _decodeJWT,
                        child: const Text('解码'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _decodeController.clear();
                            _decodeResult = '';
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
