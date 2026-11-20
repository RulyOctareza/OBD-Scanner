import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

bool get _isFlutterTest =>
    Platform.environment.containsKey('FLUTTER_TEST');

/// Configures the Android foreground service used to keep the OBD session
/// alive while a drive is active. Does **not** auto-start — call
/// [startBackgroundMonitoring] only when connected.
Future<void> initializeService() async {
  if (_isFlutterTest) return;

  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'autocare_foreground',
    'AutoCare Background Service',
    description: 'Keeps OBD monitoring alive while connected.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'autocare_foreground',
      initialNotificationTitle: 'AutoCare',
      initialNotificationContent: 'Connected to vehicle',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.connectedDevice],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

/// Starts the foreground service when an OBD session is active.
Future<void> startBackgroundMonitoring() async {
  if (_isFlutterTest || kIsWeb) return;
  try {
    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (!running) {
      await service.startService();
    }
  } catch (e) {
    debugPrint('Failed to start background service: $e');
  }
}

/// Stops the foreground service when disconnected / idle.
Future<void> stopBackgroundMonitoring() async {
  if (_isFlutterTest || kIsWeb) return;
  try {
    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (running) {
      service.invoke('stopService');
    }
  } catch (e) {
    debugPrint('Failed to stop background service: $e');
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Low-frequency keep-alive; avoid 10s notification churn.
  Timer.periodic(const Duration(seconds: 60), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: 'AutoCare',
          content: 'Monitoring vehicle data',
        );
      }
    }
  });
}
