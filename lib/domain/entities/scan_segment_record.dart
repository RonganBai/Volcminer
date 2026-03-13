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
