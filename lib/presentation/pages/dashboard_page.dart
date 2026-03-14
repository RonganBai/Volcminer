import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:volcminer/core/utils/hashrate_utils.dart';
import 'package:volcminer/domain/entities/hashrate_sample.dart';
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
  bool _show12hAverage = false;
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
        .where((miner) => miner.state == TrackedMinerState.online)
        .toList(growable: false);
    final unresponsive = allMiners
        .where((miner) => miner.state == TrackedMinerState.unresponsive)
        .toList(growable: false);
    final offline = allMiners
        .where((miner) => miner.state == TrackedMinerState.offline)
        .toList(growable: false);
    final retired = allMiners
        .where((miner) => miner.state == TrackedMinerState.retired)
        .toList(growable: false);
    final onlineWithScope =
        _minersForState(scanState.segments, TrackedMinerState.online);
    final unresponsiveWithScope =
        _minersForState(scanState.segments, TrackedMinerState.unresponsive);
    final offlineWithScope =
        _minersForState(scanState.segments, TrackedMinerState.offline);
    final retiredWithScope =
        _minersForState(scanState.segments, TrackedMinerState.retired);
    final total = allMiners.length;
    final overallHashrateGh = online.fold<double>(
      0,
      (sum, miner) =>
          sum + HashrateUtils.effectiveGh(miner.runtime.ghs5s, miner.runtime.ghsav),
    );
    final hashrateDisplay = _formatHashrate(overallHashrateGh);
    final onlineRate = total == 0 ? 0 : (online.length / total) * 100;
    final unstableScopes = scanState.segments
        .where((segment) => segment.miners.any((miner) => miner.missedScans >= 2))
        .map((segment) => segment.scope)
        .toList(growable: false);
    final averageWindow = _show12hAverage
        ? const Duration(hours: 12)
        : const Duration(hours: 1);
    final averageHashrateGh = _averageHashrate(
      scanState.hashrateHistory,
      averageWindow,
      _now,
    );
    final averageDisplay = _formatHashrate(averageHashrateGh);

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
                            l10n,
                            'overview.allOnlineTitle',
                            onlineWithScope,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SummaryCard(
                          title: l10n.t('overview.unresponsiveMiners'),
                          value: '${unresponsive.length}',
                          color: Colors.amber.shade700,
                          onTap: () => _openCategory(
                            context,
                            l10n,
                            'overview.allUnresponsiveTitle',
                            unresponsiveWithScope,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SummaryCard(
                          title: l10n.t('overview.offlineMiners'),
                          value: '${offline.length}',
                          color: Colors.red.shade400,
                          onTap: () => _openCategory(
                            context,
                            l10n,
                            'overview.allOfflineTitle',
                            offlineWithScope,
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
                            l10n,
                            'overview.allRetiredTitle',
                            retiredWithScope,
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
                    child: _InfoCard(
                      title: l10n.t('overview.averageHashrate'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _show12hAverage
                                      ? l10n.t('overview.averageWindow12h')
                                      : l10n.t('overview.averageWindow1h'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(
                                    () => _show12hAverage = !_show12hAverage,
                                  );
                                },
                                icon: const Icon(Icons.swap_horiz, size: 18),
                                label: Text(
                                  _show12hAverage
                                      ? l10n.t('overview.averageWindow1h')
                                      : l10n.t('overview.averageWindow12h'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          RichText(
                            text: TextSpan(
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.secondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                              children: [
                                TextSpan(text: averageDisplay.value),
                                TextSpan(
                                  text: ' ${averageDisplay.unit}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
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
            _InfoCard(
              title: l10n.t('overview.hourlyHashrateChart'),
              child: _HourlyHashrateChart(
                samples: scanState.hashrateHistory,
                window: averageWindow,
              ),
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              title: l10n.t('overview.onlineRate'),
              value: onlineRate.toStringAsFixed(1),
              suffix: '%',
              color: Theme.of(context).colorScheme.secondary,
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
                    if (unstableScopes.isEmpty)
                      Text(
                        l10n.t('overview.unstableScopesEmpty'),
                        style: const TextStyle(color: Colors.black54),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: unstableScopes
                            .map(
                              (scope) => Chip(
                                label: Text(scope),
                                avatar: const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                ),
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

  double _averageHashrate(
    List<HashrateSample> samples,
    Duration window,
    DateTime now,
  ) {
    final cutoff = now.subtract(window);
    final scoped = samples.where((sample) => sample.recordedAt.isAfter(cutoff)).toList();
    if (scoped.isEmpty) {
      return 0;
    }
    final total = scoped.fold<double>(
      0,
      (sum, sample) => sum + sample.totalHashrateGh,
    );
    return total / scoped.length;
  }

  List<TrackedMinerWithScope> _minersForState(
    List<dynamic> segments,
    String state,
  ) {
    return [
      for (final segment in segments)
        for (final miner in segment.miners)
          if (miner.state == state)
            TrackedMinerWithScope(scope: segment.scope, miner: miner),
    ];
  }

  void _openCategory(
    BuildContext context,
    AppLocalizer l10n,
    String titleKey,
    List<TrackedMinerWithScope> miners,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MinerCategoryPage(
          titleKey: titleKey,
          miners: miners,
        ),
      ),
    );
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

class _HashrateDisplay {
  const _HashrateDisplay({required this.value, required this.unit});

  final String value;
  final String unit;
}

class _AutoScanProgressRing extends StatelessWidget {
  const _AutoScanProgressRing({
    required this.progress,
    required this.runningLabel,
    required this.idleLabel,
    required this.finalizingLabel,
    required this.progressLabelBuilder,
  });

  final AutoScanProgress progress;
  final String runningLabel;
  final String idleLabel;
  final String finalizingLabel;
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
            value: null,
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              finalizingLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
            ),
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

class _HourlyHashrateChart extends ConsumerWidget {
  const _HourlyHashrateChart({
    required this.samples,
    required this.window,
  });

  final List<HashrateSample> samples;
  final Duration window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizer(ref);
    final buckets = _buildBuckets(samples, window);
    if (buckets.every((bucket) => bucket.value <= 0)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            l10n.t('overview.chartEmpty'),
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('overview.chartAxisHashrate'),
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              height: 260,
              child: CustomPaint(
                size: Size(constraints.maxWidth, 260),
                painter: _HashrateChartPainter(
                  buckets: buckets,
                  window: window,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            l10n.t('overview.chartAxisTime'),
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }

  List<_ChartBucket> _buildBuckets(List<HashrateSample> source, Duration window) {
    final now = DateTime.now();
    final buckets = <_ChartBucket>[];
    final bucketMinutes = window.inHours >= 12 ? 60 : 10;
    final divisions = window.inMinutes ~/ bucketMinutes;
    for (var i = divisions - 1; i >= 0; i--) {
      final bucketStart = now.subtract(Duration(minutes: bucketMinutes * (i + 1)));
      final bucketEnd = bucketStart.add(Duration(minutes: bucketMinutes));
      final points = source
          .where(
            (sample) =>
                !sample.recordedAt.isBefore(bucketStart) &&
                sample.recordedAt.isBefore(bucketEnd),
          )
          .toList(growable: false);
      final avg = points.isEmpty
          ? 0.0
          : points.fold<double>(0, (sum, sample) => sum + sample.totalHashrateGh) /
              points.length;
      buckets.add(_ChartBucket(time: bucketStart, value: avg / 1000));
    }
    return buckets;
  }
}

class _ChartBucket {
  const _ChartBucket({required this.time, required this.value});

  final DateTime time;
  final double value;
}

class _HashrateChartPainter extends CustomPainter {
  const _HashrateChartPainter({
    required this.buckets,
    required this.window,
  });

  final List<_ChartBucket> buckets;
  final Duration window;

  @override
  void paint(Canvas canvas, Size size) {
    const leftInset = 36.0;
    const topInset = 12.0;
    const rightInset = 12.0;
    const bottomInset = 42.0;
    final chartRect = Rect.fromLTWH(
      leftInset,
      topInset,
      size.width - leftInset - rightInset,
      size.height - topInset - bottomInset,
    );
    final axisPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    final borderPaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = const Color(0xFF0B5E4E)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = const Color(0xFF0B5E4E).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final rawMaxValue = buckets.fold<double>(
      0,
      (maxSoFar, bucket) => math.max(maxSoFar, bucket.value),
    );
    final maxValue = math.max(10, (rawMaxValue / 10).ceil() * 10).toDouble();
    final labelStyle = const TextStyle(
      color: Colors.black54,
      fontSize: 11,
    );
    final xLabelStyle = const TextStyle(color: Colors.black54, fontSize: 10);

    canvas.drawLine(
      Offset(chartRect.left, chartRect.top),
      Offset(chartRect.left, chartRect.bottom),
      borderPaint,
    );
    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      borderPaint,
    );

    final horizontalSteps = math.max(1, (maxValue / 10).round());
    for (var i = 0; i <= horizontalSteps; i++) {
      final y = chartRect.bottom - (chartRect.height * (i / horizontalSteps));
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        axisPaint,
      );
      final value = i * 10.0;
      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(0),
          style: labelStyle,
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(chartRect.left - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    final points = <Offset>[];
    for (var i = 0; i < buckets.length; i++) {
      final dx = chartRect.left +
          (chartRect.width * i / math.max(1, buckets.length - 1));
      final dy = chartRect.bottom -
          (chartRect.height * (buckets[i].value / maxValue).clamp(0, 1));
      points.add(Offset(dx, dy));

      canvas.drawLine(
        Offset(dx, chartRect.top),
        Offset(dx, chartRect.bottom),
        axisPaint,
      );
    }

    final labelIndexes = _buildXAxisLabelIndexes(points.length);
    for (final index in labelIndexes) {
      if (index < 0 || index >= buckets.length) {
        continue;
      }
      final dx = points[index].dx;
      final xLabel = TextPainter(
        text: TextSpan(
          text: _formatBucketLabel(buckets[index].time),
          style: xLabelStyle,
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final desiredX = dx - xLabel.width / 2;
      final clampedX = desiredX.clamp(
        chartRect.left,
        chartRect.right - xLabel.width,
      );
      xLabel.paint(
        canvas,
        Offset(
          clampedX,
          chartRect.bottom + 8,
        ),
      );
    }

    if (points.isEmpty) {
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    final fillPath = Path()
      ..moveTo(points.first.dx, chartRect.bottom)
      ..lineTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlPoint1 = Offset(
        previous.dx + (current.dx - previous.dx) / 2,
        previous.dy,
      );
      final controlPoint2 = Offset(
        previous.dx + (current.dx - previous.dx) / 2,
        current.dy,
      );
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        current.dx,
        current.dy,
      );
      fillPath.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        current.dx,
        current.dy,
      );
    }
    fillPath.lineTo(chartRect.right, chartRect.bottom);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  String _formatBucketLabel(DateTime value) {
    return DateFormat('HH:mm').format(value);
  }

  List<int> _buildXAxisLabelIndexes(int count) {
    if (count <= 1) {
      return const [0];
    }
    if (window.inHours >= 12) {
      return {
        0,
        count ~/ 4,
        count ~/ 2,
        (count * 3) ~/ 4,
        count - 1,
      }.toList()..sort();
    }
    return {
      0,
      count ~/ 3,
      (count * 2) ~/ 3,
      count - 1,
    }.toList()..sort();
  }

  @override
  bool shouldRepaint(covariant _HashrateChartPainter oldDelegate) {
    return oldDelegate.buckets != buckets || oldDelegate.window != window;
  }
}
