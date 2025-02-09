import 'package:flutter/material.dart';
import 'package:translator/translator.dart';
import '../utils/clipboard_util.dart';
import '../widgets/custom_text_field.dart';

class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key});

  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  final TextEditingController _inputController = TextEditingController();
  final translator = GoogleTranslator();
  String _result = '';
  bool _isTranslating = false;
  String _fromLanguage = 'auto';
  String _toLanguage = 'en';

  final Map<String, String> _languages = {
    'auto': '自动检测',
    'zh-cn': '中文',
    'en': '英语',
    'ja': '日语',
    'ko': '韩语',
    'fr': '法语',
    'de': '德语',
    'es': '西班牙语',
    'ru': '俄语',
  };

  Future<void> _translate() async {
    if (_inputController.text.isEmpty) {
      ClipboardUtil.showSnackBar(
        '请输入要翻译的文本',
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 80,
          right: 200,
          left: 200,
        ),
      );
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      final translation = await translator.translate(
        _inputController.text,
        from: _fromLanguage,
        to: _toLanguage,
      );

      setState(() {
        _result = translation.text;
        _isTranslating = false;
      });
    } catch (e) {
      if (context.mounted) {
        ClipboardUtil.showSnackBar(
          '翻译失败，请重试',
          backgroundColor: Colors.red,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 80,
            right: 200,
            left: 200,
          ),
        );
      }
      setState(() {
        _isTranslating = false;
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
              '文本翻译',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '支持多语言互译,使用谷歌免费翻译服务.请保持网络通畅,避免频繁请求,否则可能会被限制,限制后请稍后重试',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _fromLanguage,
                            decoration: const InputDecoration(
                              labelText: '源语言',
                            ),
                            items: _languages.entries
                                .map((e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _fromLanguage = value;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.swap_horiz),
                          onPressed: () {
                            if (_fromLanguage != 'auto') {
                              setState(() {
                                final temp = _fromLanguage;
                                _fromLanguage = _toLanguage;
                                _toLanguage = temp;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _toLanguage,
                            decoration: const InputDecoration(
                              labelText: '目标语言',
                            ),
                            items: _languages.entries
                                .where((e) => e.key != 'auto')
                                .map((e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _toLanguage = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              CustomTextField(
                                controller: _inputController,
                                hintText: '输入要翻译的文本',
                                maxLines: 5,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed:
                                        _isTranslating ? null : _translate,
                                    child: _isTranslating
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('翻译'),
                                  ),
                                  const SizedBox(width: 8),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_result.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
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
                                const Text('翻译结果:',
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
