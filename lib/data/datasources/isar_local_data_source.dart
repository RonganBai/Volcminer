import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/data/models/app_settings_record.dart';
import 'package:volcminer/data/models/pool_slot_record.dart';
import 'package:volcminer/data/models/scan_snapshot_record.dart';
import 'package:volcminer/data/models/scan_view_record.dart';
import 'package:volcminer/domain/entities/app_settings.dart';
import 'package:volcminer/domain/entities/miner_issue_diagnosis.dart';
import 'package:volcminer/domain/entities/miner_scan_item.dart';
import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/entities/persisted_scan_state.dart';
import 'package:volcminer/domain/entities/hashrate_sample.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';
import 'package:volcminer/domain/entities/pool_worker.dart';
import 'package:volcminer/domain/entities/scan_segment_record.dart';
import 'package:volcminer/domain/entities/tracked_miner.dart';
import 'package:volcminer/domain/entities/scan_view.dart';

class IsarLocalDataSource {
  IsarLocalDataSource(this._isar);

  final Isar _isar;

  Future<List<ScanView>> getScanViews() async {
    final rows = await _isar.scanViewRecords.where().findAll();
    rows.sort(
      (a, b) => IpUtils.compareIpBlocks(
        a.cidr.isNotEmpty ? a.cidr : a.startIp,
        b.cidr.isNotEmpty ? b.cidr : b.startIp,
      ),
    );
    return rows
        .map(
          (e) => ScanView(
            id: e.viewId,
            name: e.name,
            cidr: e.cidr,
            startIp: e.startIp,
            endIp: e.endIp,
            tags: e.tags,
            createdAt: e.createdAt,
            updatedAt: e.updatedAt,
          ),
        )
        .toList();
  }

  Future<void> saveScanView(ScanView view) {
    final row = ScanViewRecord()
      ..viewId = view.id
      ..name = view.name
      ..cidr = view.cidr
      ..startIp = view.startIp
      ..endIp = view.endIp
      ..tags = view.tags
      ..createdAt = view.createdAt
      ..updatedAt = view.updatedAt;
    return _isar.writeTxn(() => _isar.scanViewRecords.putByViewId(row));
  }

  Future<void> deleteScanView(String id) {
    return _isar.writeTxn(() => _isar.scanViewRecords.deleteByViewId(id));
  }

  Future<AppSettings> getSettings() async {
    final row = await _isar.appSettingsRecords.get(1);
    if (row == null) {
      return AppSettings.defaults;
    }
    final startMinute = row.autoScanStartMinute.clamp(0, 1439);
    var stopMinute = row.autoScanStopMinute.clamp(0, 1439);
    if (startMinute == 0 && stopMinute == 0) {
      stopMinute = 1439;
    }
    return AppSettings(
      fontScale: row.fontScale,
      autoRefreshEnabled: row.autoRefreshEnabled,
      autoScanStartMinute: startMinute,
      autoScanStopMinute: stopMinute,
      showOfflineEnabled: row.showOfflineEnabled,
      collectLogsEnabled: row.collectLogsEnabled,
      refreshIntervalSec: row.refreshIntervalSec,
      scanConcurrency: row.scanConcurrency,
      poolSearchUsername: row.poolSearchUsername,
      minerUsername: row.minerUsername,
    );
  }

  Future<void> saveSettings(AppSettings settings) {
    final row = AppSettingsRecord()
      ..id = 1
      ..fontScale = settings.fontScale
      ..autoRefreshEnabled = settings.autoRefreshEnabled
      ..autoScanStartMinute = settings.autoScanStartMinute
      ..autoScanStopMinute = settings.autoScanStopMinute
      ..showOfflineEnabled = settings.showOfflineEnabled
      ..collectLogsEnabled = settings.collectLogsEnabled
      ..refreshIntervalSec = settings.refreshIntervalSec
      ..scanConcurrency = settings.scanConcurrency
      ..poolSearchUsername = settings.poolSearchUsername
      ..minerUsername = settings.minerUsername;
    return _isar.writeTxn(() => _isar.appSettingsRecords.put(row));
  }

