import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bluetooth/obd_service.dart';
import '../widgets/live_obd.dart';
import '../widgets/obd_connection_sheet.dart';
import 'app_card.dart';
import 'status.dart';
import 'tokens.dart';

/// The connection fields the bar shows. Selecting only these keeps it from
/// rebuilding on every telemetry update.
typedef ConnectionView = ({
  ObdStatus status,
  bool isSimulator,
  String? deviceName,
  String? errorMessage,
  String? statusDetail,
});

ConnectionView connectionViewOf(ObdState s) => (
      status: s.status,
      isSimulator: s.isSimulatorMode,
      deviceName: s.connectedDeviceName,
      errorMessage: s.errorMessage,
      statusDetail: s.statusDetail,
    );

/// The one connection status of the app, used by every screen that needs a
/// link. Tapping it opens the connection sheet.
class ConnectionStatusBar extends ConsumerWidget {
  const ConnectionStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ObdSelect<ConnectionView>(
      selector: connectionViewOf,
      builder: (context, view, _) => ConnectionStatusCard(
        view: view,
        onTap: () => showObdConnectionSheet(context, ref),
      ),
    );
  }
}

/// Presentation of [ConnectionView], without providers (testable alone).
class ConnectionStatusCard extends StatelessWidget {
  const ConnectionStatusCard({
    super.key,
    required this.view,
    required this.onTap,
  });

  final ConnectionView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = AppStatusColors.of(context);
    final busy = view.status == ObdStatus.connecting ||
        view.status == ObdStatus.initializing;

    late final IconData icon;
    late final Color iconColor;
    late final Color iconBackground;
    late final String title;
    late final String subtitle;
    Widget? action;

    if (view.isSimulator) {
      icon = Icons.science_rounded;
      iconColor = scheme.onPrimaryContainer;
      iconBackground = scheme.primaryContainer;
      title = 'Mode simulator';
      subtitle = 'Data contoh, bukan dari mobil';
    } else if (busy) {
      icon = Icons.bluetooth_searching_rounded;
      iconColor = scheme.onPrimaryContainer;
      iconBackground = scheme.primaryContainer;
      title = 'Menghubungkan…';
      subtitle = view.statusDetail ?? view.deviceName ?? 'Adapter OBD';
    } else if (view.status == ObdStatus.connected) {
      icon = Icons.bluetooth_connected_rounded;
      iconColor = status.ok;
      iconBackground = status.okContainer;
      title = 'Terhubung';
      subtitle = view.deviceName ?? 'Adapter OBD';
    } else if (view.status == ObdStatus.error) {
      icon = Icons.error_rounded;
      iconColor = status.kritis;
      iconBackground = status.kritisContainer;
      title = 'Gagal terhubung';
      subtitle = view.errorMessage ?? 'Periksa adapter, lalu coba lagi.';
      action = FilledButton.tonal(onPressed: onTap, child: const Text('Coba lagi'));
    } else {
      icon = Icons.bluetooth_disabled_rounded;
      iconColor = scheme.onSurfaceVariant;
      iconBackground = scheme.surfaceContainerHighest;
      title = 'Belum terhubung';
      subtitle = 'Hubungkan adapter OBD untuk melihat data mobil.';
      action = FilledButton(onPressed: onTap, child: const Text('Hubungkan'));
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          action ??
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
