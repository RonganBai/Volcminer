import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:volcminer/domain/entities/scan_view.dart';
import 'package:volcminer/domain/usecases/manage_scan_view_usecase.dart';
import 'package:volcminer/presentation/localization/app_strings.dart';
import 'package:volcminer/presentation/localization/error_reason_text.dart';

class ScanViewState {
  const ScanViewState({
    required this.views,
    required this.selectedIds,
    required this.mode,
    required this.loading,
    required this.cloudLoading,
    required this.syncingRemote,
    required this.error,
  });

  final List<ScanView> views;
  final Set<String> selectedIds;
  final SelectionMode mode;
  final bool loading;
  final bool cloudLoading;
  final bool syncingRemote;
  final String? error;

  factory ScanViewState.initial() => const ScanViewState(
    views: [],
    selectedIds: {},
    mode: SelectionMode.multi,
    loading: false,
    cloudLoading: false,
    syncingRemote: false,
    error: null,
  );

  ScanViewState copyWith({
    List<ScanView>? views,
    Set<String>? selectedIds,
    SelectionMode? mode,
    bool? loading,
    bool? cloudLoading,
    bool? syncingRemote,
    String? error,
    bool clearError = false,
  }) {
    return ScanViewState(
      views: views ?? this.views,
      selectedIds: selectedIds ?? this.selectedIds,
      mode: mode ?? this.mode,
      loading: loading ?? this.loading,
      cloudLoading: cloudLoading ?? this.cloudLoading,
      syncingRemote: syncingRemote ?? this.syncingRemote,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ScanViewController extends StateNotifier<ScanViewState> {
  ScanViewController(this._useCase) : super(ScanViewState.initial()) {
    unawaited(load());
  }

  final ManageScanViewUseCase _useCase;
  final Uuid _uuid = const Uuid();

  Future<void> load() async {
    state = state.copyWith(clearError: true);
    final localViews = await _useCase.getLocal();
    final hasRemoteSyncSucceeded = await _useCase.hasRemoteSyncSucceeded();
    if (localViews.isNotEmpty) {
      state = state.copyWith(
        views: localViews,
        loading: false,
        cloudLoading: false,
        syncingRemote: true,
      );
      unawaited(_refreshRemoteViews(showLoading: false));
      return;
    }

    state = state.copyWith(
      loading: true,
      cloudLoading: true,
      syncingRemote: false,
      views: const [],
    );
    try {
      final views = await _useCase.fetchRemote();
      state = state.copyWith(
        views: views,
        loading: false,
        cloudLoading: false,
        syncingRemote: false,
      );
    } catch (e) {
      if (hasRemoteSyncSucceeded && localViews.isNotEmpty) {
        state = state.copyWith(
          views: localViews,
          loading: false,
          cloudLoading: false,
          syncingRemote: false,
        );
        return;
      }
      state = state.copyWith(
        loading: false,
        cloudLoading: false,
        syncingRemote: false,
        error: ErrorReasonText.scanViewLoadFailed(e),
      );
    }
  }

  Future<void> addView({
    required String name,
    required String cidr,
    required String startIp,
    required String endIp,
    required List<String> tags,
  }) async {
    final normalizedCidr = cidr.trim();
    final normalizedStart = startIp.trim();
    final normalizedEnd = endIp.trim();
    final exists = state.views.any(
      (view) =>
          view.cidr.trim() == normalizedCidr &&
          view.startIp.trim() == normalizedStart &&
          view.endIp.trim() == normalizedEnd,
    );
    if (exists) {
      state = state.copyWith(
        error: AppStrings.english('controller.scanView.duplicate'),
      );
      return;
    }
    final now = DateTime.now();
    final view = ScanView(
      id: _uuid.v4(),
      name: name.trim(),
      cidr: normalizedCidr,
      startIp: normalizedStart,
      endIp: normalizedEnd,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );
    final nextViews = [
      for (final existing in state.views)
        if (existing.id == view.id) view else existing,
      if (!state.views.any((existing) => existing.id == view.id)) view,
    ];
    state = state.copyWith(views: nextViews);
    unawaited(_persistLocalAndRemote(nextViews, changedView: view));
  }

  Future<void> deleteView(String id) async {
    final nextViews = state.views
        .where((view) => view.id != id)
        .toList(growable: false);
    state = state.copyWith(views: nextViews);
    final next = {...state.selectedIds}..remove(id);
    state = state.copyWith(selectedIds: next);
    unawaited(_persistDeleteAndRemote(id, nextViews));
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

  Future<void> selectAll() async {
    final ids = state.views.map((view) => view.id).toList(growable: false);
    final normalized = await _useCase.setSelected(ids, SelectionMode.multi);
    state = state.copyWith(
      mode: SelectionMode.multi,
      selectedIds: normalized.toSet(),
    );
  }

  Future<void> _persistLocalAndRemote(
    List<ScanView> views, {
    ScanView? changedView,
  }) async {
    state = state.copyWith(syncingRemote: true, clearError: true);
    try {
      if (changedView != null) {
        await _useCase.saveLocal(changedView);
      } else {
        for (final view in views) {
          await _useCase.saveLocal(view);
        }
      }
      await _useCase.syncRemote(views);
      state = state.copyWith(syncingRemote: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        syncingRemote: false,
        error: ErrorReasonText.scanViewSyncFailed(e),
      );
    }
  }

  Future<void> _persistDeleteAndRemote(
    String deletedId,
    List<ScanView> views,
  ) async {
    state = state.copyWith(syncingRemote: true, clearError: true);
    try {
      await _useCase.deleteLocal(deletedId);
      await _useCase.syncRemote(views);
      state = state.copyWith(syncingRemote: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        syncingRemote: false,
        error: ErrorReasonText.scanViewSyncFailed(e),
      );
    }
  }

  Future<void> _refreshRemoteViews({required bool showLoading}) async {
    if (showLoading) {
      state = state.copyWith(syncingRemote: true);
    }
    try {
      final remoteViews = await _useCase.fetchRemote();
      state = state.copyWith(
        views: remoteViews,
        syncingRemote: false,
        cloudLoading: false,
        loading: false,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(syncingRemote: false);
    }
  }
}
