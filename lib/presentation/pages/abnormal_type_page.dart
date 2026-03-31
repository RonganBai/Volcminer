import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/abnormal_miner_utils.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/pages/miner_category_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class AbnormalTypePage extends ConsumerWidget {
  const AbnormalTypePage({
    super.key,
    required this.group,
  });

  final String group;

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
    final counts = <String, int>{};
    for (final miner in miners) {
      if (AbnormalMinerUtils.abnormalGroupOf(miner) != group) {
        continue;
      }
      final type = AbnormalMinerUtils.abnormalTypeOf(miner);
      if (type == null) {
        continue;
      }
      counts.update(type, (value) => value + 1, ifAbsent: () => 1);
    }
    final types = counts.keys.toList(growable: false)..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(_groupTitle(l10n, group)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: types.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final type = types[index];
          final titleKey = 'abnormal.type.$type';
          final count = counts[type] ?? 0;
          return Card(
            child: ListTile(
              title: Text(
                _typeTitle(l10n, titleKey, type),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MinerCategoryPage(
                    titleText: _typeTitle(l10n, titleKey, type),
                    titleKey: 'overview.allAbnormalTitle',
                    stateFilter: 'abnormal',
                    abnormalGroup: group,
                    abnormalType: type,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _groupTitle(AppLocalizer l10n, String value) {
    switch (value) {
      case AbnormalMinerGroup.soft:
        return _text(l10n, 'abnormal.group.soft', '软异常');
      case AbnormalMinerGroup.unknown:
        return _text(l10n, 'abnormal.group.unknown', '未分类异常');
      default:
        return _text(l10n, 'abnormal.group.hard', '硬异常');
    }
  }

  String _text(AppLocalizer l10n, String key, String zhFallback) {
    final value = l10n.t(key);
    if (value == key && l10n.isZh) {
      return zhFallback;
    }
    return value;
  }

  String _typeTitle(AppLocalizer l10n, String key, String type) {
    final value = l10n.t(key);
    if (value != key || !l10n.isZh) {
      return value;
    }
    switch (type) {
      case 'zero_hash':
        return '零算力异常';
      case 'reauth':
        return '重新认证';
      case 'temperature':
        return '温度异常';
      case 'dropped_board':
        return '掉板异常';
      case 'all_board_failure':
        return '全板异常';
      case 'power':
        return '电源异常';
      case 'fan':
        return '风扇异常';
      case 'hashboard':
        return '算力板异常';
      default:
        return '通用异常';
    }
  }
}
