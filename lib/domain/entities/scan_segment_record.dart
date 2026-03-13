import 'package:volcminer/domain/entities/tracked_miner.dart';

class ScanSegmentRecord {
  const ScanSegmentRecord({
    required this.scope,
    required this.updatedAt,
    required this.miners,
  });

  final String scope;
  final DateTime updatedAt;
  final List<TrackedMiner> miners;

  int get onlineCount => miners.where((miner) => miner.isOnline).length;
  int get unresponsiveCount =>
      miners.where((miner) => miner.state == TrackedMinerState.unresponsive).length;
  int get offlineCount =>
      miners.where((miner) => miner.state == TrackedMinerState.offline).length;
  int get retiredCount =>
      miners.where((miner) => miner.state == TrackedMinerState.retired).length;
  int get issueCount => miners.where((miner) => miner.hasIssue).length;
  bool get hasIssues => issueCount > 0;

  ScanSegmentRecord copyWith({
    String? scope,
    DateTime? updatedAt,
    List<TrackedMiner>? miners,
  }) {
    return ScanSegmentRecord(
      scope: scope ?? this.scope,
      updatedAt: updatedAt ?? this.updatedAt,
      miners: miners ?? this.miners,
    );
  }
}
