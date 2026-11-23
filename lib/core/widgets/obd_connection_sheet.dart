import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../bluetooth/bluetooth_access.dart';
import '../bluetooth/obd_service.dart';
import '../../features/settings/presentation/settings_provider.dart';
import '../ui/app_sheet.dart';

/// Shared OBD connection bottom sheet used across Health, Meter, Sensor,
/// Diagnostics and Settings.
Future<void> showObdConnectionSheet(BuildContext context, WidgetRef ref) {
  // Root navigator, theme shape and drag handle, and the system bar insets
  // all come from showAppSheet.
  return showAppSheet<void>(
    context: context,
    builder: (_) => const _ObdConnectionSheet(),
  );
}

/// The connection fields the sheet renders. Selecting only these keeps the
/// sheet from rebuilding on every telemetry tick while connected.
typedef _LinkView = ({
  ObdStatus status,
  String? statusDetail,
  String? errorMessage,
  String? errorHelp,
  String? deviceName,
  String? deviceAddress,
  bool isSimulator,
});

_LinkView _linkView(ObdState s) => (
  status: s.status,
  statusDetail: s.statusDetail,
  errorMessage: s.errorMessage,
  errorHelp: s.errorHelp,
  deviceName: s.connectedDeviceName,
  deviceAddress: s.connectedDeviceAddress,
  isSimulator: s.isSimulatorMode,
);

bool _isBusy(ObdStatus status) =>
    status == ObdStatus.connecting || status == ObdStatus.initializing;

class _ObdConnectionSheet extends ConsumerStatefulWidget {
  const _ObdConnectionSheet();

  @override
  ConsumerState<_ObdConnectionSheet> createState() =>
      _ObdConnectionSheetState();
}

class _ObdConnectionSheetState extends ConsumerState<_ObdConnectionSheet> {
  // Android 11 and older skip discovery without any error while Location is
  // off: no result and no finish event ever arrive. The sheet checks shortly
  // after starting that the platform really scans, and caps every scan.
  static const _scanStartCheck = Duration(seconds: 3);
  static const _scanLimit = Duration(seconds: 20);

  late final ObdService _obd;
  late final BluetoothDiscovery _discovery;

  StreamSubscription<BluetoothDiscoveryResult>? _scanSub;
  Timer? _scanWatchdog;
  bool _scanning = false;
  bool _scanFinished = false;
  String? _scanMessage;
  BluetoothReadiness? _scanBlockedBy;
  final Map<String, BluetoothDiscoveryResult> _found = {};
  String? _pairingAddress;

  @override
  void initState() {
    super.initState();
    _obd = ref.read(obdServiceProvider.notifier);
    _discovery = ref.read(bluetoothDiscoveryProvider);
    _obd.holdAutoConnect();
  }

  @override
  void dispose() {
    _stopScan(updateUi: false);
    _obd.releaseAutoConnect();
    super.dispose();
  }

  // ---------------------------------------------------------------- actions

  void _connect(BluetoothDevice device) {
    _stopScan();
    unawaited(_obd.connectToDevice(device));
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    setState(() {
      _scanMessage = null;
      _scanBlockedBy = null;
      _scanFinished = false;
      _found.clear();
    });

    final readiness = await _discovery.check();
    if (!mounted) return;
    if (readiness != BluetoothReadiness.ready) {
      setState(() => _scanBlockedBy = readiness);
      return;
    }

    setState(() => _scanning = true);
    _scanSub = _discovery.start().listen(
      (result) {
        final device = result.device;
        if (device.isBonded || !isOfferableAdapter(device)) return;
        if (!mounted) return;
        setState(() => _found[device.address] = result);
      },
      onError: (Object e) {
        _cancelScanWatchdog();
        if (!mounted) return;
        final noPermission = e is PlatformException && e.code == 'no_permissions';
        setState(() {
          _scanning = false;
          _scanFinished = true;
          _scanMessage = noPermission
              ? 'Di Android 11 ke bawah, mencari perangkat baru butuh izin '
                    'Lokasi. Izinkan lalu coba lagi.'
              : 'Pencarian gagal: $e';
        });
      },
      onDone: () {
        _cancelScanWatchdog();
        if (!mounted) return;
        setState(() {
          _scanning = false;
          _scanFinished = true;
        });
      },
    );
    _scanWatchdog = Timer(_scanStartCheck, _checkScanStarted);
  }

