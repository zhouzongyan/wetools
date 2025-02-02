import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// 这只是示例代码，实际上我们需要使用设计工具创建图标
void generateIcon() {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = Size(1024, 1024);

  final paint = Paint()
    ..color = Colors.deepPurple
    ..style = PaintingStyle.fill;

  // 绘制图标
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

  // 保存为文件
  final picture = recorder.endRecording();
  picture.toImage(size.width.toInt(), size.height.toInt()).then((image) {
    // 将图像保存为 PNG
    image.toByteData(format: ui.ImageByteFormat.png).then((byteData) {
      final buffer = byteData!.buffer;
      File('assets/icon/app_icon.png').writeAsBytesSync(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    });
  });
}
