import 'package:flutter/material.dart';

import 'status.dart';
import 'tokens.dart';

/// A small pill with a status icon and label, e.g. "Waspada" or "Hangat".
/// Not interactive.
class StatusChip extends StatelessWidget {
  const StatusChip(this.level, {super.key, this.label});

  final StatusLevel level;

  /// Text instead of the level's own label.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = AppStatusColors.of(context);
    final fg = colors.foreground(level);
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(color: fg);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.container(level),
        borderRadius: AppRadius.chipBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(level.icon, size: 16, color: fg),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label ?? level.label,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A status icon in a tinted circle, for list rows and check items.
/// A neutral label in the shape of [StatusChip], for a fact that is not a
/// status (a trouble code's system), so the two line up in one row.
class InfoChip extends StatelessWidget {
  const InfoChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context)
        .textTheme
        .labelMedium
        ?.copyWith(color: scheme.onSurfaceVariant);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.chipBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // As tall as StatusChip's icon, so both chips share one height.
            const SizedBox(height: 16),
            Flexible(child: Text(label, style: style)),
          ],
        ),
      ),
    );
  }
}

class StatusIcon extends StatelessWidget {
  const StatusIcon(this.level, {super.key, this.size = 40});

  final StatusLevel level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppStatusColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.container(level),
        shape: BoxShape.circle,
      ),
      child: Icon(level.icon, size: size * 0.55, color: colors.foreground(level)),
    );
  }
}
