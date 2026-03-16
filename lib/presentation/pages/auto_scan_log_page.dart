import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/services/background_scan_service.dart';

class AutoScanLogPage extends ConsumerStatefulWidget {
  const AutoScanLogPage({super.key});

  @override
  ConsumerState<AutoScanLogPage> createState() => _AutoScanLogPageState();
}

class _AutoScanLogPageState extends ConsumerState<AutoScanLogPage> {
  late Future<List<AutoScanLogEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = BackgroundScanService.getAutoScanLogs();
  }

  Future<void> _reload() async {
    setState(() {
      _future = BackgroundScanService.getAutoScanLogs();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizer(ref);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('app.autoScanLog.title')),
      ),
      body: FutureBuilder<List<AutoScanLogEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = snapshot.data ?? const <AutoScanLogEntry>[];
          if (logs.isEmpty) {
            return Center(
              child: Text(
                l10n.t('app.autoScanLog.empty'),
                style: const TextStyle(color: Colors.black54),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final log = logs[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StatusChip(status: log.status, label: _statusText(l10n, log.status)),
                            const Spacer(),
                            if (log.onlineCount != null)
                              Text(
                                l10n.t(
                                  'app.autoScanLog.onlineCount',
                                  params: {'count': log.onlineCount.toString()},
                                ),
                                style: const TextStyle(color: Colors.black54),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.t(
                            'app.autoScanLog.startedAt',
                            params: {'time': _formatDateTime(log.startedAt)},
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.t(
                            'app.autoScanLog.finishedAt',
                            params: {
                              'time': log.finishedAt == null
                                  ? '--:--'
                                  : _formatDateTime(log.finishedAt!),
                            },
                          ),
                        ),
                        if (log.note != null && log.note!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            log.note!,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                        if (log.stageDurationsMs.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            l10n.t('app.autoScanLog.stageDurations'),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          ...log.stageDurationsMs.entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _stageText(l10n, entry.key),
                                      style: const TextStyle(color: Colors.black87),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDuration(entry.value),
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm').format(value);
  }

  String _statusText(AppLocalizer l10n, String status) {
    return switch (status) {
      'success' => l10n.t('app.autoScanLog.status.success'),
      'failed' => l10n.t('app.autoScanLog.status.failed'),
      'skipped' => l10n.t('app.autoScanLog.status.skipped'),
      'running' => l10n.t('app.autoScanLog.status.running'),
      _ => l10n.t('app.autoScanLog.status.unknown'),
    };
  }

  String _stageText(AppLocalizer l10n, String stageKey) {
    return l10n.t(stageKey);
  }

  String _formatDuration(int milliseconds) {
    final totalSeconds = (milliseconds / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.label,
  });

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'success' => Colors.green,
      'failed' => Colors.red,
      'skipped' => Colors.orange,
      'running' => Colors.blue,
      _ => Colors.grey,
    };
    return Chip(
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
