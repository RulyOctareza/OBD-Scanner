import 'package:autocare/core/bluetooth/obd_service.dart';
import 'package:autocare/core/database/database.dart';
import 'package:autocare/core/database/database_provider.dart';
import 'package:autocare/core/obd/obd_metric.dart';
import 'package:autocare/features/live_data/presentation/live_chart_buffer.dart';
import 'package:autocare/features/live_data/presentation/telemetry_provider.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

TelemetryPointBundle _sample(DateTime t, double rpm) => TelemetryPointBundle(
      timestamp: t,
      rpm: rpm,
      speed: 0,
      coolant: 90,
      voltage: 14,
      throttle: 0,
      engineLoad: 0,
      mapValue: 30,
    );

Future<void> _seed(AppDatabase db, DateTime start, int count) async {
  final trip = await db.into(db.trips).insert(
        TripsCompanion.insert(startTime: start),
      );
  await db.batch((b) {
    b.insertAll(db.tripPoints, [
      for (var i = 0; i < count; i++)
        TripPointsCompanion.insert(
          tripId: Value(trip),
          timestamp: start.add(Duration(seconds: i * 5)),
          rpm: 1000.0 + i,
          speed: 40,
          coolant: i.isEven ? 90 : 0, // 0 = no ECU data, never charted
          voltage: 14,
          mapValue: 40,
        ),
    ]);
  });
}

/// Counts SELECTs that read trip_points.
class _TripPointReads extends QueryInterceptor {
  int count = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('trip_points')) count++;
    return super.runSelect(executor, statement, args);
  }
}

void main() {
  final now = DateTime(2026, 11, 23, 12);

  test('merges stored and live points in time order, live value is current', () {
    final stored = [
      TelemetryPoint(timestamp: now.subtract(const Duration(seconds: 50)), value: 900),
      TelemetryPoint(timestamp: now.subtract(const Duration(seconds: 20)), value: 950),
    ];
    final live = [
      _sample(now.subtract(const Duration(seconds: 30)), 1000),
      _sample(now.subtract(const Duration(seconds: 2)), 1200),
    ];
    final h = buildTelemetryHistory(
      metricType: ObdMetricType.rpm,
      timeRange: TelemetryTimeRange.oneMin,
      stored: stored,
      live: live,
      now: now,
    );
    expect(h.points.map((p) => p.value), [900, 1000, 950, 1200]);
    expect(h.currentValue, 1200);
    expect(h.minValue, 900);
    expect(h.maxValue, 1200);
  });

  test('range filter drops points older than the range', () {
    final h = buildTelemetryHistory(
      metricType: ObdMetricType.rpm,
      timeRange: TelemetryTimeRange.oneMin,
      stored: [
        TelemetryPoint(timestamp: now.subtract(const Duration(minutes: 3)), value: 1),
        TelemetryPoint(timestamp: now.subtract(const Duration(seconds: 10)), value: 2),
      ],
      live: const [],
      now: now,
    );
    // The single point in range is padded with a copy 15 s earlier.
    expect(h.points.map((p) => p.value), [2, 2]);
  });

  group('stored series', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.withExecutor(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('a timed range reads only its window and valid values', () async {
      final start = DateTime.now().subtract(const Duration(minutes: 30));
      await _seed(db, start, 360); // 30 min at 5 s
      final points = await container.read(
        storedSeriesProvider((ObdMetricType.rpm, TelemetryTimeRange.fiveMin))
            .future,
      );
      expect(points.length, inInclusiveRange(59, 61));
      expect(
        points.first.timestamp.isAfter(
          DateTime.now().subtract(const Duration(minutes: 5, seconds: 1)),
        ),
        isTrue,
      );
      final coolant = await container.read(
        storedSeriesProvider((ObdMetricType.coolant, TelemetryTimeRange.fiveMin))
            .future,
      );
      expect(coolant.every((p) => p.value > 0), isTrue);
    });

    test('"Semua" is bucketed in SQL to a bounded row count', () async {
      final start = DateTime.now().subtract(const Duration(days: 30));
      await _seed(db, start, 20000);
      final points = await container.read(
        storedSeriesProvider((ObdMetricType.rpm, TelemetryTimeRange.all))
            .future,
      );
      expect(points.length, lessThanOrEqualTo(401));
      expect(points.length, greaterThan(300));
      for (var i = 1; i < points.length; i++) {
        expect(points[i].timestamp.isAfter(points[i - 1].timestamp), isTrue);
      }
      expect(points.last.value, 1000.0 + 19999, reason: 'newest row kept');
    });
  });

  test('a closed chart leaves no provider, timer or query running', () async {
    SharedPreferences.setMockInitialValues({});
    final reads = _TripPointReads();
    final db = AppDatabase.withExecutor(
      NativeDatabase.memory().interceptWith(reads),
    );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await _seed(db, DateTime.now().subtract(const Duration(minutes: 3)), 30);

    const key = (ObdMetricType.rpm, TelemetryTimeRange.fiveMin);
    final open = container.listen(
      telemetryHistoryProvider(ObdMetricType.rpm),
      (_, __) {},
    );
    await container.read(storedSeriesProvider(key).future);
    expect(container.exists(liveChartBufferProvider), isTrue);
    expect(container.exists(obdServiceProvider), isTrue);
    final readsWhileOpen = reads.count;
    expect(readsWhileOpen, 1, reason: 'one query per chart opening and range');

    // New points while the chart is open come through the live buffer:
    // inserting must not re-run the stored query.
    await _seed(db, DateTime.now().subtract(const Duration(minutes: 1)), 6);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(reads.count, readsWhileOpen);

    open.close();
    await Future<void>.delayed(Duration.zero);
    expect(container.exists(telemetryHistoryProvider(ObdMetricType.rpm)), isFalse);
    expect(container.exists(storedSeriesProvider(key)), isFalse);
    expect(
      container.exists(liveChartBufferProvider),
      isFalse,
      reason: 'the 1 Hz sampling timer is cancelled with the buffer',
    );

    await _seed(db, DateTime.now(), 6);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(reads.count, readsWhileOpen, reason: 'no query after close');
  });
}