  Future<List<PoolSlotConfig>> getPoolSlots() async {
    final rows = await _isar.poolSlotRecords.where().findAll();
    rows.sort((a, b) => a.slotNo.compareTo(b.slotNo));
    if (rows.isEmpty) {
      return const [
        PoolSlotConfig(slotNo: 1, poolUrl: '', workerCode: ''),
        PoolSlotConfig(slotNo: 2, poolUrl: '', workerCode: ''),
        PoolSlotConfig(slotNo: 3, poolUrl: '', workerCode: ''),
      ];
    }

    return rows
        .map(
          (e) => PoolSlotConfig(
            slotNo: e.slotNo,
            poolUrl: e.poolUrl,
            workerCode: e.workerCode,
          ),
        )
        .toList();
  }

  Future<void> savePoolSlot(PoolSlotConfig config) {
    final row = PoolSlotRecord()
      ..slotNo = config.slotNo
      ..poolUrl = config.poolUrl
      ..workerCode = config.workerCode;
    return _isar.writeTxn(() => _isar.poolSlotRecords.putBySlotNo(row));
  }

  Future<void> saveSnapshot(List<MinerScanItem> items) async {
    final payload = {
      'items': items.map(_encodeItem).toList(growable: false),
    };

    final row = ScanSnapshotRecord()
      ..id = 1
      ..updatedAt = DateTime.now()
      ..payloadJson = jsonEncode(payload);
    await _isar.writeTxn(() => _isar.scanSnapshotRecords.put(row));
  }

  Future<void> saveScanState({
    required List<ScanSegmentRecord> segments,
    required Set<String> ledActiveIps,
    required Map<String, Set<String>> knownMinerIpsByScope,
    required Set<String> ignoredMinerIps,
    required List<HashrateSample> hashrateHistory,
    DateTime? lastScanAt,
  }) async {
    final payload = {
      'version': 4,
      'lastScanAt': lastScanAt?.toIso8601String(),
      'ledActiveIps': ledActiveIps.toList(growable: false),
      'knownMinerIpsByScope': {
        for (final entry in knownMinerIpsByScope.entries)
          entry.key: entry.value.toList(growable: false),
      },
      'ignoredMinerIps': ignoredMinerIps.toList(growable: false),
      'hashrateHistory': hashrateHistory
          .map(
            (sample) => {
              'recordedAt': sample.recordedAt.toIso8601String(),
              'totalHashrateGh': sample.totalHashrateGh,
            },
          )
          .toList(growable: false),
      'segments': segments.map(_encodeSegment).toList(growable: false),
    };
    final row = ScanSnapshotRecord()
      ..id = 1
      ..updatedAt = DateTime.now()
      ..payloadJson = jsonEncode(payload);
    await _isar.writeTxn(() => _isar.scanSnapshotRecords.put(row));
  }

  Future<PersistedScanState?> loadScanState() async {
    final row = await _isar.scanSnapshotRecords.get(1);
    if (row == null || row.payloadJson.trim().isEmpty) {
      return null;
    }
    final raw = jsonDecode(row.payloadJson);
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final rawSegments = raw['segments'];
    if (rawSegments is! List) {
      return null;
    }
    final segments = rawSegments
        .whereType<Map>()
        .map((entry) => _decodeSegment(Map<String, dynamic>.from(entry)))
        .toList(growable: false);
    final ledActiveIps = ((raw['ledActiveIps'] as List?) ?? const [])
        .map((entry) => '$entry')
        .toSet();
    final rawKnown = raw['knownMinerIpsByScope'];
    final knownMinerIpsByScope = <String, Set<String>>{};
    if (rawKnown is Map) {
      for (final entry in rawKnown.entries) {
        final value = entry.value;
        if (value is List) {
          knownMinerIpsByScope['${entry.key}'] =
              value.map((item) => '$item').toSet();
        }
      }
    }
    final ignoredMinerIps = ((raw['ignoredMinerIps'] as List?) ?? const [])
        .map((entry) => '$entry')
        .toSet();
    final hashrateHistory = ((raw['hashrateHistory'] as List?) ?? const [])
        .whereType<Map>()
        .map((entry) {
          final map = Map<String, dynamic>.from(entry);
          return HashrateSample(
            recordedAt: DateTime.tryParse('${map['recordedAt'] ?? ''}') ??
                DateTime.now(),
            totalHashrateGh:
                (map['totalHashrateGh'] as num?)?.toDouble() ?? 0,
          );
        })
        .toList(growable: false);
    final lastScanAtRaw = raw['lastScanAt'] as String?;
    return PersistedScanState(
      segments: segments,
      ledActiveIps: ledActiveIps,
      knownMinerIpsByScope: knownMinerIpsByScope,
      ignoredMinerIps: ignoredMinerIps,
      hashrateHistory: hashrateHistory,
      lastScanAt: lastScanAtRaw == null ? null : DateTime.tryParse(lastScanAtRaw),
    );
  }

