import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bluetooth/obd_service.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/obd_connection_sheet.dart';
import '../../shell/shell_screen.dart';
import 'settings_provider.dart';

/// Build stamp set by tool/build_verified.sh; shown so a tester can tell
/// which build runs.
const _srcRev = String.fromEnvironment('SRC_REV');

/// Pengaturan: the car, the connection, the simulator and about. Rows keep
/// their titles whatever their value; values are edited in sheets.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _readingFromCar = false;

  Future<void> _readFromCar() async {
    if (_readingFromCar) return;
    setState(() => _readingFromCar = true);
    String message;
    try {
      final result =
          await ref.read(settingsProvider.notifier).syncVehicleIdentityFromEcu();
      message = result.message;
    } catch (_) {
      message = 'Gagal membaca dari mobil. Periksa koneksi adapter.';
    } finally {
      if (mounted) setState(() => _readingFromCar = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editText({
    required String title,
    required String initial,
    required ValueChanged<String> onSave,
  }) async {
    final value = await showAppSheet<String>(
      context: context,
      builder: (_) => _EditValueSheet(title: title, initial: initial),
    );
    if (value != null) onSave(value);
  }

  Future<void> _editKm({
    required String title,
    required double initial,
    String? helper,
    required ValueChanged<double> onSave,
  }) async {
    final value = await showAppSheet<String>(
      context: context,
      builder: (_) => _EditValueSheet(
        title: title,
        // 0 is a value not entered yet: the field starts empty.
        initial: initial > 0 ? Fmt.number(initial) : '',
        suffix: 'km',
        helper: helper,
        number: true,
      ),
    );
    final km = value == null ? null : _parseKm(value);
    if (km != null) onSave(km);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final canReadFromCar = ref.watch(
      obdServiceProvider.select(
        (s) => s.status == ObdStatus.connected && !s.isSimulatorMode,
      ),
    );

    // ObdState changes many times per second while polling, so only status
    // transitions may raise a snackbar.
    ref.listen<ObdStatus>(obdServiceProvider.select((s) => s.status), (
      previous,
      next,
    ) {
      if (next == previous) return;
      final state = ref.read(obdServiceProvider);
      if (next == ObdStatus.error && state.errorMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      } else if (next == ObdStatus.connected && !state.isSimulatorMode) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Terhubung ke ${state.connectedDeviceName ?? 'adapter OBD'}'),
        ));
      }
    });

    final oilLeft = settings.nextOilOdometer - settings.currentOdometer;
    const notEntered = 'Belum diisi';

    return Scaffold(
      appBar: AppBar(
        // Reached through Beranda's gear when the bar has no Pengaturan tab.
        leading: ShellLayout.settingsInBarOf(context)
            ? null
            : BackButton(onPressed: () => context.go('/health')),
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.xl,
        ),
        children: [
          const SectionHeader('Mobil'),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.directions_car_outlined,
                title: 'Nama mobil',
                subtitle: settings.vehicleName,
                onTap: () => _editText(
                  title: 'Nama mobil',
                  initial: settings.vehicleName,
                  onSave: notifier.updateVehicleName,
                ),
              ),
              SettingsRow(
                icon: Icons.speed_outlined,
                title: 'Odometer',
                subtitle: 'Dibaca dari mobil bila didukung, atau ubah manual.',
                value: settings.hasOdometer
                    ? Fmt.km(settings.currentOdometer)
                    : notEntered,
                onTap: () => _editKm(
                  title: 'Odometer',
                  initial: settings.currentOdometer,
                  helper: 'Samakan dengan angka di dasbor mobil.',
                  onSave: notifier.updateOdometer,
                ),
              ),
              SettingsRow(
                icon: Icons.oil_barrel_outlined,
                title: 'Ganti oli berikutnya',
                subtitle: !settings.hasOilSchedule
                    ? 'Isi agar diingatkan saat waktunya ganti oli.'
                    : !settings.hasOdometer
                        ? 'Isi odometer untuk menghitung sisanya.'
                        : oilLeft >= 0
                            ? 'Sisa ${Fmt.km(oilLeft)}'
                            : 'Lewat ${Fmt.km(-oilLeft)} dari jadwal',
                value: settings.hasOilSchedule
                    ? Fmt.km(settings.nextOilOdometer)
                    : notEntered,
                onTap: () => _editKm(
                  title: 'Ganti oli berikutnya',
                  initial: settings.nextOilOdometer,
                  helper: 'Otomatis +5.000 km setiap mencatat ganti oli.',
                  onSave: notifier.updateNextOilOdometer,
                ),
              ),
              if (settings.vehicleVin.isNotEmpty)
                SettingsRow(
                  icon: Icons.badge_outlined,
                  title: 'Nomor rangka (VIN)',
                  subtitle: settings.vehicleVin,
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: OutlinedButton.icon(
                  onPressed:
                      canReadFromCar && !_readingFromCar ? _readFromCar : null,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(_readingFromCar
                      ? 'Membaca dari mobil…'
                      : 'Baca nama & odometer dari mobil'),
                ),
              ),
            ],
          ),
          const SectionHeader('Koneksi'),
          SettingsGroup(
            children: [
              _ConnectionRow(onManage: () => showObdConnectionSheet(context, ref)),
              SettingsSwitchRow(
                icon: Icons.bluetooth_searching_rounded,
                title: 'Hubungkan otomatis',
                subtitle: 'Hubungkan ke adapter terakhir saat aplikasi dibuka.',
                value: settings.autoConnectOBD,
                onChanged: notifier.setAutoConnectOBD,
              ),
            ],
          ),
          const SectionHeader('Simulator'),
          SettingsGroup(
            children: [
              SettingsSwitchRow(
                icon: Icons.science_outlined,
                title: 'Mode simulator',
                subtitle: 'Data contoh tanpa adapter, untuk mencoba aplikasi.',
                value: settings.isSimulatorMode,
                onChanged: (v) => notifier.setSimulatorMode(v),
              ),
              if (settings.isSimulatorMode) ...[
                SettingsSwitchRow(
                  icon: Icons.power_settings_new_rounded,
                  title: 'Mesin hidup',
                  subtitle: 'Kunci kontak dan mesin dalam simulasi.',
                  value: settings.isIgnitionOn,
                  onChanged: notifier.setIgnitionOn,
                ),
                _SimulatorTrigger(
                  icon: Icons.thermostat_rounded,
                  title: 'Mesin terlalu panas',
                  subtitle: 'Suhu mesin naik ke sekitar 109 °C.',
                  selector: (s) => s.simHighTemp,
                  onChanged: (v) => ref
                      .read(obdServiceProvider.notifier)
                      .configureSimulator(hasHighTemp: v),
                ),
                _SimulatorTrigger(
                  icon: Icons.battery_alert_rounded,
                  title: 'Aki lemah',
                  subtitle: 'Tegangan aki turun ke sekitar 11,4 V.',
                  selector: (s) => s.simLowVoltage,
                  onChanged: (v) => ref
                      .read(obdServiceProvider.notifier)
                      .configureSimulator(hasLowVoltage: v),
                ),
                _SimulatorTrigger(
                  icon: Icons.warning_amber_rounded,
                  title: 'Lampu Check Engine',
                  subtitle: 'Menambahkan kode contoh P0138.',
                  selector: (s) => s.simHasDtc,
                  onChanged: (v) => ref
                      .read(obdServiceProvider.notifier)
                      .configureSimulator(injectedDtcs: v ? ['P0138'] : []),
                ),
              ],
            ],
          ),
          const SectionHeader('Tentang'),
          SettingsGroup(
            children: [
              const SettingsRow(
                icon: Icons.lock_outline_rounded,
                title: 'Data Anda',
                subtitle: 'Semua data tersimpan di HP ini. Aplikasi tidak '
                    'memakai internet.',
              ),
              SettingsRow(
                icon: Icons.description_outlined,
                title: 'Lisensi',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'AutoCare',
                  applicationVersion: _srcRev.isEmpty ? null : _srcRev,
                ),
              ),
              if (_srcRev.isNotEmpty)
                SettingsRow(
                  icon: Icons.build_circle_outlined,
                  title: 'Versi build',
                  subtitle: _srcRev,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              'AutoCare',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// "161.420", "161420" or "161 420 km" as kilometres.
double? _parseKm(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : double.tryParse(digits);
}

class _ConnectionRow extends ConsumerWidget {
  const _ConnectionRow({required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(
      obdServiceProvider.select(
        (s) => (
          status: s.status,
          sim: s.isSimulatorMode,
          name: s.connectedDeviceName,
          detail: s.statusDetail,
          error: s.errorMessage,
        ),
      ),
    );
    final lastAddress = ref.watch(settingsProvider.select((s) => s.lastOBDAddress));
    final (IconData icon, String title, String subtitle) = switch (link.status) {
      _ when link.sim => (
          Icons.science_outlined,
          'Mode simulator',
          'Matikan simulator untuk memakai adapter.',
        ),
      ObdStatus.connected => (
          Icons.bluetooth_connected_rounded,
          'Terhubung',
          link.name ?? 'Adapter OBD',
        ),
      ObdStatus.connecting || ObdStatus.initializing => (
          Icons.bluetooth_searching_rounded,
          'Menghubungkan…',
          link.detail ?? link.name ?? 'Adapter OBD',
        ),
      ObdStatus.error => (
          Icons.error_outline_rounded,
          'Gagal terhubung',
          link.error ?? 'Buka Kelola untuk langkah perbaikan.',
        ),
      ObdStatus.disconnected => (
          Icons.bluetooth_disabled_rounded,
          'Belum terhubung',
          lastAddress.isEmpty
              ? 'Pilih atau pasangkan adapter OBD.'
              : 'Adapter terakhir: $lastAddress',
        ),
    };
    return SettingsRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onManage,
      trailing: TextButton(onPressed: onManage, child: const Text('Kelola')),
    );
  }
}

class _SimulatorTrigger extends ConsumerWidget {
  const _SimulatorTrigger({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selector,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool Function(ObdState) selector;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSwitchRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: ref.watch(obdServiceProvider.select(selector)),
      onChanged: onChanged,
    );
  }
}

/// Edits one value; pops with the text, or nothing when cancelled.
class _EditValueSheet extends StatefulWidget {
  const _EditValueSheet({
    required this.title,
    required this.initial,
    this.suffix,
    this.helper,
    this.number = false,
  });

  final String title;
  final String initial;
  final String? suffix;
  final String? helper;
  final bool number;

  @override
  State<_EditValueSheet> createState() => _EditValueSheetState();
}

class _EditValueSheetState extends State<_EditValueSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: AppSheet(
        title: widget.title,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(onPressed: _save, child: const Text('Simpan')),
        ],
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: widget.number ? TextInputType.number : TextInputType.text,
          inputFormatters: widget.number
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _save(),
          decoration: InputDecoration(
            suffixText: widget.suffix,
            helperText: widget.helper,
          ),
          validator: (v) {
            final text = (v ?? '').trim();
            if (text.isEmpty) return 'Tidak boleh kosong.';
            if (widget.number && (_parseKm(text) ?? 0) <= 0) {
              return 'Isi angka kilometer.';
            }
            return null;
          },
        ),
      ),
    );
  }
}
