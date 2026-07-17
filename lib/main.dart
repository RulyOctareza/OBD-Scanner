import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/database/trip_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/router.dart';
import 'core/services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(
    const ProviderScope(
      child: AutoCareApp(),
    ),
  );
}

class AutoCareApp extends ConsumerWidget {
  const AutoCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize TripManager
    ref.watch(tripManagerProvider);

    return MaterialApp.router(
      title: 'AutoCare',
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
