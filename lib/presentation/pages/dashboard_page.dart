import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:volcminer/core/utils/hashrate_utils.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/domain/entities/tracked_miner.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/pages/miner_category_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';
import 'package:volcminer/services/background_scan_service.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanControllerProvider);
    final settings = ref.watch(settingsControllerProvider).settings;
    final l10n = AppLocalizer(ref);
    final allMiners = scanState.segments
        .expand((segment) => segment.miners)
        .toList(growable: false);
    final online = allMiners
        .where((miner) => miner.state == TrackedMinerState.online && !_isZeroHashOnline(miner))
        .toList(growable: false);
    final unresponsive = allMiners
        .where((miner) => miner.state == TrackedMinerState.unresponsive || _isZeroHashOnline(miner))
        .toList(growable: false);
    final offline = allMiners
        .where((miner) => miner.state == TrackedMinerState.offline)
        .toList(growable: false);
    final retired = allMiners
        .where((miner) => miner.state == TrackedMinerState.pendingRetire)
        .toList(growable: false);
    final abnormal = allMiners
        .where((miner) => miner.diagnosis != null || _isZeroHashOnline(miner))
        .toList(growable: false);
    final total = allMiners.length;
    final overallHashrateGh = online.fold<double>(
      0,
      (sum, miner) =>
          sum + HashrateUtils.effectiveGh(miner.runtime.ghs5s, miner.runtime.ghsav),
    );
    final hashrateDisplay = _formatHashrate(overallHashrateGh);
    final onlineRate = total == 0 ? 0 : (online.length / total) * 100;
    final unstableMinerIps = allMiners
        .where((miner) => miner.offlineEventCount >= 3)
        .map((miner) => miner.ip)
        .toList(growable: false)
      ..sort(IpUtils.compareIpBlocks);
    return FutureBuilder<_ScanScheduleInfo>(
      future: _buildScheduleInfo(settings),
      builder: (context, snapshot) {
        final schedule = snapshot.data ??
            _ScanScheduleInfo(
              asOfText: l10n.t('overview.waitingFirstAutoScan'),
              nextScanText: l10n.t('overview.waitingFirstAutoScan'),
              countdownText: null,
              progress: const AutoScanProgress(
                isRunning: false,
                scannedTargets: 0,
                totalTargets: 0,
              ),
            );
        final scheduleDate = DateFormat('yyyy-MM-dd').format(_now);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryCard(
                          title: l10n.t('overview.onlineMiners'),
                          value: '${online.length}',
                          color: Colors.green,
                          onTap: () => _openCategory(
                            context,
                            'overview.allOnlineTitle',
                            TrackedMinerState.online,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SummaryCard(
                          title: l10n.t('overview.unresponsiveMiners'),
                          value: '${unresponsive.length}',
                          color: Colors.amber.shade700,
                          onTap: () => _openCategory(
                            context,
                            'overview.allUnresponsiveTitle',
                            TrackedMinerState.unresponsive,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SummaryCard(
                          title: l10n.t('overview.offlineMiners'),
                          value: '${offline.length}',
                          color: Colors.red.shade400,
                          onTap: () => _openCategory(
                            context,
                            'overview.allOfflineTitle',
                            TrackedMinerState.offline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoCard(
                      title: '',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scheduleDate,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.t('overview.scanSchedule'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            schedule.asOfText,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            schedule.nextScanText,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (schedule.countdownText != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              schedule.countdownText!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.black54,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _AutoScanProgressRing(
                            progress: schedule.progress,
                            runningLabel: l10n.t('overview.autoScanRunning'),
                            idleLabel: l10n.t('overview.autoScanIdle'),
                            finalizingLabel: l10n.t('overview.autoScanFinalizing'),
                            stageLabelBuilder: (stageKey) =>
                                l10n.t(stageKey ?? 'overview.autoScanFinalizing'),
                            progressLabelBuilder: (current, total) => l10n.t(
                              'overview.autoScanProgress',
                              params: {
                                'current': current.toString(),
                                'total': total.toString(),
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryCard(
                          title: l10n.t('overview.retiredMiners'),
                          value: '${retired.length}',
                          color: Colors.grey.shade700,
                          onTap: () => _openCategory(
                            context,
                            'overview.allRetiredTitle',
                            TrackedMinerState.pendingRetire,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SummaryCard(
                          title: l10n.t('overview.currentHashrate'),
                          value: hashrateDisplay.value,
                          suffix: ' ${hashrateDisplay.unit}',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryCard(
                          title: l10n.t('overview.abnormalMiners'),
                          value: '${abnormal.length}',
                          color: Colors.deepOrange,
                          onTap: () => _openCategory(
                            context,
                            'overview.allAbnormalTitle',
                            'abnormal',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SummaryCard(
                          title: l10n.t('overview.onlineRate'),
                          value: onlineRate.toStringAsFixed(1),
                          suffix: '%',
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('overview.unstableScopes'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (unstableMinerIps.isEmpty)
                      Text(
                        l10n.t('overview.unstableScopesEmpty'),
                        style: const TextStyle(color: Colors.black54),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: unstableMinerIps
                            .map(
                              (ip) => InputChip(
                                label: Text(ip),
                                avatar: const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                ),
                                onDeleted: () => _confirmRemoveUnstableIp(context, ip),
                              ),
                            )
                            .toList(growable: false),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<_ScanScheduleInfo> _buildScheduleInfo(
    dynamic settings,
  ) async {
    final l10n = AppLocalizer(ref);
    final lastAutoScanAt = await BackgroundScanService.getLastAutoScanAt();
    final lastAutoScanAttemptAt =
        await BackgroundScanService.getLastAutoScanAttemptAt();
    final nextStored = await BackgroundScanService.getNextAutoScanAtStored();
    final progress = await BackgroundScanService.getAutoScanProgress();
    final computedNextAt = BackgroundScanService.getNextAutoScanAt(
      settings: settings,
      lastAutoScanAt: lastAutoScanAt,
    );
    final effectiveNextAt = _selectNextAutoScanAt(
      nextStored: nextStored,
      computedNextAt: computedNextAt,
      lastAutoScanAt: lastAutoScanAt,
    );
    final asOfText = lastAutoScanAt == null
        ? l10n.t('overview.dataAsOfCompact', params: {'time': '--'})
        : l10n.t(
            'overview.dataAsOfCompact',
            params: {'time': DateFormat('HH:mm').format(lastAutoScanAt)},
          );

    if (!settings.autoRefreshEnabled) {
      return _ScanScheduleInfo(
        asOfText: asOfText,
        nextScanText: l10n.t('overview.nextScanAtCompact', params: {'time': '--'}),
        countdownText: l10n.t(
          'overview.nextScanInCompact',
          params: {'duration': '00:00'},
        ),
        progress: progress,
      );
    }

    final nextAt = effectiveNextAt;
    if (nextAt == null) {
      return _ScanScheduleInfo(
        asOfText: asOfText,
        nextScanText: l10n.t('overview.nextScanAtCompact', params: {'time': '--'}),
        countdownText: l10n.t(
          'overview.nextScanInCompact',
          params: {'duration': '00:00'},
        ),
        progress: progress,
      );
    }

    if (nextAt.isBefore(_now) || nextAt.isAtSameMomentAs(_now)) {
      return _ScanScheduleInfo(
        asOfText: asOfText,
        nextScanText: lastAutoScanAttemptAt == null
            ? l10n.t(
                'overview.nextScanAtCompact',
                params: {'time': DateFormat('HH:mm').format(nextAt)},
              )
            : l10n.t(
                'overview.nextScanAtCompact',
                params: {'time': DateFormat('HH:mm').format(nextAt)},
              ),
        countdownText: l10n.t(
          'overview.nextScanInCompact',
          params: {'duration': '00:00'},
        ),
        progress: progress,
      );
    }

    return _ScanScheduleInfo(
      asOfText: asOfText,
      nextScanText: l10n.t(
        'overview.nextScanAtCompact',
        params: {'time': DateFormat('HH:mm').format(nextAt)},
      ),
      countdownText: l10n.t(
        'overview.nextScanInCompact',
        params: {'duration': _formatCountdown(nextAt, _now)},
      ),
      progress: progress,
    );
  }

  _HashrateDisplay _formatHashrate(double ghValue) {
    return _HashrateDisplay(
      value: (ghValue / 1000).toStringAsFixed(2),
      unit: 'TH/s',
    );
  }

  void _openCategory(
    BuildContext context,
    String titleKey,
    String stateFilter,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MinerCategoryPage(
          titleKey: titleKey,
          stateFilter: stateFilter,
        ),
      ),
    );
  }

  Future<void> _confirmRemoveUnstableIp(BuildContext context, String ip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除多次掉线标记'),
        content: Text('确认将 $ip 从多次掉线列表中移除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(scanControllerProvider.notifier).clearUnstableMinerFlag(ip);
    }
  }

  String _formatCountdown(DateTime target, DateTime now) {
    final remaining = target.difference(now);
    if (remaining.isNegative) {
      return '00:00';
    }
    final totalMinutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    return '${totalMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  DateTime? _selectNextAutoScanAt({
    required DateTime? nextStored,
    required DateTime? computedNextAt,
    required DateTime? lastAutoScanAt,
  }) {
    if (computedNextAt == null) {
      return nextStored;
    }
    if (nextStored == null) {
      return computedNextAt;
    }
    if (lastAutoScanAt != null && !nextStored.isAfter(lastAutoScanAt)) {
      return computedNextAt;
    }
    if (computedNextAt.isAfter(nextStored)) {
      return computedNextAt;
    }
    return nextStored;
  }

  bool _isZeroHashOnline(TrackedMiner miner) {
    return miner.state == TrackedMinerState.online && miner.effectiveHashrate <= 0;
  }
}

class _HashrateDisplay {
  const _HashrateDisplay({required this.value, required this.unit});

  final String value;
  final String unit;
}

class _ScanScheduleInfo {
  const _ScanScheduleInfo({
    required this.asOfText,
    required this.nextScanText,
    required this.countdownText,
    required this.progress,
  });

  final String asOfText;
  final String nextScanText;
  final String? countdownText;
  final AutoScanProgress progress;
}

class _AutoScanProgressRing extends StatelessWidget {
  const _AutoScanProgressRing({
    required this.progress,
    required this.runningLabel,
    required this.idleLabel,
    required this.finalizingLabel,
    required this.stageLabelBuilder,
    required this.progressLabelBuilder,
  });

  final AutoScanProgress progress;
  final String runningLabel;
  final String idleLabel;
  final String finalizingLabel;
  final String Function(String? stageKey) stageLabelBuilder;
  final String Function(int current, int total) progressLabelBuilder;

  @override
  Widget build(BuildContext context) {
    final ratio = progress.ratio;
    final isFinalizing =
        progress.phase == 'finalizing' ||
        (progress.isRunning &&
            progress.totalTargets > 0 &&
            progress.scannedTargets >= progress.totalTargets);
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress.isRunning ? ratio : 0,
                    strokeWidth: 6,
                    backgroundColor: Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress.isRunning
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black26,
                    ),
                  ),
                  Center(
                    child: Text(
                      progress.isRunning && ratio != null
                          ? '${(ratio * 100).round()}%'
                          : '--',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress.isRunning ? runningLabel : idleLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    progressLabelBuilder(
                      progress.scannedTargets,
                      progress.totalTargets,
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (isFinalizing) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress.stageTotal > 0
                ? (progress.stageCurrent / progress.stageTotal).clamp(0, 1).toDouble()
                : 0,
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  stageLabelBuilder(progress.stageKey),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                progress.stageTotal > 0
                    ? '${((progress.stageCurrent / progress.stageTotal) * 100).round()}%'
                    : '0%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Text(title, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    this.suffix = '',
    this.onTap,
  });

  final String title;
  final String value;
  final String suffix;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                  children: [
                    TextSpan(text: value),
                    if (suffix.isNotEmpty)
                      TextSpan(
                        text: suffix,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: (Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.fontSize ??
                                      24) *
                                  0.72,
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
