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
      final bytes = base64.decode(_decodeController.text);
      final decoded = utf8.decode(bytes);
      setState(() {
        _decodeResult = decoded;
      });
    } catch (e) {
      setState(() {
        _decodeResult = '错误: 无效的 Base64 格式';
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
                      ),
                      if (_encodeResult.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
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
                              const SizedBox(height: 4),
                              SelectableText(_encodeResult),
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
            const SizedBox(height: 8),
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
                      ),
                      if (_decodeResult.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
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
                              const SizedBox(height: 4),
                              SelectableText(_decodeResult),
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
