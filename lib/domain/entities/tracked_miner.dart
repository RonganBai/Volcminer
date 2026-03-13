import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/entities/miner_scan_item.dart';

class TrackedMinerState {
  static const String online = 'online';
  static const String unresponsive = 'unresponsive';
  static const String offline = 'offline';
  static const String retired = 'retired';
}

class TrackedMiner {
  const TrackedMiner({
    required this.ip,
    required this.lastItem,
    required this.lastSeenAt,
    required this.missedScans,
  });

  final String ip;
  final MinerScanItem lastItem;
  final DateTime lastSeenAt;
  final int missedScans;

  String get state {
    return switch (missedScans) {
      0 => TrackedMinerState.online,
      1 => TrackedMinerState.unresponsive,
      2 => TrackedMinerState.offline,
      _ => TrackedMinerState.retired,
    };
  }

  String get stateLabel {
    return switch (state) {
      TrackedMinerState.online => '在线',
      TrackedMinerState.unresponsive => '未响应',
      TrackedMinerState.offline => '离线',
      _ => '下架',
    };
  }

  bool get isOnline => state == TrackedMinerState.online;
  bool get canDelete => state == TrackedMinerState.retired;

  MinerRuntime get runtime => lastItem.runtime;

  TrackedMiner copyWith({
    String? ip,
    MinerScanItem? lastItem,
    DateTime? lastSeenAt,
    int? missedScans,
  }) {
    return TrackedMiner(
      ip: ip ?? this.ip,
      lastItem: lastItem ?? this.lastItem,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      missedScans: missedScans ?? this.missedScans,
    );
  }
}
