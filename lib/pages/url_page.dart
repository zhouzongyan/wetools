import 'package:flutter/material.dart';
import '../utils/clipboard_util.dart';

class UrlPage extends StatefulWidget {
  const UrlPage({super.key});

  @override
  State<UrlPage> createState() => _UrlPageState();
}

class _UrlPageState extends State<UrlPage> {
  final TextEditingController _encodeController = TextEditingController();
  final TextEditingController _decodeController = TextEditingController();
  String _encodeResult = '';
  String _decodeResult = '';

  void _encodeUrl() {
    try {
      final encoded = Uri.encodeFull(_encodeController.text);
      setState(() {
        _encodeResult = encoded;
      });
    } catch (e) {
      setState(() {
        _encodeResult = '错误: ${e.toString()}';
      });
    }
  }

  void _decodeUrl() {
    try {
      final decoded = Uri.decodeFull(_decodeController.text);
      setState(() {
        _decodeResult = decoded;
      });
    } catch (e) {
      setState(() {
        _decodeResult = '错误: ${e.toString()}';
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
              'URL 编码工具',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'URL 编码解码工具，支持特殊字符转换',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            // 编码部分
            Text(
              'URL 编码',
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
                          hintText: '输入要编码的 URL',
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
                              SelectionArea(child: Text(_encodeResult)),
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
                      onPressed: _encodeUrl,
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
              'URL 解码',
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
                          hintText: '输入要解码的 URL',
                        ),
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        enableInteractiveSelection: true,
                      ),
                      if (_decodeResult.isNotEmpty) ...[
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
                                            _decodeResult, context),
                                    tooltip: '复制结果',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SelectableText(_decodeResult),
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
                      onPressed: _decodeUrl,
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
