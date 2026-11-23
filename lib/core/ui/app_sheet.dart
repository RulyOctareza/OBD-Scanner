import 'package:flutter/material.dart';

import 'tokens.dart';

/// Opens a bottom sheet on the root navigator, so it covers the navigation
/// bar instead of sliding under it (a sheet opened on a tab's own navigator
/// stays inside the tab).
///
/// Every sheet's bottom inset is handled here, once: the modal route's safe
/// area leaves the bottom open so the sheet colour reaches the screen edge,
/// and the content is lifted above the system navigation bar, or above the
/// keyboard when it is taller.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final bottom = media.viewInsets.bottom > media.viewPadding.bottom
          ? media.viewInsets.bottom
          : media.viewPadding.bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: builder(sheetContext),
      );
    },
  );
}

/// Content layout of a sheet: title, optional subtitle, scrollable body and
/// actions pinned at the bottom. The drag handle comes from the theme.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Buttons in reading order; the last one is the primary action.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Insets come from showAppSheet; the body scrolls when the content is
    // taller than the room the sheet gets.
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: text.titleLarge),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: text.bodyMedium),
                ],
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: child,
            ),
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.md),
                    Expanded(child: actions[i]),
                  ],
                ],
              ),
            )
          else
            const SizedBox(height: AppSpacing.lg),
        ],
    );
  }
}

/// Asks before an action; resolves to true only when confirmed. [destructive]
/// paints the confirm button in the error colour.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Batal',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

/// Tells something that needs no decision, with one button to close.
Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  String closeLabel = 'Tutup',
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(closeLabel),
        ),
      ],
    ),
  );
}
