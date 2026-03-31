import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/eastern_time_utils.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/data/datasources/aggregator_remote_data_source.dart';
import 'package:volcminer/presentation/localization/error_reason_text.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class RepeatedOfflineSegmentPage extends ConsumerStatefulWidget {
  const RepeatedOfflineSegmentPage({super.key, required this.segment});

  final String segment;

  @override
  ConsumerState<RepeatedOfflineSegmentPage> createState() =>
      _RepeatedOfflineSegmentPageState();
}

class _RepeatedOfflineSegmentPageState
    extends ConsumerState<RepeatedOfflineSegmentPage> {
  Future<AggregatorRepeatedOfflineSegmentDetails>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AggregatorRepeatedOfflineSegmentDetails> _load() {
    final serverUrl = ref.read(settingsControllerProvider).serverUrl;
    return ref
        .read(aggregatorRemoteDataSourceProvider)
        .loadRepeatedOfflineSegment(serverUrl, widget.segment);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final segmentLabel = _displaySegment(widget.segment);
    return Scaffold(
      appBar: AppBar(title: Text('$segmentLabel 多次离线IP')),
      body: FutureBuilder<AggregatorRepeatedOfflineSegmentDetails>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  ErrorReasonText.repeatedOfflineSegmentLoadFailed(
                    widget.segment,
                    snapshot.error ?? '未知错误',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final details = snapshot.data!;
          final miners = [...details.miners]
            ..sort((a, b) => IpUtils.compareIpBlocks(a.ip, b.ip));

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE15B64,
                            ).withValues(alpha: 0.12),
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
                              Text(
                                segmentLabel,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '多次离线IP ${details.minerCount} 台',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...miners.map(
                  (miner) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    miner.ip,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFE15B64,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    '多次离线',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFE15B64),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(
                              label: '矿机名称',
                              value: miner.name.isEmpty ? '--' : miner.name,
                            ),
                            const SizedBox(height: 6),
                            _InfoRow(
                              label: '最后扫描',
                              value: miner.lastSeenAt == null
                                  ? '--'
                                  : EasternTimeUtils.format(
                                      miner.lastSeenAt!,
                                      pattern: 'yyyy-MM-dd HH:mm',
                                    ),
                            ),
                            const SizedBox(height: 6),
                            _InfoRow(
                              label: '标记时间',
                              value: miner.repeatedOfflineMarkedAt == null
                                  ? '--'
                                  : EasternTimeUtils.format(
                                      miner.repeatedOfflineMarkedAt!,
                                      pattern: 'yyyy-MM-dd HH:mm',
                                    ),
                            ),
                          ],
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

  String _displaySegment(String value) {
    final parts = value.split('.');
    if (parts.length == 3 && parts.first == '172') {
      return '${parts[1]}.${parts[2]}';
    }
    return value;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
