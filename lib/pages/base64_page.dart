import 'package:flutter/material.dart';
import 'package:wetools/widgets/windows_text_field.dart';
import 'dart:convert';
import '../utils/clipboard_util.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

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
  Uint8List? _decodedImage;
  Uint8List? _imageToEncode;
  final ImagePicker _picker = ImagePicker();

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

      // 尝试将解码后的数据解析为图片
      try {
        setState(() {
          _decodedImage = bytes;
          _decodeResult = ''; // 清空文本结果
        });
      } catch (e) {
        // 如果不是图片，则尝试解码为文本
        final decoded = utf8.decode(bytes);
        setState(() {
          _decodedImage = null;
          _decodeResult = decoded;
        });
      }
    } catch (e) {
      setState(() {
        _decodedImage = null;
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

  Future<void> _downloadImage() async {
    if (_decodedImage == null) return;

    try {
      final now = DateTime.now();
      final fileName = 'decoded_image_${now.millisecondsSinceEpoch}.png';

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
      await file.writeAsBytes(_decodedImage!);

      if (context.mounted) {
        ClipboardUtil.showSnackBar(
          '图片保存成功！\n保存路径: $savePath',
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
          '保存图片失败，请重试',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 80,
            right: 200,
            left: 200,
          ),
          action: SnackBarAction(
            label: '确定',
            textColor: Colors.white,
            onPressed: () {
              ClipboardUtil.rootScaffoldMessengerKey.currentState
                  ?.hideCurrentSnackBar();
            },
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    // 立即显示操作提示
    if (context.mounted) {
      ClipboardUtil.showSnackBar(
        '选择图片中...',
        duration: const Duration(seconds: 10),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 80,
          right: 200,
          left: 200,
        ),
      );
    }

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        // 更新提示为转码中
        if (context.mounted) {
          ClipboardUtil.rootScaffoldMessengerKey.currentState
              ?.hideCurrentSnackBar();
          ClipboardUtil.showSnackBar(
            '图片转码中...',
            duration: const Duration(seconds: 10),
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 80,
              right: 200,
              left: 200,
            ),
          );
        }

        final bytes = await image.readAsBytes();
        setState(() {
          _imageToEncode = bytes;
          _encodeImageToBase64(bytes);
        });
      } else {
        // 用户取消选择时关闭提示
        if (context.mounted) {
          ClipboardUtil.rootScaffoldMessengerKey.currentState
              ?.hideCurrentSnackBar();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ClipboardUtil.rootScaffoldMessengerKey.currentState
            ?.hideCurrentSnackBar();
        ClipboardUtil.showSnackBar(
          '选择图片失败',
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 80,
            right: 200,
            left: 200,
          ),
        );
      }
    }
  }

  Future<void> _pasteImage() async {
    // 显示确认对话框
    if (!context.mounted) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认'),
          content: const Text('是否从剪贴板粘贴并转换图片？'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('确定'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    // 显示操作提示
    if (context.mounted) {
      ClipboardUtil.showSnackBar(
        '获取剪贴板图片中...',
        duration: const Duration(seconds: 10),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 80,
          right: 200,
          left: 200,
        ),
      );
    }

    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null) {
        setState(() {
          _imageToEncode = imageBytes;
          _encodeImageToBase64(imageBytes);
        });
      } else {
        if (context.mounted) {
          ClipboardUtil.rootScaffoldMessengerKey.currentState
              ?.hideCurrentSnackBar();
          ClipboardUtil.showSnackBar(
            '剪贴板中没有图片',
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 80,
              right: 200,
              left: 200,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ClipboardUtil.rootScaffoldMessengerKey.currentState
            ?.hideCurrentSnackBar();
        ClipboardUtil.showSnackBar(
          '粘贴图片失败',
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

  void _encodeImageToBase64(Uint8List bytes) {
    try {
      // 显示转码中提示
      if (context.mounted) {
        ClipboardUtil.showSnackBar(
          'Base64编码中...',
          duration: const Duration(seconds: 10),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 80,
            right: 200,
            left: 200,
          ),
        );
      }

      final encoded = base64.encode(bytes);
      setState(() {
        _encodeResult = encoded;
      });

      // 编码完成后显示提示
      if (context.mounted) {
        ClipboardUtil.rootScaffoldMessengerKey.currentState
            ?.hideCurrentSnackBar();
        ClipboardUtil.showSnackBar(
          'Base64编码完成',
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 80,
            right: 200,
            left: 200,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _encodeResult = '错误: ${e.toString()}';
      });
      if (context.mounted) {
        ClipboardUtil.showSnackBar(
          'Base64编码失败',
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

  void _clearEncode() {
    setState(() {
      _encodeController.clear();
      _encodeResult = '';
      _imageToEncode = null;
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
                        if (_imageToEncode != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: Colors.grey.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Image.memory(
                                  _imageToEncode!,
                                  height: 200,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: _clearEncode,
                                      child: const Text('移除图片'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        WindowsTextField(
                          controller: _encodeController,
                          hintText: '输入要编码的文本',
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
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
                                Text(
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
                      ElevatedButton(
                        onPressed: _pickImage,
                        child: const Text('选择图片'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _pasteImage,
                        child: const Text('粘贴图片'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _clearEncode,
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
                        if (_decodeResult.isNotEmpty ||
                            _decodedImage != null) ...[
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
                                    if (_decodedImage != null) ...[
                                      IconButton(
                                        icon:
                                            const Icon(Icons.download, size: 20),
                                        onPressed: _downloadImage,
                                        tooltip: '下载图片',
                                      ),
                                    ],
                                    if (_decodeResult.isNotEmpty)
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
                                if (_decodedImage != null) ...[
                                  Center(
                                    child: Image.memory(
                                      _decodedImage!,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Text('无法显示图片');
                                      },
                                    ),
                                  ),
                                ] else
                                  Text(
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
      ),
    );
  }
}
