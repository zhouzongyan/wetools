import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextStyle? textStyle;

  const CustomTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
    this.keyboardType,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.all(12),
      ),
      style: textStyle ??
          const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14,
          ),
      maxLines: maxLines,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      keyboardType: keyboardType ??
          (maxLines == 1 ? TextInputType.text : TextInputType.multiline),
      contextMenuBuilder: (context, editableTextState) {
        return AdaptiveTextSelectionToolbar.editableText(
          editableTextState: editableTextState,
        );
      },
    );
  }
}
