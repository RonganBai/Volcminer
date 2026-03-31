import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/abnormal_miner_utils.dart';
import 'package:volcminer/core/utils/eastern_time_utils.dart';
import 'package:volcminer/domain/entities/tracked_miner.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/localization/legacy_zh_texts.dart';
import 'package:volcminer/presentation/pages/issue_miner_list_page.dart';
import 'package:volcminer/presentation/pages/miner_category_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

const double _statusCardHeight = 136;

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _requestedRefresh = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedRefresh) {
      return;
    }
    _requestedRefresh = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(ref.read(scanControllerProvider.notifier).refreshServerSummary());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizer(ref);
    final scanState = ref.watch(scanControllerProvider);
    final allMiners = scanState.segments
        .expand((segment) => segment.miners)
        .toList(growable: false);

    final fallbackOnline = allMiners
        .where(
          (miner) =>
              miner.state == TrackedMinerState.online &&
              !_isZeroHashOnline(miner),
        )
        .length;
    final fallbackUnresponsive = allMiners
        .where(
          (miner) =>
              miner.state == TrackedMinerState.unresponsive ||
              _isZeroHashOnline(miner),
        )
        .length;
    final fallbackOffline = allMiners
        .where((miner) => miner.state == TrackedMinerState.offline)
        .length;
    final fallbackPendingRetire = allMiners
        .where((miner) => miner.state == TrackedMinerState.pendingRetire)
        .length;
    final fallbackAbnormal = allMiners
        .where(AbnormalMinerUtils.isSoftOrUnknownAbnormal)
        .length;
    final fallbackFault = allMiners
        .where(AbnormalMinerUtils.isHardAbnormal)
        .length;
    final fallbackSelfCheckFailure = allMiners
        .where(AbnormalMinerUtils.isSelfCheckFailure)
        .length;
    final fallbackMultiRestart = allMiners
        .where(AbnormalMinerUtils.isMultiRestart)
        .length;

    final online = scanState.serverOnlineCount ?? fallbackOnline;
    final unresponsive =
        scanState.serverUnresponsiveCount ?? fallbackUnresponsive;
    final offline = scanState.serverOfflineCount ?? fallbackOffline;
    final pendingRetire =
        scanState.serverPendingRetireCount ?? fallbackPendingRetire;
    final abnormal = fallbackAbnormal;
    final fault = fallbackFault;
    final selfCheckFailure = fallbackSelfCheckFailure;
    final multiRestart = fallbackMultiRestart;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (scanState.error != null) ...[
          Card(
            color: const Color(0xFFFFF4E5),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                scanState.error!,
                style: const TextStyle(
                  color: Color(0xFF8A4B00),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _TimeSummaryCard(
          generatedAt: scanState.generatedAt ?? scanState.lastScanAt,
          lastServerSyncAt: scanState.lastServerSyncAt,
          nextScheduledAt: scanState.nextScheduledAt,
          nextGlobalScanAt: scanState.nextGlobalScanAt,
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.18,
          children: [
            _StatusCard(
              title: LegacyZhTexts.dashboardOnline,
              value: online.toString(),
              color: const Color(0xFF2EAF62),
              icon: Icons.wifi_rounded,
            ),
            _StatusCard(
              title: LegacyZhTexts.dashboardUnresponsive,
              value: unresponsive.toString(),
              color: const Color(0xFFF0A21C),
              icon: Icons.portable_wifi_off_rounded,
            ),
            _StatusCard(
              title: LegacyZhTexts.dashboardOffline,
              value: offline.toString(),
              color: const Color(0xFFE15B64),
              icon: Icons.power_off_rounded,
              onTap: () => _openCategory(
                context,
                'overview.allOfflineTitle',
                TrackedMinerState.offline,
              ),
            ),
            _StatusCard(
              title: LegacyZhTexts.dashboardPendingRetire,
              value: pendingRetire.toString(),
              color: const Color(0xFF6F748B),
              icon: Icons.inventory_2_outlined,
              onTap: () => _openCategory(
                context,
                'overview.allRetiredTitle',
                TrackedMinerState.pendingRetire,
              ),
            ),
            _StatusCard(
              title: LegacyZhTexts.dashboardAbnormal,
              value: abnormal.toString(),
              color: const Color(0xFFD77700),
              icon: Icons.warning_amber_rounded,
              onTap: () => _openIssueList(context, IssueMinerListKind.abnormal),
            ),
            _StatusCard(
              title: LegacyZhTexts.dashboardFault,
              value: fault.toString(),
              color: const Color(0xFFD95050),
              icon: Icons.build_circle_rounded,
              onTap: () => _openIssueList(context, IssueMinerListKind.fault),
            ),
            _StatusCard(
              title: LegacyZhTexts.dashboardSelfCheckFailure,
              value: selfCheckFailure.toString(),
              color: const Color(0xFF7A4DDB),
              icon: Icons.fact_check_rounded,
              onTap: () =>
                  _openIssueList(context, IssueMinerListKind.selfCheckFailure),
            ),
            _StatusCard(
              title: l10n.isZh ? '多次重启' : 'Multi-restart',
              value: multiRestart.toString(),
              color: const Color(0xFF5A7BEF),
              icon: Icons.restart_alt_rounded,
              onTap: () =>
                  _openIssueList(context, IssueMinerListKind.multiRestart),
            ),
          ],
        ),
      ],
    );
  }

  bool _isZeroHashOnline(TrackedMiner miner) {
    return miner.state == TrackedMinerState.online &&
        miner.effectiveHashrate <= 0;
  }

  void _openCategory(
    BuildContext context,
    String titleKey,
    String stateFilter,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MinerCategoryPage(titleKey: titleKey, stateFilter: stateFilter),
      ),
    );
  }

  void _openIssueList(BuildContext context, IssueMinerListKind kind) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => IssueMinerListPage(kind: kind)),
    );
  }
}

