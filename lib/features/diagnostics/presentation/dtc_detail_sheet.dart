import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/dtc_repository.dart';
import '../domain/dtc_model.dart';
import 'dtc_display.dart';

/// Explanation of one trouble code: what it means, symptoms, causes and what
/// to do. The same sheet serves scan results and the code dictionary.
Future<void> showDtcDetailSheet(BuildContext context, String code) {
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) => _DtcDetail(code: code),
  );
}

class _DtcDetail extends StatelessWidget {
  const _DtcDetail({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dtc = DtcRepository.getCodeInfo(code);
    final known = DtcRepository.isKnown(code);
    return AppSheet(
      title: dtc.code,
      subtitle: dtcSummary(code),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusChip(dtcLevel(dtc.severity), label: dtc.severity.label),
              Chip(label: Text(dtcCategoryLabel(dtc.category))),
            ],
          ),
          if (known) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(dtc.title, style: text.bodySmall),
            _Section(title: 'Gejala', items: dtc.symptoms),
            _Section(title: 'Kemungkinan penyebab', items: dtc.possibleCauses),
            _Section(title: 'Yang bisa dilakukan', items: dtc.recommendations),
          ] else
            _Section(
              title: 'Yang bisa dilakukan',
              items: const [
                'Catat kodenya, lalu periksakan ke bengkel.',
                'Jangan hapus kode sebelum diperiksa: bengkel butuh kode itu.',
              ],
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: text.titleSmall)),
          const SizedBox(height: AppSpacing.xs),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: text.bodyMedium),
                  Expanded(child: Text(item, style: text.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
