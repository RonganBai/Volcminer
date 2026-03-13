import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/domain/entities/tracked_miner.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/pages/miner_detail_page.dart';

class MinerCategoryPage extends ConsumerWidget {
  const MinerCategoryPage({
    super.key,
    required this.titleKey,
    required this.miners,
  });

  final String titleKey;
  final List<TrackedMinerWithScope> miners;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizer(ref);
    final sorted = [...miners]
      ..sort((a, b) => IpUtils.ipToInt(a.miner.ip).compareTo(IpUtils.ipToInt(b.miner.ip)));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t(titleKey))),
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
                          Text(
                            '${_stateLabel(miner, l10n)} | ${miner.runtime.ghs5s}/${miner.runtime.ghsav}',
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
                              miner.diagnosis!.reason,
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MinerDetailPage(miner: miner),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
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
    final color = hashrateGh > 11000
        ? Colors.green
        : hashrateGh > 5000
            ? Colors.amber
            : Colors.red;
    final widthFactor = (hashrateGh / 15000).clamp(0.08, 1.0);
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
