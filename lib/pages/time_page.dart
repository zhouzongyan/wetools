import 'package:flutter/material.dart';
import '../utils/clipboard_util.dart';

class TimePage extends StatefulWidget {
  const TimePage({super.key});

  @override
  State<TimePage> createState() => _TimePageState();
}

class _TimePageState extends State<TimePage> {
  final TextEditingController _inputController = TextEditingController();
  String _result = '';
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _updateCurrentTime();
  }

  void _updateCurrentTime() {
    final now = DateTime.now();
    final utc = now.toUtc();
    setState(() {
      _currentTime = '''
当前时间：${now.toString()}
UTC时间：${utc.toString()}
UTC时间戳(秒)：${utc.millisecondsSinceEpoch ~/ 1000}
UTC时间戳(毫秒)：${utc.millisecondsSinceEpoch}
本地时间戳(秒)：${now.millisecondsSinceEpoch ~/ 1000}
本地时间戳(毫秒)：${now.millisecondsSinceEpoch}
''';
    });
  }

  void _convertTime() {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _result = '请输入时间或时间戳';
      });
      return;
    }

    try {
      if (input.contains('-') || input.contains(':')) {
        // 尝试解析日期时间字符串
        final dateTime = DateTime.parse(input);
        final utc = dateTime.toUtc();
        setState(() {
          _result = '''
本地时间：${dateTime.toLocal()}
UTC时间：${utc.toString()}
UTC时间戳(秒)：${utc.millisecondsSinceEpoch ~/ 1000}
UTC时间戳(毫秒)：${utc.millisecondsSinceEpoch}
本地时间戳(秒)：${dateTime.millisecondsSinceEpoch ~/ 1000}
本地时间戳(毫秒)：${dateTime.millisecondsSinceEpoch}
''';
        });
      } else {
        // 尝试解析时间戳
        final timestamp = int.parse(input);
        final dateTime = timestamp.toString().length > 10
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        final utc = dateTime.toUtc();
        setState(() {
          _result = '''
本地时间：${dateTime.toLocal()}
UTC时间：${utc.toString()}
UTC时间戳(秒)：${utc.millisecondsSinceEpoch ~/ 1000}
UTC时间戳(毫秒)：${utc.millisecondsSinceEpoch}
本地时间戳(秒)：${dateTime.millisecondsSinceEpoch ~/ 1000}
本地时间戳(毫秒)：${dateTime.millisecondsSinceEpoch}
''';
        });
      }
    } catch (e) {
      setState(() {
        _result =
            '无效的输入格式\n支持的格式：\n1. 标准日期时间（如：2024-01-01 12:00:00）\n2. 时间戳（秒或毫秒）';
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
              '时间工具',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '时间格式转换工具，支持时间戳与日期时间的互相转换',
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '系统时间',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: _updateCurrentTime,
                                tooltip: '刷新当前时间',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(_currentTime),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '输入时间',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: '输入时间戳或日期时间（如：2024-01-01 12:00:00）',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _convertTime,
                          child: const Text('转换'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _inputController.clear();
                              _result = '';
                            });
                          },
                          child: const Text('清除'),
                        ),
                      ],
                    ),
                    if (_result.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
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
                                const Text('转换结果:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  onPressed: () {
                                    final content = _result.trim();
                                    ClipboardUtil.copyToClipboard(
                                        content, context);
                                  },
                                  tooltip: '复制结果',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SelectableText(_result),
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
