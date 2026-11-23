import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bluetooth/obd_service.dart';

enum ScanPhase { idle, scanning, done }

@immutable
class DiagnosticScanState {
  const DiagnosticScanState({
    this.phase = ScanPhase.idle,
    this.progress = 0,
    this.result,
    this.clearing = false,
  });

  final ScanPhase phase;

  /// 0–1 while scanning.
  final double progress;

  /// Last finished scan, kept until the next one: leaving the tab does not
  /// lose it.
  final DiagnosticScanResult? result;

  /// A code clear is running.
  final bool clearing;

  DiagnosticScanState copyWith({
    ScanPhase? phase,
    double? progress,
    DiagnosticScanResult? result,
    bool? clearing,
  }) {
    return DiagnosticScanState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      result: result ?? this.result,
      clearing: clearing ?? this.clearing,
    );
  }
}

/// Runs the diagnostic scan and the code clear outside any widget, so a scan
/// keeps going and its result stays when the screen is left (a widget-owned
/// scan used its ref after the screen was disposed).
class DiagnosticScanNotifier extends StateNotifier<DiagnosticScanState> {
  DiagnosticScanNotifier(this._ref) : super(const DiagnosticScanState());

  final Ref _ref;

  Future<void> scan() async {
    if (state.phase == ScanPhase.scanning) return;
    state = state.copyWith(phase: ScanPhase.scanning, progress: 0.05);
    try {
      final result = await _ref
          .read(obdServiceProvider.notifier)
          .performFullDiagnosticScan(
        onProgress: (progress, _) {
          if (mounted) state = state.copyWith(progress: progress);
        },
      );
      if (!mounted) return;
      state = DiagnosticScanState(phase: ScanPhase.done, progress: 1, result: result);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        phase: state.result == null ? ScanPhase.idle : ScanPhase.done,
        progress: 0,
      );
      rethrow;
    }
  }

  /// Clears the codes and reads them back; the shown result keeps only the
  /// codes that are still there.
  Future<DtcClearResult> clearCodes() async {
    state = state.copyWith(clearing: true);
    try {
      final outcome =
          await _ref.read(obdServiceProvider.notifier).clearTroubleCodes();
      final previous = state.result;
      if (mounted &&
          previous != null &&
          (outcome.outcome == DtcClearOutcome.cleared ||
              outcome.outcome == DtcClearOutcome.partial)) {
        state = state.copyWith(
          result: DiagnosticScanResult(
            protocol: previous.protocol,
            vin: previous.vin,
            milStatus: outcome.remaining.isNotEmpty,
            dtcCount: outcome.remaining.length,
            supportedSensorsCount: previous.supportedSensorsCount,
            activeDtcs: outcome.remaining,
            pendingDtcs: const [],
            permanentDtcs: previous.permanentDtcs,
            // Readiness monitors restart after a clear.
            imReadiness: const {},
            scanTimestamp: previous.scanTimestamp,
            odometerKm: previous.odometerKm,
            activeDtcsRead: true,
          ),
        );
      }
      return outcome;
    } finally {
      if (mounted) state = state.copyWith(clearing: false);
    }
  }
}

final diagnosticScanProvider =
    StateNotifierProvider<DiagnosticScanNotifier, DiagnosticScanState>(
  (ref) => DiagnosticScanNotifier(ref),
);
