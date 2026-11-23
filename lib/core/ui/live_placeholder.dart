import 'package:flutter/material.dart';

import 'connection_status_bar.dart';
import 'empty_state.dart';
import 'tokens.dart';

/// What a live screen shows without a link: the one connection bar (with its
/// Hubungkan button) and what will appear here once connected.
class LivePlaceholder extends StatelessWidget {
  const LivePlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.xs,
        AppSpacing.screen,
        AppSpacing.xl,
      ),
      children: [
        const ConnectionStatusBar(),
        EmptyState(icon: icon, title: title, message: message),
      ],
    );
  }
}
