import 'package:flutter/material.dart';

class WindowsTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final InputDecoration? decoration;
  final bool readOnly;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;

  const WindowsTextField({
    super.key,
    this.controller,
    this.hintText,
    this.maxLines,
    this.keyboardType,
    this.textInputAction,
    this.decoration,
    this.readOnly = false,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      decoration: decoration ??
          InputDecoration(
            border: const OutlineInputBorder(),
            hintText: hintText,
          ),
      readOnly: readOnly,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamilyFallback: const ['SourceHanSansSC', 'JetBrainsMono'],
          ),
    );
  }
}
