import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/domain/entities/scan_target_mode.dart';
import 'package:volcminer/domain/entities/scan_view.dart';
import 'package:volcminer/presentation/controllers/settings_controller.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';
import 'package:volcminer/presentation/widgets/scan_view_card.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final _cidrController = TextEditingController();
  final _startIpController = TextEditingController(text: '1');
  final _endIpController = TextEditingController(text: '255');
  final _batchStartController = TextEditingController(text: '1');
  final _batchEndController = TextEditingController(text: '20');
  final _viewSearchController = TextEditingController();
  String _viewSearchQuery = '';
  bool _batchAddEnabled = false;

  @override
  void dispose() {
    _cidrController.dispose();
    _startIpController.dispose();
    _endIpController.dispose();
    _batchStartController.dispose();
    _batchEndController.dispose();
    _viewSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanViewState = ref.watch(scanViewControllerProvider);
    final settingsState = ref.watch(settingsControllerProvider);
    final scanTargetMode = ref.watch(scanTargetModeProvider);
    final l10n = AppLocalizer(ref);
    final filteredViews = scanViewState.views.where((view) {
      if (_viewSearchQuery.isEmpty) {
        return true;
      }
      final q = _viewSearchQuery.toLowerCase();
      final displayBlock = IpUtils.formatIpBlockLabel(
        view.cidr.isNotEmpty ? view.cidr : view.startIp,
      ).toLowerCase();
      return displayBlock.contains(q);
    }).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildScanModeSection(scanTargetMode, l10n),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            initiallyExpanded: false,
            title: Text(
              l10n.t('dashboard.minerAuth'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _buildCredentialFields(settingsState, l10n),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            initiallyExpanded: false,
            title: Text(
              l10n.t('dashboard.addScanView'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _buildScanViewEntry(l10n),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _viewSearchController,
          decoration: InputDecoration(
            labelText: l10n.t('dashboard.searchIpBlock'),
            hintText: l10n.t('dashboard.searchIpBlockHint'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _viewSearchQuery.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _viewSearchController.clear();
                      setState(() {
                        _viewSearchQuery = '';
                      });
                    },
                    tooltip: l10n.t('common.clearInput'),
                    icon: const Icon(Icons.clear),
                  ),
          ),
          onChanged: (value) {
            setState(() {
              _viewSearchQuery = value.trim();
            });
          },
        ),
        const SizedBox(height: 12),
        _buildSelectionMode(scanViewState.mode, l10n),
        const SizedBox(height: 8),
        ...filteredViews.map(
          (view) => ScanViewCard(
            view: view,
            selected: scanViewState.selectedIds.contains(view.id),
            onTap: () => ref
                .read(scanViewControllerProvider.notifier)
                .toggleSelected(view.id),
            onDelete: () => _confirmDeleteView(view, l10n),
          ),
        ),
        if (scanViewState.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              scanViewState.error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildScanModeSection(ScanTargetMode mode, AppLocalizer l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('dashboard.scanType'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.t('dashboard.scanType.full')),
                  selected: mode == ScanTargetMode.full,
                  onSelected: (_) =>
                      ref.read(scanTargetModeProvider.notifier).state =
                          ScanTargetMode.full,
                ),
                ChoiceChip(
                  label: Text(l10n.t('dashboard.scanType.known')),
                  selected: mode == ScanTargetMode.known,
                  onSelected: (_) =>
                      ref.read(scanTargetModeProvider.notifier).state =
                          ScanTargetMode.known,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              mode == ScanTargetMode.full
                  ? l10n.t('dashboard.scanType.fullDesc')
                  : l10n.t('dashboard.scanType.knownDesc'),
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialFields(SettingsState settingsState, AppLocalizer l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: settingsState.settings.minerUsername,
          decoration: InputDecoration(
            labelText: l10n.t('dashboard.minerUsername'),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) async {
            final next = settingsState.settings.copyWith(minerUsername: value);
            await ref.read(settingsControllerProvider.notifier).updateSettings(next);
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: settingsState.minerAuthPassword,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.t('dashboard.minerPassword'),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            ref.read(settingsControllerProvider.notifier).saveMinerAuthPassword(value);
          },
        ),
      ],
    );
  }

  Widget _buildScanViewEntry(AppLocalizer l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _cidrController,
          decoration: InputDecoration(
            labelText: _batchAddEnabled
                ? l10n.t('dashboard.baseIpBlock')
                : l10n.t('dashboard.ipBlockOptional'),
            hintText: _batchAddEnabled
                ? l10n.t('dashboard.baseIpBlockHint')
                : l10n.t('dashboard.ipBlockHint'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _batchAddEnabled,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.t('dashboard.batchAddTitle')),
          subtitle: Text(l10n.t('dashboard.batchAddSubtitle')),
          onChanged: (value) {
            setState(() {
              _batchAddEnabled = value ?? false;
            });
          },
        ),
        if (_batchAddEnabled) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _batchStartController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.t('dashboard.batchStart'),
                    hintText: '1',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _batchEndController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.t('dashboard.batchEnd'),
                    hintText: '20',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _startIpController,
                decoration: InputDecoration(
                  labelText: l10n.t('dashboard.startIp'),
                  hintText: l10n.t('dashboard.startIpHint'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _endIpController,
                decoration: InputDecoration(
                  labelText: l10n.t('dashboard.endIp'),
                  hintText: l10n.t('dashboard.endIpHint'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () async {
              final cidr = _cidrController.text.trim();
              if (_batchAddEnabled) {
                await _addBatchViews(cidr, l10n);
                return;
              }
              final normalizedCidr = cidr.isEmpty
                  ? ''
                  : IpUtils.normalizeCidrInput(cidr);
              final cidrBaseIp = normalizedCidr?.split('/').first;
              final startIp = _startIpController.text.trim();
              final endIp = _endIpController.text.trim();
              final normalizedStart = startIp.isEmpty
                  ? ''
                  : IpUtils.normalizeIpv4WithBase(startIp, baseIp: cidrBaseIp);
              final normalizedEnd = endIp.isEmpty
                  ? ''
                  : IpUtils.normalizeIpv4WithBase(endIp, baseIp: cidrBaseIp);
              if (cidr.isNotEmpty && normalizedCidr == null) {
                _showError(l10n.t('dashboard.error.invalidIpBlock'));
                return;
              }
              if ((startIp.isNotEmpty && normalizedStart == null) ||
                  (endIp.isNotEmpty && normalizedEnd == null)) {
                _showError(l10n.t('dashboard.error.invalidRange'));
                return;
              }
              if (normalizedStart != null &&
                  normalizedEnd != null &&
                  IpUtils.ipToInt(normalizedStart) > IpUtils.ipToInt(normalizedEnd)) {
                _showError(l10n.t('dashboard.error.startGreaterThanEnd'));
                return;
              }
              final resolvedName = normalizedCidr?.split('/').first ??
                  normalizedStart ??
                  normalizedEnd ??
                  l10n.t('dashboard.defaultViewName');
              await ref.read(scanViewControllerProvider.notifier).addView(
                    name: resolvedName,
                    cidr: normalizedCidr ?? '',
                    startIp: normalizedStart ?? '',
                    endIp: normalizedEnd ?? '',
                    tags: const [],
                  );
              _cidrController.clear();
              _startIpController.text = '1';
              _endIpController.text = '255';
            },
            child: Text(
              _batchAddEnabled
                  ? l10n.t('dashboard.batchAdd')
                  : l10n.t('dashboard.addView'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addBatchViews(String rawBase, AppLocalizer l10n) async {
    final baseParts = rawBase
        .trim()
        .split('.')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (baseParts.length != 2) {
      _showError(l10n.t('dashboard.error.batchBase'));
      return;
    }
    final first = int.tryParse(baseParts[0]);
    final second = int.tryParse(baseParts[1]);
    final batchStart = int.tryParse(_batchStartController.text.trim());
    final batchEnd = int.tryParse(_batchEndController.text.trim());
    if (first == null ||
        second == null ||
        first < 0 ||
        first > 255 ||
        second < 0 ||
        second > 255) {
      _showError(l10n.t('dashboard.error.batchBaseInvalid'));
      return;
    }
    if (batchStart == null ||
        batchEnd == null ||
        batchStart < 0 ||
        batchStart > 255 ||
        batchEnd < 0 ||
        batchEnd > 255 ||
        batchStart > batchEnd) {
      _showError(l10n.t('dashboard.error.batchRangeInvalid'));
      return;
    }

    final notifier = ref.read(scanViewControllerProvider.notifier);
    for (var third = batchStart; third <= batchEnd; third++) {
      final block = '$first.$second.$third';
      final normalizedCidr = IpUtils.normalizeCidrInput(block);
      if (normalizedCidr == null) {
        continue;
      }
      await notifier.addView(
        name: block,
        cidr: normalizedCidr,
        startIp: '$first.$second.$third.${_startIpController.text.trim()}',
        endIp: '$first.$second.$third.${_endIpController.text.trim()}',
        tags: const [],
      );
    }

    _cidrController.clear();
    _batchStartController.text = '1';
    _batchEndController.text = '20';
    _startIpController.text = '1';
    _endIpController.text = '255';
  }

  Widget _buildSelectionMode(SelectionMode mode, AppLocalizer l10n) {
    return Row(
      children: [
        Text(l10n.t('dashboard.selectionMode')),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Text(l10n.t('dashboard.selectionMode.single')),
          selected: mode == SelectionMode.single,
          onSelected: (_) => ref
              .read(scanViewControllerProvider.notifier)
              .setMode(SelectionMode.single),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Text(l10n.t('dashboard.selectionMode.multi')),
          selected: mode == SelectionMode.multi,
          onSelected: (_) => ref
              .read(scanViewControllerProvider.notifier)
              .setMode(SelectionMode.multi),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () =>
              ref.read(scanViewControllerProvider.notifier).selectAll(),
          child: Text(l10n.t('dashboard.selectionMode.selectAll')),
        ),
      ],
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDeleteView(ScanView view, AppLocalizer l10n) async {
    final displayBlock = IpUtils.formatIpBlockLabel(
      view.cidr.isNotEmpty ? view.cidr : view.startIp,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.t('view.deleteTitle')),
          content: Text(
            l10n.t('view.deleteMessage', params: {'scope': displayBlock}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('common.delete')),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      await ref.read(scanViewControllerProvider.notifier).deleteView(view.id);
    }
  }
}
