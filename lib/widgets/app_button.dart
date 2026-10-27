import 'package:flutter/material.dart';

enum AppButtonStyle { filled, outlined }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.style = AppButtonStyle.filled,
    this.color,
  });

  const AppButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
  }) : style = AppButtonStyle.outlined;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final AppButtonStyle style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isOutlined = style == AppButtonStyle.outlined;
    final foreground = isOutlined
        ? (color ?? Theme.of(context).colorScheme.onSurface)
        : Colors.white;

    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: isLoading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground),
            )
          : Row(
              key: const ValueKey('content'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );

    final pressHandler = isLoading ? null : onPressed;

    if (isOutlined) {
      return OutlinedButton(
        onPressed: pressHandler,
        style: color == null
            ? null
            : OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color!.withValues(alpha: 0.5), width: 1.4),
              ),
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: pressHandler,
      style: color == null ? null : ElevatedButton.styleFrom(backgroundColor: color),
      child: child,
    );
  }
}
