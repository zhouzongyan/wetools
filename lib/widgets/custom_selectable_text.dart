import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/clipboard_util.dart';

class CustomSelectableText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const CustomSelectableText(
    this.text, {
    super.key,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (_) {}, // 拦截所有键盘事件
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.text,
            child: Text(
              text,
              style: style ??
                  const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 14,
                  ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => ClipboardUtil.copyToClipboard(text, context),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('复制'),
          ),
        ],
      ),
    );
  }
}
