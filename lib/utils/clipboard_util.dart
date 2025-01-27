import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClipboardUtil {
  static void copyToClipboard(String text, BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar(context);
  }

  static void _showSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('已复制到剪贴板'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        width: 400,
        duration: const Duration(milliseconds: 1500),
        action: SnackBarAction(
          label: '关闭',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
