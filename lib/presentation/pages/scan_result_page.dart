import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/eastern_time_utils.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/domain/entities/scan_segment_record.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/localization/legacy_zh_texts.dart';
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
    final segmentsState = ref.watch(
      scanControllerProvider.select((state) => state.segments),
    );
    final l10n = AppLocalizer(ref);
    final segments = segmentsState.where((segment) {
      if (_query.isEmpty) {
        return true;
      }
      return IpUtils.formatIpBlockLabel(segment.scope).contains(_query);
    }).toList(growable: false)
      ..sort((a, b) => IpUtils.compareIpBlocks(a.scope, b.scope));

    if (segmentsState.isEmpty) {
      return Center(child: Text(l10n.t('results.empty')));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.t('results.searchLabel'),
                  hintText: l10n.t('results.searchHint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: const Color(0xFF2F67D8).withValues(alpha: 0.16),
                    ),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF9FBFF),
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
                          icon: const Icon(Icons.clear_rounded),
                        ),
                ),
                onChanged: (value) {
                  setState(() {
                    _query = value.trim();
                  });
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: segments.length,
            itemBuilder: (context, index) {
              final segment = segments[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SegmentCard(
                  key: ValueKey(segment.scope),
                  segment: segment,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SegmentCard extends ConsumerWidget {
  const _SegmentCard({super.key, required this.segment});

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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F67D8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.router_outlined,
                      color: Color(0xFF2F67D8),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      displayScope,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (segment.hasIssues)
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SegmentInfoTile(
                      icon: Icons.update_rounded,
                      label: LegacyZhTexts.segmentLastScan,
                      child: _DateTimeValue(
                        value: segment.updatedAt,
                        timeColor: const Color(0xFF2EAF62),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SegmentInfoTile(
                      icon: Icons.travel_explore_outlined,
                      label: LegacyZhTexts.segmentScope,
                      child: Text(
                        displayScope,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF30343F),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.9,
                children: [
                  _SegmentMetricCard(
                    label: LegacyZhTexts.segmentOnline,
                    value: '${segment.onlineCount}',
                    color: Colors.green,
                    icon: Icons.wifi_rounded,
                  ),
                  _SegmentMetricCard(
                    label: LegacyZhTexts.segmentUnresponsive,
                    value: '${segment.unresponsiveCount}',
                    color: Colors.amber.shade700,
                    icon: Icons.portable_wifi_off_rounded,
                  ),
                  _SegmentMetricCard(
                    label: LegacyZhTexts.segmentOffline,
                    value: '${segment.offlineCount}',
                    color: Colors.red.shade400,
                    icon: Icons.power_off_rounded,
                  ),
                  _SegmentMetricCard(
                    label: LegacyZhTexts.segmentRetired,
                    value: '${segment.retiredCount}',
                    color: Colors.grey.shade500,
                    icon: Icons.inventory_2_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallInfoChip(
                    icon: Icons.memory_outlined,
                    text: l10n.t(
                      'results.trackedMiners',
                      params: {'count': segment.miners.length.toString()},
                    ),
                  ),
                  if (segment.hasIssues)
                    _SmallInfoChip(
                      icon: Icons.warning_amber_rounded,
                      text: l10n.t(
                        'results.issueCount',
                        params: {'count': segment.issueCount.toString()},
                      ),
                      color: Colors.orange,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentInfoTile extends StatelessWidget {
  const _SegmentInfoTile({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF6F748B)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6F748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DateTimeValue extends StatelessWidget {
  const _DateTimeValue({
    required this.value,
    required this.timeColor,
  });

  final DateTime value;
  final Color timeColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          EasternTimeUtils.format(value, pattern: 'yyyy-MM-dd'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF70778B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          EasternTimeUtils.format(value, pattern: 'HH:mm'),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: timeColor,
          ),
        ),
      ],
    );
  }
}

class _SegmentMetricCard extends StatelessWidget {
  const _SegmentMetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6F748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallInfoChip extends StatelessWidget {
  const _SmallInfoChip({
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? const Color(0xFF6F748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: chipColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}
