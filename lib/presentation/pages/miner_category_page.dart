import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/abnormal_miner_utils.dart';
import 'package:volcminer/core/utils/eastern_time_utils.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/tracked_miner.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/localization/legacy_zh_texts.dart';
import 'package:volcminer/presentation/localization/issue_localizer.dart';
import 'package:volcminer/presentation/pages/miner_detail_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';
import 'package:volcminer/services/background_scan_service.dart';

class MinerCategoryPage extends ConsumerStatefulWidget {
  const MinerCategoryPage({
    super.key,
    required this.titleKey,
    required this.stateFilter,
    this.titleText,
    this.abnormalGroup,
    this.abnormalType,
  });

  final String titleKey;
  final String stateFilter;
  final String? titleText;
  final String? abnormalGroup;
  final String? abnormalType;

  @override
  ConsumerState<MinerCategoryPage> createState() => _MinerCategoryPageState();
}

class _MinerCategoryPageState extends ConsumerState<MinerCategoryPage> {
  bool _refreshing = false;

  bool _isZeroHashOnline(TrackedMiner miner) {
    return miner.state == TrackedMinerState.online && miner.effectiveHashrate <= 0;
  }

  bool _matchesFilter(TrackedMiner miner) {
    if (widget.stateFilter == 'abnormal') {
      if (!AbnormalMinerUtils.isAbnormal(miner)) {
        return false;
      }
      if (widget.abnormalGroup != null &&
          AbnormalMinerUtils.abnormalGroupOf(miner) != widget.abnormalGroup) {
        return false;
      }
      if (widget.abnormalType != null &&
          AbnormalMinerUtils.abnormalTypeOf(miner) != widget.abnormalType) {
        return false;
      }
      return true;
    }
    if (widget.stateFilter == TrackedMinerState.unresponsive) {
      return miner.state == TrackedMinerState.unresponsive || _isZeroHashOnline(miner);
    }
    return miner.state == widget.stateFilter;
  }

  bool get _showUnstableBadgePage =>
      widget.stateFilter == TrackedMinerState.offline ||
      widget.stateFilter == TrackedMinerState.pendingRetire;

