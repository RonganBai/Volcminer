import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/domain/entities/scan_target_mode.dart';
import 'package:volcminer/domain/entities/scan_view.dart';
import 'package:volcminer/presentation/controllers/settings_controller.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';
import 'package:volcminer/presentation/widgets/scan_view_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final _cidrController = TextEditingController();
  final _startIpController = TextEditingController();
  final _endIpController = TextEditingController();
  final _viewSearchController = TextEditingController();
  String _viewSearchQuery = '';

  @override
  void dispose() {
    _cidrController.dispose();
    _startIpController.dispose();
    _endIpController.dispose();
    _viewSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanViewState = ref.watch(scanViewControllerProvider);
    final settingsState = ref.watch(settingsControllerProvider);
    final scanTargetMode = ref.watch(scanTargetModeProvider);
    final filteredViews = scanViewState.views.where((view) {
      if (_viewSearchQuery.isEmpty) {
        return true;
      }
      final q = _viewSearchQuery.toLowerCase();
      return view.cidr.toLowerCase().contains(q) ||
          view.startIp.toLowerCase().contains(q) ||
          view.endIp.toLowerCase().contains(q);
    }).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildScanModeSection(scanTargetMode),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            initiallyExpanded: false,
            title: const Text(
              'Miner Auth',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _buildCredentialFields(settingsState),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            initiallyExpanded: false,
            title: const Text(
              'Add Scan View',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _buildScanViewEntry(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildSelectionMode(scanViewState.mode),
        const SizedBox(height: 8),
        TextField(
          controller: _viewSearchController,
          decoration: const InputDecoration(
            labelText: 'Search IP Block',
            hintText: '例如 100.16',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              _viewSearchQuery = value.trim();
            });
          },
        ),
        const SizedBox(height: 8),
        ...filteredViews.map(
          (view) => ScanViewCard(
            view: view,
            selected: scanViewState.selectedIds.contains(view.id),
            onTap: () => ref
                .read(scanViewControllerProvider.notifier)
                .toggleSelected(view.id),
            onDelete: () => ref
                .read(scanViewControllerProvider.notifier)
                .deleteView(view.id),
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

  Widget _buildScanModeSection(ScanTargetMode mode) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan Type',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('全段扫描'),
                  selected: mode == ScanTargetMode.full,
                  onSelected: (_) =>
                      ref.read(scanTargetModeProvider.notifier).state =
                          ScanTargetMode.full,
                ),
                ChoiceChip(
                  label: const Text('已知扫描'),
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
                  ? '当前会扫描所选 IP 段里的完整范围，例如 1-255。'
                  : '当前只扫描结果页中该 IP 段已经记录过的矿机 IP，不再扫描完整 256 个地址。',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialFields(SettingsState settingsState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: settingsState.settings.minerUsername,
          decoration: const InputDecoration(
            labelText: 'Miner Username',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) async {
            final next = settingsState.settings.copyWith(
              minerUsername: value,
            );
            await ref.read(settingsControllerProvider.notifier).updateSettings(next);
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: settingsState.minerAuthPassword,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Miner Password',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            ref.read(settingsControllerProvider.notifier).saveMinerAuthPassword(value);
          },
        ),
      ],
    );
  }

  Widget _buildScanViewEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _cidrController,
          decoration: const InputDecoration(
            labelText: 'IP Block (optional)',
            hintText: 'example 172.100.1',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _startIpController,
                decoration: const InputDecoration(
                  labelText: 'Start IP / Host (optional)',
                  hintText: '1 or 172.100.1.1',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _endIpController,
                decoration: const InputDecoration(
                  labelText: 'End IP / Host (optional)',
                  hintText: '255 or 172.100.1.255',
                  border: OutlineInputBorder(),
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
              final normalizedCidr = cidr.isEmpty
                  ? ''
                  : IpUtils.normalizeCidrInput(cidr);
              final cidrBaseIp = normalizedCidr?.split('/').first;
              final startIp = _startIpController.text.trim();
              final endIp = _endIpController.text.trim();
              final normalizedStart = startIp.isEmpty
                  ? ''
                  : IpUtils.normalizeIpv4WithBase(
                      startIp,
                      baseIp: cidrBaseIp,
                    );
              final normalizedEnd = endIp.isEmpty
                  ? ''
                  : IpUtils.normalizeIpv4WithBase(
                      endIp,
                      baseIp: cidrBaseIp,
                    );
              if (cidr.isNotEmpty && normalizedCidr == null) {
                _showError('Invalid IP Block format');
                return;
              }
              if ((startIp.isNotEmpty && normalizedStart == null) ||
                  (endIp.isNotEmpty && normalizedEnd == null)) {
                _showError(
                  'Invalid start/end IP format. You can use full IP or host suffix with IP Block.',
                );
                return;
              }
              if (normalizedStart != null &&
                  normalizedEnd != null &&
                  IpUtils.ipToInt(normalizedStart) >
                      IpUtils.ipToInt(normalizedEnd)) {
                _showError('Start IP must be less than or equal to End IP.');
                return;
              }
              final resolvedName =
                  normalizedCidr?.split('/').first ??
                  normalizedStart ??
                  normalizedEnd ??
                  'IP Block';
              await ref.read(scanViewControllerProvider.notifier).addView(
                    name: resolvedName,
                    cidr: normalizedCidr ?? '',
                    startIp: normalizedStart ?? '',
                    endIp: normalizedEnd ?? '',
                    tags: const [],
                  );
              _cidrController.clear();
              _startIpController.clear();
              _endIpController.clear();
            },
            child: const Text('Add View'),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionMode(SelectionMode mode) {
    return Row(
      children: [
        const Text('Selection Mode:'),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Single'),
          selected: mode == SelectionMode.single,
          onSelected: (_) => ref
              .read(scanViewControllerProvider.notifier)
              .setMode(SelectionMode.single),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Multi'),
          selected: mode == SelectionMode.multi,
          onSelected: (_) => ref
              .read(scanViewControllerProvider.notifier)
              .setMode(SelectionMode.multi),
        ),
      ],
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
