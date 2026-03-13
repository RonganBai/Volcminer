import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/entities/miner_scan_item.dart';

class ScanSession {
  const ScanSession({
    required this.id,
    required this.scannedAt,
    required this.searchScopes,
    required this.items,
    required this.requestedTargetCount,
  });

  final String id;
  final DateTime scannedAt;
  final List<String> searchScopes;
  final List<MinerScanItem> items;
  final int requestedTargetCount;

  String get scopeLabel => searchScopes.join(' / ');

  int get onlineCount => items
      .where((item) => item.runtime.onlineStatus == MinerRuntimeStatus.online)
      .length;

  int get offlineCount => items
      .where((item) => item.runtime.onlineStatus == MinerRuntimeStatus.offline)
      .length;
}
