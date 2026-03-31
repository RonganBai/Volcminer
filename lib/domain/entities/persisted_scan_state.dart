import 'package:volcminer/domain/entities/scan_segment_record.dart';
import 'package:volcminer/domain/entities/hashrate_sample.dart';

class PersistedScanState {
  const PersistedScanState({
    required this.segments,
    required this.ledActiveIps,
    required this.knownMinerIpsByScope,
    required this.ignoredMinerIps,
    required this.hashrateHistory,
    required this.lastScanAt,
    required this.generatedAt,
    required this.nextScheduledAt,
    required this.nextGlobalScanAt,
    required this.nextScheduledIsGlobalAllViews,
    required this.serverMinerCount,
    required this.serverOnlineCount,
    required this.serverUnresponsiveCount,
    required this.serverOfflineCount,
    required this.serverPendingRetireCount,
    required this.serverDiagnosisCount,
    required this.serverRepeatedOfflineCount,
  });

  final List<ScanSegmentRecord> segments;
  final Set<String> ledActiveIps;
  final Map<String, Set<String>> knownMinerIpsByScope;
  final Set<String> ignoredMinerIps;
  final List<HashrateSample> hashrateHistory;
  final DateTime? lastScanAt;
  final DateTime? generatedAt;
  final DateTime? nextScheduledAt;
  final DateTime? nextGlobalScanAt;
  final bool nextScheduledIsGlobalAllViews;
  final int? serverMinerCount;
  final int? serverOnlineCount;
  final int? serverUnresponsiveCount;
  final int? serverOfflineCount;
  final int? serverPendingRetireCount;
  final int? serverDiagnosisCount;
  final int? serverRepeatedOfflineCount;
}
