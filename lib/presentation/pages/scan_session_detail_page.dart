import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/scan_segment_record.dart';
import 'package:volcminer/domain/entities/tracked_miner.dart';
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
    final settingsState = ref.watch(settingsControllerProvider);
    final credential = MinerCredential(
      username: settingsState.settings.minerUsername,
      password: settingsState.minerAuthPassword,
    );

    return Scaffold(
      appBar: AppBar(title: Text('${currentSegment.scope} 搜索详情')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '上次扫描: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(currentSegment.updatedAt)}',
                ),
                Text('IP 段: ${currentSegment.scope}'),
                Text('在线数量: ${currentSegment.onlineCount}'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip('全部', _SegmentFilter.all),
                    _filterChip('在线', _SegmentFilter.online),
                    _filterChip('未响应', _SegmentFilter.unresponsive),
                    _filterChip('离线', _SegmentFilter.offline),
                    _filterChip('下架', _SegmentFilter.retired),
                  ],
                ),
                const SizedBox(height: 12),
                if (_selectionMode) ...[
                  Row(
                    children: [
                      Text('已选择: ${_selectedVisibleCount(miners)}'),
                      const Spacer(),
                      TextButton(
                        onPressed: miners.isEmpty ? null : () => _toggleSelectAll(miners),
                        child: const Text('全选'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedIps.clear();
                            _selectionMode = false;
                          });
                        },
                        child: const Text('取消选择'),
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
                              : () => _confirmBatchLedOn(context, credential),
                          icon: _batchBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.lightbulb_outline),
                          label: Text(_batchBusy ? '批量开灯中...' : '批量开灯'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _batchOffBusy || _selectedIps.isEmpty
                              ? null
                              : () => _confirmBatchLedOff(context, credential),
                          icon: _batchOffBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.lightbulb_circle_outlined),
                          label: Text(_batchOffBusy ? '批量关灯中...' : '批量关灯'),
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
                                        targetIps:
                                            _selectedIps.toList(growable: false),
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.swap_horiz_outlined),
                          label: Text('矿池配置 (${_selectedIps.length})'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _batchClearBusy || _selectedIps.isEmpty
                              ? null
                              : () => _confirmBatchAction(
                                  context: context,
                                  title: '确认批量清除自适应',
                                  message:
                                      '本次将清除 ${_selectedIps.length} 台矿机的自适应，是否继续？',
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cleaning_services_outlined),
                          label: Text(
                            _batchClearBusy ? '批量清除中...' : '批量清除自适应',
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
                              title: '确认批量重启矿机',
                              message: '本次将重启 ${_selectedIps.length} 台矿机，是否继续？',
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
                      label: Text(_batchRebootBusy ? '批量重启中...' : '批量重启矿机'),
                    ),
                  ),
                ] else
                  const Text(
                    '长按单个矿机记录可进入批量选择模式。',
                    style: TextStyle(color: Colors.black54),
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
                final tile = ListTile(
                  leading: _selectionMode
                      ? Checkbox(
                          value: selected,
                          onChanged: (_) => _toggleItemSelection(miner.ip),
                        )
                      : null,
                  title: Text(miner.ip),
                  subtitle: Text(
                    '${miner.stateLabel} | ${miner.runtime.ghs5s}/${miner.runtime.ghsav} | Last seen ${DateFormat('MM-dd HH:mm').format(miner.lastSeenAt)}',
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
                        builder: (_) => MinerDetailPage(item: miner.lastItem),
                      ),
                    );
                  },
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
                          title: const Text('删除矿机'),
                          content: Text('删除 ${miner.ip} 这台下架矿机记录？'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: const Text('删除'),
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
  ) async {
    await _confirmBatchAction(
      context: context,
      title: '确认批量打开指示灯',
      message: '本次将打开 ${_selectedIps.length} 台矿机的指示灯，是否继续？',
      busySetter: (value) => setState(() => _batchBusy = value),
      action: () => ref
          .read(scanControllerProvider.notifier)
          .toggleLedForIps(
            _selectedIps.toList(growable: false),
            true,
            credential,
          ),
    );
  }

  Future<void> _confirmBatchLedOff(
    BuildContext context,
    MinerCredential credential,
  ) async {
    await _confirmBatchAction(
      context: context,
      title: '确认批量关闭指示灯',
      message: '本次将关闭 ${_selectedIps.length} 台矿机的指示灯，是否继续？',
      busySetter: (value) => setState(() => _batchOffBusy = value),
      action: () => ref
          .read(scanControllerProvider.notifier)
          .toggleLedForIps(
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
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认'),
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
    final filtered = miners.where((miner) {
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
    return filtered;
  }
}
