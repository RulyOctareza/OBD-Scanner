// Dev-only benchmark entrypoint. Never imported by lib/main.dart, so none of
// it is compiled into app builds. Build and run with tool/bench/run_bench.sh.
import 'dart:developer' show Timeline;
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app.dart';
import '../../core/bluetooth/obd_link.dart';
import '../../core/database/database_provider.dart';
import '../fake_elm327.dart';
import 'bench_runner.dart';
import 'bench_seed.dart';
import 'perf_probe.dart';

/// Release builds have no INTERNET permission, so every connection fails at
/// once. Profile builds do have it; this makes the bench behave like release.
class _ReleaseLikeNoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..connectionFactory = (uri, proxyHost, proxyPort) => Future.error(
          const SocketException('bench: no INTERNET permission, as in release'),
        );
}

Future<void> main() async {
  final mainClock = Stopwatch()..start();
  final mainStartMicros = Timeline.now;
  HttpOverrides.global = _ReleaseLikeNoNetwork();
  WidgetsFlutterBinding.ensureInitialized();

  // Fonts google_fonts downloaded in an earlier run would hide the release
  // path (fetch fails, font load retried on every call), so none are kept.
  final support = await getApplicationSupportDirectory();
  final cachedFonts = support
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.ttf'))
      .toList();
  for (final font in cachedFonts) {
    font.deleteSync();
  }

  final dir = await getApplicationDocumentsDirectory();
  BenchRunner.resultsFile = File('${dir.path}/bench_results.jsonl')
    ..writeAsStringSync('');

  final seedClock = Stopwatch()..start();
  final db = await openSeededBenchDatabase();
  seedClock.stop();

  final adapter = FakeElm327Connector();
  final probe = PerfProbe()..start();
  late final ProviderContainer container;
  await runAutoCare(
    overrides: [
      databaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
      obdLinkConnectorProvider.overrideWithValue(adapter),
    ],
    onContainer: (c) => container = c,
  );
  await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
  // Dart main to first rasterized frame. Seeding is bench-only work, so it is
  // taken out; process start to first frame is measured on the host.
  final firstFrameMs =
      mainClock.elapsedMilliseconds - seedClock.elapsedMilliseconds;

  final runner = BenchRunner(
    container: container,
    adapter: adapter,
    probe: probe,
    mainStartMicros: mainStartMicros,
    seedMs: seedClock.elapsedMilliseconds,
  );
  final startup = <String, Object>{
    'abi': Abi.current().toString(),
    'os': Platform.operatingSystemVersion,
    'cpus': Platform.numberOfProcessors,
    'mode': kProfileMode ? 'profile' : (kReleaseMode ? 'release' : 'debug'),
    'main_to_first_frame_ms': firstFrameMs,
    'cached_fonts_deleted': cachedFonts.length,
    'seed_ms': seedClock.elapsedMilliseconds,
  };
  // "background": link-survival check driven by tool/bench/run_background.sh.
  if (const String.fromEnvironment('BENCH_SCENARIO') == 'background') {
    await runner.runBackground(startup);
  } else {
    await runner.run(startup);
  }
}
