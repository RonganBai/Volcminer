import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/domain/entities/scan_segment_record.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/pages/scan_session_detail_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class ScanResultPage extends ConsumerStatefulWidget {
  const ScanResultPage({super.key});

  @override
  ConsumerState<ScanResultPage> createState() => _ScanResultPageState();
}

class _ScanResultPageState extends ConsumerState<ScanResultPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanControllerProvider);
    final l10n = AppLocalizer(ref);
    final segments = scanState.segments.where((segment) {
      if (_query.isEmpty) {
        return true;
      }
      return IpUtils.formatIpBlockLabel(segment.scope).contains(_query);
    }).toList(growable: false)
      ..sort((a, b) => IpUtils.compareIpBlocks(a.scope, b.scope));

    if (scanState.segments.isEmpty) {
      return Center(child: Text(l10n.t('results.empty')));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: l10n.t('results.searchLabel'),
              hintText: l10n.t('results.searchHint'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                        });
                      },
                      tooltip: l10n.t('common.clearInput'),
                      icon: const Icon(Icons.clear),
                    ),
            ),
            onChanged: (value) {
              setState(() {
                _query = value.trim();
              });
            },
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              ...segments.map(
                (segment) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SegmentCard(segment: segment),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentCard extends ConsumerWidget {
  const _SegmentCard({required this.segment});

  final ScanSegmentRecord segment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayScope = IpUtils.formatIpBlockLabel(segment.scope);
    final l10n = AppLocalizer(ref);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ScanSessionDetailPage(segment: segment),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      displayScope,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (segment.hasIssues)
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.t(
                  'results.lastScan',
                  params: {
                    'time':
                        DateFormat('yyyy-MM-dd HH:mm:ss').format(segment.updatedAt),
                  },
                ),
              ),
              Text(l10n.t('results.ipBlock', params: {'scope': displayScope})),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 420;
                  final cards = [
                    _countChip(
                      context,
                      color: Colors.green,
                      text: l10n.t(
                        'results.onlineMiners',
                        params: {'count': '${segment.onlineCount}'},
                      ),
                    ),
                    _countChip(
                      context,
                      color: Colors.amber.shade700,
                      text: l10n.t(
                        'results.unresponsiveMiners',
                        params: {'count': '${segment.unresponsiveCount}'},
                      ),
                    ),
                    _countChip(
                      context,
                      color: Colors.red.shade400,
                      text: l10n.t(
                        'results.offlineMiners',
                        params: {'count': '${segment.offlineCount}'},
                      ),
                    ),
                    _countChip(
                      context,
                      color: Colors.grey.shade500,
                      text: l10n.t(
                        'results.retiredMiners',
                        params: {'count': '${segment.retiredCount}'},
                      ),
                    ),
                  ];
                  if (wide) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: cards,
                    );
                  }
                  return Column(
                    children: [
                      Row(children: [Expanded(child: cards[0]), const SizedBox(width: 8), Expanded(child: cards[1])]),
                      const SizedBox(height: 8),
                      Row(children: [Expanded(child: cards[2]), const SizedBox(width: 8), Expanded(child: cards[3])]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                l10n.t(
                  'results.trackedMiners',
                  params: {'count': segment.miners.length.toString()},
                ),
              ),
              if (segment.hasIssues)
                Text(
                  l10n.t(
                    'results.issueCount',
                    params: {'count': segment.issueCount.toString()},
                  ),
                  style: const TextStyle(color: Colors.orange),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countChip(
    BuildContext context, {
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(text)),
        ],
      ),
    );
  }
}