  Future<void> _checkScanStarted() async {
    if (!mounted || !_scanning) return;
    if (_found.isNotEmpty || await _discovery.isRunning()) {
      if (!mounted || !_scanning) return;
      _scanWatchdog = Timer(_scanLimit - _scanStartCheck, _stopScan);
      return;
    }
    final locationOff = await _discovery.isLocationServiceOff();
    if (!mounted || !_scanning) return;
    _stopScan(
      message: locationOff
          ? 'Lokasi HP mati. Di Android 11 ke bawah, mencari adapter baru '
                'butuh Lokasi. Nyalakan Lokasi, lalu ketuk Cari lagi.'
          : 'Pencarian tidak dimulai oleh sistem. Matikan lalu nyalakan lagi '
                'Bluetooth, lalu ketuk Cari lagi.',
    );
  }

  void _cancelScanWatchdog() {
    _scanWatchdog?.cancel();
    _scanWatchdog = null;
  }

  void _stopScan({bool updateUi = true, String? message}) {
    _cancelScanWatchdog();
    final sub = _scanSub;
    _scanSub = null;
    if (sub != null) {
      unawaited(sub.cancel());
      unawaited(_discovery.stop());
    }
    if (updateUi && mounted && _scanning) {
      setState(() {
        _scanning = false;
        _scanFinished = true;
        _scanMessage = message;
      });
    }
  }

