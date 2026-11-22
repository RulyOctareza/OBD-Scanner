import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/router.dart';
import 'core/theme/app_theme.dart';

/// App startup, shared with the dev benchmark (lib/dev/bench) so a benchmark
/// measures the startup the app really runs.
Future<void> runAutoCare({
  List<Override> overrides = const [],
  void Function(ProviderContainer container)? onContainer,
}) async {
  // Nothing is awaited before runApp: the first frame is not delayed.
  WidgetsFlutterBinding.ensureInitialized();
  // Read lazily, only when the licenses page opens.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['Inter'],
      await rootBundle.loadString('assets/fonts/Inter-OFL.txt'),
    );
  });
  final container = ProviderContainer(overrides: overrides);
  onContainer?.call(container);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AutoCareApp(),
    ),
  );
}

class AutoCareApp extends ConsumerWidget {
  const AutoCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'AutoCare',
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