  Map<String, dynamic> _encodeSegment(ScanSegmentRecord segment) {
    return {
      'scope': segment.scope,
      'updatedAt': segment.updatedAt.toIso8601String(),
      'miners': segment.miners.map(_encodeTrackedMiner).toList(growable: false),
    };
  }

  ScanSegmentRecord _decodeSegment(Map<String, dynamic> json) {
    final miners = ((json['miners'] as List?) ?? const [])
        .whereType<Map>()
        .map((entry) => _decodeTrackedMiner(Map<String, dynamic>.from(entry)))
        .toList(growable: false);
    return ScanSegmentRecord(
      scope: '${json['scope'] ?? ''}',
      updatedAt:
          DateTime.tryParse('${json['updatedAt'] ?? ''}') ?? DateTime.now(),
      miners: miners,
    );
  }

  Map<String, dynamic> _encodeTrackedMiner(TrackedMiner miner) {
    return {
      'ip': miner.ip,
      'lastSeenAt': miner.lastSeenAt.toIso8601String(),
      'missedScans': miner.missedScans,
      'offlineEventCount': miner.offlineEventCount,
      'stableOnlineSince': miner.stableOnlineSince?.toIso8601String(),
      'clearRefineAttempted': miner.clearRefineAttempted,
      'offlineSince': miner.offlineSince?.toIso8601String(),
      'offlineScanMisses': miner.offlineScanMisses,
      'retiredAt': miner.retiredAt?.toIso8601String(),
      'zeroHashWaitUntil': miner.zeroHashWaitUntil?.toIso8601String(),
      'forcedOfflineAt': miner.forcedOfflineAt?.toIso8601String(),
      'lastItem': _encodeItem(miner.lastItem),
      if (miner.diagnosis != null) 'diagnosis': _encodeDiagnosis(miner.diagnosis!),
    };
  }

  TrackedMiner _decodeTrackedMiner(Map<String, dynamic> json) {
    return TrackedMiner(
      ip: '${json['ip'] ?? ''}',
      lastSeenAt:
          DateTime.tryParse('${json['lastSeenAt'] ?? ''}') ?? DateTime.now(),
      missedScans: (json['missedScans'] as num?)?.toInt() ?? 0,
      offlineEventCount: (json['offlineEventCount'] as num?)?.toInt() ?? 0,
      stableOnlineSince: json['stableOnlineSince'] == null
          ? null
          : DateTime.tryParse('${json['stableOnlineSince']}'),
      clearRefineAttempted: json['clearRefineAttempted'] == true,
      offlineSince: json['offlineSince'] == null
          ? null
          : DateTime.tryParse('${json['offlineSince']}'),
      offlineScanMisses: (json['offlineScanMisses'] as num?)?.toInt() ?? 0,
      retiredAt: json['retiredAt'] == null
          ? null
          : DateTime.tryParse('${json['retiredAt']}'),
      zeroHashWaitUntil: json['zeroHashWaitUntil'] == null
          ? null
          : DateTime.tryParse('${json['zeroHashWaitUntil']}'),
      forcedOfflineAt: json['forcedOfflineAt'] == null
          ? null
          : DateTime.tryParse('${json['forcedOfflineAt']}'),
      lastItem: _decodeItem(Map<String, dynamic>.from(json['lastItem'] as Map)),
      diagnosis: json['diagnosis'] is Map
          ? _decodeDiagnosis(Map<String, dynamic>.from(json['diagnosis'] as Map))
          : null,
    );
  }

