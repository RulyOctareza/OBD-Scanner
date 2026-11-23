import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads the app's bundled fonts (Inter, Material Icons) so text in widget
/// tests has real widths; the default test font draws every glyph 1 em wide,
/// which makes labels look far longer than on a phone.
Future<void> loadAppFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final family in manifest) {
    final loader = FontLoader(family['family'] as String);
    for (final font in family['fonts'] as List) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  // Older screens ask for the platform 'monospace' family; Inter stands in.
  final mono = FontLoader('monospace')
    ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'));
  await mono.load();
}
