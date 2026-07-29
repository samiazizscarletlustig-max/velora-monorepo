import 'package:flutter/material.dart';

class VeloraInput extends StatelessWidget {
  final String? hintText;
  final String? labelText;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget? prefixIcon;

  const VeloraInput({
    super.key,
    this.hintText,
    this.labelText,
    this.controller,
    this.obscureText = false,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.secondary),
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: theme.scaffoldBackgroundColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.colorScheme.onSurface),
            ),
          ),
        ),
      ],
    );
  }
}