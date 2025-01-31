import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/clipboard_util.dart';

class Base64Page extends StatefulWidget {
  const Base64Page({super.key});

  @override
  State<Base64Page> createState() => _Base64PageState();
}

class _Base64PageState extends State<Base64Page> {
  final TextEditingController _encodeController = TextEditingController();
  final TextEditingController _decodeController = TextEditingController();
  String _encodeResult = '';
  String _decodeResult = '';

  void _encodeBase64() {
    try {
      final bytes = utf8.encode(_encodeController.text);
      final encoded = base64.encode(bytes);
      setState(() {
        _encodeResult = encoded;
      });
    } catch (e) {
      setState(() {
        _encodeResult = '错误: ${e.toString()}';
      });
    }
  }

  void _decodeBase64() {
    try {
      final bytes = base64.decode(_decodeController.text.trim());
      final decoded = utf8.decode(bytes);
      setState(() {
        _decodeResult = decoded;
      });
    } catch (e) {
      setState(() {
        if (e is FormatException) {
          _decodeResult = '错误: 无效的 Base64 格式\n'
              '提示：\n'
              '1. Base64 字符串只能包含 A-Z、a-z、0-9、+、/ 和 = 字符\n'
              '2. 字符串长度必须是 4 的倍数（可能需要补充 = 号）\n'
              '3. 中文等非 ASCII 字符需要先进行 Base64 编码';
        } else {
          _decodeResult = '错误: ${e.toString()}';
        }
      });
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
              'Base64 编码工具',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Base64 编码解码工具，支持中文等 Unicode 字符',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            // 编码部分
            Text(
              'Base64 编码',
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
                      TextField(
                        controller: _encodeController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '输入要编码的文本',
                        ),
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        enableInteractiveSelection: true,
                      ),
                      if (_encodeResult.isNotEmpty) ...[
                        const SizedBox(height: 8),
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
                              CustomSelectableText(
                                _encodeResult,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
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
                      onPressed: _encodeBase64,
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
              'Base64 解码',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _decodeController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '输入要解码的 Base64 字符串',
                        ),
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        enableInteractiveSelection: true,
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
                              CustomSelectableText(
                                _decodeResult,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
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
                      onPressed: _decodeBase64,
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
    );
  }
}

class CustomSelectableText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const CustomSelectableText(
    this.text, {
    super.key,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: SelectionArea(
        child: Text(
          text,
          style: style,
        ),
      ),
    );
  }
}
