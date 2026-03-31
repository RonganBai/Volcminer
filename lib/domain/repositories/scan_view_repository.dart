import 'package:volcminer/domain/entities/scan_view.dart';

abstract class ScanViewRepository {
  Future<List<ScanView>> getLocal();
  Future<List<ScanView>> fetchRemote();
  Future<void> saveLocal(ScanView view);
  Future<void> deleteLocal(String viewId);
  Future<void> syncRemote(List<ScanView> views);
  Future<bool> hasRemoteSyncSucceeded();
  Future<List<String>> setSelected(List<String> ids, SelectionMode mode);
}
