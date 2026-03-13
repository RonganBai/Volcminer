import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:volcminer/domain/entities/scan_view.dart';
import 'package:volcminer/domain/usecases/manage_scan_view_usecase.dart';

class ScanViewState {
  const ScanViewState({
    required this.views,
    required this.selectedIds,
    required this.mode,
    required this.loading,
    required this.error,
  });

  final List<ScanView> views;
  final Set<String> selectedIds;
  final SelectionMode mode;
  final bool loading;
  final String? error;

  factory ScanViewState.initial() => const ScanViewState(
    views: [],
    selectedIds: {},
    mode: SelectionMode.multi,
    loading: false,
    error: null,
  );

  ScanViewState copyWith({
    List<ScanView>? views,
    Set<String>? selectedIds,
    SelectionMode? mode,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return ScanViewState(
      views: views ?? this.views,
      selectedIds: selectedIds ?? this.selectedIds,
      mode: mode ?? this.mode,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ScanViewController extends StateNotifier<ScanViewState> {
  ScanViewController(this._useCase) : super(ScanViewState.initial()) {
    load();
  }

  final ManageScanViewUseCase _useCase;
  final Uuid _uuid = const Uuid();

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final views = await _useCase.getAll();
      state = state.copyWith(views: views, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: '读取组合视图失败: $e');
    }
  }

  Future<void> addView({
    required String name,
    required String cidr,
    required String startIp,
    required String endIp,
    required List<String> tags,
  }) async {
    final now = DateTime.now();
    final view = ScanView(
      id: _uuid.v4(),
      name: name.trim(),
      cidr: cidr.trim(),
      startIp: startIp.trim(),
      endIp: endIp.trim(),
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );
    await _useCase.save(view);
    await load();
  }

  Future<void> deleteView(String id) async {
    await _useCase.delete(id);
    final next = {...state.selectedIds}..remove(id);
    state = state.copyWith(selectedIds: next);
    await load();
  }

  Future<void> setMode(SelectionMode mode) async {
    state = state.copyWith(mode: mode);
    if (mode == SelectionMode.single && state.selectedIds.length > 1) {
      final keep = state.selectedIds.last;
      state = state.copyWith(selectedIds: {keep});
    }
  }

  Future<void> toggleSelected(String id) async {
    final current = {...state.selectedIds};
    if (state.mode == SelectionMode.single) {
      if (current.contains(id)) {
        current.clear();
      } else {
        current
          ..clear()
          ..add(id);
      }
    } else {
      if (current.contains(id)) {
        current.remove(id);
      } else {
        current.add(id);
      }
    }
    final normalized = await _useCase.setSelected(
      current.toList(growable: false),
      state.mode,
    );
    state = state.copyWith(selectedIds: normalized.toSet());
  }
}
