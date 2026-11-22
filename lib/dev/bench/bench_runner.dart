// Dev-only benchmark scenarios (see lib/dev/bench/bench_main.dart).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bluetooth/obd_service.dart';
import '../../core/navigation/router.dart';
import '../../features/live_data/presentation/dashboard_screen.dart';
import '../../features/live_data/presentation/widgets/gauge_widget.dart';
import '../../features/live_data/presentation/widgets/telemetry_chart_modal.dart';
import '../../features/timeline/presentation/timeline_screen.dart';
import '../fake_elm327.dart';
import 'perf_probe.dart';

/// Log tag the host script (tool/bench/run_bench.sh) collects.
const benchTag = 'AUTOCARE_BENCH';

const _window = Duration(seconds: 20);
const _settle = Duration(seconds: 3);

/// Fixed scenario script. Every scenario settles, then measures one window.
class BenchRunner {
  BenchRunner({
    required this.container,
    required this.adapter,
    required this.probe,
  });

  final ProviderContainer container;
  final FakeElm327Connector adapter;
  final PerfProbe probe;

  /// The app itself logs unhandled errors in a normal run (google_fonts in a
  /// release-like setup), so a failed bench reports itself with its own line.
  Future<void> run(Map<String, Object> startup) async {
    try {
      await _run(startup);
    } catch (e, stack) {
      debugPrint('${benchTag}_FAILED $e\n$stack');
    }
  }

  Future<void> _run(Map<String, Object> startup) async {
    emit({'type': 'startup', ...startup});
    await _waitFor('splash done', () => _path == '/health');
    await Future<void>.delayed(_settle);

    unawaited(
      container.read(obdServiceProvider.notifier).connectToDevice(
            const BluetoothDevice(
              name: 'Bench ELM327',
              address: '00:00:00:00:BE:01',
            ),
          ),
    );
    await _waitFor(
      'link connected',
      () => container.read(obdServiceProvider).status == ObdStatus.connected,
    );
    final linkClock = Stopwatch()..start();
    final answersAtConnect = adapter.answers;

    await _screen('meter_drive', '/dashboard');
    await _screen('sensor_drive', '/live_data');
    await _screen('health_drive', '/health');
    await _chartModal();
    await _tabSwitching();
    await _timelineScroll();
    adapter.profile = FakeEngineProfile.idle;
    await _screen('meter_idle', '/dashboard');

    final seconds = linkClock.elapsedMilliseconds / 1000;
    // Ends with a user disconnect, so the host can check that the foreground
    // service and its wake lock are gone afterwards.
    container.read(obdServiceProvider.notifier).disconnect();
    await Future<void>.delayed(const Duration(seconds: 2));
    emit({
      'type': 'done',
      'answers_per_s':
          ((adapter.answers - answersAtConnect) / seconds * 100).round() / 100,
    });
    debugPrint('${benchTag}_DONE');
  }

  /// Results also go to a file, because a long run can push early lines out
  /// of the logcat buffer.
  static File? resultsFile;

  static void emit(Map<String, Object> data) {
    final line = jsonEncode(data);
    debugPrint('$benchTag $line');
    resultsFile?.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  }

  String get _path => goRouter.routerDelegate.currentConfiguration.uri.path;

  Future<void> _waitFor(String what, bool Function() done) async {
    final clock = Stopwatch()..start();
    while (!done()) {
      if (clock.elapsed > const Duration(seconds: 40)) {
        throw StateError('bench: timed out waiting for $what');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _measure(String name, Future<void> Function() during) async {
    final window = probe.open(name);
    await during();
    emit({'type': 'scenario', ...await window.close()});
  }

  Future<void> _screen(String name, String path) async {
    goRouter.go(path);
    await Future<void>.delayed(_settle);
    await _measure(name, () => Future<void>.delayed(_window));
  }

  /// Opens the RPM chart from the Meter tab, as a tap on its gauge does.
  Future<void> _chartModal() async {
    goRouter.go('/dashboard');
    await Future<void>.delayed(_settle);
    final meter = _find((e) => e.widget is DashboardScreen)!;
    TelemetryChartModal.show(meter, ObdMetricType.rpm);
    await Future<void>.delayed(_settle);
    await _measure('chart_modal_rpm', () => Future<void>.delayed(_window));
    // Popped through the sheet's own context: correct whichever navigator
    // (tab branch or root) the sheet is shown on.
    Navigator.of(_find((e) => e.widget is TelemetryChartModal)!).pop();
    await Future<void>.delayed(_settle);
  }

  Future<void> _tabSwitching() async {
    const tabs = ['/health', '/dashboard', '/live_data', '/timeline', '/settings'];
    goRouter.go(tabs.first);
    await Future<void>.delayed(_settle);
    await _measure('tab_switching', () async {
      final clock = Stopwatch()..start();
      for (var i = 1; clock.elapsed < _window; i++) {
        goRouter.go(tabs[i % tabs.length]);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
    });
  }

  Future<void> _timelineScroll() async {
    goRouter.go('/timeline');
    await Future<void>.delayed(_settle);
    final timeline = _find((e) => e.widget is TimelineScreen)!;
    final position = _mainScrollPosition(timeline);
    if (position == null || position.maxScrollExtent <= 0) {
      throw StateError('bench: timeline has nothing to scroll');
    }
    await _measure('timeline_scroll', () async {
      final clock = Stopwatch()..start();
      while (clock.elapsed < _window) {
        await position.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 2500),
          curve: Curves.linear,
        );
        await position.animateTo(
          0,
          duration: const Duration(milliseconds: 2500),
          curve: Curves.linear,
        );
      }
    });
  }

  static Element? _find(bool Function(Element element) test) {
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      if (test(element)) {
        found = element;
        return;
      }
      element.visitChildElements(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(visit);
    return found;
  }

  static ScrollPosition? _mainScrollPosition(Element root) {
    ScrollPosition? best;
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        if (position.axis == Axis.vertical &&
            position.hasContentDimensions &&
            (best == null || position.maxScrollExtent > best!.maxScrollExtent)) {
          best = position;
        }
      }
      element.visitChildElements(visit);
    }

    root.visitChildElements(visit);
    return best;
  }
}
