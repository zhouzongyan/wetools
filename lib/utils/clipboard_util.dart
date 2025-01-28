import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClipboardUtil {
  static void copyToClipboard(String text, BuildContext context) {
    // 使用 async 方式复制，避免键盘事件冲突
    Future<void> copy() async {
      await Clipboard.setData(ClipboardData(text: text));
    }

    copy().then((_) {
      // 移除任何已经显示的 SnackBar
      ScaffoldMessenger.of(context).removeCurrentSnackBar();

      // 显示新的 SnackBar，并设置其位置和行为
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已复制到剪贴板'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 50,
            right: 500,
            left: 500,
          ),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: '关闭',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    });
  }
}
