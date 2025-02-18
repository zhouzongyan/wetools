import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:network_info_plus/network_info_plus.dart';
import '../utils/logger_util.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../utils/settings_util.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class FtpPage extends StatefulWidget {
  const FtpPage({super.key});

  @override
  State<FtpPage> createState() => _FtpPageState();
}

class _FtpPageState extends State<FtpPage> {
  bool _isServerRunning = false;
  String _serverAddress = '';
  int _port = 2121;
  String _username = 'wetools';
  String _password = '123456';
  List<TransferRecord> _transferRecords = [];
  HttpServer? _server;
  String _downloadPath = '';
  final _info = NetworkInfo();
  List<String> _availableIPs = [];
  String? _selectedIP;
  List<SharedFile> _sharedFiles = [];
  String? _lastTextContent;

  @override
  void initState() {
    super.initState();
    _initDownloadPath();
    _loadAvailableIPs();
    _loadSettings();
  }

  Future<void> _initDownloadPath() async {
    try {
      final dir = await getDownloadsDirectory();
      if (dir != null) {
        _downloadPath = path.join(dir.path, 'WeTools_FTP');
        final ftpDir = Directory(_downloadPath);
        if (!ftpDir.existsSync()) {
          await ftpDir.create(recursive: true);
        }
      }
    } catch (e) {
      LoggerUtil.error('初始化下载目录失败', e);
    }
  }

  Future<void> _loadAvailableIPs() async {
    try {
      List<String> ips = [];

      // 尝试获取WiFi IP
      final wifiIP = await _info.getWifiIP();
      if (wifiIP != null) {
        ips.add(wifiIP);
      }

      // 获取所有网络接口的IP
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      for (var interface in interfaces) {
        if (interface.name.toLowerCase().contains('loopback')) continue;
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            ips.add(addr.address);
          }
        }
      }