  Future<void> _pairAndConnect(BluetoothDevice device) async {
    _stopScan();
    setState(() {
      _pairingAddress = device.address;
      _scanMessage = null;
    });
    bool paired = false;
    String? failure;
    try {
      paired = await BluetoothAccess.pair(device.address);
    } catch (e) {
      failure = '$e';
    }
    if (!mounted) return;
    setState(() {
      _pairingAddress = null;
      if (paired) {
        _found.remove(device.address);
      } else {
        _scanMessage = failure == null
            ? 'Gagal memasangkan ${device.name ?? device.address}. '
                  'Pastikan PIN benar (biasanya 1234 atau 0000) lalu coba lagi.'
            : 'Gagal memasangkan: $failure';
      }
    });
    if (paired) {
      ref.invalidate(obdDeviceListProvider);
      _connect(device);
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final link = ref.watch(obdServiceProvider.select(_linkView));
    final isSimulatorPref = ref.watch(
      settingsProvider.select((s) => s.isSimulatorMode),
    );

    ref.listen<ObdStatus>(obdServiceProvider.select((s) => s.status), (
      previous,
      next,
    ) {
      if (next == ObdStatus.connected &&
          previous != null &&
          _isBusy(previous) &&
          !ref.read(obdServiceProvider).isSimulatorMode) {
        HapticFeedback.lightImpact();
        final navigator = Navigator.of(context);
        final route = ModalRoute.of(context);
        // Let the success state register before the sheet goes away.
        Future.delayed(const Duration(milliseconds: 1100), () {
          if (mounted && (route?.isCurrent ?? false)) navigator.pop();
        });
      }
    });

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Adapter OBD',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                if (!link.isSimulator)
                  IconButton(
                    tooltip: 'Muat ulang daftar',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => ref.invalidate(obdDeviceListProvider),
                  ),
                IconButton(
                  tooltip: 'Tutup',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mode simulator'),
                    subtitle: const Text('Data contoh tanpa adapter'),
                    value: isSimulatorPref,
                    onChanged: (val) {
                      _stopScan();
                      ref.read(settingsProvider.notifier).setSimulatorMode(val);
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  if (link.isSimulator)
                    const _SimulatorNotice()
                  else ...[
                    if (link.status != ObdStatus.disconnected) ...[
                      _LinkStatusCard(
                        link: link,
                        onCancel: _obd.cancelConnect,
                        onDisconnect: _obd.disconnect,
                        onRetry: link.deviceAddress == null
                            ? null
                            : () => _connect(
                                BluetoothDevice(
                                  name: link.deviceName,
                                  address: link.deviceAddress!,
                                ),
                              ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    _buildBondedSection(link),
                    const SizedBox(height: AppSpacing.lg),
                    _buildDiscoverySection(link),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBondedSection(_LinkView link) {
    return ref
        .watch(obdDeviceListProvider)
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => _NoticeCard(
            icon: Icons.error_outline_rounded,
            color: AppColors.danger,
            title: 'Gagal memuat perangkat Bluetooth',
            body: '$err',
            actionLabel: 'Coba lagi',
            onAction: () => ref.invalidate(obdDeviceListProvider),
          ),
          data: (list) {
            final blocked = _readinessNotice(
              list.readiness,
              onResolved: () => ref.invalidate(obdDeviceListProvider),
            );
            if (blocked != null) return blocked;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionLabel('Adapter yang dipasangkan'),
                if (list.likely.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'Belum ada adapter OBD yang dipasangkan. Cari adapter '
                      'baru di bawah, atau pilih dari perangkat lain.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  for (final device in list.likely)
                    _DeviceTile(
                      device: device,
                      link: link,
                      isLastUsed: device.address == list.lastUsedAddress,
                      highlight: true,
                      onConnect: () => _connect(device),
                      onDisconnect: _obd.disconnect,
                    ),
                if (list.others.isNotEmpty)
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      initiallyExpanded: list.likely.isEmpty,
                      title: Text(
                        'Perangkat Bluetooth lain (${list.others.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      children: [
                        for (final device in list.others)
                          _DeviceTile(
                            device: device,
                            link: link,
                            isLastUsed: false,
                            highlight: false,
                            onConnect: () => _connect(device),
                            onDisconnect: _obd.disconnect,
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
  }

  Widget _buildDiscoverySection(_LinkView link) {
    final found = _found.values.toList()
      ..sort((a, b) {
        final aObd = isLikelyObdAdapter(a.device.name);
        final bObd = isLikelyObdAdapter(b.device.name);
        if (aObd != bObd) return aObd ? -1 : 1;
        return b.rssi.compareTo(a.rssi);
      });

    // A "Bluetooth off" block left by an earlier Cari is stale once the bonded
    // list, re-read after Bluetooth came on, reports ready.
    final listReady =
        ref.watch(obdDeviceListProvider).valueOrNull?.readiness ==
        BluetoothReadiness.ready;
    final blockedBy =
        _scanBlockedBy == BluetoothReadiness.bluetoothOff && listReady
        ? null
        : _scanBlockedBy;
    final blocked = blockedBy == null
        ? null
        : _readinessNotice(blockedBy, onResolved: _startScan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionLabel('Perangkat baru')),
            if (_scanning)
              TextButton.icon(
                onPressed: _stopScan,
                icon: const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                label: const Text('Berhenti'),
              )
            else
              TextButton.icon(
                onPressed: _pairingAddress != null || _isBusy(link.status)
                    ? null
                    : _startScan,
                icon: const Icon(Icons.bluetooth_searching_rounded, size: 18),
                label: Text(_scanFinished ? 'Cari lagi' : 'Cari'),
              ),
          ],
        ),
        if (!_scanning && !_scanFinished && blocked == null)
          const Text(
            'Colok adapter ke port OBD, nyalakan kontak, lalu ketuk Cari. '
            'Adapter baru dipasangkan otomatis (PIN 1234).',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ?blocked,
        for (final result in found)
          _DiscoveredTile(
            result: result,
            isPairing: _pairingAddress == result.device.address,
            enabled: _pairingAddress == null && !_isBusy(link.status),
            onTap: () => _pairAndConnect(result.device),
          ),
        if (_scanFinished && found.isEmpty && _scanMessage == null)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Tidak ada perangkat baru ditemukan. Pastikan adapter terpasang '
              'dan kontak ON. Di Android 11 ke bawah, aktifkan juga Lokasi '
              '(GPS).',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        if (_scanMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              _scanMessage!,
              style: const TextStyle(fontSize: 12, color: AppColors.danger),
            ),
          ),
      ],
    );
  }

  /// A card explaining what blocks Bluetooth, with the one action that fixes
  /// it; null when nothing does.
  Widget? _readinessNotice(
    BluetoothReadiness readiness, {
    required VoidCallback onResolved,
  }) {
    switch (readiness) {
      case BluetoothReadiness.ready:
        return null;
      case BluetoothReadiness.unsupported:
        return const _NoticeCard(
          icon: Icons.bluetooth_disabled_rounded,
          color: AppColors.textSecondary,
          title: 'Bluetooth tidak tersedia',
          body:
              'HP ini tidak mendukung Bluetooth Classic. Pakai mode '
              'simulator untuk mencoba aplikasi.',
        );
      case BluetoothReadiness.bluetoothOff:
        return _NoticeCard(
          icon: Icons.bluetooth_disabled_rounded,
          color: AppColors.warning,
          title: 'Bluetooth mati',
          body: 'Nyalakan Bluetooth untuk melihat dan menghubungkan adapter OBD.',
          actionLabel: 'Nyalakan Bluetooth',
          onAction: () async {
            await BluetoothAccess.requestEnable();
            onResolved();
          },
        );
      case BluetoothReadiness.permissionDenied:
        return _NoticeCard(
          icon: Icons.lock_outline_rounded,
          color: AppColors.warning,
          title: 'Izin Bluetooth diperlukan',
          body:
              'AutoCare butuh izin "Perangkat di sekitar" untuk menemukan dan '
              'menghubungkan adapter OBD.',
          actionLabel: 'Izinkan',
          onAction: onResolved,
        );
      case BluetoothReadiness.permissionPermanentlyDenied:
        return _NoticeCard(
          icon: Icons.lock_outline_rounded,
          color: AppColors.danger,
          title: 'Izin Bluetooth ditolak',
          body:
              'Buka Pengaturan Aplikasi > Izin, aktifkan "Perangkat di sekitar", '
              'lalu kembali ke sini.',
          actionLabel: 'Buka Pengaturan Aplikasi',
          onAction: () async {
            await BluetoothAccess.openAppPermissionSettings();
            onResolved();
          },
        );
    }
  }
}

// ------------------------------------------------------------------ widgets

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _LinkStatusCard extends StatefulWidget {
  final _LinkView link;
  final VoidCallback onCancel;
  final VoidCallback onDisconnect;
  final VoidCallback? onRetry;

  const _LinkStatusCard({
    required this.link,
    required this.onCancel,
    required this.onDisconnect,
    required this.onRetry,
  });

  @override
  State<_LinkStatusCard> createState() => _LinkStatusCardState();
}

class _LinkStatusCardState extends State<_LinkStatusCard> {
  bool _showHelp = false;

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final name = link.deviceName ?? 'adapter OBD';
    final Color color;
    final Widget leading;
    final String title;
    final String? subtitle;
    final List<Widget> actions;

    switch (link.status) {
      case ObdStatus.connecting:
      case ObdStatus.initializing:
        color = AppColors.primary;
        leading = const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        );
        title = 'Menghubungkan ke $name';
        subtitle = link.statusDetail;
        actions = [
          TextButton(onPressed: widget.onCancel, child: const Text('Batal')),
        ];
      case ObdStatus.connected:
        color = AppColors.success;
        leading = const Icon(Icons.check_circle_rounded, color: AppColors.success);
        title = 'Terhubung ke $name';
        subtitle = 'Data sensor mulai dibaca.';
        actions = [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            onPressed: widget.onDisconnect,
            child: const Text('Putuskan'),
          ),
        ];
      case ObdStatus.error:
        color = AppColors.danger;
        leading = const Icon(Icons.error_outline_rounded, color: AppColors.danger);
        title = link.errorMessage ?? 'Gagal terhubung';
        subtitle = null;
        actions = [
          if (link.errorHelp != null)
            TextButton(
              onPressed: () => setState(() => _showHelp = !_showHelp),
              child: Text(_showHelp ? 'Tutup langkah' : 'Langkah perbaikan'),
            ),
          if (widget.onRetry != null)
            FilledButton(
              onPressed: widget.onRetry,
              child: const Text('Coba lagi'),
            ),
        ];
      case ObdStatus.disconnected:
        return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppBorderRadius.lgBorder,
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: leading,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          subtitle,
                          key: ValueKey(subtitle),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_isBusy(link.status)) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: color,
                backgroundColor: AppColors.progressBackground,
              ),
            ),
          ],
          if (_showHelp && link.errorHelp != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              link.errorHelp!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final BluetoothDevice device;
  final _LinkView link;
  final bool isLastUsed;
  final bool highlight;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _DeviceTile({
    required this.device,
    required this.link,
    required this.isLastUsed,
    required this.highlight,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final isThis = link.deviceAddress == device.address;
    final isConnected = isThis && link.status == ObdStatus.connected;
    final isConnecting = isThis && _isBusy(link.status);
    final anyBusy = _isBusy(link.status);

    final Widget trailing;
    if (isConnected) {
      trailing = OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: AppColors.danger),
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onDisconnect,
        child: const Text('Putuskan'),
      );
    } else if (isConnecting) {
      trailing = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      trailing = Icon(
        Icons.chevron_right_rounded,
        color: anyBusy
            ? AppColors.textSecondary.withValues(alpha: 0.3)
            : AppColors.textSecondary,
      );
    }

    final iconColor = isConnected
        ? AppColors.success
        : (highlight ? AppColors.primary : AppColors.textSecondary);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: isConnected || !anyBusy,
      onTap: isConnected || anyBusy ? null : onConnect,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isConnected
              ? Icons.bluetooth_connected_rounded
              : Icons.bluetooth_rounded,
          color: iconColor,
          size: 20,
        ),
      ),
      title: Text(
        device.name ?? 'Perangkat tanpa nama',
        style: TextStyle(
          fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        isLastUsed ? 'Terakhir dipakai · ${device.address}' : device.address,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: trailing,
    );
  }
}

class _DiscoveredTile extends StatelessWidget {
  final BluetoothDiscoveryResult result;
  final bool isPairing;
  final bool enabled;
  final VoidCallback onTap;

  const _DiscoveredTile({
    required this.result,
    required this.isPairing,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final device = result.device;
    final likely = isLikelyObdAdapter(device.name);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled || isPairing,
      onTap: enabled ? onTap : null,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (likely ? AppColors.primary : AppColors.textSecondary)
              .withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.bluetooth_searching_rounded,
          size: 20,
          color: likely ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
      title: Text(
        device.name ?? 'Perangkat tanpa nama',
        style: TextStyle(
          fontWeight: likely ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        isPairing ? 'Memasangkan…' : device.address,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: isPairing
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text(
              'Pasangkan',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppBorderRadius.lgBorder,
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SimulatorNotice extends StatelessWidget {
  const _SimulatorNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_rounded, color: AppColors.warning, size: 20),
              SizedBox(width: 8),
              Text(
                'Mode simulator aktif',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Aplikasi memakai data contoh. Matikan mode simulator di '
            'atas untuk menghubungkan adapter OBD.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
              ),
              onPressed: () {
                Navigator.pop(context);
                context.go('/settings');
              },
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Pengaturan simulator'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty-state CTA when OBD is not connected.
class ObdNotConnectedView extends StatelessWidget {
  final ObdState state;
  final VoidCallback onConnect;

  const ObdNotConnectedView({
    super.key,
    required this.state,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final isConnecting = _isBusy(state.status);
    final isError = state.status == ObdStatus.error;

    final String message;
    if (isConnecting) {
      message = state.statusDetail ?? 'Menghubungkan ke adapter OBD…';
    } else if (isError) {
      message = state.errorMessage ?? 'Koneksi terakhir gagal.';
    } else {
      message =
          'Hubungkan adapter OBD atau nyalakan mode simulator untuk melihat data live.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled_rounded,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum terhubung ke mobil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isError ? AppColors.danger : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            if (!isConnecting)
              FilledButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.bluetooth_searching_rounded),
                label: Text(isError ? 'Coba hubungkan lagi' : 'Hubungkan'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            if (isConnecting)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
          ],
        ),
      ),
    );
  }
}
