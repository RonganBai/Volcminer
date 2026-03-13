import 'package:volcminer/domain/entities/scan_view.dart';
import 'package:volcminer/domain/repositories/scan_view_repository.dart';

class ManageScanViewUseCase {
  ManageScanViewUseCase(this._repository);

  final ScanViewRepository _repository;

  Future<List<ScanView>> getAll() => _repository.getAll();

  Future<void> save(ScanView view) => _repository.save(view);

  Future<void> delete(String viewId) => _repository.delete(viewId);

  Future<List<String>> setSelected(List<String> ids, SelectionMode mode) {
    return _repository.setSelected(ids, mode);
  }
}
