import 'package:volcminer/domain/entities/scan_view.dart';
import 'package:volcminer/domain/repositories/scan_view_repository.dart';

class ManageScanViewUseCase {
  ManageScanViewUseCase(this._repository);

  final ScanViewRepository _repository;

  Future<List<ScanView>> getLocal() => _repository.getLocal();

  Future<List<ScanView>> fetchRemote() => _repository.fetchRemote();

  Future<void> saveLocal(ScanView view) => _repository.saveLocal(view);

  Future<void> deleteLocal(String viewId) => _repository.deleteLocal(viewId);

  Future<void> syncRemote(List<ScanView> views) =>
      _repository.syncRemote(views);

  Future<bool> hasRemoteSyncSucceeded() => _repository.hasRemoteSyncSucceeded();

  Future<List<String>> setSelected(List<String> ids, SelectionMode mode) {
    return _repository.setSelected(ids, mode);
  }
}
