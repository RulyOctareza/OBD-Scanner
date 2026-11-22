import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bluetooth/obd_service.dart';
import '../obd/obd_metric.dart';

// Live OBD data for screens. ObdState changes on every PID response (about
// 10/s on a real link) and the shell keeps visited tabs mounted, so a screen
// that watches the whole state rebuilds ten times a second, visible or not.
// These helpers rebuild only what changed, and nothing while offstage.

extension VisibleWatch on WidgetRef {
  /// Watches [provider] while [context] is on screen and only reads it while
  /// offstage: an inactive shell tab and a route covered by another one run
  /// with TickerMode off. The TickerMode dependency rebuilds the widget with a
  /// fresh value when it shows again.
  ///
  /// Not for autoDispose providers: a read does not keep them alive.
  T watchVisible<T>(BuildContext context, ProviderListenable<T> provider) =>
      TickerMode.of(context) ? watch(provider) : read(provider);
}

/// Rebuilds [builder] only when [selector]'s result changes (by `==`), and
/// not while offstage.
class ObdSelect<T> extends ConsumerWidget {
  const ObdSelect({
    super.key,
    required this.selector,
    required this.builder,
    this.child,
  });

  final T Function(ObdState state) selector;
  final Widget Function(BuildContext context, T value, Widget? child) builder;

  /// Passed to [builder] unchanged, for subtrees that do not depend on value.
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => builder(
        context,
        ref.watchVisible(context, obdServiceProvider.select(selector)),
        child,
      );
}

/// One metric as a screen shows it.
@immutable
class MetricReading {
  const MetricReading({
    this.value,
    this.isPending = false,
    this.isUnsupported = false,
  });

  /// The last value received. Meaningless while [isPending] (it is the empty
  /// default then, often 0).
  final double? value;

  /// Not asked from the car yet on this link, or not connected. In simulator
  /// mode every metric counts as asked.
  final bool isPending;

  /// Asked, and the car does not answer it.
  final bool isUnsupported;

  bool get hasValue => !isPending && !isUnsupported && value != null;

  @override
  bool operator ==(Object other) =>
      other is MetricReading &&
      other.value == value &&
      other.isPending == isPending &&
      other.isUnsupported == isUnsupported;

  @override
  int get hashCode => Object.hash(value, isPending, isUnsupported);

  @override
  String toString() =>
      'MetricReading($value, pending: $isPending, unsupported: $isUnsupported)';
}

/// [type]'s reading in [state]. With [step], the value is rounded to it, so
/// changes finer than what a screen displays do not count as changes.
MetricReading readingOf(ObdState state, ObdMetricType type, {double? step}) {
  final checked = state.checkedSensors.contains(type);
  var value = metricValue(state.telemetry, type);
  if (value != null && step != null) {
    value = (value / step).roundToDouble() * step;
  }
  return MetricReading(
    value: value,
    isPending: !checked,
    isUnsupported: checked && !state.supportedSensors.contains(type),
  );
}

/// Rebuilds [builder] only when [type]'s reading changes, and not while
/// offstage. Use [step] for text: the display precision, e.g. 1 for RPM, 0.1
/// for voltage. Leave it null for a gauge needle, which shows every change.
class LiveMetric extends ConsumerWidget {
  const LiveMetric({
    super.key,
    required this.type,
    this.step,
    required this.builder,
    this.child,
  });

  final ObdMetricType type;
  final double? step;
  final Widget Function(BuildContext context, MetricReading reading, Widget? child)
      builder;
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => builder(
        context,
        ref.watchVisible(
          context,
          obdServiceProvider.select((s) => readingOf(s, type, step: step)),
        ),
        child,
      );
}
