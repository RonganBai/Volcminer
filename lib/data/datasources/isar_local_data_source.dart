import 'dart:convert';

import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/domain/entities/app_settings.dart';
import 'package:volcminer/domain/entities/hashrate_sample.dart';
import 'package:volcminer/domain/entities/miner_issue_diagnosis.dart';
import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/entities/miner_scan_item.dart';
import 'package:volcminer/domain/entities/persisted_scan_state.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';
import 'package:volcminer/domain/entities/pool_worker.dart';
import 'package:volcminer/domain/entities/scan_segment_record.dart';
import 'package:volcminer/domain/entities/scan_view.dart';
import 'package:volcminer/domain/entities/tracked_miner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IsarLocalDataSource {
  IsarLocalDataSource([Object? _]);

  static const String _scanViewsKey = 'local_scan_views_v1';
  static const String _settingsKey = 'local_settings_v1';
  static const String _poolSlotsKey = 'local_pool_slots_v1';
  static const String _snapshotKey = 'local_snapshot_items_v1';
  static const String _scanStateKey = 'local_scan_state_v1';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<List<ScanView>> getScanViews() async {
    final prefs = await _prefs;
    final decoded = _decodeList(prefs.getString(_scanViewsKey));
    final views =
        decoded
            .whereType<Map<String, dynamic>>()
            .map(_decodeScanView)
            .toList(growable: false)
          ..sort(
            (a, b) => IpUtils.compareIpBlocks(
              a.cidr.isNotEmpty ? a.cidr : a.startIp,
              b.cidr.isNotEmpty ? b.cidr : b.startIp,
            ),
          );
    return views;
  }

  Future<void> saveScanView(ScanView view) async {
    final prefs = await _prefs;
    final current = await getScanViews();
    final next = [
      for (final existing in current)
        if (existing.id == view.id) view else existing,
      if (!current.any((existing) => existing.id == view.id)) view,
    ];
    await prefs.setString(
      _scanViewsKey,
      jsonEncode(next.map(_encodeScanView).toList(growable: false)),
    );
  }

  Future<void> deleteScanView(String id) async {
    final prefs = await _prefs;
    final current = await getScanViews();
    final next = current.where((view) => view.id != id).toList(growable: false);
    await prefs.setString(
      _scanViewsKey,
      jsonEncode(next.map(_encodeScanView).toList(growable: false)),
    );
  }

  Future<AppSettings> getSettings() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return AppSettings.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return AppSettings.defaults;
      }
      final startMinute =
          (decoded['autoScanStartMinute'] as num?)?.toInt().clamp(0, 1439) ?? 0;
      var stopMinute =
          (decoded['autoScanStopMinute'] as num?)?.toInt().clamp(0, 1439) ??
          1439;
      if (startMinute == 0 && stopMinute == 0) {
        stopMinute = 1439;
      }
      return AppSettings(
        fontScale:
            (decoded['fontScale'] as num?)?.toDouble() ??
            AppSettings.defaults.fontScale,
        autoRefreshEnabled:
            decoded['autoRefreshEnabled'] as bool? ??
            AppSettings.defaults.autoRefreshEnabled,
        autoScanStartMinute: startMinute,
        autoScanStopMinute: stopMinute,
        showOfflineEnabled:
            decoded['showOfflineEnabled'] as bool? ??
            AppSettings.defaults.showOfflineEnabled,
        collectLogsEnabled:
            decoded['collectLogsEnabled'] as bool? ??
            AppSettings.defaults.collectLogsEnabled,
        minerDetailChainsCollapsedByDefault:
            decoded['minerDetailChainsCollapsedByDefault'] as bool? ??
            AppSettings.defaults.minerDetailChainsCollapsedByDefault,
        minerDetailLogsCollapsedByDefault:
            decoded['minerDetailLogsCollapsedByDefault'] as bool? ??
            AppSettings.defaults.minerDetailLogsCollapsedByDefault,
        refreshIntervalSec:
            (decoded['refreshIntervalSec'] as num?)?.toInt() ??
            AppSettings.defaults.refreshIntervalSec,
        scanConcurrency:
            (decoded['scanConcurrency'] as num?)?.toInt() ??
            AppSettings.defaults.scanConcurrency,
        poolSearchUsername:
            '${decoded['poolSearchUsername'] ?? AppSettings.defaults.poolSearchUsername}',
        minerUsername:
            '${decoded['minerUsername'] ?? AppSettings.defaults.minerUsername}',
        subAccounts: ((decoded['subAccounts'] as List?) ?? const [])
            .map((entry) => '$entry'.trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false),
        miningUrls: ((decoded['miningUrls'] as List?) ?? const [])
            .map((entry) => '$entry'.trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false),
      );
    } catch (_) {
      return AppSettings.defaults;
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await _prefs;
    await prefs.setString(
      _settingsKey,
      jsonEncode({
        'fontScale': settings.fontScale,
        'autoRefreshEnabled': settings.autoRefreshEnabled,
        'autoScanStartMinute': settings.autoScanStartMinute,
        'autoScanStopMinute': settings.autoScanStopMinute,
        'showOfflineEnabled': settings.showOfflineEnabled,
        'collectLogsEnabled': settings.collectLogsEnabled,
        'minerDetailChainsCollapsedByDefault':
            settings.minerDetailChainsCollapsedByDefault,
        'minerDetailLogsCollapsedByDefault':
            settings.minerDetailLogsCollapsedByDefault,
        'refreshIntervalSec': settings.refreshIntervalSec,
        'scanConcurrency': settings.scanConcurrency,
        'poolSearchUsername': settings.poolSearchUsername,
        'minerUsername': settings.minerUsername,
        'subAccounts': settings.subAccounts,
        'miningUrls': settings.miningUrls,
      }),
    );
  }

  Future<List<PoolSlotConfig>> getPoolSlots() async {
    final prefs = await _prefs;
    final decoded = _decodeList(prefs.getString(_poolSlotsKey));
    final slots =
        decoded
            .whereType<Map<String, dynamic>>()
            .map(
              (entry) => PoolSlotConfig(
                slotNo: (entry['slotNo'] as num?)?.toInt() ?? 0,
                poolUrl: '${entry['poolUrl'] ?? ''}',
                workerCode: '${entry['workerCode'] ?? ''}',
              ),
            )
            .where((slot) => slot.slotNo > 0)
            .toList(growable: false)
          ..sort((a, b) => a.slotNo.compareTo(b.slotNo));
    if (slots.isEmpty) {
      return const [
        PoolSlotConfig(slotNo: 1, poolUrl: '', workerCode: ''),
        PoolSlotConfig(slotNo: 2, poolUrl: '', workerCode: ''),
        PoolSlotConfig(slotNo: 3, poolUrl: '', workerCode: ''),
      ];
    }
    return slots;
  }

  Future<void> savePoolSlot(PoolSlotConfig config) async {
    final prefs = await _prefs;
    final current = await getPoolSlots();
    final next = [
      for (final slot in current)
        if (slot.slotNo == config.slotNo) config else slot,
      if (!current.any((slot) => slot.slotNo == config.slotNo)) config,
    ]..sort((a, b) => a.slotNo.compareTo(b.slotNo));
    await prefs.setString(
      _poolSlotsKey,
      jsonEncode(
        next
            .map(
              (slot) => {
                'slotNo': slot.slotNo,
                'poolUrl': slot.poolUrl,
                'workerCode': slot.workerCode,
              },
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> saveSnapshot(List<MinerScanItem> items) async {
    final prefs = await _prefs;
    final payload = {'items': items.map(_encodeItem).toList(growable: false)};
    await prefs.setString(_snapshotKey, jsonEncode(payload));
  }

  Future<void> saveScanState({
    required List<ScanSegmentRecord> segments,
    required Set<String> ledActiveIps,
    required Map<String, Set<String>> knownMinerIpsByScope,
    required Set<String> ignoredMinerIps,
    required List<HashrateSample> hashrateHistory,
    DateTime? lastScanAt,
    DateTime? generatedAt,
    DateTime? nextScheduledAt,
    DateTime? nextGlobalScanAt,
    bool nextScheduledIsGlobalAllViews = false,
    int? serverMinerCount,
    int? serverOnlineCount,
    int? serverUnresponsiveCount,
    int? serverOfflineCount,
    int? serverPendingRetireCount,
    int? serverDiagnosisCount,
    int? serverRepeatedOfflineCount,
  }) async {
    final prefs = await _prefs;
    final payload = {
      'version': 7,
      'lastScanAt': lastScanAt?.toIso8601String(),
      'generatedAt': generatedAt?.toIso8601String(),
      'nextScheduledAt': nextScheduledAt?.toIso8601String(),
      'nextGlobalScanAt': nextGlobalScanAt?.toIso8601String(),
      'nextScheduledIsGlobalAllViews': nextScheduledIsGlobalAllViews,
      'serverMinerCount': serverMinerCount,
      'serverOnlineCount': serverOnlineCount,
      'serverUnresponsiveCount': serverUnresponsiveCount,
      'serverOfflineCount': serverOfflineCount,
      'serverPendingRetireCount': serverPendingRetireCount,
      'serverDiagnosisCount': serverDiagnosisCount,
      'serverRepeatedOfflineCount': serverRepeatedOfflineCount,
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
    await prefs.setString(_scanStateKey, jsonEncode(payload));
  }

  Future<PersistedScanState?> loadScanState() async {
    final prefs = await _prefs;
    final rawText = prefs.getString(_scanStateKey);
    if (rawText == null || rawText.trim().isEmpty) {
      return null;
    }
    final raw = jsonDecode(rawText);
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
          knownMinerIpsByScope['${entry.key}'] = value
              .map((item) => '$item')
              .toSet();
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
            recordedAt:
                DateTime.tryParse('${map['recordedAt'] ?? ''}') ??
                DateTime.now(),
            totalHashrateGh: (map['totalHashrateGh'] as num?)?.toDouble() ?? 0,
          );
        })
        .toList(growable: false);
    final lastScanAtRaw = raw['lastScanAt'] as String?;
    final generatedAtRaw = raw['generatedAt'] as String?;
    final nextScheduledAtRaw = raw['nextScheduledAt'] as String?;
    final nextGlobalScanAtRaw = raw['nextGlobalScanAt'] as String?;
    return PersistedScanState(
      segments: segments,
      ledActiveIps: ledActiveIps,
      knownMinerIpsByScope: knownMinerIpsByScope,
      ignoredMinerIps: ignoredMinerIps,
      hashrateHistory: hashrateHistory,
      lastScanAt: lastScanAtRaw == null
          ? null
          : DateTime.tryParse(lastScanAtRaw),
      generatedAt: generatedAtRaw == null
          ? null
          : DateTime.tryParse(generatedAtRaw),
      nextScheduledAt: nextScheduledAtRaw == null
          ? null
          : DateTime.tryParse(nextScheduledAtRaw),
      nextGlobalScanAt: nextGlobalScanAtRaw == null
          ? null
          : DateTime.tryParse(nextGlobalScanAtRaw),
      nextScheduledIsGlobalAllViews:
          raw['nextScheduledIsGlobalAllViews'] == true,
      serverMinerCount: (raw['serverMinerCount'] as num?)?.toInt(),
      serverOnlineCount: (raw['serverOnlineCount'] as num?)?.toInt(),
      serverUnresponsiveCount: (raw['serverUnresponsiveCount'] as num?)
          ?.toInt(),
      serverOfflineCount: (raw['serverOfflineCount'] as num?)?.toInt(),
      serverPendingRetireCount: (raw['serverPendingRetireCount'] as num?)
          ?.toInt(),
      serverDiagnosisCount: (raw['serverDiagnosisCount'] as num?)?.toInt(),
      serverRepeatedOfflineCount: (raw['serverRepeatedOfflineCount'] as num?)
          ?.toInt(),
    );
  }

  List<dynamic> _decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic> _encodeScanView(ScanView view) => {
    'id': view.id,
    'name': view.name,
    'cidr': view.cidr,
    'startIp': view.startIp,
    'endIp': view.endIp,
    'tags': view.tags,
    'createdAt': view.createdAt.toIso8601String(),
    'updatedAt': view.updatedAt.toIso8601String(),
  };

  ScanView _decodeScanView(Map<String, dynamic> json) => ScanView(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    cidr: '${json['cidr'] ?? ''}',
    startIp: '${json['startIp'] ?? ''}',
    endIp: '${json['endIp'] ?? ''}',
    tags: ((json['tags'] as List?) ?? const [])
        .map((e) => '$e')
        .toList(growable: false),
    createdAt:
        DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse('${json['updatedAt'] ?? ''}') ?? DateTime.now(),
  );

  Map<String, dynamic> _encodeSegment(ScanSegmentRecord segment) => {
    'scope': segment.scope,
    'updatedAt': segment.updatedAt.toIso8601String(),
    'miners': segment.miners.map(_encodeTrackedMiner).toList(growable: false),
  };

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

  Map<String, dynamic> _encodeTrackedMiner(TrackedMiner miner) => {
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
    'zeroHashRestartPending': miner.zeroHashRestartPending,
    'droppedBoardRestartPending': miner.droppedBoardRestartPending,
    'allBoardFailureRestartPending': miner.allBoardFailureRestartPending,
    'tempFullSpeedMarkedAt': miner.tempFullSpeedMarkedAt?.toIso8601String(),
    'tempFullSpeedScanMisses': miner.tempFullSpeedScanMisses,
    'forcedOfflineAt': miner.forcedOfflineAt?.toIso8601String(),
    'lastItem': _encodeItem(miner.lastItem),
    if (miner.diagnosis != null)
      'diagnosis': _encodeDiagnosis(miner.diagnosis!),
  };

  TrackedMiner _decodeTrackedMiner(Map<String, dynamic> json) => TrackedMiner(
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
    zeroHashRestartPending: json['zeroHashRestartPending'] == true,
    droppedBoardRestartPending: json['droppedBoardRestartPending'] == true,
    allBoardFailureRestartPending:
        json['allBoardFailureRestartPending'] == true,
    tempFullSpeedMarkedAt: json['tempFullSpeedMarkedAt'] == null
        ? null
        : DateTime.tryParse('${json['tempFullSpeedMarkedAt']}'),
    tempFullSpeedScanMisses:
        (json['tempFullSpeedScanMisses'] as num?)?.toInt() ?? 0,
    forcedOfflineAt: json['forcedOfflineAt'] == null
        ? null
        : DateTime.tryParse('${json['forcedOfflineAt']}'),
    lastItem: _decodeItem(Map<String, dynamic>.from(json['lastItem'] as Map)),
    diagnosis: json['diagnosis'] is Map
        ? _decodeDiagnosis(Map<String, dynamic>.from(json['diagnosis'] as Map))
        : null,
  );

  Map<String, dynamic> _encodeDiagnosis(MinerIssueDiagnosis diagnosis) => {
    'code': diagnosis.code,
    'category': diagnosis.category,
    'reason': diagnosis.reason,
    'solution': diagnosis.solution,
    'logSnippet': diagnosis.logSnippet,
    'detectedAt': diagnosis.detectedAt.toIso8601String(),
    'secondaryCode': diagnosis.secondaryCode,
    'secondaryReason': diagnosis.secondaryReason,
  };

  MinerIssueDiagnosis _decodeDiagnosis(Map<String, dynamic> json) =>
      MinerIssueDiagnosis(
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

  Map<String, dynamic> _encodeItem(MinerScanItem item) => {
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
    'chains': item.runtime.chains
        .map(
          (chain) => {
            'index': chain.index,
            'chainRate': chain.chainRate,
            'temp': chain.temp,
            'freq': chain.freq,
            'hw': chain.hw,
            'chainAcn': chain.chainAcn,
            'chainAcs': chain.chainAcs,
          },
        )
        .toList(growable: false),
    'logSnippet': item.runtime.logSnippet,
    'fetchedAt': item.runtime.fetchedAt.toIso8601String(),
  };

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
        chains: ((json['chains'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (entry) => MinerChainStatus(
                index:
                    (entry['index'] as num?)?.toInt() ??
                    int.tryParse('${entry['index'] ?? ''}') ??
                    0,
                chainRate: '${entry['chainRate'] ?? '--'}',
                temp: '${entry['temp'] ?? '--'}',
                freq: '${entry['freq'] ?? '--'}',
                hw: '${entry['hw'] ?? '--'}',
                chainAcn: '${entry['chainAcn'] ?? '--'}',
                chainAcs: '${entry['chainAcs'] ?? '--'}',
              ),
            )
            .where((chain) => chain.index >= 0)
            .toList(growable: false),
        logSnippet: '${json['logSnippet'] ?? '--'}',
        fetchedAt:
            DateTime.tryParse('${json['fetchedAt'] ?? ''}') ?? DateTime.now(),
      ),
    );
  }
}
