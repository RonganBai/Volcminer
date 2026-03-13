import 'package:flutter_test/flutter_test.dart';
import 'package:volcminer/domain/entities/scan_view.dart';
import 'package:volcminer/domain/repositories/scan_view_repository.dart';
import 'package:volcminer/domain/usecases/manage_scan_view_usecase.dart';
import 'package:volcminer/presentation/controllers/scan_view_controller.dart';

class _FakeScanViewRepository implements ScanViewRepository {
  final List<ScanView> _views = [];

  @override
  Future<void> delete(String viewId) async {
    _views.removeWhere((e) => e.id == viewId);
  }

  @override
  Future<List<ScanView>> getAll() async => List.unmodifiable(_views);

  @override
  Future<void> save(ScanView view) async {
    _views.removeWhere((e) => e.id == view.id);
    _views.add(view);
  }

  @override
  Future<List<String>> setSelected(List<String> ids, SelectionMode mode) async {
    if (mode == SelectionMode.single && ids.isNotEmpty) {
      return [ids.last];
    }
    return ids.toSet().toList();
  }
}

void main() {
  test('single selection keeps one id only', () async {
    final repo = _FakeScanViewRepository();
    final useCase = ManageScanViewUseCase(repo);
    final controller = ScanViewController(useCase);

    await controller.addView(
      name: 'A',
      cidr: '192.168.1.0/30',
      startIp: '',
      endIp: '',
      tags: const ['x'],
    );
    await controller.addView(
      name: 'B',
      cidr: '10.0.0.0/30',
      startIp: '',
      endIp: '',
      tags: const ['y'],
    );
    await controller.setMode(SelectionMode.single);
    final first = controller.state.views.first.id;
    final second = controller.state.views.last.id;
    await controller.toggleSelected(first);
    await controller.toggleSelected(second);

    expect(controller.state.selectedIds.length, 1);
    expect(controller.state.selectedIds.first, second);
  });
}
