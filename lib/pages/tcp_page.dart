import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../utils/clipboard_util.dart';
import 'dart:async';

class TcpPage extends StatefulWidget {
  const TcpPage({super.key});

  @override
  State<TcpPage> createState() => _TcpPageState();
}

class _TcpPageState extends State<TcpPage> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _messageController = TextEditingController();
  final _wsUrlController = TextEditingController();
  final _wsMessageController = TextEditingController();
  String _response = '';
  String _wsResponse = '';
  Socket? _socket;
  WebSocket? _webSocket;
  bool _isConnected = false;
  bool _isWsConnected = false;
  bool _isConnecting = false;
  bool _isWsConnecting = false;
  StreamSubscription? _wsSubscription;

  Future<void> _connect() async {
    if (_hostController.text.isEmpty || _portController.text.isEmpty) {
      ClipboardUtil.showSnackBar('请输入主机和端口');
      return;
    }

    setState(() {
      _isConnecting = true;
      _response = '';
    });

    try {
      final socket = await Socket.connect(
        _hostController.text,
        int.parse(_portController.text),
      );

      setState(() {
        _socket = socket;
        _isConnected = true;
        _response += '连接成功\n';
      });

      socket.listen(
        (data) {
          setState(() {
            // 尝试多种编码方式解析响应
            String response;
            try {
              // 尝试 UTF-8
              response = String.fromCharCodes(data);
            } catch (e) {
              try {
                // 尝试 ASCII
                response =
                    String.fromCharCodes(data.map((byte) => byte & 0x7F));
              } catch (e) {
                // 如果都失败，显示十六进制
                response = data
                    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                    .join(' ');
              }
            }
            _response += '收到: $response\n';
          });
        },
        onError: (error) {
          setState(() {
            _response += '错误: $error\n';
            _isConnected = false;
          });
          _socket?.close();
          _socket = null;
        },
        onDone: () {
          setState(() {
            _response += '连接已关闭\n';
            _isConnected = false;
          });
          _socket = null;
        },
      );
    } catch (e) {
      setState(() {
        _response += '连接失败: $e\n';
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _disconnect() {
    _socket?.close();
    setState(() {
      _socket = null;
      _isConnected = false;
      _response += '已断开连接\n';
    });
  }

  void _sendMessage() {
    if (!_isConnected) {
      ClipboardUtil.showSnackBar('请先连接服务器');
      return;
    }

    if (_messageController.text.isEmpty) {
      ClipboardUtil.showSnackBar('请输入要发送的消息');
      return;
    }

    try {
      // 添加回车换行，确保命令被发送
      final message = '${_messageController.text}\r\n';
      _socket?.write(message);
      setState(() {
        _response += '发送: ${_messageController.text}\n';
      });
      _messageController.clear();
    } catch (e) {
      setState(() {
        _response += '发送失败: $e\n';
      });
    }
  }

  void _clearAll() {
    setState(() {
      _hostController.clear();
      _portController.clear();
      _messageController.clear();
      _response = '';
    });
  }

  Future<void> _connectWebSocket() async {
    if (_wsUrlController.text.isEmpty) {
      ClipboardUtil.showSnackBar('请输入WebSocket地址');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isWsConnecting = true;
      _wsResponse = '';
    });

    try {
      final wsUrl = _wsUrlController.text;
      _webSocket = await WebSocket.connect(wsUrl);

      if (!mounted) {
        _webSocket?.close();
        return;
      }

      setState(() {
        _isWsConnected = true;
        _wsResponse += '连接成功\n';
      });

      _wsSubscription = _webSocket!.listen(
        (data) {
          if (!mounted) return;
          setState(() {
            _wsResponse += '收到: $data\n';
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _wsResponse += '错误: $error\n';
            _isWsConnected = false;
          });
          _disconnectWebSocket();
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _wsResponse += '连接已关闭\n';
            _isWsConnected = false;
          });
          _disconnectWebSocket();
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _wsResponse += '连接失败: $e\n';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isWsConnecting = false;
      });
    }
  }

  void _disconnectWebSocket() {
    if (_webSocket == null && _wsSubscription == null) return;

    _wsSubscription?.cancel();
    _webSocket?.close();
    _webSocket = null;

    // 只在组件未销毁且需要更新UI时调用setState
    if (mounted && _isWsConnected) {
      setState(() {
        _isWsConnected = false;
        _wsResponse += '已断开连接\n';
      });
    } else {
      _isWsConnected = false;
    }
  }

  void _sendWsMessage() {
    if (!_isWsConnected) {
      ClipboardUtil.showSnackBar('请先连接WebSocket服务器');
      return;
    }

    if (_wsMessageController.text.isEmpty) {
      ClipboardUtil.showSnackBar('请输入要发送的消息');
      return;
    }

    try {
      _webSocket?.add(_wsMessageController.text);
      if (!mounted) return;
      setState(() {
        _wsResponse += '发送: ${_wsMessageController.text}\n';
      });
      _wsMessageController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _wsResponse += '发送失败: $e\n';
      });
    }
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
                'TCP/WebSocket 连接工具',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '建立 TCP/WebSocket 连接并发送/接收数据',
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
                      Text(
                        'TCP 连接',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: _hostController,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          labelText: '主机',
                                          hintText: 'localhost',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 1,
                                      child: TextField(
                                        controller: _portController,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          labelText: '端口',
                                          hintText: '8080',
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _messageController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: '消息',
                                    hintText: '输入要发送的消息',
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                  minLines: 5,
                                  maxLines: 10,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ElevatedButton(
                                  onPressed: _isConnecting
                                      ? null
                                      : (_isConnected ? _disconnect : _connect),
                                  child: _isConnecting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(_isConnected ? '断开' : '连接'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _isConnected ? _sendMessage : null,
                                  child: const Text('发送'),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: _clearAll,
                                  child: const Text('清除'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_response.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('TCP日志:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.save_alt, size: 20),
                              onPressed: () => _saveToFile(_response),
                              tooltip: '保存日志',
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () => ClipboardUtil.copyToClipboard(
                                  _response, context),
                              tooltip: '复制日志',
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
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                color: Theme.of(context).cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WebSocket 连接',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: Column(
                              children: [
                                TextField(
                                  controller: _wsUrlController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'WebSocket地址',
                                    hintText: 'ws://localhost:8080',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _wsMessageController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: '消息',
                                    hintText: '输入要发送的消息',
                                  ),
                                  onSubmitted: (_) => _sendWsMessage(),
                                  minLines: 5,
                                  maxLines: 10,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ElevatedButton(
                                  onPressed: _isWsConnecting
                                      ? null
                                      : (_isWsConnected
                                          ? _disconnectWebSocket
                                          : _connectWebSocket),
                                  child: _isWsConnecting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(_isWsConnected ? '断开' : '连接'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed:
                                      _isWsConnected ? _sendWsMessage : null,
                                  child: const Text('发送'),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _wsMessageController.clear();
                                      _wsResponse = '';
                                    });
                                  },
                                  child: const Text('清除'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_wsResponse.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('WebSocket日志:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.save_alt, size: 20),
                              onPressed: () => _saveToFile(_wsResponse),
                              tooltip: '保存日志',
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () => ClipboardUtil.copyToClipboard(
                                  _wsResponse, context),
                              tooltip: '复制日志',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_wsResponse),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveToFile(String content) async {
    try {
      final now = DateTime.now();
      final fileName = 'tcp_${now.millisecondsSinceEpoch}.txt';

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

  @override
  void dispose() {
    // 先取消所有控制器
    _hostController.dispose();
    _portController.dispose();
    _messageController.dispose();
    _wsUrlController.dispose();
    _wsMessageController.dispose();

    // 清理TCP连接
    if (_socket != null) {
      _socket?.close();
      _socket = null;
      _isConnected = false;
    }

    // 清理WebSocket连接，但不触发setState
    if (_webSocket != null || _wsSubscription != null) {
      _wsSubscription?.cancel();
      _webSocket?.close();
      _webSocket = null;
      _isWsConnected = false;
    }

    super.dispose();
  }
}
