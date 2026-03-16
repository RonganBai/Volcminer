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
  });

  final List<ScanSegmentRecord> segments;
  final Set<String> ledActiveIps;
  final Map<String, Set<String>> knownMinerIpsByScope;
  final Set<String> ignoredMinerIps;
  final List<HashrateSample> hashrateHistory;
  final DateTime? lastScanAt;
}
