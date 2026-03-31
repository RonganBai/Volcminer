import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/abnormal_miner_utils.dart';
import 'package:volcminer/core/utils/eastern_time_utils.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/domain/entities/tracked_miner.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/localization/issue_localizer.dart';
import 'package:volcminer/presentation/pages/miner_detail_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

enum IssueMinerListKind { abnormal, fault, selfCheckFailure, multiRestart }

class IssueMinerListPage extends ConsumerStatefulWidget {
  const IssueMinerListPage({super.key, required this.kind});

  final IssueMinerListKind kind;

  @override
  ConsumerState<IssueMinerListPage> createState() => _IssueMinerListPageState();
}

class _IssueMinerListPageState extends ConsumerState<IssueMinerListPage> {
  bool _requestedRefresh = false;

  IssueMinerListKind get kind => widget.kind;

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
      unawaited(
        ref.read(scanControllerProvider.notifier).refreshServerSnapshot(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final l10n = AppLocalizer(ref);
    final miners = ref.watch(
      scanControllerProvider.select(
        (state) => state.segments
            .expand(
              (segment) => segment.miners.map(
                (miner) => _MinerScope(scope: segment.scope, miner: miner),
              ),
            )
            .toList(growable: false),
      ),
    );
    final filtered = miners.where(_matches).toList(growable: false)
      ..sort(
        (a, b) =>
            IpUtils.ipToInt(a.miner.ip).compareTo(IpUtils.ipToInt(b.miner.ip)),
      );

    return Scaffold(
      appBar: AppBar(title: Text(_title(l10n))),
      body: filtered.isEmpty
          ? Center(child: Text(l10n.t('overview.emptyCategory')))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _IssueMinerCard(
                  item: item,
                  kind: kind,
                  l10n: l10n,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MinerDetailPage(miner: item.miner),
                    ),
                  ),
                );
              },
            ),
    );
  }

  bool _matches(_MinerScope item) {
    final miner = item.miner;
    return switch (kind) {
      IssueMinerListKind.abnormal => AbnormalMinerUtils.isSoftOrUnknownAbnormal(
        miner,
      ),
      IssueMinerListKind.fault => AbnormalMinerUtils.isHardAbnormal(miner),
      IssueMinerListKind.selfCheckFailure =>
        AbnormalMinerUtils.isSelfCheckFailure(miner),
      IssueMinerListKind.multiRestart => AbnormalMinerUtils.isMultiRestart(
        miner,
      ),
    };
  }

  String _title(AppLocalizer l10n) {
    return switch (kind) {
      IssueMinerListKind.abnormal => l10n.t('overview.allAbnormalTitle'),
      IssueMinerListKind.fault => l10n.t('overview.allFaultTitle'),
      IssueMinerListKind.selfCheckFailure => l10n.t(
        'overview.allSelfCheckFailureTitle',
      ),
      IssueMinerListKind.multiRestart =>
        l10n.isZh ? '全部多次重启矿机' : 'All Multi-restart Miners',
    };
  }
}

class _MinerScope {
  const _MinerScope({required this.scope, required this.miner});

  final String scope;
  final TrackedMiner miner;
}

class _IssueMinerCard extends StatelessWidget {
  const _IssueMinerCard({
    required this.item,
    required this.kind,
    required this.l10n,
    required this.onTap,
  });

