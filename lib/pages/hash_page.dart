import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:sm_crypto/sm_crypto.dart';
import 'dart:convert';
import '../utils/clipboard_util.dart';

class HashPage extends StatefulWidget {
  const HashPage({super.key});

  @override
  State<HashPage> createState() => _HashPageState();
}

class _HashPageState extends State<HashPage> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _saltController = TextEditingController();
  String _result = '';
  bool _upperCase = false;

  String _calculateHash(String type) {
    try {
      final input = _inputController.text;
      final salt = _saltController.text;
      final data = salt.isEmpty ? input : input + salt;
      String hashResult;

      switch (type) {
        case 'md5':
          hashResult = md5.convert(utf8.encode(data)).toString();
          break;
        case 'sha1':
          hashResult = sha1.convert(utf8.encode(data)).toString();
          break;
        case 'sha256':
          hashResult = sha256.convert(utf8.encode(data)).toString();
          break;
        case 'sm3':
          hashResult = SM3.encryptBytes(utf8.encode(data)).toString();
          break;
        default:
          return '不支持的哈希类型';
      }

      return _upperCase ? hashResult.toUpperCase() : hashResult.toLowerCase();
    } catch (e) {
      return '错误: ${e.toString()}';
    }
  }

  void _updateHash(String type) {
    setState(() {
      _result = _calculateHash(type);
    });
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
              'Hash 工具',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              '支持 MD5、SHA1、SHA256、SM3 等多种哈希算法',
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
                        controller: _inputController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '输入要计算哈希的文本',
                        ),
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        enableInteractiveSelection: true,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _saltController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '可选：输入加盐值',
                        ),
                        keyboardType: TextInputType.text,
                        enableInteractiveSelection: true,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('结果大小写：'),
                          Switch(
                            value: _upperCase,
                            onChanged: (bool value) {
                              setState(() {
                                _upperCase = value;
                                if (_result.isNotEmpty) {
                                  _result = _upperCase
                                      ? _result.toUpperCase()
                                      : _result.toLowerCase();
                                }
                              });
                            },
                          ),
                          Text(_upperCase ? '大写' : '小写'),
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
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(_result),
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
                      onPressed: () => _updateHash('md5'),
                      child: const Text('MD5'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _updateHash('sha1'),
                      child: const Text('SHA1'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _updateHash('sha256'),
                      child: const Text('SHA256'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _updateHash('sm3'),
                      child: const Text('SM3'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _inputController.clear();
                          _saltController.clear();
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
