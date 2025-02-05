import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/clipboard_util.dart';

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
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final object = json.decode(body);
      return encoder.convert(object);
    } catch (e) {
      return body;
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
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () => ClipboardUtil.copyToClipboard(
                                _response, context),
                            tooltip: '复制响应',
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
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _headersController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}
