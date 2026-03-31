import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/eastern_time_utils.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/data/datasources/aggregator_remote_data_source.dart';
import 'package:volcminer/presentation/pages/repeated_offline_segment_page.dart';
import 'package:volcminer/presentation/localization/error_reason_text.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class RepeatedOfflinePage extends ConsumerStatefulWidget {
  const RepeatedOfflinePage({super.key});

  @override
  ConsumerState<RepeatedOfflinePage> createState() =>
      _RepeatedOfflinePageState();
}

class _RepeatedOfflinePageState extends ConsumerState<RepeatedOfflinePage> {
  Future<AggregatorRepeatedOfflineSummary>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AggregatorRepeatedOfflineSummary> _load() {
    final serverUrl = ref.read(settingsControllerProvider).serverUrl;
    return ref
        .read(aggregatorRemoteDataSourceProvider)
        .loadRepeatedOfflineSummary(serverUrl);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final serverUrl = ref.watch(settingsControllerProvider).serverUrl;
    return Scaffold(
      appBar: AppBar(title: const Text('多次离线IP')),
      body: serverUrl.trim().isEmpty
          ? const Center(child: Text('请先配置服务器地址'))
          : FutureBuilder<AggregatorRepeatedOfflineSummary>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFE15B64),
                            size: 36,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '读取多次离线IP失败',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ErrorReasonText.repeatedOfflineLoadFailed(
                              snapshot.error ?? '未知错误',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final summary = snapshot.data!;
                final segments = [...summary.segments]
                  ..sort(
                    (a, b) => IpUtils.compareIpBlocks(a.segment, b.segment),
                  );

                if (segments.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 120),
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 40,
                          color: Color(0xFF2EAF62),
                        ),
                        SizedBox(height: 12),
                        Center(
                          child: Text(
                            '当前没有多次离线IP',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _RepeatedOfflineSummaryCard(summary: summary),
                      const SizedBox(height: 12),
                      ...segments.map(
                        (segment) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RepeatedOfflineSegmentCard(
                            segment: segment,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => RepeatedOfflineSegmentPage(
                                  segment: segment.segment,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _RepeatedOfflineSummaryCard extends StatelessWidget {
  const _RepeatedOfflineSummaryCard({required this.summary});

  final AggregatorRepeatedOfflineSummary summary;

  @override
  Widget build(BuildContext context) {
    final generatedAt = summary.generatedAt == null
        ? '--'
        : EasternTimeUtils.format(
            summary.generatedAt!,
            pattern: 'yyyy-MM-dd HH:mm',
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE15B64).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE15B64),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PDU可能异常的多次离线IP',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '总数 ${summary.repeatedOfflineCount} · 更新时间 $generatedAt',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepeatedOfflineSegmentCard extends StatelessWidget {
  const _RepeatedOfflineSegmentCard({
    required this.segment,
    required this.onTap,
  });

  final AggregatorRepeatedOfflineSegment segment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = _displaySegment(segment.segment);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F67D8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.dns_rounded, color: Color(0xFF2F67D8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '内部IP数量 ${segment.minerCount}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                segment.minerCount.toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE15B64),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF6F748B)),
            ],
          ),
        ),
      ),
    );
  }

  String _displaySegment(String value) {
    final parts = value.split('.');
    if (parts.length == 3 && parts.first == '172') {
      return '${parts[1]}.${parts[2]}';
    }
    return value;
  }
}