  final _MinerScope item;
  final IssueMinerListKind kind;
  final AppLocalizer l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(kind);
    final subtitleLines = _subtitleLines();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(_iconOf(kind), color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.miner.ip,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'IP 段：${item.scope}',
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
                  _KindPill(label: _kindLabel(), color: accent),
                ],
              ),
              if (subtitleLines.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final line in subtitleLines) ...[
                  Text(
                    line,
                    style: const TextStyle(
                      color: Color(0xFF4A5161),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
              const SizedBox(height: 8),
              Text(
                EasternTimeUtils.format(
                  item.miner.lastSeenAt,
                  pattern: 'yyyy-MM-dd HH:mm:ss',
                ),
                style: const TextStyle(
                  color: Color(0xFF8B91A3),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _subtitleLines() {
    final miner = item.miner;
    return switch (kind) {
      IssueMinerListKind.abnormal => [
        _reasonText() ?? '异常矿机',
        if (miner.diagnosis != null &&
            IssueLocalizer.snippetSummary(l10n, miner.diagnosis!) != null)
          IssueLocalizer.snippetSummary(l10n, miner.diagnosis!)!,
      ],
      IssueMinerListKind.fault => [
        _reasonText() ?? '故障矿机',
        if (miner.diagnosis != null &&
            IssueLocalizer.snippetSummary(l10n, miner.diagnosis!) != null)
          IssueLocalizer.snippetSummary(l10n, miner.diagnosis!)!,
      ],
      IssueMinerListKind.selfCheckFailure => [
        _reasonText() ?? '自检失败',
        if (miner.diagnosis != null &&
            IssueLocalizer.secondaryReason(l10n, miner.diagnosis!) != null)
          l10n.t(
            'miner.issueSecondary',
            params: {
              'reason': IssueLocalizer.secondaryReason(l10n, miner.diagnosis!)!,
            },
          ),
      ],
      IssueMinerListKind.multiRestart => [
        _reasonText() ?? (l10n.isZh ? '多次重启矿机' : 'Multi-restart miner'),
        if (miner.diagnosis != null &&
            IssueLocalizer.shortBadge(l10n, miner.diagnosis!) != null)
          IssueLocalizer.shortBadge(l10n, miner.diagnosis!)!,
      ],
    };
  }

  String? _reasonText() {
    final diagnosis = item.miner.diagnosis;
    if (diagnosis == null) {
      if (kind == IssueMinerListKind.abnormal &&
          item.miner.state == TrackedMinerState.online &&
          item.miner.effectiveHashrate <= 0) {
        return l10n.t('issue.reason.UNKNOWN_ZERO_HASH');
      }
      return null;
    }
    return switch (kind) {
      IssueMinerListKind.abnormal =>
        AbnormalMinerUtils.isSoftOrUnknownAbnormal(item.miner)
            ? IssueLocalizer.reason(l10n, diagnosis)
            : null,
      IssueMinerListKind.fault =>
        AbnormalMinerUtils.isHardAbnormal(item.miner)
            ? IssueLocalizer.reason(l10n, diagnosis)
            : null,
      IssueMinerListKind.selfCheckFailure => IssueLocalizer.reason(
        l10n,
        diagnosis,
      ),
      IssueMinerListKind.multiRestart =>
        AbnormalMinerUtils.isMultiRestart(item.miner)
            ? IssueLocalizer.reason(l10n, diagnosis)
            : null,
    };
  }

  String _kindLabel() {
    return switch (kind) {
      IssueMinerListKind.abnormal => l10n.t('segment.filter.abnormal'),
      IssueMinerListKind.fault => l10n.t('overview.allFaultTitle'),
      IssueMinerListKind.selfCheckFailure => l10n.t(
        'overview.allSelfCheckFailureTitle',
      ),
      IssueMinerListKind.multiRestart => l10n.isZh ? '多次重启' : 'Multi-restart',
    };
  }

  IconData _iconOf(IssueMinerListKind value) {
    return switch (value) {
      IssueMinerListKind.abnormal => Icons.warning_amber_rounded,
      IssueMinerListKind.fault => Icons.build_circle_rounded,
      IssueMinerListKind.selfCheckFailure => Icons.fact_check_rounded,
      IssueMinerListKind.multiRestart => Icons.restart_alt_rounded,
    };
  }

  Color _accentColor(IssueMinerListKind value) {
    return switch (value) {
      IssueMinerListKind.abnormal => const Color(0xFFD77700),
      IssueMinerListKind.fault => const Color(0xFFD95050),
      IssueMinerListKind.selfCheckFailure => const Color(0xFF7A4DDB),
      IssueMinerListKind.multiRestart => const Color(0xFF5A7BEF),
    };
  }
}

class _KindPill extends StatelessWidget {
  const _KindPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
