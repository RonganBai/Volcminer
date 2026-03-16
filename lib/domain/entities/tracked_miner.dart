import 'package:volcminer/core/utils/hashrate_utils.dart';
import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/entities/miner_issue_diagnosis.dart';
import 'package:volcminer/domain/entities/miner_scan_item.dart';

class TrackedMinerState {
  static const String online = 'online';
  static const String unresponsive = 'unresponsive';
  static const String offline = 'offline';
  static const String pendingRetire = 'pending_retire';
}

class TrackedMiner {
  const TrackedMiner({
    required this.ip,
    required this.lastItem,
    required this.lastSeenAt,
    required this.missedScans,
    this.offlineEventCount = 0,
    this.stableOnlineSince,
    this.clearRefineAttempted = false,
    this.offlineSince,
    this.offlineScanMisses = 0,
    this.retiredAt,
    this.zeroHashWaitUntil,
    this.forcedOfflineAt,
    this.diagnosis,
  });

  final String ip;
  final MinerScanItem lastItem;
  final DateTime lastSeenAt;
  final int missedScans;
  final int offlineEventCount;
  final DateTime? stableOnlineSince;
  final bool clearRefineAttempted;
  final DateTime? offlineSince;
  final int offlineScanMisses;
  final DateTime? retiredAt;
  final DateTime? zeroHashWaitUntil;
  final DateTime? forcedOfflineAt;
  final MinerIssueDiagnosis? diagnosis;

  String get state {
    if (retiredAt != null) {
      return TrackedMinerState.pendingRetire;
    }
    if (forcedOfflineAt != null) {
      return TrackedMinerState.offline;
    }
    return switch (missedScans) {
      0 => TrackedMinerState.online,
      1 => TrackedMinerState.unresponsive,
      _ => TrackedMinerState.offline,
    };
  }

  String get stateLabel {
    return switch (state) {
      TrackedMinerState.online => 'Online',
      TrackedMinerState.unresponsive => 'Unresponsive',
      TrackedMinerState.offline => 'Offline',
      _ => 'Pending Retire',
    };
  }

  bool get isOnline => state == TrackedMinerState.online;
  bool get canDelete => state == TrackedMinerState.pendingRetire;
  bool get hasIssue => diagnosis != null;
  bool get isWaitingZeroHashRecheck => zeroHashWaitUntil != null;

  MinerRuntime get runtime => lastItem.runtime;

  double get effectiveHashrate =>
      HashrateUtils.effectiveGh(runtime.ghs5s, runtime.ghsav);

  bool get isZeroHashrate => state == TrackedMinerState.online && effectiveHashrate <= 0;

  TrackedMiner copyWith({
    String? ip,
    MinerScanItem? lastItem,
    DateTime? lastSeenAt,
    int? missedScans,
    int? offlineEventCount,
    DateTime? stableOnlineSince,
    bool clearStableOnlineSince = false,
    bool? clearRefineAttempted,
    DateTime? offlineSince,
    bool clearOfflineSince = false,
    int? offlineScanMisses,
    DateTime? retiredAt,
    bool clearRetiredAt = false,
    DateTime? zeroHashWaitUntil,
    bool clearZeroHashWaitUntil = false,
    DateTime? forcedOfflineAt,
    bool clearForcedOfflineAt = false,
    MinerIssueDiagnosis? diagnosis,
    bool clearDiagnosis = false,
  }) {
    return TrackedMiner(
      ip: ip ?? this.ip,
      lastItem: lastItem ?? this.lastItem,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      missedScans: missedScans ?? this.missedScans,
      offlineEventCount: offlineEventCount ?? this.offlineEventCount,
      stableOnlineSince: clearStableOnlineSince
          ? null
          : (stableOnlineSince ?? this.stableOnlineSince),
      clearRefineAttempted:
          clearRefineAttempted ?? this.clearRefineAttempted,
      offlineSince: clearOfflineSince ? null : (offlineSince ?? this.offlineSince),
      offlineScanMisses: offlineScanMisses ?? this.offlineScanMisses,
      retiredAt: clearRetiredAt ? null : (retiredAt ?? this.retiredAt),
      zeroHashWaitUntil: clearZeroHashWaitUntil
          ? null
          : (zeroHashWaitUntil ?? this.zeroHashWaitUntil),
      forcedOfflineAt: clearForcedOfflineAt
          ? null
          : (forcedOfflineAt ?? this.forcedOfflineAt),
      diagnosis: clearDiagnosis ? null : (diagnosis ?? this.diagnosis),
    );
  }
}
