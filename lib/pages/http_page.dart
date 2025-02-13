import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/clipboard_util.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class HttpPage extends StatefulWidget {
  const HttpPage({super.key});

  @override
  State<HttpPage> createState() => _HttpPageState();
}

class _HttpPageState extends State<HttpPage> {
  final _urlController = TextEditingController();
  final _headersController = TextEditingController();
  final _bodyController = TextEditingController();
  String _response = '';
  String _method = 'GET';
  bool _isLoading = false;
  String _contentType = '';

  Future<void> _sendRequest() async {
    if (_urlController.text.isEmpty) {
      ClipboardUtil.showSnackBar('请输入URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _response = '';
    });

    try {
      Map<String, String> headers = {};
      if (_headersController.text.isNotEmpty) {
        final headerLines = _headersController.text.split('\n');
        for (var line in headerLines) {
          if (line.contains(':')) {
            final parts = line.split(':');
            headers[parts[0].trim()] = parts[1].trim();
          }
        }
      }

      http.Response response;
      if (_method == 'GET') {
        response = await http.get(
          Uri.parse(_urlController.text),
          headers: headers,
        );
      } else {
        response = await http.post(
          Uri.parse(_urlController.text),
          headers: headers,
          body: _bodyController.text,
        );
      }

      // 获取响应的 Content-Type
      _contentType = response.headers['content-type'] ?? '';
      
      setState(() {
        _response = '''状态码: ${response.statusCode}
        
请求头:
${response.request?.headers.entries.map((e) => '${e.key}: ${e.value}').join('\n')}

响应头:
${response.headers.entries.map((e) => '${e.key}: ${e.value}').join('\n')}

响应体:
${_formatResponse(response.body)}''';
      });
    } catch (e) {
      setState(() {
        _response = '错误: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatResponse(String body) {
    try {
      if (_contentType.contains('json')) {
        const JsonEncoder encoder = JsonEncoder.withIndent('  ');
        final object = json.decode(body);
        return encoder.convert(object);
      }
      return body;
    } catch (e) {
      return body;
    }
  }

  String _getResponseBody() {
    final lines = _response.split('\n');
    final bodyIndex = lines.indexOf('响应体:');
    if (bodyIndex != -1 && bodyIndex < lines.length - 1) {
      return lines.sublist(bodyIndex + 1).join('\n');
    }
    return '';
  }

  Future<void> _saveToFile(String content, {String? prefix}) async {
    try {
      final now = DateTime.now();
      final fileName = '${prefix ?? 'http'}_${now.millisecondsSinceEpoch}.txt';

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

  void _clearAll() {
    setState(() {
      _urlController.clear();
      _headersController.clear();
      _bodyController.clear();
      _response = '';
    });
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
              'HTTP 请求工具',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '发送 HTTP 请求并查看响应,支持GET和POST请求',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              color: Theme.of(context).cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: _method,
                          items: ['GET', 'POST'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _method = newValue!;
                            });
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'URL',
                              hintText: 'https://example.com/api',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _headersController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '请求头',
                        hintText:
                            'Content-Type: application/json\nAuthorization: Bearer token',
                      ),
                      maxLines: 3,
                    ),
                    if (_method == 'POST') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _bodyController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '请求体',
                          hintText: '{"key": "value"}',
                        ),
                        maxLines: 5,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _clearAll,
                          child: const Text('清除'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _sendRequest,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('发送请求'),
                        ),
                      ],
                    ),
                    if (_response.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('响应:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.save_alt, size: 20),
                            onPressed: () => _saveToFile(_getResponseBody()),
                            tooltip: '保存响应体',
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () =>
                                ClipboardUtil.copyToClipboard(_getResponseBody(), context),
                            tooltip: '复制响应体',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_response),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  @override
  void dispose() {
    _urlController.dispose();
    _headersController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}