      setState(() {
        _availableIPs = ips.toSet().toList(); // 去重
        if (_availableIPs.isNotEmpty) {
          _selectedIP = _availableIPs.first;
        }
      });
    } catch (e) {
      LoggerUtil.error('加载IP地址失败', e);
    }
  }

  Future<void> _loadSettings() async {
    final port = await SettingsUtil.getFtpPort();
    final username = await SettingsUtil.getFtpUsername();
    final password = await SettingsUtil.getFtpPassword();

    setState(() {
      _port = port;
      _username = username;
      _password = password;
    });

    // 监听设置变更
    SettingsUtil.addListener(() async {
      final newPort = await SettingsUtil.getFtpPort();
      final newUsername = await SettingsUtil.getFtpUsername();
      final newPassword = await SettingsUtil.getFtpPassword();

      // 如果服务正在运行且设置发生变化，需要重启服务
      final needRestart = _isServerRunning &&
          (newPort != _port ||
              newUsername != _username ||
              newPassword != _password);

      setState(() {
        _port = newPort;
        _username = newUsername;
        _password = newPassword;
      });

      if (needRestart) {
        await _stopServer();
        await _startServer();
      }
    });
  }

  Future<void> _selectFilesToShare() async {
    try {
      final result = await showDialog<List<SharedFile>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('选择要共享的文件'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('添加文件'),
                      onPressed: () async {
                        final file = await FilePicker.platform.pickFiles();
                        if (file != null) {
                          Navigator.pop(context, [
                            ..._sharedFiles,
                            SharedFile(
                              name: file.files.first.name,
                              path: file.files.first.path!,
                              size: file.files.first.size,
                              timestamp: DateTime.now(),
                              isText: false,
                            ),
                          ]);
                        }
                      },
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.text_fields),
                      label: const Text('添加文本'),
                      onPressed: () async {
                        final controller =
                            TextEditingController(text: _lastTextContent);
                        final text = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('输入要共享的文本'),
                            content: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.8,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withOpacity(0.5),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TextField(
                                      controller: controller,
                                      maxLines: 12,
                                      decoration: const InputDecoration(
                                        hintText: '在此输入文本内容...',
                                        contentPadding: EdgeInsets.all(16),
                                        border: InputBorder.none,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                  if (_lastTextContent != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceVariant
                                            .withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.history, size: 20),
                                          const SizedBox(width: 8),
                                          const Text('上次文本：'),
                                          TextButton(
                                            onPressed: () {
                                              controller.text =
                                                  _lastTextContent!;
                                            },
                                            child: const Text('点击使用'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('取消'),
                              ),
                              FilledButton.icon(
                                icon: const Icon(Icons.check),
                                label: const Text('确定'),
                                onPressed: () =>
                                    Navigator.pop(context, controller.text),
                              ),
                            ],
                          ),
                        );
                        controller.dispose();

                        if (text != null && text.isNotEmpty) {
                          setState(() {
                            _lastTextContent = text;
                          });

                          // 创建临时文本文件
                          final fileName =
                              'text_${DateTime.now().millisecondsSinceEpoch}.txt';
                          final filePath = path.join(_downloadPath, fileName);
                          final file = File(filePath);
                          await file.writeAsString(text.trim());

                          Navigator.pop(context, [
                            ..._sharedFiles,
                            SharedFile(
                              name: fileName,
                              path: filePath,
                              size: text.length,
                              timestamp: DateTime.now(),
                              isText: true,
                              textContent: text.trim(),
                            ),
                          ]);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_sharedFiles.isNotEmpty) ...[
                  const Text('当前共享的内容：'),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _sharedFiles.length,
                      itemBuilder: (context, index) {
                        final file = _sharedFiles[index];
                        return ListTile(
                          leading: Icon(
                            file.isText
                                ? Icons.text_fields
                                : Icons.insert_drive_file,
                          ),
                          title: Text(file.isText ? '文本内容' : file.name),
                          subtitle: Text(file.isText
                              ? '${file.textContent?.substring(0, file.textContent!.length.clamp(0, 50))}${file.textContent!.length > 50 ? '...' : ''}'
                              : _formatFileSize(file.size)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (file.isText)
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    if (file.textContent != null) {
                                      Clipboard.setData(ClipboardData(
                                          text: file.textContent!));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('文本已复制到剪贴板'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  tooltip: '复制文本',
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  Navigator.pop(context, [
                                    ..._sharedFiles.sublist(0, index),
                                    ..._sharedFiles.sublist(index + 1),
                                  ]);
                                },
                                tooltip: '删除',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );

      if (result != null) {
        setState(() {
          _sharedFiles = result;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('选择文件失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startServer() async {
    if (_isServerRunning) return;

    try {
      if (_selectedIP == null) {
        throw Exception('请选择要使用的IP地址');
      }

      _server = await HttpServer.bind(_selectedIP, _port);
      setState(() {
        _isServerRunning = true;
        _serverAddress = 'http://$_selectedIP:$_port';
      });

      _server!.listen((HttpRequest request) async {
        if (request.method == 'GET') {
          if (request.uri.path == '/files') {
            // 返回文件列表
            request.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode(_sharedFiles.map((f) => f.toJson()).toList()))
              ..close();
            return;
          } else if (request.uri.path.startsWith('/download/')) {
            // 处理文件下载
            final fileName = Uri.decodeComponent(
                request.uri.path.substring('/download/'.length));
            final file = _sharedFiles.firstWhere((f) => f.name == fileName);
            final fileBytes = await File(file.path).readAsBytes();

            request.response
              ..headers.contentType = ContentType.binary
              ..headers.add(
                  'Content-Disposition', 'attachment; filename="$fileName"')
              ..add(fileBytes)
              ..close();

            setState(() {
              _transferRecords.insert(
                  0,
                  TransferRecord(
                    fileName: fileName,
                    size: fileBytes.length,
                    progress: 1.0,
                    timestamp: DateTime.now(),
                    status: 'completed',
                  ));
            });
            return;
          }

          // 返回上传/下载页面
          request.response
            ..headers.contentType = ContentType.html
            ..write('''
<!DOCTYPE html>
<html>
<head>
    <title>WeTools文件共享</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
    <style>
        body { 
            font-family: Arial, sans-serif; 
            max-width: 800px; 
            margin: 0 auto; 
            padding: 20px;
            line-height: 1.6;
        }
        .section { 
            border: 2px dashed #ccc; 
            padding: 20px; 
            margin: 20px 0; 
            text-align: center;
            border-radius: 8px;
        }
        .btn { 
            background: #4CAF50; 
            color: white; 
            padding: 10px 20px; 
            border: none; 
            cursor: pointer; 
            margin: 5px; 
            border-radius: 4px;
            font-size: 14px;
            transition: all 0.3s;
        }
        .btn:hover { 
            opacity: 0.9;
            transform: translateY(-1px);
        }
        .btn:active {
            transform: translateY(1px);
        }
        .file-input { 
            margin: 20px 0;
            width: 100%;
            max-width: 300px;
        }
        .progress { 
            width: 100%; 
            height: 20px; 
            background: #f0f0f0; 
            display: none;
            border-radius: 10px;
            overflow: hidden;
            margin: 10px 0;
        }
        .progress-bar { 
            width: 0%; 
            height: 100%; 
            background: #4CAF50; 
            transition: width 0.3s;
        }
        .file-list { 
            text-align: left;
            margin-top: 20px;
        }
        .file-item { 
            display: flex; 
            padding: 16px; 
            border-bottom: 1px solid #eee;
            align-items: flex-start;
        }
        .file-item:last-child {
            border-bottom: none;
        }
        .material-icons { 
            font-size: 24px;
            margin-right: 12px;
        }
        .text-content {
            margin: 8px 0;
            padding: 12px;
            background: #f5f5f5;
            border-radius: 4px;
            white-space: pre-wrap;
            word-break: break-word;
            font-family: monospace;
            max-height: 200px;
            overflow-y: auto;
            position: relative;
        }
        .copy-success {
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: rgba(0, 0, 0, 0.8);
            color: white;
            padding: 10px 20px;
            border-radius: 4px;
            display: none;
            z-index: 1000;
        }
        @media (max-width: 600px) {
            body {
                padding: 10px;
            }
            .section {
                padding: 15px;
                margin: 10px 0;
            }
            .file-item {
                flex-direction: column;
            }
            .btn {
                width: 100%;
                margin: 5px 0;
            }
            .file-input {
                width: 100%;
            }
        }
        @media (prefers-color-scheme: dark) {
            body { 
                background: #1a1a1a; 
                color: #fff; 
            }
            .section { 
                border-color: #333;
                background: #2d2d2d;
            }
            .text-content {
                background: #333;
                color: #fff;
            }
            .file-item { 
                border-bottom-color: #333;
            }
            .progress {
                background: #333;
            }
        }
    </style>
</head>
<body>
    <div id="copySuccess" class="copy-success">文本已复制到剪贴板！</div>
    <h2>WeTools文件共享</h2>
    
    <div class="section">
        <h3>共享文件列表</h3>
        <div id="fileList" class="file-list">加载中...</div>
    </div>
    
    <div class="section">
        <h3>上传文件</h3>
        <input type="file" id="fileInput" class="file-input" multiple>
        <button onclick="uploadFiles()" class="btn">上传文件</button>
        <div class="progress">
            <div class="progress-bar" id="progressBar"></div>
        </div>
    </div>

    <script>
        // 复制文本功能
        async function copyText(text) {
            try {
                await navigator.clipboard.writeText(text);
                const copySuccess = document.getElementById('copySuccess');
                copySuccess.style.display = 'block';
                setTimeout(() => {
                    copySuccess.style.display = 'none';
                }, 2000);
            } catch (err) {
                // 如果clipboard API不可用，使用传统方法
                const textarea = document.createElement('textarea');
                textarea.value = text;
                textarea.style.position = 'fixed';
                textarea.style.opacity = '0';
                document.body.appendChild(textarea);
                textarea.select();
                try {
                    document.execCommand('copy');
                    const copySuccess = document.getElementById('copySuccess');
                    copySuccess.style.display = 'block';
                    setTimeout(() => {
                        copySuccess.style.display = 'none';
                    }, 2000);
                } catch (err) {
                    alert('复制失败，请手动复制文本。');
                }
                document.body.removeChild(textarea);
            }
        }
        
        // 加载共享文件列表
        async function loadSharedFiles() {
            try {
                const response = await fetch('/files');
                const files = await response.json();
                const fileList = document.getElementById('fileList');
                
                if (files.length === 0) {
                    fileList.innerHTML = '<p>暂无共享文件</p>';
                    return;
                }
                
                fileList.innerHTML = files.map(file => `
                    <div class="file-item">
                        <div style="flex: 1;">
                            <div style="display: flex; align-items: center;">
                                <span>
                                    <i class="material-icons">\${file.isText ? 'text_fields' : 'insert_drive_file'}</i>
                                </span>
                                <span>\${file.name} (\${formatFileSize(file.size)})</span>
                            </div>
                            \${file.isText && file.textContent ? `
                                <div class="text-content">
                                    \${file.textContent}
                                </div>
                                <div>
                                    <button onclick="copyText('\${file.textContent.replace(/'/g, "\\'")}')" class="btn" style="background: #2196F3;">复制文本</button>
                                    <button onclick="downloadFile('\${file.name}')" class="btn">下载为文件</button>
                                </div>
                            ` : `
                                <button onclick="downloadFile('\${file.name}')" class="btn">下载</button>
                            `}
                        </div>
                    </div>
                `).join('');
            } catch (error) {
                console.error('加载文件列表失败:', error);
                fileList.innerHTML = '<p>加载文件列表失败</p>';
            }
        }
        
        // 下载文件
        function downloadFile(fileName) {
            window.location.href = '/download/' + encodeURIComponent(fileName);
        }
        
        // 上传文件
        async function uploadFiles() {
            const files = document.getElementById('fileInput').files;
            if (files.length === 0) return alert('请选择文件');
            
            const progress = document.querySelector('.progress');
            const progressBar = document.getElementById('progressBar');
            progress.style.display = 'block';
            
            for (let file of files) {
                try {
                    const response = await fetch('', {
                        method: 'POST',
                        headers: {
                            'X-File-Name': file.name
                        },
                        body: file
                    });
                    
                    if (!response.ok) throw new Error('上传失败');
                    progressBar.style.width = '100%';
                    alert('文件上传成功！');
                    await loadSharedFiles(); // 刷新文件列表
                } catch (error) {
                    alert('上传失败: ' + error.message);
                }
            }
            
            document.getElementById('fileInput').value = '';
            progress.style.display = 'none';
            progressBar.style.width = '0%';
        }
        
        function formatFileSize(bytes) {
            const units = ['B', 'KB', 'MB', 'GB'];
            let size = bytes;
            let unitIndex = 0;
            while (size >= 1024 && unitIndex < units.length - 1) {
                size /= 1024;
                unitIndex++;
            }
            return `\${size.toFixed(1)} \${units[unitIndex]}`;
        }
        
        // 页面加载时获取文件列表
        loadSharedFiles();
        // 定期刷新文件列表
        setInterval(loadSharedFiles, 5000);
    </script>
</body>
</html>
''')
            ..close();
        } else if (request.method == 'POST') {
          // 处理文件上传
          try {
            final contentLength = request.headers.contentLength;
            final fileName =
                request.headers.value('X-File-Name') ?? 'unknown_file';
            final filePath = path.join(_downloadPath, fileName);

            final file = File(filePath);
            final sink = file.openWrite();

            // 删除可能存在的重复记录
            _transferRecords.removeWhere((record) =>
                record.fileName == fileName && record.status == 'transferring');

            int receivedBytes = 0;
            await for (var chunk in request) {
              sink.add(chunk);
              receivedBytes += chunk.length;

              setState(() {
                // 更新或插入传输记录
                final existingIndex = _transferRecords.indexWhere((record) =>
                    record.fileName == fileName &&
                    record.status == 'transferring');

                final newRecord = TransferRecord(
                  fileName: fileName,
                  size: contentLength ?? 0,
                  progress:
                      contentLength != null ? receivedBytes / contentLength : 0,
                  timestamp: DateTime.now(),
                  status: 'transferring',
                );

                if (existingIndex != -1) {
                  _transferRecords[existingIndex] = newRecord;
                } else {
                  _transferRecords.insert(0, newRecord);
                }
              });
            }

            await sink.close();

            // 添加到共享文件列表
            setState(() {
              _sharedFiles.add(SharedFile(
                name: fileName,
                path: filePath,
                size: file.lengthSync(),
                timestamp: DateTime.now(),
                isText: false,
              ));

              // 更新传输记录状态
              final index = _transferRecords.indexWhere((record) =>
                  record.fileName == fileName &&
                  record.status == 'transferring');
              if (index != -1) {
                _transferRecords[index] = _transferRecords[index].copyWith(
                  status: 'completed',
                  progress: 1.0,
                );
              }
            });

            request.response
              ..statusCode = HttpStatus.ok
              ..write('File uploaded successfully')
              ..close();
          } catch (e) {
            setState(() {
              _transferRecords.insert(
                  0,
                  TransferRecord(
                    fileName:
                        request.headers.value('X-File-Name') ?? 'unknown_file',
                    size: request.headers.contentLength ?? 0,
                    progress: 0,
                    timestamp: DateTime.now(),
                    status: 'failed',
                    error: e.toString(),
                  ));
            });

            request.response
              ..statusCode = HttpStatus.internalServerError
              ..write('Upload failed: $e')
              ..close();
          }
        } else {
          request.response
            ..statusCode = HttpStatus.methodNotAllowed
            ..write('Method not allowed')
            ..close();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件共享服务已启动')),
      );
    } catch (e) {
      setState(() {
        _isServerRunning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('启动服务失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopServer() async {
    if (!_isServerRunning) return;

    try {
      await _server?.close();
      setState(() {
        _isServerRunning = false;
        _serverAddress = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件共享服务已停止')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('停止服务失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearTransferRecords() {
    setState(() {
      _transferRecords.clear();
    });
  }

  void _openDownloadFolder() async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [_downloadPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [_downloadPath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [_downloadPath]);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('打开下载文件夹失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '文件共享',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                '在局域网内快速共享文件',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '服务状态: ${_isServerRunning ? "运行中" : "已停止"}',
                            style: TextStyle(
                              color:
                                  _isServerRunning ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (!_isServerRunning && _availableIPs.isNotEmpty)
                            DropdownButton<String>(
                              value: _selectedIP,
                              hint: const Text('选择IP地址'),
                              items: _availableIPs
                                  .map((ip) => DropdownMenuItem(
                                        value: ip,
                                        child: Text(ip),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedIP = value;
                                });
                              },
                            ),
                          const SizedBox(width: 16),
                          if (_isServerRunning)
                            FilledButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('选择共享文件'),
                              onPressed: _selectFilesToShare,
                            ),
                          const SizedBox(width: 16),
                          FilledButton.icon(
                            icon: Icon(_isServerRunning
                                ? Icons.stop
                                : Icons.play_arrow),
                            label: Text(_isServerRunning ? '停止服务' : '启动服务'),
                            onPressed:
                                _isServerRunning ? _stopServer : _startServer,
                          ),
                        ],
                      ),
                      if (_isServerRunning) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('服务地址: $_serverAddress'),
                                  const SizedBox(height: 8),
                                  const Text('使用说明:'),
                                  const Text('1. 扫描右侧二维码或在浏览器中访问服务地址'),
                                  const Text('2. 选择要下载的共享文件或上传新文件'),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.folder_open),
                                    label: const Text('打开下载文件夹'),
                                    onPressed: _openDownloadFolder,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            QrImageView(
                              data: _serverAddress,
                              version: QrVersions.auto,
                              size: 150.0,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Text(
                        '传输记录',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_transferRecords.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.clear_all),
                          label: const Text('清除记录'),
                          onPressed: _clearTransferRecords,
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _transferRecords.isEmpty
                      ? const Center(
                          child: Text(
                            '暂无传输记录',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _transferRecords.length,
                          itemBuilder: (context, index) {
                            final record = _transferRecords[index];
                            return ListTile(
                              leading: Icon(
                                record.status == 'completed'
                                    ? Icons.check_circle
                                    : record.status == 'failed'
                                        ? Icons.error
                                        : Icons.upload_file,
                                color: record.status == 'completed'
                                    ? Colors.green
                                    : record.status == 'failed'
                                        ? Colors.red
                                        : Colors.blue,
                              ),
                              title: Text(record.fileName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (record.status == 'transferring')
                                    LinearProgressIndicator(
                                      value: record.progress,
                                    ),
                                  Text(
                                    '${_formatFileSize(record.size)} • ${_formatTimestamp(record.timestamp)}',
                                  ),
                                  if (record.error != null)
                                    Text(
                                      record.error!,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _stopServer();
    super.dispose();
  }
}

class TransferRecord {
  final String fileName;
  final int size;
  final double progress;
  final DateTime timestamp;
  final String status; // 'transferring', 'completed', 'failed'
  final String? error;

  TransferRecord({
    required this.fileName,
    required this.size,
    required this.progress,
    required this.timestamp,
    required this.status,
    this.error,
  });

  TransferRecord copyWith({
    String? fileName,
    int? size,
    double? progress,
    DateTime? timestamp,
    String? status,
    String? error,
  }) {
    return TransferRecord(
      fileName: fileName ?? this.fileName,
      size: size ?? this.size,
      progress: progress ?? this.progress,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

class SharedFile {
  final String name;
  final String path;
  final int size;
  final DateTime timestamp;
  final bool isText;
  final String? textContent;

  const SharedFile({
    required this.name,
    required this.path,
    required this.size,
    required this.timestamp,
    this.isText = false,
    this.textContent,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'size': size,
      'timestamp': timestamp.toIso8601String(),
      'isText': isText,
      'textContent': textContent,
    };
  }
}
