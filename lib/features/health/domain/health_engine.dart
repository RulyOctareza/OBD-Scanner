import 'package:flutter/foundation.dart' show immutable, listEquals;

import '../../../core/obd/obd_telemetry.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/metric_status.dart';
import '../../../core/ui/status.dart';

/// Where a warning's button leads.
enum HealthAction {
  /// Live sensor values (path `/live_data`).
  openLive('/live_data', 'Lihat data live'),

  /// Diagnostic scan (path `/diagnostics`).
  openDiagnostics('/diagnostics', 'Buka Diagnostik'),

  /// Service history, to log an oil change (path `/timeline`).
  openRiwayat('/timeline', 'Buka Riwayat'),

  /// Settings, to enter the odometer and the oil target (path `/settings`).
  openSettings('/settings', 'Buka Pengaturan');

  const HealthAction(this.route, this.label);

  final String route;
  final String label;
}

/// One row of the Health checks: what was checked and how it stands. A check
/// without a reading is [StatusLevel.noData], never ok.
@immutable
class CheckItem {
  const CheckItem({
    required this.title,
    required this.level,
    required this.detail,
    this.note,
    this.action,
  });

  final String title;
  final StatusLevel level;

  /// The value or state ("86 °C", "Belum dipindai", "2 kode aktif").
  final String detail;

  /// Short judgement ("Normal", "Hangat"); null when [detail] says it all.
  final String? note;

  /// Where tapping the row leads.
  final HealthAction? action;

  bool get isOk => level == StatusLevel.ok;

  @override
  bool operator ==(Object other) =>
      other is CheckItem &&
      other.title == title &&
      other.level == level &&
      other.detail == detail &&
      other.note == note &&
      other.action == action;

  @override
  int get hashCode => Object.hash(title, level, detail, note, action);
}

enum HealthWarningKind {
  coolant,
  charging,
  battery,
  dtc,
  idle,
  oilOverdue,
  oilDue,
}

/// A problem found by the health check, with what to do about it. The action
/// comes from [kind], not from the wording, so rewording never breaks it.
@immutable
class HealthWarning {
  const HealthWarning({
    required this.kind,
    required this.level,
    required this.title,
    required this.detail,
    required this.action,
  });

  final HealthWarningKind kind;

  /// [StatusLevel.waspada] or [StatusLevel.kritis].
  final StatusLevel level;
  final String title;
  final String detail;
  final HealthAction action;

  @override
  bool operator ==(Object other) =>
      other is HealthWarning &&
      other.kind == kind &&
      other.level == level &&
      other.title == title &&
      other.detail == detail &&
      other.action == action;

  @override
  int get hashCode => Object.hash(kind, level, title, detail, action);
}

@immutable
class HealthReport {
  const HealthReport({
    required this.score,
    required this.level,
    required this.statusTitle,
    required this.statusDescription,
    required this.checks,
    required this.warnings,
  });

  /// 0–100, or null while nothing has been measured: no data is never shown
  /// as a healthy score.
  final int? score;

  /// Band of [score]; [StatusLevel.noData] when there is no score.
  final StatusLevel level;
  final String statusTitle;
  final String statusDescription;
  final List<CheckItem> checks;

  /// Most severe first.
  final List<HealthWarning> warnings;

  bool get hasData => score != null;

  /// Value equality: healthProvider is recomputed on every telemetry change,
  /// and Provider only notifies its watchers when the report differs. Every
  /// field belongs here.
  @override
  bool operator ==(Object other) =>
      other is HealthReport &&
      other.score == score &&
      other.level == level &&
      other.statusTitle == statusTitle &&
      other.statusDescription == statusDescription &&
      listEquals(other.checks, checks) &&
      listEquals(other.warnings, warnings);

  @override
  int get hashCode => Object.hash(
        score,
        level,
        statusTitle,
        statusDescription,
        Object.hashAll(checks),
        Object.hashAll(warnings),
      );
}

class HealthEngine {
  /// Score deductions; see biblio book health/health_score.
  static const int _coolantCritical = 35;
  static const int _coolantHigh = 15;
  static const int _coolantWarm = 5;
  static const int _charging = 15;
  static const int _battery = 10;
  static const int _perDtc = 20;
  static const int _idle = 5;
  static const int _oilOverdue = 10;
  static const int _oilDue = 2;

