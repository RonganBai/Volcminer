import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:volcminer/data/models/app_settings_record.dart';
import 'package:volcminer/data/models/pool_slot_record.dart';
import 'package:volcminer/data/models/scan_snapshot_record.dart';
import 'package:volcminer/data/models/scan_view_record.dart';
import 'package:volcminer/domain/entities/app_settings.dart';
import 'package:volcminer/domain/entities/miner_scan_item.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';
import 'package:volcminer/domain/entities/scan_view.dart';

class IsarLocalDataSource {
  IsarLocalDataSource(this._isar);

  final Isar _isar;

  Future<List<ScanView>> getScanViews() async {
    final rows = await _isar.scanViewRecords.where().findAll();
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
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
    return AppSettings(
      fontScale: row.fontScale,
      autoRefreshEnabled: row.autoRefreshEnabled,
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
    final payload = items
        .map(
          (e) => {
            'workerName': e.worker.workerName,
            'ip': e.worker.ip,
            'status': e.worker.status,
            'lastShareTime': e.worker.lastShareTime,
            'dailyHashrate': e.worker.dailyHashrate,
            'rejectRate': e.worker.rejectRate,
            'onlineStatus': e.runtime.onlineStatus,
            'ghs5s': e.runtime.ghs5s,
            'ghsav': e.runtime.ghsav,
            'ambientTemp': e.runtime.ambientTemp,
            'power': e.runtime.power,
            'fan1': e.runtime.fan1,
            'fan2': e.runtime.fan2,
            'fan3': e.runtime.fan3,
            'fan4': e.runtime.fan4,
            'runningMode': e.runtime.runningMode,
            'logSnippet': e.runtime.logSnippet,
            'fetchedAt': e.runtime.fetchedAt.toIso8601String(),
          },
        )
        .toList();

    final row = ScanSnapshotRecord()
      ..id = 1
      ..updatedAt = DateTime.now()
      ..payloadJson = jsonEncode(payload);
    await _isar.writeTxn(() => _isar.scanSnapshotRecords.put(row));
  }
}
