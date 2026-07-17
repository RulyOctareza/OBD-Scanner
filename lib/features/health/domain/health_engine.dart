import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/obd/obd_telemetry.dart';

class CheckItem {
  final String title;
  final bool isOk;
  final String detail;

  CheckItem({
    required this.title,
    required this.isOk,
    required this.detail,
  });
}

class HealthReport {
  final int score;
  final String statusTitle;
  final String statusDescription;
  final Color statusColor;
  final List<CheckItem> checks;
  final List<String> warnings;

  HealthReport({
    required this.score,
    required this.statusTitle,
    required this.statusDescription,
    required this.statusColor,
    required this.checks,
    required this.warnings,
  });
}

class HealthEngine {
  static HealthReport calculate(
    ObdTelemetry telemetry, {
    double? nextOilOdometer,
    double? currentOdometer,
    String vehicleName = "Agya",
  }) {
    int score = 100;
    final List<CheckItem> checks = [];
    final List<String> warnings = [];

    // 1. Coolant Check
    bool coolantOk = true;
    String coolantDetail = "${telemetry.coolant.toStringAsFixed(0)}°C";
    if (telemetry.coolant <= 0) {
      coolantDetail = "No Data";
    } else if (telemetry.coolant > 115) {
      score -= 35;
      coolantOk = false;
      coolantDetail = "$coolantDetail (Sangat Tinggi!)";
      warnings.add("Suhu coolant kritis ($coolantDetail). Matikan mesin segera!");
    } else if (telemetry.coolant > 105) {
      score -= 15;
      coolantOk = false;
      coolantDetail = "$coolantDetail (Tinggi)";
      warnings.add("Suhu mesin di atas batas normal ($coolantDetail). Cek air radiator.");
    } else if (telemetry.coolant > 100) {
      score -= 5;
      coolantOk = false;
      coolantDetail = "$coolantDetail (Hangat)";
      warnings.add("Suhu coolant sedikit meningkat ($coolantDetail).");
    } else {
      coolantDetail = "$coolantDetail (Normal)";
    }
    checks.add(CheckItem(title: "Suhu Coolant", isOk: coolantOk, detail: coolantDetail));

    // 2. Battery Voltage Check
    bool batteryOk = true;
    String voltDetail = "${telemetry.voltage.toStringAsFixed(1)}V";
    if (telemetry.voltage <= 0) {
      voltDetail = "No Data";
    } else {
      final isEngineRunning = telemetry.rpm > 500;
      if (isEngineRunning) {
        if (telemetry.voltage < 12.8) {
          score -= 15;
          batteryOk = false;
          voltDetail = "$voltDetail (Pengisian Lemah)";
          warnings.add("Pengisian aki alternator bermasalah ($voltDetail).");
        } else {
          voltDetail = "$voltDetail (Pengisian OK)";
        }
      } else {
        if (telemetry.voltage < 11.8) {
          score -= 10;
          batteryOk = false;
          voltDetail = "$voltDetail (Drop)";
          warnings.add("Tegangan aki lemah sebelum mesin hidup ($voltDetail).");
        } else {
          voltDetail = "$voltDetail (Siaga)";
        }
      }
    }
    checks.add(CheckItem(title: "Tegangan Aki", isOk: batteryOk, detail: voltDetail));

    // 3. DTC Errors Check
    bool dtcOk = true;
    String dtcDetail = "Tidak ada masalah";
    if (telemetry.dtcs.isNotEmpty) {
      dtcOk = false;
      dtcDetail = "${telemetry.dtcs.length} Masalah Aktif";
      for (final code in telemetry.dtcs) {
        score -= 20;
        final translated = _translateDtc(code);
        warnings.add("Trouble Code [$code]: ${translated.title} (${translated.severity})");
      }
    }
    checks.add(CheckItem(title: "Sistem Elektronik (DTC)", isOk: dtcOk, detail: dtcDetail));

    // 4. Idle Stability Check (when speed is 0 and engine running)
    if (telemetry.rpm > 500 && telemetry.speed < 1.0) {
      // Normal idle is between 700 and 950 RPM
      if (telemetry.rpm < 650 || telemetry.rpm > 1100) {
        score -= 5;
        warnings.add("RPM Idle kurang stabil (${telemetry.rpm.toStringAsFixed(0)} RPM).");
      }
    }

    // 5. Maintenance / Oil Change check (if odometer data is available)
    if (nextOilOdometer != null && currentOdometer != null) {
      final remaining = nextOilOdometer - currentOdometer;
      if (remaining <= 0) {
        score -= 10;
        warnings.add("Oli mesin melewati batas ganti! Segera ganti oli.");
      } else if (remaining < 2500) {
        score -= 2;
        warnings.add("Ganti oli berikutnya dalam ${remaining.toStringAsFixed(0)} km.");
      }
    }

    // Clip score between 0 and 100
    score = score.clamp(0, 100);

    // Determine status branding
    String statusTitle;
    String statusDescription;
    Color statusColor;

    if (score >= 95) {
      statusTitle = "${vehicleName.toUpperCase()} DALAM KONDISI PRIMA";
      statusDescription = "Seluruh sistem utama bekerja dengan optimal.";
      statusColor = AppColors.success;
    } else if (score >= 80) {
      statusTitle = "BUTUH PERHATIAN RINGAN";
      statusDescription = "Ada beberapa parameter di luar batas ideal atau masa servis mendekati limit.";
      statusColor = AppColors.warning;
    } else {
      statusTitle = "PERIKSA KENDARAAN SEGERA";
      statusDescription = "Terdeteksi kode kerusakan aktif atau parameter sensor kritis.";
      statusColor = AppColors.danger;
    }

    return HealthReport(
      score: score,
      statusTitle: statusTitle,
      statusDescription: statusDescription,
      statusColor: statusColor,
      checks: checks,
      warnings: warnings,
    );
  }

  static DtcTranslation _translateDtc(String code) {
    switch (code.toUpperCase()) {
      case 'P0138':
        return DtcTranslation(
          title: "Oxygen Sensor Circuit High Voltage (Sensor 2)",
          severity: "Tidak berbahaya, tapi periksa kabel sensor O2.",
        );
      case 'P0115':
        return DtcTranslation(
          title: "Engine Coolant Temperature Circuit Malfunction",
          severity: "Sedang, sensor suhu coolant bermasalah.",
        );
      case 'P0300':
        return DtcTranslation(
          title: "Random/Multiple Cylinder Misfire Detected",
          severity: "Kritis! Mesin pincang, cek busi & koil segera.",
        );
      case 'P0420':
        return DtcTranslation(
          title: "Catalyst System Efficiency Below Threshold",
          severity: "Ringan, performa konverter katalitik menurun.",
        );
      default:
        return DtcTranslation(
          title: "Unknown Trouble Code ($code)",
          severity: "Silakan konsultasikan ke bengkel terdekat.",
        );
    }
  }
}

class DtcTranslation {
  final String title;
  final String severity;

  DtcTranslation({required this.title, required this.severity});
}
