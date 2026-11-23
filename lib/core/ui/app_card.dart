import 'package:flutter/material.dart';

import 'tokens.dart';

/// The one card of the app: a tonal surface with the card radius. Tappable
/// when [onTap] is set, announced as a button then.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Surface colour; defaults to `surfaceContainer`.
  final Color? color;

  /// Optional 1 dp outline, for cards that carry a status.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color ?? scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor!),
      ),
      clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
      child: onTap == null
          ? content
          : Semantics(
              button: true,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}

/// Title above a group of content, with an optional text action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.xs,
      AppSpacing.xl,
      0,
      AppSpacing.sm,
    ),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: text.titleMedium),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
