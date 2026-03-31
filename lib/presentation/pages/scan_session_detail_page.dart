import 'package:volcminer/core/utils/abnormal_miner_utils.dart';
import 'package:volcminer/core/utils/hashrate_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/eastern_time_utils.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/scan_segment_record.dart';
import 'package:volcminer/domain/entities/tracked_miner.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/localization/legacy_zh_texts.dart';
import 'package:volcminer/presentation/localization/issue_localizer.dart';
import 'package:volcminer/presentation/pages/miner_detail_page.dart';
import 'package:volcminer/presentation/pages/multi_pool_config_page.dart';
import 'package:volcminer/presentation/pages/pool_config_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

enum _SegmentFilter { all, online, unresponsive, abnormal, offline, retired }

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
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip(
                            l10n.t('segment.filter.all'),
                            _SegmentFilter.all,
                            color: const Color(0xFF2F67D8),
                            icon: Icons.apps_rounded,
                          ),
                          const SizedBox(width: 8),
                          _filterChip(
                            l10n.t('segment.filter.online'),
                            _SegmentFilter.online,
                            color: const Color(0xFF2EAF62),
                            icon: Icons.wifi_rounded,
                          ),
                          const SizedBox(width: 8),
                          _filterChip(
                            l10n.t('segment.filter.unresponsive'),
                            _SegmentFilter.unresponsive,
                            color: const Color(0xFFF0A21C),
                            icon: Icons.portable_wifi_off_rounded,
                          ),
                          const SizedBox(width: 8),
                          _filterChip(
                            l10n.t('segment.filter.abnormal'),
                            _SegmentFilter.abnormal,
                            color: const Color(0xFFD77700),
                            icon: Icons.warning_amber_rounded,
                          ),
                          const SizedBox(width: 8),
                          _filterChip(
                            l10n.t('segment.filter.offline'),
                            _SegmentFilter.offline,
                            color: const Color(0xFFE15B64),
                            icon: Icons.power_off_rounded,
                          ),
                          const SizedBox(width: 8),
                          _filterChip(
                            l10n.t('segment.filter.retired'),
                            _SegmentFilter.retired,
                            color: const Color(0xFF6F748B),
                            icon: Icons.inventory_2_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_selectionMode) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FBF9),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE1ECE7)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2EAF62,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(
                                    Icons.checklist_rounded,
                                    color: Color(0xFF2EAF62),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.t(
                                      'segment.selected',
                                      params: {
                                        'count': _selectedVisibleCount(
                                          miners,
                                        ).toString(),
                                      },
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF243042),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: miners.isEmpty
                                      ? null
                                      : () => _toggleSelectAll(miners),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(l10n.t('segment.selectAll')),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedIps.clear();
                                      _selectionMode = false;
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(l10n.t('segment.cancelSelect')),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _BatchActionButton(
                                    label: _batchBusy
                                        ? l10n.t('segment.batchLedOnBusy')
                                        : l10n.t('segment.batchLedOn'),
                                    icon: Icons.lightbulb_outline,
                                    busy: _batchBusy,
                                    filled: true,
                                    onPressed:
                                        _batchBusy || _selectedIps.isEmpty
                                        ? null
                                        : () => _confirmBatchLedOn(
                                            context,
                                            credential,
                                            l10n,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _BatchActionButton(
                                    label: _batchOffBusy
                                        ? l10n.t('segment.batchLedOffBusy')
                                        : l10n.t('segment.batchLedOff'),
                                    icon: Icons.lightbulb_circle_outlined,
                                    busy: _batchOffBusy,
                                    tonal: true,
                                    onPressed:
                                        _batchOffBusy || _selectedIps.isEmpty
                                        ? null
                                        : () => _confirmBatchLedOff(
                                            context,
                                            credential,
                                            l10n,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _BatchActionButton(
                                    label: l10n.t(
                                      'segment.poolConfig',
                                      params: {
                                        'count': _selectedIps.length.toString(),
                                      },
                                    ),
                                    icon: Icons.swap_horiz_outlined,
                                    onPressed: _selectedIps.isEmpty
                                        ? null
                                        : () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) {
                                                  final targetIps = _selectedIps
                                                      .toList(growable: false);
                                                  if (targetIps.length <= 1) {
                                                    return PoolConfigPage(
                                                      targetIps: targetIps,
                                                    );
                                                  }
                                                  return MultiPoolConfigPage(
                                                    targetIps: targetIps,
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _BatchActionButton(
                                    label: _batchClearBusy
                                        ? l10n.t('segment.batchClearBusy')
                                        : l10n.t('segment.batchClear'),
                                    icon: Icons.cleaning_services_outlined,
                                    busy: _batchClearBusy,
                                    onPressed:
                                        _batchClearBusy || _selectedIps.isEmpty
                                        ? null
                                        : () => _confirmBatchAction(
                                            context: context,
                                            title: l10n.t(
                                              'segment.confirmClearTitle',
                                            ),
                                            message: l10n.t(
                                              'segment.confirmClearMessage',
                                              params: {
                                                'count': _selectedIps.length
                                                    .toString(),
                                              },
                                            ),
                                            cancelLabel: l10n.t(
                                              'common.cancel',
                                            ),
                                            confirmLabel: l10n.t(
                                              'common.confirm',
                                            ),
                                            busySetter: (value) => setState(
                                              () => _batchClearBusy = value,
                                            ),
                                            action: () => ref
                                                .read(
                                                  scanControllerProvider
                                                      .notifier,
                                                )
                                                .clearRefineForIps(
                                                  _selectedIps.toList(
                                                    growable: false,
                                                  ),
                                                  credential,
                                                ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: _BatchActionButton(
                                label: _batchRebootBusy
                                    ? l10n.t('segment.batchRebootBusy')
                                    : l10n.t('segment.batchReboot'),
                                icon: Icons.restart_alt,
                                busy: _batchRebootBusy,
                                filled: true,
                                onPressed:
                                    _batchRebootBusy || _selectedIps.isEmpty
                                    ? null
                                    : () => _confirmBatchAction(
                                        context: context,
                                        title: l10n.t(
                                          'segment.confirmRebootTitle',
                                        ),
                                        message: l10n.t(
                                          'segment.confirmRebootMessage',
                                          params: {
                                            'count': _selectedIps.length
                                                .toString(),
                                          },
                                        ),
                                        cancelLabel: l10n.t('common.cancel'),
                                        confirmLabel: l10n.t('common.confirm'),
                                        busySetter: (value) => setState(
                                          () => _batchRebootBusy = value,
                                        ),
                                        action: () => ref
                                            .read(
                                              scanControllerProvider.notifier,
                                            )
                                            .rebootForIps(
                                              _selectedIps.toList(
                                                growable: false,
                                              ),
                                              credential,
                                            ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      const Text(
                        LegacyZhTexts.segmentLongPressHint,
                        style: TextStyle(
                          color: Color(0xFF6F748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: miners.length,
              itemBuilder: (context, index) {
                final miner = miners[index];
                final selected = _selectedIps.contains(miner.ip);
                final ledActive = ledActiveIps.contains(miner.ip);
                final showDroppedBoardBadge = miner.hasDroppedBoardIssue;
                final showUnstableBadge =
                    (miner.state == TrackedMinerState.offline ||
                        miner.state == TrackedMinerState.pendingRetire) &&
                    miner.offlineEventCount >= 3;
                final issueBadgeLabel = miner.diagnosis == null
                    ? null
                    : IssueLocalizer.shortBadge(l10n, miner.diagnosis!);
                final tile = Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: ledActive
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_selectionMode) ...[
                                  Checkbox(
                                    value: selected,
                                    onChanged: (_) =>
                                        _toggleItemSelection(miner.ip),
                                  ),
                                  const SizedBox(width: 6),
                                ] else ...[
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF2F67D8,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.memory_rounded,
                                      color: Color(0xFF2F67D8),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        miner.ip,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n.t(
                                          'overview.scope',
                                          params: {
                                            'scope': currentSegment.scope,
                                          },
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xFF6F748B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _SegmentStatusPill(
                                      label: _stateLabel(miner, l10n),
                                      color: _statusPillColor(miner),
                                    ),
                                    if (ledActive) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF5E6),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          l10n.t('segment.ledOnTag'),
                                          style: const TextStyle(
                                            color: Color(0xFFD77700),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            if (showDroppedBoardBadge ||
                                showUnstableBadge ||
                                issueBadgeLabel != null) ...[
                              const SizedBox(height: 10),
                              _SegmentMinerBadges(
                                showUnstableBadge: showUnstableBadge,
                                showDroppedBoardBadge: showDroppedBoardBadge,
                                issueBadgeLabel: issueBadgeLabel,
                                l10n: l10n,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _SegmentMinerInfoTile(
                                    icon: Icons.flash_on_rounded,
                                    color: const Color(0xFF2F67D8),
                                    label:
                                        LegacyZhTexts.minerFiveSecondHashrate,
                                    value: miner.runtime.ghs5s,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _SegmentMinerInfoTile(
                                    icon: Icons.update_rounded,
                                    color: const Color(0xFF6F748B),
                                    label: LegacyZhTexts.segmentLastScan,
                                    value: EasternTimeUtils.format(
                                      miner.runtime.fetchedAt,
                                      pattern: 'yyyy-MM-dd HH:mm:ss',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _HashrateBar(miner: miner),
                            if (miner.diagnosis != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                IssueLocalizer.reason(l10n, miner.diagnosis!),
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (IssueLocalizer.snippetSummary(
                                    l10n,
                                    miner.diagnosis!,
                                  ) !=
                                  null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  IssueLocalizer.snippetSummary(
                                    l10n,
                                    miner.diagnosis!,
                                  )!,
                                  style: const TextStyle(
                                    color: Color(0xFF6F748B),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
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
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                    ),
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

  Widget _filterChip(
    String label,
    _SegmentFilter value, {
    required Color color,
    required IconData icon,
  }) {
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: _filter == value ? color : color.withValues(alpha: 0.8),
      ),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: _filter == value ? color : const Color(0xFF6F748B),
        ),
      ),
      selected: _filter == value,
      showCheckmark: false,
      selectedColor: color.withValues(alpha: 0.14),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: _filter == value
            ? color.withValues(alpha: 0.35)
            : const Color(0xFFCDD5E1),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
    return miners
        .where((miner) {
          return switch (_filter) {
            _SegmentFilter.all => true,
            _SegmentFilter.online => miner.state == TrackedMinerState.online,
            _SegmentFilter.unresponsive =>
              miner.state == TrackedMinerState.unresponsive,
            _SegmentFilter.abnormal => AbnormalMinerUtils.isAbnormal(miner),
            _SegmentFilter.offline => miner.state == TrackedMinerState.offline,
            _SegmentFilter.retired =>
              miner.state == TrackedMinerState.pendingRetire,
          };
        })
        .toList(growable: false)
      ..sort((a, b) => IpUtils.ipToInt(a.ip).compareTo(IpUtils.ipToInt(b.ip)));
  }

  String _stateLabel(TrackedMiner miner, AppLocalizer l10n) {
    if (_filter == _SegmentFilter.abnormal) {
      return l10n.t('segment.filter.abnormal');
    }
    return switch (miner.state) {
      TrackedMinerState.online => l10n.t('segment.filter.online'),
      TrackedMinerState.unresponsive => l10n.t('segment.filter.unresponsive'),
      TrackedMinerState.offline => l10n.t('segment.filter.offline'),
      _ => l10n.t('segment.filter.retired'),
    };
  }
}

class _BatchActionButton extends StatelessWidget {
  const _BatchActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.filled = false,
    this.tonal = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool filled;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = busy
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 16);

    final Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );

    final ButtonStyle style =
        (filled || tonal
                ? FilledButton.styleFrom()
                : OutlinedButton.styleFrom())
            .copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(122, 34)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              ),
              backgroundColor: tonal
                  ? const WidgetStatePropertyAll(Color(0xFFEAF3FF))
                  : null,
              foregroundColor: tonal
                  ? const WidgetStatePropertyAll(Color(0xFF2F67D8))
                  : null,
            );

    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: onPressed, style: style, child: child),
      );
    }
    if (tonal) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.tonal(
          onPressed: onPressed,
          style: style,
          child: child,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: onPressed, style: style, child: child),
    );
  }
}

class _HashrateBar extends StatelessWidget {
  const _HashrateBar({required this.miner});

  final TrackedMiner miner;
  static const double _maxDisplayGh = 16;

  @override
  Widget build(BuildContext context) {
    final hashrate = HashrateUtils.effectiveGh(
      miner.runtime.ghs5s,
      miner.runtime.ghsav,
    );
    final clamped = hashrate.clamp(0, _maxDisplayGh).toDouble();
    final ratio = _maxDisplayGh <= 0 ? 0.0 : (clamped / _maxDisplayGh);
    final isZero = hashrate <= 0;

    return Container(
      width: double.infinity,
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: isZero
            ? [
                BoxShadow(
                  color: Colors.redAccent.withValues(alpha: 0.45),
                  blurRadius: 8,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black, width: 1.4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final currentWidth = constraints.maxWidth * ratio;
              return Stack(
                children: [
                  Container(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFE53935),
                          Color(0xFFFDD835),
                          Color(0xFF43A047),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: constraints.maxWidth - currentWidth,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

Color _statusPillColor(TrackedMiner miner) {
  return switch (miner.state) {
    TrackedMinerState.online => const Color(0xFF2EAF62),
    TrackedMinerState.unresponsive => const Color(0xFFF0A21C),
    TrackedMinerState.offline => const Color(0xFFE15B64),
    _ => const Color(0xFF6F748B),
  };
}

class _SegmentStatusPill extends StatelessWidget {
  const _SegmentStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SegmentMinerInfoTile extends StatelessWidget {
  const _SegmentMinerInfoTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6F748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentMinerBadges extends StatelessWidget {
  const _SegmentMinerBadges({
    required this.showUnstableBadge,
    required this.showDroppedBoardBadge,
    required this.issueBadgeLabel,
    required this.l10n,
  });

  final bool showUnstableBadge;
  final bool showDroppedBoardBadge;
  final String? issueBadgeLabel;
  final AppLocalizer l10n;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      if (issueBadgeLabel != null)
        _MinerBadge(label: issueBadgeLabel!, color: Colors.redAccent),
      if (showDroppedBoardBadge)
        _MinerBadge(
          label: l10n.t('segment.badge.droppedBoard'),
          color: Colors.deepOrange,
        ),
      if (showUnstableBadge)
        _MinerBadge(
          label: l10n.t('segment.badge.unstable'),
          color: Colors.orange,
        ),
    ];
    return Wrap(spacing: 6, runSpacing: 6, children: badges);
  }
}

class _MinerBadge extends StatelessWidget {
  const _MinerBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