class _TimeSummaryCard extends StatefulWidget {
  const _TimeSummaryCard({
    required this.generatedAt,
    required this.lastServerSyncAt,
    required this.nextScheduledAt,
    required this.nextGlobalScanAt,
  });

  final DateTime? generatedAt;
  final DateTime? lastServerSyncAt;
  final DateTime? nextScheduledAt;
  final DateTime? nextGlobalScanAt;

  @override
  State<_TimeSummaryCard> createState() => _TimeSummaryCardState();
}

class _TimeSummaryCardState extends State<_TimeSummaryCard> {
  Timer? _timer;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant _TimeSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nextGlobalScanAt != widget.nextGlobalScanAt ||
        oldWidget.generatedAt != widget.generatedAt ||
        oldWidget.lastServerSyncAt != widget.lastServerSyncAt) {
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.nextGlobalScanAt == null) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  DateTime? _serverNow() {
    final generatedAt = widget.generatedAt;
    final lastServerSyncAt = widget.lastServerSyncAt;
    if (generatedAt == null || lastServerSyncAt == null) {
      return null;
    }
    return generatedAt.add(DateTime.now().difference(lastServerSyncAt));
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  String _formatCountdown(DateTime? targetTime) {
    if (targetTime == null) {
      return '--';
    }
    final remaining = targetTime.difference(_serverNow() ?? DateTime.now());
    if (remaining.inSeconds <= 0) {
      return '即将开始';
    }
    if (remaining.inMinutes < 1) {
      return '1分钟内';
    }
    if (remaining.inHours < 1) {
      return '${remaining.inMinutes}分钟';
    }
    if (remaining.inDays < 1) {
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes.remainder(60);
      return minutes == 0 ? '$hours小时' : '$hours小时$minutes分钟';
    }
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    return hours == 0 ? '$days天' : '$days天$hours小时';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _toggleExpanded,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: _expanded
              ? Column(
                  children: [
                    _TimeRow(
                      icon: Icons.update_rounded,
                      label: LegacyZhTexts.dashboardUpdatedAt,
                      value: widget.generatedAt,
                      timeColor: const Color(0xFF2EAF62),
                    ),
                    const Divider(height: 18, thickness: 0.8),
                    _TimeRow(
                      icon: Icons.schedule_rounded,
                      label: LegacyZhTexts.dashboardNextScan,
                      value: widget.nextScheduledAt,
                      timeColor: const Color(0xFF2F67D8),
                    ),
                    const Divider(height: 18, thickness: 0.8),
                    _CountdownRow(
                      icon: Icons.hourglass_bottom_rounded,
                      label: '\u8ddd\u79bb\u4e0b\u6b21\u5168\u6bb5\u626b\u63cf',
                      targetTime: widget.nextGlobalScanAt,
                      referenceNow: _serverNow(),
                      timeColor: const Color(0xFF7A4DDB),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _CompactTimeItem(
                        icon: Icons.update_rounded,
                        value: widget.generatedAt == null
                            ? '--'
                            : EasternTimeUtils.format(
                                widget.generatedAt,
                                pattern: 'HH:mm',
                              ),
                        timeColor: const Color(0xFF2EAF62),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CompactTimeItem(
                        icon: Icons.schedule_rounded,
                        value: widget.nextScheduledAt == null
                            ? '--'
                            : EasternTimeUtils.format(
                                widget.nextScheduledAt,
                                pattern: 'HH:mm',
                              ),
                        timeColor: const Color(0xFF2F67D8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CompactTimeItem(
                        icon: Icons.hourglass_bottom_rounded,
                        value: _formatCountdown(widget.nextGlobalScanAt),
                        timeColor: const Color(0xFF7A4DDB),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CompactTimeItem extends StatelessWidget {
  const _CompactTimeItem({
    required this.icon,
    required this.value,
    required this.timeColor,
  });

  final IconData icon;
  final String value;
  final Color timeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: timeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: timeColor, size: 17),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: timeColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.timeColor,
  });

  final IconData icon;
  final String label;
  final DateTime? value;
  final Color timeColor;

  @override
  Widget build(BuildContext context) {
    final dateText = value == null
        ? '--'
        : EasternTimeUtils.format(value, pattern: 'yyyy-MM-dd');
    final timeText = value == null
        ? '--'
        : EasternTimeUtils.format(value, pattern: 'HH:mm');

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: timeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: timeColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF30343F),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              dateText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF70778B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timeText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: timeColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({
    required this.icon,
    required this.label,
    required this.targetTime,
    required this.referenceNow,
    required this.timeColor,
  });

  final IconData icon;
  final String label;
  final DateTime? targetTime;
  final DateTime? referenceNow;
  final Color timeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: timeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: timeColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF30343F),
            ),
          ),
        ),
        Text(
          _formatCountdown(targetTime, referenceNow),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: timeColor,
          ),
        ),
      ],
    );
  }

  String _formatCountdown(DateTime? targetTime, DateTime? referenceNow) {
    if (targetTime == null) {
      return '--';
    }
    final remaining = targetTime.difference(referenceNow ?? DateTime.now());
    if (remaining.inSeconds <= 0) {
      return '即将开始';
    }
    if (remaining.inMinutes < 1) {
      return '1分钟内';
    }
    if (remaining.inHours < 1) {
      return '${remaining.inMinutes}分钟';
    }
    if (remaining.inDays < 1) {
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes.remainder(60);
      return minutes == 0 ? '$hours小时' : '$hours小时$minutes分';
    }
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    return hours == 0 ? '$days天' : '$days天$hours小时';
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _statusCardHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4A5161),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Card(
      child: onTap == null
          ? child
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: child,
            ),
    );
  }
}
