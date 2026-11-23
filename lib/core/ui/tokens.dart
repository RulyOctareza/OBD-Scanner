import 'package:flutter/widgets.dart';

/// Spacing steps (dp). Layouts use only these values so screens line up.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal inset of screen content from the display edge.
  static const double screen = 16;
}

/// Corner radii by role: chips and inputs, tiles, cards, sheets and dialogs.
abstract final class AppRadius {
  static const double chip = 8;
  static const double tile = 12;
  static const double card = 16;
  static const double sheet = 24;

  static const BorderRadius chipBorder = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius tileBorder = BorderRadius.all(Radius.circular(tile));
  static const BorderRadius cardBorder = BorderRadius.all(Radius.circular(card));
  static const BorderRadius sheetBorder =
      BorderRadius.vertical(top: Radius.circular(sheet));
}

/// Minimum sizes that keep controls usable in a moving car.
abstract final class AppSizes {
  /// Smallest touch target for any control.
  static const double minTouch = 48;

  /// Height of primary and secondary buttons.
  static const double button = 48;
}
