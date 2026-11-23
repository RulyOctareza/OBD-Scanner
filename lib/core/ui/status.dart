import 'package:flutter/material.dart';

/// How a value or check stands. One set for every screen, so the same reading
/// never looks normal in one place and critical in another.
enum StatusLevel {
  ok('Normal', Icons.check_circle_rounded),
  waspada('Waspada', Icons.error_rounded),
  kritis('Kritis', Icons.warning_rounded),

  /// Nothing measured yet (not connected, not asked, not scanned).
  noData('Belum ada data', Icons.remove_circle_outline_rounded),

  /// Asked, but this car does not report it.
  unsupported('Tidak didukung', Icons.block_rounded);

  const StatusLevel(this.label, this.icon);

  final String label;
  final IconData icon;

  /// True for levels that mean something needs the driver's attention.
  bool get isProblem => this == waspada || this == kritis;
}

/// Raw colours of the dark theme. Widgets read colours through the theme
/// (`ColorScheme`, [AppStatusColors]), never from here directly.
abstract final class AppPalette {
  static const Color background = Color(0xFF0F1115);
  static const Color surfaceLow = Color(0xFF14171C);
  static const Color surface = Color(0xFF181C22);
  static const Color surfaceHigh = Color(0xFF1F242C);
  static const Color surfaceHighest = Color(0xFF272D36);

  static const Color onSurface = Color(0xFFE8EAED);
  static const Color onSurfaceVariant = Color(0xFFA3AAB4);
  static const Color outline = Color(0xFF7A828E);
  static const Color outlineVariant = Color(0xFF2E343D);

  static const Color primary = Color(0xFF5A9BFF);
  static const Color onPrimary = Color(0xFF031735);
  static const Color primaryContainer = Color(0xFF17345F);
  static const Color onPrimaryContainer = Color(0xFFD6E4FF);

  static const Color secondary = Color(0xFFA9B6C8);
  static const Color onSecondary = Color(0xFF142030);
  static const Color secondaryContainer = Color(0xFF26303D);
  static const Color onSecondaryContainer = Color(0xFFD9E3F0);

  static const Color ok = Color(0xFF3DD68C);
  static const Color okContainer = Color(0xFF12291E);
  static const Color waspada = Color(0xFFF5B544);
  static const Color waspadaContainer = Color(0xFF33260F);
  static const Color kritis = Color(0xFFFF6B6B);
  static const Color onKritis = Color(0xFF2D0707);
  static const Color kritisContainer = Color(0xFF3A1717);
  static const Color onKritisContainer = Color(0xFFFFDAD6);
  static const Color noData = Color(0xFF8F97A3);
  static const Color noDataContainer = Color(0xFF222831);

  static const Color inverseSurface = Color(0xFFE8EAED);
  static const Color onInverseSurface = Color(0xFF1A1D22);
  static const Color inversePrimary = Color(0xFF1F5BC6);
}

/// Status colours as a theme extension: `AppStatusColors.of(context)`.
/// Foregrounds keep at least 4.5:1 contrast on every surface and on their own
/// container (checked in test/ui/theme_test.dart).
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.ok,
    required this.okContainer,
    required this.waspada,
    required this.waspadaContainer,
    required this.kritis,
    required this.kritisContainer,
    required this.noData,
    required this.noDataContainer,
  });

  static const AppStatusColors dark = AppStatusColors(
    ok: AppPalette.ok,
    okContainer: AppPalette.okContainer,
    waspada: AppPalette.waspada,
    waspadaContainer: AppPalette.waspadaContainer,
    kritis: AppPalette.kritis,
    kritisContainer: AppPalette.kritisContainer,
    noData: AppPalette.noData,
    noDataContainer: AppPalette.noDataContainer,
  );

  final Color ok;
  final Color okContainer;
  final Color waspada;
  final Color waspadaContainer;
  final Color kritis;
  final Color kritisContainer;
  final Color noData;
  final Color noDataContainer;

  static AppStatusColors of(BuildContext context) =>
      Theme.of(context).extension<AppStatusColors>() ?? dark;

  Color foreground(StatusLevel level) => switch (level) {
        StatusLevel.ok => ok,
        StatusLevel.waspada => waspada,
        StatusLevel.kritis => kritis,
        StatusLevel.noData || StatusLevel.unsupported => noData,
      };

  Color container(StatusLevel level) => switch (level) {
        StatusLevel.ok => okContainer,
        StatusLevel.waspada => waspadaContainer,
        StatusLevel.kritis => kritisContainer,
        StatusLevel.noData || StatusLevel.unsupported => noDataContainer,
      };

  @override
  AppStatusColors copyWith({
    Color? ok,
    Color? okContainer,
    Color? waspada,
    Color? waspadaContainer,
    Color? kritis,
    Color? kritisContainer,
    Color? noData,
    Color? noDataContainer,
  }) {
    return AppStatusColors(
      ok: ok ?? this.ok,
      okContainer: okContainer ?? this.okContainer,
      waspada: waspada ?? this.waspada,
      waspadaContainer: waspadaContainer ?? this.waspadaContainer,
      kritis: kritis ?? this.kritis,
      kritisContainer: kritisContainer ?? this.kritisContainer,
      noData: noData ?? this.noData,
      noDataContainer: noDataContainer ?? this.noDataContainer,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      ok: Color.lerp(ok, other.ok, t)!,
      okContainer: Color.lerp(okContainer, other.okContainer, t)!,
      waspada: Color.lerp(waspada, other.waspada, t)!,
      waspadaContainer: Color.lerp(waspadaContainer, other.waspadaContainer, t)!,
      kritis: Color.lerp(kritis, other.kritis, t)!,
      kritisContainer: Color.lerp(kritisContainer, other.kritisContainer, t)!,
      noData: Color.lerp(noData, other.noData, t)!,
      noDataContainer: Color.lerp(noDataContainer, other.noDataContainer, t)!,
    );
  }
}
