import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClipboardUtil {
  static final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showSnackBar(
    String message, {
    Duration? duration,
    SnackBarAction? action,
    SnackBarBehavior? behavior,
    Color? backgroundColor,
    EdgeInsets? margin,
  }) {
    rootScaffoldMessengerKey.currentState?.clearSnackBars();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            message,
            style: const TextStyle(height: 1.5),
          ),
        ),
        duration: duration ?? const Duration(seconds: 2),
        action: action,
        behavior: behavior ?? SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        margin: margin ?? const EdgeInsets.all(8),
      ),
    );
  }

  static void copyToClipboard(String text, BuildContext context) {
    // 使用 async 方式复制，避免键盘事件冲突
    Future<void> copy() async {
      await Clipboard.setData(ClipboardData(text: text));
    }

    copy().then((_) {
      showSnackBar(
        '已复制到剪贴板',
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 80,
          right: 200,
          left: 200,
        ),
        action: SnackBarAction(
          label: '关闭',
          onPressed: () {
            rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
          },
        ),
      );
    });
  }
}
