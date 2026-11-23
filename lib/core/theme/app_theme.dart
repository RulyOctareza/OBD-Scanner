import 'package:flutter/material.dart';

import '../ui/status.dart';
import '../ui/tokens.dart';

/// Older colour names, mapped onto the redesign palette while screens move to
/// `Theme.of(context).colorScheme` and [AppStatusColors]. New code reads the
/// theme instead.
class AppColors {
  static const Color background = AppPalette.background;
  static const Color surface = AppPalette.surface;
  static const Color card = AppPalette.surfaceHigh;
  static const Color primary = AppPalette.primary;
  static const Color success = AppPalette.ok;
  static const Color warning = AppPalette.waspada;
  static const Color danger = AppPalette.kritis;

  static const Color textPrimary = AppPalette.onSurface;
  static const Color textSecondary = AppPalette.onSurfaceVariant;

  static const Color progressBackground = AppPalette.surfaceHighest;
  static const Color dragHandle = AppPalette.outline;
  static const Color timelineTrack = AppPalette.outlineVariant;
}

class AppTheme {
  /// Built once: ThemeData is large, and the app has a single theme.
  static final ThemeData darkTheme = _buildDark();

  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.primary,
    onPrimary: AppPalette.onPrimary,
    primaryContainer: AppPalette.primaryContainer,
    onPrimaryContainer: AppPalette.onPrimaryContainer,
    secondary: AppPalette.secondary,
    onSecondary: AppPalette.onSecondary,
    secondaryContainer: AppPalette.secondaryContainer,
    onSecondaryContainer: AppPalette.onSecondaryContainer,
    // One accent only: the tertiary role repeats the neutral secondary.
    tertiary: AppPalette.secondary,
    onTertiary: AppPalette.onSecondary,
    tertiaryContainer: AppPalette.secondaryContainer,
    onTertiaryContainer: AppPalette.onSecondaryContainer,
    error: AppPalette.kritis,
    onError: AppPalette.onKritis,
    errorContainer: AppPalette.kritisContainer,
    onErrorContainer: AppPalette.onKritisContainer,
    surface: AppPalette.background,
    onSurface: AppPalette.onSurface,
    onSurfaceVariant: AppPalette.onSurfaceVariant,
    surfaceDim: AppPalette.background,
    surfaceBright: AppPalette.surfaceHighest,
    surfaceContainerLowest: Color(0xFF0B0D10),
    surfaceContainerLow: AppPalette.surfaceLow,
    surfaceContainer: AppPalette.surface,
    surfaceContainerHigh: AppPalette.surfaceHigh,
    surfaceContainerHighest: AppPalette.surfaceHighest,
    outline: AppPalette.outline,
    outlineVariant: AppPalette.outlineVariant,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppPalette.inverseSurface,
    onInverseSurface: AppPalette.onInverseSurface,
    inversePrimary: AppPalette.inversePrimary,
    // No tint: surfaces keep their exact tone at any elevation.
    surfaceTint: Colors.transparent,
  );

  static TextTheme _textTheme(ColorScheme scheme) {
    // Inter is bundled (pubspec fonts:), so text renders in it from the
    // first frame and nothing is fetched at runtime.
    final base = ThemeData(brightness: Brightness.dark)
        .textTheme
        .apply(fontFamily: 'Inter');
    TextStyle? role(TextStyle? style, double size, double height,
        FontWeight weight, Color color) {
      return style?.copyWith(
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        letterSpacing: 0,
        color: color,
      );
    }

    final on = scheme.onSurface;
    final onVariant = scheme.onSurfaceVariant;
    // No role is smaller than 12 sp: labels are read in a moving car.
    return base.copyWith(
      displayLarge: role(base.displayLarge, 57, 64, FontWeight.w600, on),
      displayMedium: role(base.displayMedium, 45, 52, FontWeight.w600, on),
      displaySmall: role(base.displaySmall, 36, 44, FontWeight.w600, on),
      headlineLarge: role(base.headlineLarge, 32, 40, FontWeight.w600, on),
      headlineMedium: role(base.headlineMedium, 28, 36, FontWeight.w600, on),
      headlineSmall: role(base.headlineSmall, 24, 32, FontWeight.w600, on),
      titleLarge: role(base.titleLarge, 20, 28, FontWeight.w600, on),
      titleMedium: role(base.titleMedium, 16, 24, FontWeight.w600, on),
      titleSmall: role(base.titleSmall, 14, 20, FontWeight.w600, on),
      bodyLarge: role(base.bodyLarge, 16, 24, FontWeight.w400, on),
      // Secondary text by default, as before the redesign.
      bodyMedium: role(base.bodyMedium, 14, 20, FontWeight.w400, onVariant),
      bodySmall: role(base.bodySmall, 12, 16, FontWeight.w400, onVariant),
      labelLarge: role(base.labelLarge, 14, 20, FontWeight.w600, on),
      labelMedium: role(base.labelMedium, 12, 16, FontWeight.w600, on),
      labelSmall: role(base.labelSmall, 12, 16, FontWeight.w500, onVariant),
    );
  }

  static ThemeData _buildDark() {
    const scheme = colorScheme;
    final text = _textTheme(scheme);
    const buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.tileBorder);
    const buttonSize = Size(64, AppSizes.button);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      textTheme: text,
      fontFamily: 'Inter',
      // InkSparkle compiles a shader on first tap, which stutters on the
      // Adreno 506 with Skia; the classic ripple does not.
      splashFactory: InkRipple.splashFactory,
      extensions: const [AppStatusColors.dark],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: const CardThemeData(
        color: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSizes.minTouch, AppSizes.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: buttonShape,
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          elevation: 0,
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurface,
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        extendedTextStyle: text.labelLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.tileBorder,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.tileBorder,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.tileBorder,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.tileBorder,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.tileBorder,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: scheme.primary),
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerLow,
        labelStyle: text.labelLarge,
        secondaryLabelStyle:
            text.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.chipBorder),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        checkmarkColor: scheme.onPrimaryContainer,
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTouch),
          backgroundColor: scheme.surfaceContainer,
          foregroundColor: scheme.onSurfaceVariant,
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: text.labelLarge,
          shape: buttonShape,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetBorder),
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        dragHandleSize: const Size(32, 4),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sheet)),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.tileBorder),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          return states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.surfaceContainerHighest.withValues(alpha: 0.5);
          }
          return states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? scheme.primary : null),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          );
        }),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodyMedium,
        leadingAndTrailingTextStyle: text.bodyMedium,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppRadius.chipBorder,
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.tileBorder),
        textStyle: text.bodyLarge,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.error,
        textColor: scheme.onError,
        textStyle: text.labelSmall,
      ),
    );
  }

  static TextStyle numberStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color color = AppColors.textPrimary,
  }) {
    // Tabular figures keep every digit the same width, so a changing value
    // does not shift its neighbours.
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
