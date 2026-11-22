// Summarizes tool/bench/run_bench.sh output as a markdown table: the median
// and range over runs for every scenario metric, plus the change against a
// baseline when a second directory is given.
//
// Usage: dart run tool/bench/summarize.dart <dir> [<baseline-dir>]
import 'dart:convert';
import 'dart:io';

const _metrics = [
  'fps',
  'build_avg_ms',
  'build_p90_ms',
  'raster_avg_ms',
  'raster_p90_ms',
  'jank_pct',
  'cpu_pct',
  'rss_mb',
];

/// scenario -> metric -> one value per run.
Map<String, Map<String, List<double>>> _load(String dir) {
  final result = <String, Map<String, List<double>>>{};
  void add(String scenario, String metric, num value) => result
      .putIfAbsent(scenario, () => {})
      .putIfAbsent(metric, () => [])
      .add(value.toDouble());

  final runs = Directory(dir)
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'run\d+\.jsonl$').hasMatch(f.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final run in runs) {
    for (final line in run.readAsLinesSync().where((l) => l.trim().isNotEmpty)) {
      final data = jsonDecode(line) as Map<String, dynamic>;
      switch (data['type']) {
        case 'startup':
          add('startup', 'main_to_first_frame_ms', data['main_to_first_frame_ms'] as num);
        case 'scenario':
          for (final metric in _metrics) {
            add(data['scenario'] as String, metric, data[metric] as num);
          }
        case 'done':
          add('link', 'answers_per_s', data['answers_per_s'] as num);
      }
    }
    final amStart = File(run.path.replaceFirst('.jsonl', '-am-start.txt'));
    if (amStart.existsSync()) {
      final total = RegExp(r'TotalTime: (\d+)').firstMatch(amStart.readAsStringSync());
      if (total != null) add('startup', 'cold_start_total_ms', int.parse(total[1]!));
    }
  }
  return result;
}

double _median(List<double> values) {
  final v = [...values]..sort();
  final mid = v.length ~/ 2;
  return v.length.isOdd ? v[mid] : (v[mid - 1] + v[mid]) / 2;
}

String _fmt(double v) => v.abs() >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/bench/summarize.dart <dir> [<baseline-dir>]');
    exit(64);
  }
  final current = _load(args[0]);
  final baseline = args.length > 1 ? _load(args[1]) : null;

  stdout.writeln(baseline == null
      ? '| scenario | metric | median | range |'
      : '| scenario | metric | baseline | after | range | change |');
  stdout.writeln(baseline == null ? '|---|---|---|---|' : '|---|---|---|---|---|---|');
  for (final scenario in current.keys) {
    for (final entry in current[scenario]!.entries) {
      final values = entry.value;
      final med = _median(values);
      final range =
          '${_fmt(values.reduce((a, b) => a < b ? a : b))}–${_fmt(values.reduce((a, b) => a > b ? a : b))}';
      if (baseline == null) {
        stdout.writeln('| $scenario | ${entry.key} | ${_fmt(med)} | $range |');
        continue;
      }
      final before = baseline[scenario]?[entry.key];
      if (before == null) {
        stdout.writeln('| $scenario | ${entry.key} | – | ${_fmt(med)} | $range | – |');
        continue;
      }
      final base = _median(before);
      final change = base == 0 ? '–' : '${((med - base) / base * 100).toStringAsFixed(0)} %';
      stdout.writeln('| $scenario | ${entry.key} | ${_fmt(base)} | ${_fmt(med)} | $range | $change |');
    }
  }
}
