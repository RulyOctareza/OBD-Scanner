import 'package:flutter/material.dart';

import 'fit_text.dart';
import 'tokens.dart';

/// One row of a settings group: icon, title, optional subtitle and value.
/// Tappable rows end with a chevron.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Current value, shown on the right ("161.420 km"); under the title when
  /// the system text is enlarged, where a value on the right leaves the title
  /// and subtitle a few letters per line.
  final String? value;
  final VoidCallback? onTap;

  /// Replaces value and chevron.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final valueBelow = value != null && isTextEnlarged(context);
    return ListTile(
      leading: Icon(icon),
      minLeadingWidth: 24,
      title: WordFitText(title),
      subtitle: valueBelow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LineFitText(
                  value!,
                  style: text.bodyLarge?.copyWith(color: scheme.onSurface),
                ),
                if (subtitle != null) WordFitText(subtitle!),
              ],
            )
          : subtitle == null
              ? null
              : WordFitText(subtitle!),
      onTap: onTap,
      trailing: trailing ??
          (value == null && onTap == null
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (value != null && !valueBelow)
                      Text(value!, style: text.bodyMedium),
                    if (onTap != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant),
                    ],
                  ],
                )),
    );
  }
}

/// A settings row with a switch. The title never changes with the value; the
/// switch shows the state.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: WordFitText(title),
      subtitle: subtitle == null ? null : WordFitText(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Rows grouped on one card surface, separated by dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}
