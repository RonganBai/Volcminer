import 'package:volcminer/domain/entities/scan_view.dart';

abstract class ScanViewRepository {
  Future<List<ScanView>> getAll();
  Future<void> save(ScanView view);
  Future<void> delete(String viewId);
  Future<List<String>> setSelected(List<String> ids, SelectionMode mode);
}
