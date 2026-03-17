import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/tracked_miner.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/localization/issue_localizer.dart';
import 'package:volcminer/presentation/pages/miner_detail_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';
import 'package:volcminer/services/background_scan_service.dart';

class MinerCategoryPage extends ConsumerStatefulWidget {
  const MinerCategoryPage({
    super.key,
    required this.titleKey,
    required this.stateFilter,
  });

  final String titleKey;
  final String stateFilter;

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
      return miner.diagnosis != null || _isZeroHashOnline(miner);
    }
    if (widget.stateFilter == TrackedMinerState.unresponsive) {
      return miner.state == TrackedMinerState.unresponsive || _isZeroHashOnline(miner);
    }
    return miner.state == widget.stateFilter;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(scanControllerProvider.notifier).loadPersistedState());
    });
  }

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
    if (mounted) {
      setState(() => _refreshing = true);
    }
    try {
      await ref.read(scanControllerProvider.notifier).refreshMinerIps(
            ips: ips,
            minerCredential: credential,
            concurrency: settingsState.settings.scanConcurrency,
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
    final scanState = ref.watch(scanControllerProvider);
    final sorted = scanState.segments
        .expand(
          (segment) => segment.miners
              .where(_matchesFilter)
              .map((miner) => TrackedMinerWithScope(scope: segment.scope, miner: miner)),
        )
        .toList(growable: false)
      ..sort((a, b) => IpUtils.ipToInt(a.miner.ip).compareTo(IpUtils.ipToInt(b.miner.ip)));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t(widget.titleKey)),
        actions: [
          if (widget.stateFilter == TrackedMinerState.offline || widget.stateFilter == 'abnormal')
            IconButton(
              onPressed: _refreshing ? null : () => _refreshCategory(forceScan: true),
              tooltip: '刷新矿机',
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
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      miner.ip,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.t('overview.scope', params: {'scope': item.scope}),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (_statusDotColor(miner, widget.stateFilter) != null) ...[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _statusDotColor(miner, widget.stateFilter),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  '${_stateLabel(miner, l10n)} | ${miner.runtime.ghs5s}/${miner.runtime.ghsav}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Last seen ${DateFormat('yyyy-MM-dd HH:mm:ss').format(miner.lastSeenAt)}',
                          ),
                          const SizedBox(height: 6),
                          _HashrateBar(hashrateGh: miner.effectiveHashrate),
                          if (miner.diagnosis != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              IssueLocalizer.reason(l10n, miner.diagnosis!),
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (IssueLocalizer.snippetSummary(l10n, miner.diagnosis!) != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                IssueLocalizer.snippetSummary(l10n, miner.diagnosis!)!,
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MinerDetailPage(miner: miner),
                        ),
                      );
                      if (!mounted) {
                        return;
                      }
                      await ref.read(scanControllerProvider.notifier).loadPersistedState();
                    },
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

class _HashrateBar extends StatelessWidget {
  const _HashrateBar({required this.hashrateGh});

  final double hashrateGh;

  @override
  Widget build(BuildContext context) {
    final stateIndex = hashrateGh > 14
        ? 0
        : hashrateGh > 5
            ? 1
            : 2;
    const colors = [Colors.green, Colors.amber, Colors.red];
    return Row(
      children: [
        for (var i = 0; i < colors.length; i++) ...[
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: colors[i].withValues(alpha: i == stateIndex ? 1 : 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          if (i != colors.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

Color? _statusDotColor(TrackedMiner miner, String filter) {
  if (filter == 'abnormal' && (miner.diagnosis != null || miner.effectiveHashrate <= 0)) {
    return Colors.deepOrange;
  }
  return switch (miner.state) {
    TrackedMinerState.online => Colors.green,
    TrackedMinerState.offline => Colors.red,
    _ => null,
  };
}