  Map<String, dynamic> _encodeDiagnosis(MinerIssueDiagnosis diagnosis) {
    return {
      'code': diagnosis.code,
      'category': diagnosis.category,
      'reason': diagnosis.reason,
      'solution': diagnosis.solution,
      'logSnippet': diagnosis.logSnippet,
      'detectedAt': diagnosis.detectedAt.toIso8601String(),
      'secondaryCode': diagnosis.secondaryCode,
      'secondaryReason': diagnosis.secondaryReason,
    };
  }

  MinerIssueDiagnosis _decodeDiagnosis(Map<String, dynamic> json) {
    return MinerIssueDiagnosis(
      code: '${json['code'] ?? ''}',
      category: '${json['category'] ?? 'generic'}',
      reason: '${json['reason'] ?? ''}',
      solution: '${json['solution'] ?? ''}',
      logSnippet: '${json['logSnippet'] ?? ''}',
      detectedAt:
          DateTime.tryParse('${json['detectedAt'] ?? ''}') ?? DateTime.now(),
      secondaryCode: json['secondaryCode'] as String?,
      secondaryReason: json['secondaryReason'] as String?,
    );
  }

  Map<String, dynamic> _encodeItem(MinerScanItem item) {
    return {
      'workerName': item.worker.workerName,
      'ip': item.worker.ip,
      'status': item.worker.status,
      'lastShareTime': item.worker.lastShareTime,
      'dailyHashrate': item.worker.dailyHashrate,
      'rejectRate': item.worker.rejectRate,
      'onlineStatus': item.runtime.onlineStatus,
      'ghs5s': item.runtime.ghs5s,
      'ghsav': item.runtime.ghsav,
      'ambientTemp': item.runtime.ambientTemp,
      'power': item.runtime.power,
      'fan1': item.runtime.fan1,
      'fan2': item.runtime.fan2,
      'fan3': item.runtime.fan3,
      'fan4': item.runtime.fan4,
      'runningMode': item.runtime.runningMode,
      'logSnippet': item.runtime.logSnippet,
      'fetchedAt': item.runtime.fetchedAt.toIso8601String(),
    };
  }

  MinerScanItem _decodeItem(Map<String, dynamic> json) {
    final ip = '${json['ip'] ?? ''}';
    return MinerScanItem(
      worker: PoolWorker(
        workerName: '${json['workerName'] ?? ip}',
        ip: ip,
        status: '${json['status'] ?? ''}',
        lastShareTime: '${json['lastShareTime'] ?? ''}',
        dailyHashrate: '${json['dailyHashrate'] ?? ''}',
        rejectRate: '${json['rejectRate'] ?? ''}',
      ),
      runtime: MinerRuntime(
        ip: ip,
        onlineStatus: '${json['onlineStatus'] ?? MinerRuntimeStatus.offline}',
        ghs5s: '${json['ghs5s'] ?? '--'}',
        ghsav: '${json['ghsav'] ?? '--'}',
        ambientTemp: '${json['ambientTemp'] ?? '--'}',
        power: '${json['power'] ?? '--'}',
        fan1: '${json['fan1'] ?? '--'}',
        fan2: '${json['fan2'] ?? '--'}',
        fan3: '${json['fan3'] ?? '--'}',
        fan4: '${json['fan4'] ?? '--'}',
        runningMode: '${json['runningMode'] ?? '--'}',
        logSnippet: '${json['logSnippet'] ?? '--'}',
        fetchedAt:
            DateTime.tryParse('${json['fetchedAt'] ?? ''}') ?? DateTime.now(),
      ),
    );
  }
}
