import 'package:volcminer/data/datasources/isar_local_data_source.dart';
import 'package:volcminer/data/datasources/aggregator_remote_data_source.dart';
import 'package:volcminer/core/utils/server_url_defaults.dart';
import 'package:volcminer/domain/entities/scan_view.dart';
import 'package:volcminer/domain/repositories/scan_view_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanViewRepositoryImpl implements ScanViewRepository {
  ScanViewRepositoryImpl(this._local, this._remote);

  final IsarLocalDataSource _local;
  final AggregatorRemoteDataSource _remote;
  List<String> _selectedIds = const [];
  static const String _serverUrlKey = 'aggregator_server_url';
  static const String _lastRemoteSyncSucceededKey =
      'aggregator_scan_views_last_remote_sync_succeeded';

  @override
  Future<void> deleteLocal(String viewId) async {
    final current = await _local.getScanViews();
    final nextViews = current
        .where((view) => view.id != viewId)
        .toList(growable: false);
    await _replaceLocal(nextViews);
    _selectedIds = _selectedIds.where((e) => e != viewId).toList();
  }

  @override
  Future<List<ScanView>> fetchRemote() async {
    final serverUrl = await _readServerUrl();
    if (serverUrl != null) {
      try {
        final remoteViews = await _remote.loadScanViews(serverUrl);
        await _replaceLocal(remoteViews);
        await _setLastRemoteSyncSucceeded(true);
        return remoteViews;
      } catch (error) {
        throw Exception('Load remote scan views failed: $error');
      }
    }
    return _local.getScanViews();
  }

  @override
  Future<List<ScanView>> getLocal() => _local.getScanViews();

  @override
  Future<bool> hasRemoteSyncSucceeded() async {
    return _readLastRemoteSyncSucceeded();
  }

  @override
  Future<void> saveLocal(ScanView view) async {
    final current = await _local.getScanViews();
    final next = [
      for (final existing in current)
        if (existing.id == view.id) view else existing,
      if (!current.any((existing) => existing.id == view.id)) view,
    ];
    await _replaceLocal(next);
  }

  @override
  Future<void> syncRemote(List<ScanView> views) async {
    await _saveViews(views);
  }

  @override
  Future<List<String>> setSelected(List<String> ids, SelectionMode mode) async {
    if (mode == SelectionMode.single) {
      _selectedIds = ids.isEmpty ? const [] : [ids.last];
    } else {
      _selectedIds = ids.toSet().toList();
    }
    return _selectedIds;
  }

  Future<void> _saveViews(List<ScanView> views) async {
    final serverUrl = await _readServerUrl();
    if (serverUrl != null) {
      final saved = await _remote.saveScanViews(serverUrl, views);
      await _replaceLocal(saved);
      await _setLastRemoteSyncSucceeded(true);
      return;
    }
    await _replaceLocal(views);
  }

  Future<void> _replaceLocal(List<ScanView> views) async {
    final current = await _local.getScanViews();
    for (final view in current) {
      await _local.deleteScanView(view.id);
    }
    for (final view in views) {
      await _local.saveScanView(view);
    }
  }

  Future<String?> _readServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_serverUrlKey)?.trim() ??
        ServerUrlDefaults.value;
    return value.isEmpty ? null : value;
  }

  Future<bool> _readLastRemoteSyncSucceeded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lastRemoteSyncSucceededKey) ?? false;
  }

  Future<void> _setLastRemoteSyncSucceeded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lastRemoteSyncSucceededKey, value);
  }
}
