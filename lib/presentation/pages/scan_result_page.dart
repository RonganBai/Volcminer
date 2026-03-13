import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:volcminer/domain/entities/scan_segment_record.dart';
import 'package:volcminer/presentation/pages/scan_session_detail_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class ScanResultPage extends ConsumerWidget {
  const ScanResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(scanControllerProvider);

    if (scanState.segments.isEmpty) {
      return const Center(
        child: Text('还没有扫描记录，先去 Dashboard 发起一次扫描。'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: scanState.segments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final segment = scanState.segments[index];
        return _SegmentCard(segment: segment);
      },
    );
  }
}

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({required this.segment});

  final ScanSegmentRecord segment;

  @override
  Widget build(BuildContext context) {
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
              Text(
                segment.scope,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Last Scan: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(segment.updatedAt)}',
              ),
              Text('IP Block: ${segment.scope}'),
              Text('Online Miners: ${segment.onlineCount}'),
              Text('Tracked Miners: ${segment.miners.length}'),
            ],
          ),
        ),
      ),
    );
  }
}
