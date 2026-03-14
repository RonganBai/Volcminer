import 'package:volcminer/core/utils/hashrate_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/scan_segment_record.dart';
import 'package:volcminer/domain/entities/tracked_miner.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/pages/miner_detail_page.dart';
import 'package:volcminer/presentation/pages/pool_config_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

enum _SegmentFilter { all, online, unresponsive, offline, retired }

class ScanSessionDetailPage extends ConsumerStatefulWidget {
  const ScanSessionDetailPage({super.key, required this.segment});

  final ScanSegmentRecord segment;

  @override
  ConsumerState<ScanSessionDetailPage> createState() =>
      _ScanSessionDetailPageState();
}

class _ScanSessionDetailPageState extends ConsumerState<ScanSessionDetailPage> {
  _SegmentFilter _filter = _SegmentFilter.all;
  final Set<String> _selectedIps = <String>{};
  bool _selectionMode = false;
  bool _batchBusy = false;
  bool _batchOffBusy = false;
  bool _batchClearBusy = false;
  bool _batchRebootBusy = false;

  @override
  Widget build(BuildContext context) {
    final currentSegment = ref.watch(
      scanControllerProvider.select(
        (state) => state.segments.firstWhere(
          (segment) => segment.scope == widget.segment.scope,
          orElse: () => widget.segment,
        ),
      ),
    );
    final miners = _visibleMiners(currentSegment.miners);
    final ledActiveIps = ref.watch(
      scanControllerProvider.select((state) => state.ledActiveIps),
    );
    final settingsState = ref.watch(settingsControllerProvider);
    final credential = MinerCredential(
      username: settingsState.settings.minerUsername,
      password: settingsState.minerAuthPassword,
    );
    final displayScope = IpUtils.formatIpBlockLabel(currentSegment.scope);
    final l10n = AppLocalizer(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('segment.title', params: {'scope': displayScope})),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t(
                    'segment.lastScan',
                    params: {
                      'time':
                          DateFormat('yyyy-MM-dd HH:mm:ss').format(currentSegment.updatedAt),
                    },
                  ),
                ),
                Text(l10n.t('results.ipBlock', params: {'scope': displayScope})),
                Text(
                  l10n.t(
                    'segment.onlineCount',
                    params: {'count': currentSegment.onlineCount.toString()},
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip(l10n.t('segment.filter.all'), _SegmentFilter.all),
                    _filterChip(
                      l10n.t('segment.filter.online'),
                      _SegmentFilter.online,
                    ),
                    _filterChip(
                      l10n.t('segment.filter.unresponsive'),
                      _SegmentFilter.unresponsive,
                    ),
                    _filterChip(
                      l10n.t('segment.filter.offline'),
                      _SegmentFilter.offline,
                    ),
                    _filterChip(
                      l10n.t('segment.filter.retired'),
                      _SegmentFilter.retired,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_selectionMode) ...[
                  Row(
                    children: [
                      Text(
                        l10n.t(
                          'segment.selected',
                          params: {
                            'count': _selectedVisibleCount(miners).toString(),
                          },
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: miners.isEmpty ? null : () => _toggleSelectAll(miners),
                        child: Text(l10n.t('segment.selectAll')),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedIps.clear();
                            _selectionMode = false;
                          });
                        },
                        child: Text(l10n.t('segment.cancelSelect')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _batchBusy || _selectedIps.isEmpty
                              ? null
                              : () => _confirmBatchLedOn(context, credential, l10n),
                          icon: _batchBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.lightbulb_outline),
                          label: Text(
                            _batchBusy
                                ? l10n.t('segment.batchLedOnBusy')
                                : l10n.t('segment.batchLedOn'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _batchOffBusy || _selectedIps.isEmpty
                              ? null
                              : () => _confirmBatchLedOff(context, credential, l10n),
                          icon: _batchOffBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.lightbulb_circle_outlined),
                          label: Text(
                            _batchOffBusy
                                ? l10n.t('segment.batchLedOffBusy')
                                : l10n.t('segment.batchLedOff'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectedIps.isEmpty
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => PoolConfigPage(
                                        targetIps: _selectedIps.toList(growable: false),
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.swap_horiz_outlined),
                          label: Text(
                            l10n.t(
                              'segment.poolConfig',
                              params: {'count': _selectedIps.length.toString()},
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _batchClearBusy || _selectedIps.isEmpty
                              ? null
                              : () => _confirmBatchAction(
                                  context: context,
                                  title: l10n.t('segment.confirmClearTitle'),
                                  message: l10n.t(
                                    'segment.confirmClearMessage',
                                    params: {'count': _selectedIps.length.toString()},
                                  ),
                                  cancelLabel: l10n.t('common.cancel'),
                                  confirmLabel: l10n.t('common.confirm'),
                                  busySetter: (value) =>
                                      setState(() => _batchClearBusy = value),
                                  action: () => ref
                                      .read(scanControllerProvider.notifier)
                                      .clearRefineForIps(
                                        _selectedIps.toList(growable: false),
                                        credential,
                                      ),
                                ),
                          icon: _batchClearBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cleaning_services_outlined),
                          label: Text(
                            _batchClearBusy
                                ? l10n.t('segment.batchClearBusy')
                                : l10n.t('segment.batchClear'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _batchRebootBusy || _selectedIps.isEmpty
                          ? null
                          : () => _confirmBatchAction(
                              context: context,
                              title: l10n.t('segment.confirmRebootTitle'),
                              message: l10n.t(
                                'segment.confirmRebootMessage',
                                params: {'count': _selectedIps.length.toString()},
                              ),
                              cancelLabel: l10n.t('common.cancel'),
                              confirmLabel: l10n.t('common.confirm'),
                              busySetter: (value) =>
                                  setState(() => _batchRebootBusy = value),
                              action: () => ref
                                  .read(scanControllerProvider.notifier)
                                  .rebootForIps(
                                    _selectedIps.toList(growable: false),
                                    credential,
                                  ),
                            ),
                      icon: _batchRebootBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restart_alt),
                      label: Text(
                        _batchRebootBusy
                            ? l10n.t('segment.batchRebootBusy')
                            : l10n.t('segment.batchReboot'),
                      ),
                    ),
                  ),
                ] else
                  Text(
                    l10n.t('segment.longPressHint'),
                    style: const TextStyle(color: Colors.black54),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: miners.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final miner = miners[index];
                final selected = _selectedIps.contains(miner.ip);
                final ledActive = ledActiveIps.contains(miner.ip);
                final tile = Container(
                  color: ledActive
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    leading: _selectionMode
                        ? Checkbox(
                            value: selected,
                            onChanged: (_) => _toggleItemSelection(miner.ip),
                          )
                        : null,
                    title: Text(miner.ip),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (miner.state == TrackedMinerState.online) ...[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  '${_stateLabel(miner, l10n)} | ${miner.runtime.ghs5s}/${miner.runtime.ghsav} | Last seen ${DateFormat('MM-dd HH:mm').format(miner.runtime.fetchedAt)}${ledActive ? ' | ${l10n.t('segment.ledOnTag')}' : ''}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _HashrateBar(miner: miner),
                          if (miner.diagnosis != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              l10n.t(
                                'segment.issueReason',
                                params: {'reason': miner.diagnosis!.reason},
                              ),
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.t(
                                'segment.issueSolution',
                                params: {'solution': miner.diagnosis!.solution},
                              ),
                              style: const TextStyle(color: Colors.black54),
                            ),
                            if (miner.diagnosis!.secondaryReason != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                l10n.t(
                                  'segment.issueSecondary',
                                  params: {
                                    'reason': miner.diagnosis!.secondaryReason!,
                                  },
                                ),
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    trailing: _selectionMode
                        ? Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                          )
                        : const Icon(Icons.chevron_right),
                    selected: _selectionMode && selected,
                    onLongPress: () {
                      setState(() {
                        _selectionMode = true;
                        _selectedIps.add(miner.ip);
                      });
                    },
                    onTap: () {
                      if (_selectionMode) {
                        _toggleItemSelection(miner.ip);
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MinerDetailPage(miner: miner),
                        ),
                      );
                    },
                  ),
                );

                if (!miner.canDelete) {
                  return tile;
                }

                return Dismissible(
                  key: ValueKey('${currentSegment.scope}-${miner.ip}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: Colors.red.shade400,
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: Text(l10n.t('segment.deleteMiner')),
                          content: Text(
                            l10n.t(
                              'segment.deleteMinerMessage',
                              params: {'ip': miner.ip},
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: Text(l10n.t('common.cancel')),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: Text(l10n.t('common.delete')),
                            ),
                          ],
                        );
                      },
                    );
                    return confirmed == true;
                  },
                  onDismissed: (_) {
                    ref
                        .read(scanControllerProvider.notifier)
                        .deleteSegmentMiner(currentSegment.scope, miner.ip);
                  },
                  child: tile,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  ChoiceChip _filterChip(String label, _SegmentFilter value) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Future<void> _confirmBatchLedOn(
    BuildContext context,
    MinerCredential credential,
    AppLocalizer l10n,
  ) async {
    await _confirmBatchAction(
      context: context,
      title: l10n.t('segment.confirmLedOnTitle'),
      message: l10n.t(
        'segment.confirmLedOnMessage',
        params: {'count': _selectedIps.length.toString()},
      ),
      cancelLabel: l10n.t('common.cancel'),
      confirmLabel: l10n.t('common.confirm'),
      busySetter: (value) => setState(() => _batchBusy = value),
      action: () => ref.read(scanControllerProvider.notifier).toggleLedForIps(
            _selectedIps.toList(growable: false),
            true,
            credential,
          ),
    );
  }

  Future<void> _confirmBatchLedOff(
    BuildContext context,
    MinerCredential credential,
    AppLocalizer l10n,
  ) async {
    await _confirmBatchAction(
      context: context,
      title: l10n.t('segment.confirmLedOffTitle'),
      message: l10n.t(
        'segment.confirmLedOffMessage',
        params: {'count': _selectedIps.length.toString()},
      ),
      cancelLabel: l10n.t('common.cancel'),
      confirmLabel: l10n.t('common.confirm'),
      busySetter: (value) => setState(() => _batchOffBusy = value),
      action: () => ref.read(scanControllerProvider.notifier).toggleLedForIps(
            _selectedIps.toList(growable: false),
            false,
            credential,
          ),
    );
  }

  Future<void> _confirmBatchAction({
    required BuildContext context,
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
    required void Function(bool value) busySetter,
    required Future<dynamic> Function() action,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    busySetter(true);
    final result = await action();
    if (!mounted) {
      return;
    }
    busySetter(false);
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }

  int _selectedVisibleCount(List<TrackedMiner> miners) {
    final visibleIps = miners.map((miner) => miner.ip).toSet();
    return _selectedIps.where(visibleIps.contains).length;
  }

  void _toggleSelectAll(List<TrackedMiner> miners) {
    setState(() {
      final visibleIps = miners.map((miner) => miner.ip).toSet();
      if (visibleIps.isNotEmpty && visibleIps.every(_selectedIps.contains)) {
        _selectedIps.removeAll(visibleIps);
      } else {
        _selectedIps.addAll(visibleIps);
        _selectionMode = true;
      }
      if (_selectedIps.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _toggleItemSelection(String ip) {
    setState(() {
      _selectionMode = true;
      if (_selectedIps.contains(ip)) {
        _selectedIps.remove(ip);
      } else {
        _selectedIps.add(ip);
      }
      if (_selectedIps.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  List<TrackedMiner> _visibleMiners(List<TrackedMiner> miners) {
    return miners.where((miner) {
      return switch (_filter) {
        _SegmentFilter.all => true,
        _SegmentFilter.online => miner.state == TrackedMinerState.online,
        _SegmentFilter.unresponsive =>
          miner.state == TrackedMinerState.unresponsive,
        _SegmentFilter.offline => miner.state == TrackedMinerState.offline,
        _SegmentFilter.retired => miner.state == TrackedMinerState.retired,
      };
    }).toList(growable: false)
      ..sort((a, b) => IpUtils.ipToInt(a.ip).compareTo(IpUtils.ipToInt(b.ip)));
  }

  String _stateLabel(TrackedMiner miner, AppLocalizer l10n) {
    return switch (miner.state) {
      TrackedMinerState.online => l10n.t('segment.filter.online'),
      TrackedMinerState.unresponsive => l10n.t('segment.filter.unresponsive'),
      TrackedMinerState.offline => l10n.t('segment.filter.offline'),
      _ => l10n.t('segment.filter.retired'),
    };
  }
}

class _HashrateBar extends StatelessWidget {
  const _HashrateBar({required this.miner});

  final TrackedMiner miner;

  @override
  Widget build(BuildContext context) {
    final hashrate = HashrateUtils.effectiveGh(miner.runtime.ghs5s, miner.runtime.ghsav);
    final color = hashrate > 11000
        ? Colors.green
        : hashrate > 5000
            ? Colors.amber
            : Colors.red;
    final widthFactor = (hashrate / 15000).clamp(0.08, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 6,
        color: Colors.black12,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            child: Container(color: color),
          ),
        ),
      ),
    );
  }

}
