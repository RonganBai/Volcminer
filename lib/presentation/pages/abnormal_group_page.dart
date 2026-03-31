import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/abnormal_miner_utils.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/pages/abnormal_type_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class AbnormalGroupPage extends ConsumerWidget {
  const AbnormalGroupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizer(ref);
    final miners = ref.watch(
      scanControllerProvider.select(
        (state) => state.segments
            .expand((segment) => segment.miners)
            .toList(growable: false),
      ),
    );
    final soft = miners
        .where(
          (miner) =>
              AbnormalMinerUtils.abnormalGroupOf(miner) ==
              AbnormalMinerGroup.soft,
        )
        .toList(growable: false);
    final unknown = miners
        .where(
          (miner) =>
              AbnormalMinerUtils.abnormalGroupOf(miner) ==
              AbnormalMinerGroup.unknown,
        )
        .toList(growable: false);
    final hard = miners
        .where(
          (miner) =>
              AbnormalMinerUtils.abnormalGroupOf(miner) ==
              AbnormalMinerGroup.hard,
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(_text(l10n, 'abnormal.group.title', '异常分组')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GroupCard(
            title: _text(l10n, 'abnormal.group.soft', '软异常'),
            subtitle: _text(
              l10n,
              'abnormal.group.softHint',
              '常见为等待恢复、重启复查、临时高温等可继续观察的问题。',
            ),
            count: soft.length,
            color: Colors.orange,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const AbnormalTypePage(group: AbnormalMinerGroup.soft),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _GroupCard(
            title: _text(l10n, 'abnormal.group.unknown', '未分类异常'),
            subtitle: _text(
              l10n,
              'abnormal.group.unknownHint',
              '日志里已有异常，但暂时无法明确归类，建议继续查看详情。',
            ),
            count: unknown.length,
            color: Colors.blueGrey,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const AbnormalTypePage(group: AbnormalMinerGroup.unknown),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _GroupCard(
            title: _text(l10n, 'abnormal.group.hard', '硬异常'),
            subtitle: _text(
              l10n,
              'abnormal.group.hardHint',
              '常见为电源、风扇、算力板等需要处理或更换的故障。',
            ),
            count: hard.length,
            color: Colors.redAccent,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const AbnormalTypePage(group: AbnormalMinerGroup.hard),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _text(AppLocalizer l10n, String key, String zhFallback) {
    final value = l10n.t(key);
    if (value == key && l10n.isZh) {
      return zhFallback;
    }
    return value;
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 26,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
