import 'dart:async';
import 'dart:math' as math;

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
    final onlineWithScope =
        _minersForState(scanState.segments, TrackedMinerState.online);
    final unresponsiveWithScope =
        _minersForState(scanState.segments, TrackedMinerState.unresponsive);
    final offlineWithScope =
        _minersForState(scanState.segments, TrackedMinerState.offline);
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
      future: _buildScheduleInfo(settings, scanState.lastScanAt),
      builder: (context, snapshot) {
        final schedule = snapshot.data ??
            _ScanScheduleInfo(
              asOfText: l10n.t('overview.waitingFirstAutoScan'),
              nextScanText: l10n.t('overview.waitingFirstAutoScan'),
              countdownText: null,
            );

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
                      title: l10n.t('overview.scanSchedule'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            schedule.asOfText,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(schedule.nextScanText),
                          if (schedule.countdownText != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              schedule.countdownText!,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: l10n.t('overview.currentHashrate'),
                    value: hashrateDisplay.value,
                    suffix: ' ${hashrateDisplay.unit}',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoCard(
                    title: l10n.t('overview.averageHashrate'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text(l10n.t('overview.averageWindow1h')),
                              selected: !_show12hAverage,
                              onSelected: (_) {
                                setState(() => _show12hAverage = false);
                              },
                            ),
                            ChoiceChip(
                              label: Text(l10n.t('overview.averageWindow12h')),
                              selected: _show12hAverage,
                              onSelected: (_) {
                                setState(() => _show12hAverage = true);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${averageDisplay.value} ${averageDisplay.unit}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoCard(
              title: l10n.t('overview.hourlyHashrateChart'),
              child: _HourlyHashrateChart(
                samples: scanState.hashrateHistory,
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
    DateTime? lastScanAt,
  ) async {
    final l10n = AppLocalizer(ref);
    final lastAutoScanAt = await BackgroundScanService.getLastAutoScanAt();
    final nextStored = await BackgroundScanService.getNextAutoScanAtStored();
    final asOfText = lastScanAt == null
        ? l10n.t('overview.waitingFirstAutoScan')
        : l10n.t(
            'overview.dataAsOf',
            params: {'time': DateFormat('yyyy-MM-dd HH:mm:ss').format(lastScanAt)},
          );

    if (!settings.autoRefreshEnabled) {
      return _ScanScheduleInfo(
        asOfText: asOfText,
        nextScanText: l10n.t('overview.autoRefreshOff'),
        countdownText: null,
      );
    }

    final nextAt = nextStored ??
        BackgroundScanService.getNextAutoScanAt(
          settings: settings,
          lastAutoScanAt: lastAutoScanAt,
        );
    if (nextAt == null) {
      return _ScanScheduleInfo(
        asOfText: asOfText,
        nextScanText: l10n.t('overview.waitingFirstAutoScan'),
        countdownText: null,
      );
    }

    if (nextAt.isBefore(_now)) {
      return _ScanScheduleInfo(
        asOfText: asOfText,
        nextScanText: l10n.t('overview.scanOverdue'),
        countdownText: l10n.t(
          'overview.nextScanAt',
          params: {'time': DateFormat('yyyy-MM-dd HH:mm:ss').format(nextAt)},
        ),
      );
    }

    return _ScanScheduleInfo(
      asOfText: asOfText,
      nextScanText: l10n.t(
        'overview.nextScanAt',
        params: {'time': DateFormat('yyyy-MM-dd HH:mm:ss').format(nextAt)},
      ),
      countdownText: l10n.t(
        'overview.nextScanIn',
        params: {'duration': _formatCountdown(nextAt, _now)},
      ),
    );
  }

  _HashrateDisplay _formatHashrate(double ghValue) {
    if (ghValue >= 1000000) {
      return _HashrateDisplay(
        value: (ghValue / 1000000).toStringAsFixed(2),
        unit: 'PH/s',
      );
    }
    if (ghValue >= 1000) {
      return _HashrateDisplay(
        value: (ghValue / 1000).toStringAsFixed(2),
        unit: 'TH/s',
      );
    }
    return _HashrateDisplay(
      value: ghValue.toStringAsFixed(2),
      unit: 'GH/s',
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
      return '0s';
    }
    if (remaining.inHours >= 1) {
      return '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
    }
    if (remaining.inMinutes >= 1) {
      return '${remaining.inMinutes}m ${remaining.inSeconds.remainder(60)}s';
    }
    return '${remaining.inSeconds}s';
  }
}

class _ScanScheduleInfo {
  const _ScanScheduleInfo({
    required this.asOfText,
    required this.nextScanText,
    required this.countdownText,
  });

  final String asOfText;
  final String nextScanText;
  final String? countdownText;
}

class _HashrateDisplay {
  const _HashrateDisplay({required this.value, required this.unit});

  final String value;
  final String unit;
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
            Text(title, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
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
              Text(
                '$value$suffix',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
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
  const _HourlyHashrateChart({required this.samples});

  final List<HashrateSample> samples;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizer(ref);
    final buckets = _buildHourlyBuckets(samples);
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
      children: [
        SizedBox(
          height: 180,
          child: CustomPaint(
            painter: _HashrateChartPainter(buckets: buckets),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('HH:mm').format(buckets.first.time),
              style: const TextStyle(color: Colors.black54),
            ),
            Text(
              DateFormat('HH:mm').format(buckets.last.time),
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }

  List<_ChartBucket> _buildHourlyBuckets(List<HashrateSample> source) {
    final now = DateTime.now();
    final buckets = <_ChartBucket>[];
    for (var i = 11; i >= 0; i--) {
      final hourStart = DateTime(now.year, now.month, now.day, now.hour - i);
      final hourEnd = hourStart.add(const Duration(hours: 1));
      final points = source
          .where(
            (sample) =>
                !sample.recordedAt.isBefore(hourStart) &&
                sample.recordedAt.isBefore(hourEnd),
          )
          .toList(growable: false);
      final avg = points.isEmpty
          ? 0.0
          : points.fold<double>(0, (sum, sample) => sum + sample.totalHashrateGh) /
              points.length;
      buckets.add(_ChartBucket(time: hourStart, value: avg));
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
  const _HashrateChartPainter({required this.buckets});

  final List<_ChartBucket> buckets;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 20);
    final axisPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = const Color(0xFF0B5E4E)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = const Color(0xFF0B5E4E).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final maxValue = math.max(
      1,
      buckets.fold<double>(0, (maxSoFar, bucket) => math.max(maxSoFar, bucket.value)),
    );

    for (var i = 0; i < 4; i++) {
      final y = chartRect.top + (chartRect.height / 3) * i;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        axisPaint,
      );
    }

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < buckets.length; i++) {
      final dx = chartRect.left +
          (chartRect.width * i / math.max(1, buckets.length - 1));
      final dy = chartRect.bottom -
          (chartRect.height * (buckets[i].value / maxValue));
      if (i == 0) {
        path.moveTo(dx, dy);
        fillPath.moveTo(dx, chartRect.bottom);
        fillPath.lineTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
        fillPath.lineTo(dx, dy);
      }
    }
    fillPath.lineTo(chartRect.right, chartRect.bottom);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _HashrateChartPainter oldDelegate) {
    return oldDelegate.buckets != buckets;
  }
}