  /// Oil reminder starts this many km before the target.
  static const double oilDueKm = 2500;

  /// Builds the report from live [telemetry] and the oil target.
  ///
  /// [dtcsChecked] says whether trouble codes were read on this link; until
  /// then the DTC check is "Belum dipindai". Codes present count as read.
  static HealthReport calculate(
    ObdTelemetry telemetry, {
    double? nextOilOdometer,
    double? currentOdometer,
    String vehicleName = 'Mobil saya',
    bool dtcsChecked = false,
  }) {
    var score = 100;
    var measured = false;
    final checks = <CheckItem>[];
    final warnings = <HealthWarning>[];
    final running = isEngineRunning(telemetry.rpm);

    // 1. Coolant.
    final coolant = assessCoolant(telemetry.coolant);
    if (coolant.level == StatusLevel.noData) {
      checks.add(const CheckItem(
        title: 'Suhu mesin',
        level: StatusLevel.noData,
        detail: 'Belum ada data',
        action: HealthAction.openLive,
      ));
    } else {
      measured = true;
      final value = Fmt.celsius(telemetry.coolant);
      checks.add(CheckItem(
        title: 'Suhu mesin',
        level: coolant.level,
        detail: value,
        note: coolant.note,
        action: HealthAction.openLive,
      ));
      if (telemetry.coolant > MetricThresholds.coolantCritical) {
        score -= _coolantCritical;
        warnings.add(HealthWarning(
          kind: HealthWarningKind.coolant,
          level: StatusLevel.kritis,
          title: 'Mesin terlalu panas',
          detail: 'Suhu mesin $value. Menepi dan matikan mesin. Jangan buka '
              'tutup radiator selagi panas.',
          action: HealthAction.openLive,
        ));
      } else if (telemetry.coolant > MetricThresholds.coolantHigh) {
        score -= _coolantHigh;
        warnings.add(HealthWarning(
          kind: HealthWarningKind.coolant,
          level: StatusLevel.waspada,
          title: 'Suhu mesin tinggi',
          detail: 'Suhu mesin $value. Setelah mesin dingin, periksa air '
              'radiator dan kipas.',
          action: HealthAction.openLive,
        ));
      } else if (telemetry.coolant > MetricThresholds.coolantWarm) {
        score -= _coolantWarm;
        warnings.add(HealthWarning(
          kind: HealthWarningKind.coolant,
          level: StatusLevel.waspada,
          title: 'Suhu mesin agak tinggi',
          detail: 'Suhu mesin $value. Perhatikan kalau terus naik.',
          action: HealthAction.openLive,
        ));
      }
    }

    // 2. Battery and charging.
    final voltage = assessVoltage(telemetry.voltage, engineRunning: running);
    if (voltage.level == StatusLevel.noData) {
      checks.add(const CheckItem(
        title: 'Tegangan aki',
        level: StatusLevel.noData,
        detail: 'Belum ada data',
        action: HealthAction.openLive,
      ));
    } else {
      measured = true;
      final value = Fmt.volts(telemetry.voltage);
      checks.add(CheckItem(
        title: 'Tegangan aki',
        level: voltage.level,
        detail: value,
        note: voltage.note,
        action: HealthAction.openLive,
      ));
      if (voltage.level != StatusLevel.ok) {
        if (running) {
          score -= _charging;
          warnings.add(HealthWarning(
            kind: HealthWarningKind.charging,
            level: StatusLevel.waspada,
            title: 'Pengisian aki lemah',
            detail: 'Tegangan $value saat mesin hidup; normalnya '
                '13,5–14,7 V. Periksa alternator dan tali kipas.',
            action: HealthAction.openLive,
          ));
        } else {
          score -= _battery;
          warnings.add(HealthWarning(
            kind: HealthWarningKind.battery,
            level: StatusLevel.waspada,
            title: 'Aki lemah',
            detail: 'Tegangan $value saat mesin mati. Aki mungkin perlu '
                'dicas atau diganti.',
            action: HealthAction.openLive,
          ));
        }
      }
    }

    // 3. Trouble codes.
    final codes = telemetry.dtcs;
    if (codes.isNotEmpty) {
      measured = true;
      score -= _perDtc * codes.length;
      checks.add(CheckItem(
        title: 'Kode kerusakan',
        level: StatusLevel.kritis,
        detail: '${codes.length} kode aktif',
        action: HealthAction.openDiagnostics,
      ));
      warnings.add(HealthWarning(
        kind: HealthWarningKind.dtc,
        level: StatusLevel.kritis,
        title: codes.length == 1
            ? 'Lampu Check Engine: 1 kode kerusakan'
            : 'Lampu Check Engine: ${codes.length} kode kerusakan',
        detail: '${codes.join(', ')}. Buka Diagnostik untuk penjelasan dan '
            'langkah perbaikannya.',
        action: HealthAction.openDiagnostics,
      ));
    } else if (dtcsChecked) {
      measured = true;
      checks.add(const CheckItem(
        title: 'Kode kerusakan',
        level: StatusLevel.ok,
        detail: 'Tidak ada kode',
        action: HealthAction.openDiagnostics,
      ));
    } else {
      checks.add(const CheckItem(
        title: 'Kode kerusakan',
        level: StatusLevel.noData,
        detail: 'Belum dipindai',
        action: HealthAction.openDiagnostics,
      ));
    }

    // 4. Idle stability (stopped, engine running).
    if (running && telemetry.speed < 1.0) {
      if (telemetry.rpm < MetricThresholds.idleMinRpm ||
          telemetry.rpm > MetricThresholds.idleMaxRpm) {
        score -= _idle;
        warnings.add(HealthWarning(
          kind: HealthWarningKind.idle,
          level: StatusLevel.waspada,
          title: 'Putaran idle tidak stabil',
          detail: '${Fmt.rpm(telemetry.rpm)} saat berhenti; normalnya '
              '${Fmt.number(MetricThresholds.idleMinRpm)}–'
              '${Fmt.number(MetricThresholds.idleMaxRpm)} rpm.',
          action: HealthAction.openLive,
        ));
      }
    }

    // 5. Oil change, from the odometer: known without a live link.
    if (nextOilOdometer != null && currentOdometer != null) {
      final remaining = nextOilOdometer - currentOdometer;
      if (remaining <= 0) {
        score -= _oilOverdue;
        warnings.add(HealthWarning(
          kind: HealthWarningKind.oilOverdue,
          level: StatusLevel.waspada,
          title: 'Jadwal ganti oli terlewat',
          detail: 'Lewat ${Fmt.km(-remaining)} dari jadwal. Ganti oli, lalu '
              'catat servisnya di Riwayat.',
          action: HealthAction.openRiwayat,
        ));
      } else if (remaining < oilDueKm) {
        score -= _oilDue;
        warnings.add(HealthWarning(
          kind: HealthWarningKind.oilDue,
          level: StatusLevel.waspada,
          title: 'Ganti oli sebentar lagi',
          detail: 'Sisa ${Fmt.km(remaining)} sampai jadwal ganti oli.',
          action: HealthAction.openRiwayat,
        ));
      }
    }

    warnings.sort((a, b) => _rank(b.level).compareTo(_rank(a.level)));

    if (!measured) {
      return HealthReport(
        score: null,
        level: StatusLevel.noData,
        statusTitle: 'Belum ada data',
        statusDescription:
            'Hubungkan adapter OBD untuk memeriksa kondisi mobil.',
        checks: checks,
        warnings: warnings,
      );
    }

    score = score.clamp(0, 100);
    final StatusLevel level;
    final String title;
    final String description;
    if (score >= 95) {
      level = StatusLevel.ok;
      title = '$vehicleName dalam kondisi baik';
      description = 'Semua pemeriksaan normal.';
    } else if (score >= 80) {
      level = StatusLevel.waspada;
      title = 'Perlu perhatian';
      description = 'Ada nilai di luar batas normal atau jadwal servis '
          'sudah dekat.';
    } else {
      level = StatusLevel.kritis;
      title = 'Periksa segera';
      description = 'Ada kode kerusakan aktif atau nilai sensor kritis.';
    }

    return HealthReport(
      score: score,
      level: level,
      statusTitle: title,
      statusDescription: description,
      checks: checks,
      warnings: warnings,
    );
  }

  static int _rank(StatusLevel level) => switch (level) {
        StatusLevel.kritis => 2,
        StatusLevel.waspada => 1,
        _ => 0,
      };
}
