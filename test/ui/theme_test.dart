import 'package:autocare/core/theme/app_theme.dart';
import 'package:autocare/core/ui/status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final theme = AppTheme.darkTheme;
  final scheme = theme.colorScheme;
  final status = theme.extension<AppStatusColors>()!;

  final surfaces = <String, Color>{
    'surface': scheme.surface,
    'surfaceContainerLow': scheme.surfaceContainerLow,
    'surfaceContainer': scheme.surfaceContainer,
    'surfaceContainerHigh': scheme.surfaceContainerHigh,
    'surfaceContainerHighest': scheme.surfaceContainerHighest,
  };

  test('text colours reach 4.5:1 on every surface', () {
    final texts = <String, Color>{
      'onSurface': scheme.onSurface,
      'onSurfaceVariant': scheme.onSurfaceVariant,
      'primary': scheme.primary,
      'error': scheme.error,
    };
    for (final text in texts.entries) {
      for (final surface in surfaces.entries) {
        expect(contrast(text.value, surface.value), greaterThanOrEqualTo(4.5),
            reason: '${text.key} on ${surface.key}');
      }
    }
  });

  test('status colours reach 4.5:1 on surfaces and on their container', () {
    for (final level in StatusLevel.values) {
      final fg = status.foreground(level);
      for (final surface in surfaces.entries) {
        expect(contrast(fg, surface.value), greaterThanOrEqualTo(4.5),
            reason: '$level on ${surface.key}');
      }
      expect(contrast(fg, status.container(level)), greaterThanOrEqualTo(4.5),
          reason: '$level on its container');
    }
  });

  test('on-colours reach 4.5:1 on their roles', () {
    final pairs = <String, (Color, Color)>{
      'onPrimary/primary': (scheme.onPrimary, scheme.primary),
      'onPrimaryContainer/primaryContainer':
          (scheme.onPrimaryContainer, scheme.primaryContainer),
      'onSecondaryContainer/secondaryContainer':
          (scheme.onSecondaryContainer, scheme.secondaryContainer),
      'onError/error': (scheme.onError, scheme.error),
      'onErrorContainer/errorContainer':
          (scheme.onErrorContainer, scheme.errorContainer),
      'onInverseSurface/inverseSurface':
          (scheme.onInverseSurface, scheme.inverseSurface),
      'inversePrimary/inverseSurface':
          (scheme.inversePrimary, scheme.inverseSurface),
    };
    for (final pair in pairs.entries) {
      expect(contrast(pair.value.$1, pair.value.$2), greaterThanOrEqualTo(4.5),
          reason: pair.key);
    }
  });

  test('no Material default accent leaks into components', () {
    const defaultTeal = Color(0xFF03DAC6);
    expect(scheme.secondary, isNot(defaultTeal));
    expect(scheme.tertiary, scheme.secondary);
    expect(scheme.surfaceTint, Colors.transparent);
  });

  test('no text role is smaller than 12 sp', () {
    final t = theme.textTheme;
    final roles = [
      t.displayLarge, t.displayMedium, t.displaySmall,
      t.headlineLarge, t.headlineMedium, t.headlineSmall,
      t.titleLarge, t.titleMedium, t.titleSmall,
      t.bodyLarge, t.bodyMedium, t.bodySmall,
      t.labelLarge, t.labelMedium, t.labelSmall,
    ];
    for (final role in roles) {
      expect(role!.fontSize, greaterThanOrEqualTo(12));
      expect(role.fontFamily, 'Inter');
    }
  });
}
