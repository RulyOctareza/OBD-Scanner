import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/dtc_repository.dart';
import '../domain/dtc_model.dart';
import 'diagnostic_scanner_screen.dart';

/// Category filter: label shown and the repository's category name.
const List<(String, String?)> _categories = [
  ('Semua', null),
  ('Mesin', 'Powertrain'),
  ('Sasis', 'Chassis'),
  ('Bodi', 'Body'),
  ('Jaringan', 'Network'),
];

final RegExp _codePattern = RegExp(r'^[PCBU][0-9A-F]{4}$');

/// Diagnostik › Kamus kode: search the dictionary by code or symptom; each
/// code opens the same explanation sheet as a scan result.
class DtcLookupScreen extends StatefulWidget {
  const DtcLookupScreen({super.key});

  @override
  State<DtcLookupScreen> createState() => _DtcLookupScreenState();
}

class _DtcLookupScreenState extends State<DtcLookupScreen> {
  final TextEditingController _search = TextEditingController();
  String? _category;
  List<DtcCode> _results = DtcRepository.getAllCodes();

  void _update() {
    setState(() {
      _results = DtcRepository.searchCodes(
        _search.text,
        categoryFilter: _category ?? 'Semua',
      );
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final query = _search.text.trim().toUpperCase();
    // A well-formed code that is not in the dictionary still opens its
    // sheet, with the generic advice.
    final unknownCode = _codePattern.hasMatch(query) &&
            !DtcRepository.isKnown(query)
        ? query
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const SegmentSwitch(
          segments: diagnosticSegments,
          current: '/dtc_lookup',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.xs,
              AppSpacing.screen,
              AppSpacing.md,
            ),
            child: TextField(
              controller: _search,
              onChanged: (_) => _update(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari kode atau gejala, mis. P0300',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          _update();
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
              children: [
                for (final (label, category) in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _category == category,
                      onSelected: (_) {
                        _category = category;
                        _update();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              children: [
                if (unknownCode != null) ...[
                  SettingsGroup(children: [DtcRow(code: unknownCode)]),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_results.isEmpty && unknownCode == null)
                  const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Kode tidak ditemukan',
                    message: 'Kamus berisi kode yang paling umum. Ketik kode '
                        'lengkap, mis. P0420, untuk melihat saran umumnya.',
                  )
                else if (_results.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.xs,
                      bottom: AppSpacing.sm,
                    ),
                    child: Text('${_results.length} kode', style: text.bodySmall),
                  ),
                  SettingsGroup(
                    children: [
                      for (final dtc in _results) DtcRow(code: dtc.code),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
