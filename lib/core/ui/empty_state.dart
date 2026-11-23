import 'package:flutter/material.dart';

import 'tokens.dart';

/// What a screen or section shows when it has nothing yet: why, and the one
/// thing to do about it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;

  /// Usually one button.
  final Widget? action;

  /// Smaller icon and spacing, for use inside a card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconBox = compact ? 48.0 : 64.0;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: compact ? AppSpacing.lg : AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconBox,
            height: iconBox,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: iconBox * 0.5, color: scheme.onSurfaceVariant),
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
