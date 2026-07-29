import 'package:flutter/material.dart';

enum VeloraButtonVariant { primary, secondary, outline, ghost }

class VeloraButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final VeloraButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  const VeloraButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = VeloraButtonVariant.primary,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Color bgColor;
    Color fgColor;
    BorderSide border;

    switch (variant) {
      case VeloraButtonVariant.primary:
        bgColor = theme.colorScheme.onSurface;
        fgColor = theme.scaffoldBackgroundColor;
        border = BorderSide.none;
        break;
      case VeloraButtonVariant.secondary:
        bgColor = theme.colorScheme.surfaceContainerHighest;
        fgColor = theme.colorScheme.onSurface;
        border = BorderSide.none;
        break;
      case VeloraButtonVariant.outline:
        bgColor = Colors.transparent;
        fgColor = theme.colorScheme.onSurface;
        border = BorderSide(color: theme.dividerColor);
        break;
      case VeloraButtonVariant.ghost:
        bgColor = Colors.transparent;
        fgColor = theme.colorScheme.secondary;
        border = BorderSide.none;
        break;
    }

    return Material(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: border,
      ),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fgColor),
                ),
                const SizedBox(width: 8),
              ] else if (icon != null) ...[
                Icon(icon, size: 18, color: fgColor),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: theme.textTheme.labelLarge?.copyWith(color: fgColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}