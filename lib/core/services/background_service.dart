import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native foreground service (android/.../ObdLinkService.kt) that keeps the
/// OBD session alive with the screen off. It runs only between
/// [startBackgroundMonitoring] and [stopBackgroundMonitoring]: nothing starts
/// at app launch, on boot or after an update, and no second Flutter engine
/// is involved.
const MethodChannel _channel = MethodChannel('autocare/obd_link_service');

bool get _unsupported =>
    kIsWeb ||
    !Platform.isAndroid ||
    Platform.environment.containsKey('FLUTTER_TEST');

/// Starts the foreground service when an OBD session is active.
Future<void> startBackgroundMonitoring() async {
  if (_unsupported) return;
  try {
    await _channel.invokeMethod<bool>('start', {
      'title': 'AutoCare',
      'text': 'Connected to vehicle',
    });
  } catch (e) {
    debugPrint('Failed to start background service: $e');
  }
}

/// Stops the foreground service when disconnected / idle.
Future<void> stopBackgroundMonitoring() async {
  if (_unsupported) return;
  try {
    await _channel.invokeMethod<void>('stop');
  } catch (e) {
    debugPrint('Failed to stop background service: $e');
  }
}