  Future<void> _refreshCategory({bool forceScan = false}) async {
    await ref.read(scanControllerProvider.notifier).loadPersistedState();
    if (!forceScan || !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final foregroundState = ref.read(scanControllerProvider);
    if (foregroundState.isScanning || foregroundState.isPostProcessing) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizer(ref).t('overview.categoryRefreshBusyForeground'),
          ),
        ),
      );
      return;
    }
    final backgroundProgress = await BackgroundScanService.getAutoScanProgress();
    if (backgroundProgress.isRunning) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizer(ref).t('overview.categoryRefreshBusyBackground'),
          ),
        ),
      );
      return;
    }
    final scanState = ref.read(scanControllerProvider);
    final ips = scanState.segments
        .expand((segment) => segment.miners)
        .where(_matchesFilter)
        .map((miner) => miner.ip)
        .toSet()
        .toList(growable: false)
      ..sort(IpUtils.compareIpBlocks);
    if (ips.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizer(ref).t('overview.categoryRefreshEmpty'),
          ),
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizer(ref);
        return AlertDialog(
          title: Text(l10n.t('overview.categoryRefreshTitle')),
          content: Text(
            l10n.t(
              'overview.categoryRefreshBody',
              params: {'count': ips.length.toString()},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('common.confirm')),
            ),
          ],
        );
      },
    );
    if (!mounted || confirmed != true) {
      return;
    }
    final settingsState = ref.read(settingsControllerProvider);
    final credential = MinerCredential(
      username: settingsState.settings.minerUsername,
      password: settingsState.minerAuthPassword,
    );
    final shouldRediagnoseLogs = widget.stateFilter == 'abnormal' &&
        widget.abnormalGroup == AbnormalMinerGroup.hard;
    if (mounted) {
      setState(() => _refreshing = true);
    }
    try {
      await ref.read(scanControllerProvider.notifier).refreshMinerIps(
            ips: ips,
            minerCredential: credential,
            concurrency: settingsState.settings.scanConcurrency,
            rediagnoseLogs: shouldRediagnoseLogs,
          );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizer(ref).t(
              'overview.categoryRefreshDone',
              params: {'count': ips.length.toString()},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizer(ref);
    final segments = ref.watch(
      scanControllerProvider.select((state) => state.segments),
    );
    final sorted = segments
        .expand(
          (segment) => segment.miners
              .where(_matchesFilter)
              .map((miner) => TrackedMinerWithScope(scope: segment.scope, miner: miner)),
        )
        .toList(growable: false)
      ..sort((a, b) => IpUtils.ipToInt(a.miner.ip).compareTo(IpUtils.ipToInt(b.miner.ip)));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titleText ?? l10n.t(widget.titleKey)),
        actions: [
          if (widget.stateFilter == TrackedMinerState.offline || widget.stateFilter == 'abnormal')
            IconButton(
              onPressed: _refreshing ? null : () => _refreshCategory(forceScan: true),
              tooltip: l10n.t('miner.refresh'),
              icon: _refreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
        ],
      ),
      body: sorted.isEmpty
          ? Center(child: Text(l10n.t('overview.emptyCategory')))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = sorted[index];
                final miner = item.miner;
                final showUnstableBadge =
                    _showUnstableBadgePage && miner.offlineEventCount >= 3;
                final showDroppedBoardBadge = miner.hasDroppedBoardIssue;
                final issueBadgeLabel = miner.diagnosis == null
                    ? null
                    : IssueLocalizer.shortBadge(l10n, miner.diagnosis!);
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await Navigator.of(context).push(
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
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2F67D8).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.memory_rounded,
                                  color: Color(0xFF2F67D8),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      l10n.t('overview.scope', params: {'scope': item.scope}),
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
                              _StatusPill(
                                label: _stateLabel(miner, l10n),
                                color: _statusColor(miner, widget.stateFilter),
                              ),
                            ],
                          ),
                          if (showUnstableBadge ||
                              showDroppedBoardBadge ||
                              issueBadgeLabel != null) ...[
                            const SizedBox(height: 10),
                            _MinerBadges(
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
                                child: _MinerInfoTile(
                                  icon: Icons.flash_on_rounded,
                                  color: const Color(0xFF2F67D8),
                                  label: LegacyZhTexts.minerFiveSecondHashrate,
                                  value: miner.runtime.ghs5s,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MinerInfoTile(
                                  icon: Icons.update_rounded,
                                  color: const Color(0xFF6F748B),
                                  label: LegacyZhTexts.segmentLastScan,
                                  value: EasternTimeUtils.format(
                                    miner.lastSeenAt,
                                    pattern: 'yyyy-MM-dd HH:mm:ss',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _HashrateBar(hashrateGh: miner.effectiveHashrate),
                          if (miner.diagnosis != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              IssueLocalizer.reason(l10n, miner.diagnosis!),
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (IssueLocalizer.snippetSummary(l10n, miner.diagnosis!) != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                IssueLocalizer.snippetSummary(l10n, miner.diagnosis!)!,
                                style: const TextStyle(color: Color(0xFF6F748B)),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _stateLabel(TrackedMiner miner, AppLocalizer l10n) {
    if (_isZeroHashOnline(miner)) {
      return l10n.t('segment.filter.unresponsive');
    }
    if (widget.stateFilter == 'abnormal' && miner.diagnosis != null) {
      return l10n.t('overview.abnormalMiners');
    }
    return switch (miner.state) {
      TrackedMinerState.online => l10n.t('segment.filter.online'),
      TrackedMinerState.unresponsive => l10n.t('segment.filter.unresponsive'),
      TrackedMinerState.offline => l10n.t('segment.filter.offline'),
      _ => l10n.t('segment.filter.retired'),
    };
  }
}

class TrackedMinerWithScope {
  const TrackedMinerWithScope({
    required this.scope,
    required this.miner,
  });

  final String scope;
  final TrackedMiner miner;
}

class _MinerBadges extends StatelessWidget {
  const _MinerBadges({
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
        _MinerBadge(
          label: issueBadgeLabel!,
          color: Colors.redAccent,
        ),
      if (issueBadgeLabel != null && showDroppedBoardBadge)
        const SizedBox(height: 6),
      if (showDroppedBoardBadge)
        _MinerBadge(
          label: l10n.t('segment.badge.droppedBoard'),
          color: Colors.deepOrange,
        ),
      if ((issueBadgeLabel != null || showDroppedBoardBadge) && showUnstableBadge)
        const SizedBox(height: 6),
      if (showUnstableBadge)
        _MinerBadge(
          label: l10n.t('segment.badge.unstable'),
          color: Colors.orange,
        ),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: badges,
    );
  }
}

class _MinerBadge extends StatelessWidget {
  const _MinerBadge({
    required this.label,
    required this.color,
  });

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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

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

class _MinerInfoTile extends StatelessWidget {
  const _MinerInfoTile({
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A5161),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _HashrateBar extends StatelessWidget {
  const _HashrateBar({required this.hashrateGh});

  final double hashrateGh;
  static const double _maxDisplayGh = 16;

  @override
  Widget build(BuildContext context) {
    final clamped = hashrateGh.clamp(0, _maxDisplayGh).toDouble();
    final ratio = _maxDisplayGh <= 0 ? 0.0 : (clamped / _maxDisplayGh);
    final isZero = hashrateGh <= 0;

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

Color _statusColor(TrackedMiner miner, String filter) {
  if (filter == 'abnormal' && (miner.diagnosis != null || miner.effectiveHashrate <= 0)) {
    return Colors.deepOrange;
  }
  if (miner.state == TrackedMinerState.online &&
      miner.effectiveHashrate <= 0) {
    return const Color(0xFFF0A21C);
  }
  return switch (miner.state) {
    TrackedMinerState.online => const Color(0xFF2EAF62),
    TrackedMinerState.unresponsive => const Color(0xFFF0A21C),
    TrackedMinerState.offline => const Color(0xFFE15B64),
    _ => const Color(0xFF6F748B),
  };
}
