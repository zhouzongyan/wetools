import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../utils/clipboard_util.dart';
import '../utils/logger_util.dart';

class WatermarkPage extends StatefulWidget {
  const WatermarkPage({Key? key}) : super(key: key);

  @override
  State<WatermarkPage> createState() => _WatermarkPageState();
}

class _WatermarkPageState extends State<WatermarkPage> {
  File? _selectedFile;
  String? _fileType;
  Uint8List? _filePreview;
  bool _isProcessing = false;
  bool _isTextWatermark = true;
  String _watermarkText = '水印文字';
  double _watermarkOpacity = 0.5;
  double _watermarkSize = 30;
  double _watermarkRotation = 45;
  Color _watermarkColor = Colors.red.withOpacity(0.5);
  File? _watermarkImage;
  Uint8List? _watermarkImagePreview;
  double _watermarkImageScale = 0.3;

  final TextEditingController _textController =
      TextEditingController(text: '水印文字');

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {
        _watermarkText = _textController.text;
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String fileType = result.files.single.extension!.toLowerCase();

        setState(() {
          _selectedFile = file;
          _fileType = fileType;
          _isProcessing = true;
        });

        // 生成预览
        if (fileType == 'pdf') {
          // PDF预览 - 只显示第一页
          try {
            final pdfData = await file.readAsBytes();
            // 使用 Printing.raster 方法获取 PDF 栅格化流
            final rasterStream = Printing.raster(
              pdfData,
              pages: [0], // 只渲染第一页
              dpi: 150,
            );

            // 获取流中的第一个元素（第一页）
            final firstPage = await rasterStream.first;
            if (firstPage != null) {
              // 将 PDF 页面转换为 PNG 图像
              final image = await firstPage.toPng();

              setState(() {
                _filePreview = image;
                _isProcessing = false;
              });
            } else {
              throw Exception('PDF 渲染失败');
            }
          } catch (e) {
            LoggerUtil.error('PDF预览错误: $e');
            setState(() {
              _isProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('PDF预览生成失败: $e')),
            );
          }
        } else {
          // 图片预览
          final bytes = await file.readAsBytes();
          setState(() {
            _filePreview = bytes;
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      LoggerUtil.error('文件选择错误: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickWatermarkImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        File file = File(image.path);
        final bytes = await file.readAsBytes();

        setState(() {
          _watermarkImage = file;
          _watermarkImagePreview = bytes;
        });
      }
    } catch (e) {
      LoggerUtil.error('水印图片选择错误: $e');
    }
  }

  Future<void> _applyWatermark() async {
    if (_selectedFile == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      late File outputFile;

      if (_fileType == 'pdf') {
        outputFile = await _applyWatermarkToPdf();
      } else {
        outputFile = await _applyWatermarkToImage();
      }

      // 显示成功对话框
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('处理完成'),
          content: Text('文件已保存至: ${outputFile.path}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ClipboardUtil.copyToClipboard(outputFile.path, context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('路径已复制到剪贴板')),
                );
              },
              child: const Text('复制路径'),
            ),
          ],
        ),
      );
    } catch (e) {
      LoggerUtil.error('添加水印错误: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('处理失败: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<File> _applyWatermarkToImage() async {
    final bytes = await _selectedFile!.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('无法解码图片');
    }

    // 创建一个副本以便绘制水印
    final watermarkedImage =
        img.copyResize(image, width: image.width, height: image.height);

    if (_isTextWatermark) {
      // 文字水印
      _applyTextWatermarkToImage(watermarkedImage);
    } else if (_watermarkImage != null) {
      // 图片水印
      await _applyImageWatermarkToImage(watermarkedImage);
    }

    // 保存处理后的图片
    final directory = await getTemporaryDirectory();
    final outputPath =
        '${directory.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.${_fileType}';
    final outputFile = File(outputPath);

    await outputFile.writeAsBytes(img.encodeJpg(watermarkedImage));
    return outputFile;
  }

  void _applyTextWatermarkToImage(img.Image image) {
    final int r = (_watermarkColor.red * 255).round();
    final int g = (_watermarkColor.green * 255).round();
    final int b = (_watermarkColor.blue * 255).round();
    final int a = (_watermarkColor.alpha * 255 * _watermarkOpacity).round();

    // 计算水印间距
    final int spacingX = (image.width / 3).round();
    final int spacingY = (image.height / 3).round();

    // 在图片上绘制多个水印
    for (int y = 0; y < image.height; y += spacingY) {
      for (int x = 0; x < image.width; x += spacingX) {
        img.drawString(
          image,
          _watermarkText,
          font: img.arial14, // 使用内置的 arial14 字体
          x: x,
          y: y,
          color: img.ColorRgba8(r, g, b, a),
          // 由于 img.drawString 不支持 fontSize 参数，需要使用其他方式调整文字大小
          // 或者使用默认大小
        );
      }
    }
  }

  Future<void> _applyImageWatermarkToImage(img.Image targetImage) async {
    final bytes = await _watermarkImage!.readAsBytes();
    final watermarkImg = img.decodeImage(bytes);

    if (watermarkImg == null) {
      throw Exception('无法解码水印图片');
    }

    // 调整水印图片大小
    final int newWidth = (targetImage.width * _watermarkImageScale).round();
    final int newHeight =
        ((newWidth / watermarkImg.width) * watermarkImg.height).round();
    final resizedWatermark =
        img.copyResize(watermarkImg, width: newWidth, height: newHeight);

    // 计算水印间距
    final int spacingX = (targetImage.width / 2).round();
    final int spacingY = (targetImage.height / 2).round();

    // 在图片上绘制多个水印
    for (int y = 0; y < targetImage.height; y += spacingY) {
      for (int x = 0; x < targetImage.width; x += spacingX) {
        img.compositeImage(
          targetImage,
          resizedWatermark,
          dstX: x,
          dstY: y,
        );
      }
    }
  }

  Future<File> _applyWatermarkToPdf() async {
    final pdfData = await _selectedFile!.readAsBytes();
    final pdf = pw.Document();

    // 用 printing 包渲染每一页
    final pageCount = await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
    ).then((_) => null); // 这里只是为了获取页数，实际不需要

    // 你需要用 raster 获取每一页
    final rasterStream = Printing.raster(
      pdfData,
      dpi: 150,
    );

    int pageIndex = 0;
    await for (final page in rasterStream) {
      final imageBytes = await page.toPng();
      pdf.addPage(
        pw.Page(
          pageFormat:
              PdfPageFormat(page.width.toDouble(), page.height.toDouble()),
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.Image(pw.MemoryImage(imageBytes)),
                _buildPdfWatermark(),
              ],
            );
          },
        ),
      );
      pageIndex++;
    }

    // 保存处理后的PDF
    final directory = await getTemporaryDirectory();
    final outputPath =
        '${directory.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final outputFile = File(outputPath);

    await outputFile.writeAsBytes(await pdf.save());
    return outputFile;
  }

  pw.Widget _buildPdfWatermark() {
    if (_isTextWatermark) {
      // 文字水印
      return pw.Center(
        child: pw.Transform.rotate(
          angle: _watermarkRotation * 3.14159 / 180,
          child: pw.Text(
            _watermarkText,
            style: pw.TextStyle(
              color: PdfColor(
                _watermarkColor.red.toDouble(),
                _watermarkColor.green.toDouble(),
                _watermarkColor.blue.toDouble(),
                _watermarkOpacity * _watermarkColor.alpha,
              ),
              fontSize: _watermarkSize,
            ),
          ),
        ),
      );
    } else if (_watermarkImagePreview != null) {
      // 图片水印
      return pw.Center(
        child: pw.Opacity(
          opacity: _watermarkOpacity,
          child: pw.Image(
            pw.MemoryImage(_watermarkImagePreview!),
            width: 200 * _watermarkImageScale,
            height: 200 * _watermarkImageScale,
          ),
        ),
      );
    }

    return pw.Container();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Platform.isAndroid || Platform.isIOS;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('图片/PDF水印工具'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 文件选择区域
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '第一步：选择文件',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _pickFile,
                        icon: const Icon(Icons.file_upload),
                        label: const Text('选择图片或PDF文件'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isProcessing)
                      const Center(child: CircularProgressIndicator())
                    else if (_filePreview != null)
                      Center(
                        child: Column(
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: isMobile ? screenWidth * 0.8 : 300,
                                maxHeight: 400,
                              ),
                              child: Image.memory(_filePreview!),
                            ),
                            const SizedBox(height: 8),
                            Text('已选择: ${_selectedFile?.path.split('/').last}'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 水印设置区域
            if (_selectedFile != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '第二步：设置水印',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // 水印类型选择
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('文字水印'),
                              value: true,
                              groupValue: _isTextWatermark,
                              onChanged: (value) {
                                setState(() {
                                  _isTextWatermark = value!;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('图片水印'),
                              value: false,
                              groupValue: _isTextWatermark,
                              onChanged: (value) {
                                setState(() {
                                  _isTextWatermark = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 文字水印设置
                      if (_isTextWatermark)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _textController,
                              decoration: const InputDecoration(
                                labelText: '水印文字',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 文字大小
                            Row(
                              children: [
                                const Text('文字大小: '),
                                Expanded(
                                  child: Slider(
                                    value: _watermarkSize,
                                    min: 10,
                                    max: 100,
                                    divisions: 90,
                                    label: _watermarkSize.round().toString(),
                                    onChanged: (value) {
                                      setState(() {
                                        _watermarkSize = value;
                                      });
                                    },
                                  ),
                                ),
                                Text('${_watermarkSize.round()}'),
                              ],
                            ),

                            // 文字旋转
                            Row(
                              children: [
                                const Text('旋转角度: '),
                                Expanded(
                                  child: Slider(
                                    value: _watermarkRotation,
                                    min: 0,
                                    max: 360,
                                    divisions: 36,
                                    label:
                                        _watermarkRotation.round().toString(),
                                    onChanged: (value) {
                                      setState(() {
                                        _watermarkRotation = value;
                                      });
                                    },
                                  ),
                                ),
                                Text('${_watermarkRotation.round()}°'),
                              ],
                            ),

                            // 文字颜色
                            Row(
                              children: [
                                const Text('文字颜色: '),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('选择水印颜色'),
                                        content: SingleChildScrollView(
                                          child: ColorPicker(
                                            pickerColor: _watermarkColor,
                                            onColorChanged: (color) {
                                              setState(() {
                                                _watermarkColor = color
                                                    .withOpacity(_watermarkColor
                                                        .opacity);
                                              });
                                            },
                                            pickerAreaHeightPercent: 0.8,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('确定'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _watermarkColor,
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      // 图片水印设置
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: _pickWatermarkImage,
                                icon: const Icon(Icons.image),
                                label: const Text('选择水印图片'),
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (_watermarkImagePreview != null)
                              Center(
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        isMobile ? screenWidth * 0.5 : 200,
                                    maxHeight: 200,
                                  ),
                                  child: Image.memory(_watermarkImagePreview!),
                                ),
                              ),

                            const SizedBox(height: 16),

                            // 图片大小
                            Row(
                              children: [
                                const Text('图片大小: '),
                                Expanded(
                                  child: Slider(
                                    value: _watermarkImageScale,
                                    min: 0.1,
                                    max: 1.0,
                                    divisions: 9,
                                    label: (_watermarkImageScale * 100)
                                            .round()
                                            .toString() +
                                        '%',
                                    onChanged: (value) {
                                      setState(() {
                                        _watermarkImageScale = value;
                                      });
                                    },
                                  ),
                                ),
                                Text(
                                    '${(_watermarkImageScale * 100).round()}%'),
                              ],
                            ),
                          ],
                        ),

                      const SizedBox(height: 16),

                      // 水印透明度
                      Row(
                        children: [
                          const Text('透明度: '),
                          Expanded(
                            child: Slider(
                              value: _watermarkOpacity,
                              min: 0.1,
                              max: 1.0,
                              divisions: 9,
                              label:
                                  (_watermarkOpacity * 100).round().toString() +
                                      '%',
                              onChanged: (value) {
                                setState(() {
                                  _watermarkOpacity = value;
                                });
                              },
                            ),
                          ),
                          Text('${(_watermarkOpacity * 100).round()}%'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // 应用水印按钮
            if (_selectedFile != null)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ||
                          (_isTextWatermark ? false : _watermarkImage == null)
                      ? null
                      : _applyWatermark,
                  icon: const Icon(Icons.add),
                  label: const Text('应用水印'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
