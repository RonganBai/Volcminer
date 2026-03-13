import 'package:volcminer/data/datasources/isar_local_data_source.dart';
import 'package:volcminer/domain/entities/scan_view.dart';
import 'package:volcminer/domain/repositories/scan_view_repository.dart';

class ScanViewRepositoryImpl implements ScanViewRepository {
  ScanViewRepositoryImpl(this._local);

  final IsarLocalDataSource _local;
  List<String> _selectedIds = const [];

  @override
  Future<void> delete(String viewId) async {
    await _local.deleteScanView(viewId);
    _selectedIds = _selectedIds.where((e) => e != viewId).toList();
  }

  @override
  Future<List<ScanView>> getAll() => _local.getScanViews();

  @override
  Future<void> save(ScanView view) => _local.saveScanView(view);

  @override
  Future<List<String>> setSelected(List<String> ids, SelectionMode mode) async {
    if (mode == SelectionMode.single) {
      _selectedIds = ids.isEmpty ? const [] : [ids.last];
    } else {
      _selectedIds = ids.toSet().toList();
    }
    return _selectedIds;
  }
}
