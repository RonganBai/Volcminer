import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volcminer/core/utils/hashrate_utils.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/core/utils/server_url_defaults.dart';
import 'package:volcminer/data/datasources/aggregator_remote_data_source.dart';
import 'package:volcminer/data/datasources/isar_local_data_source.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/led_toggle_result.dart';
import 'package:volcminer/domain/entities/miner_issue_diagnosis.dart';
import 'package:volcminer/domain/entities/miner_pool_config_snapshot.dart';
import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/entities/miner_scan_item.dart';
import 'package:volcminer/domain/entities/pool_worker.dart';
import 'package:volcminer/domain/entities/hashrate_sample.dart';
import 'package:volcminer/domain/entities/persisted_scan_state.dart';
import 'package:volcminer/domain/entities/scan_segment_record.dart';
import 'package:volcminer/domain/entities/scan_target_mode.dart';
import 'package:volcminer/domain/entities/scan_session.dart';
import 'package:volcminer/domain/entities/scan_view.dart';
import 'package:volcminer/domain/entities/search_request.dart';
import 'package:volcminer/domain/entities/tracked_miner.dart';
import 'package:volcminer/domain/usecases/apply_pool_config_usecase.dart';
import 'package:volcminer/domain/usecases/clear_refine_usecase.dart';
import 'package:volcminer/domain/usecases/fetch_miner_detail_usecase.dart';
import 'package:volcminer/domain/usecases/reboot_miner_usecase.dart';
import 'package:volcminer/domain/usecases/search_pool_workers_usecase.dart';
import 'package:volcminer/domain/usecases/toggle_indicator_usecase.dart';
import 'package:volcminer/presentation/localization/app_strings.dart';
import 'package:volcminer/presentation/localization/error_reason_text.dart';
import 'package:volcminer/presentation/localization/legacy_zh_texts.dart';

class ScanRunState {
  static const String idle = 'idle';
  static const String running = 'running';
  static const String paused = 'paused';
  static const String cancelling = 'cancelling';
}

class ServerSyncStatus {
  static const String progress = 'progress';
  static const String success = 'success';
  static const String error = 'error';
}

class _ServerSummaryCounts {
  const _ServerSummaryCounts({
    required this.minerCount,
    required this.onlineCount,
    required this.unresponsiveCount,
    required this.offlineCount,
    required this.pendingRetireCount,
    required this.diagnosisCount,
  });

  final int minerCount;
  final int onlineCount;
  final int unresponsiveCount;
  final int offlineCount;
  final int pendingRetireCount;
  final int diagnosisCount;
}

class ScanState {
  const ScanState({
    required this.isScanning,
    required this.isPostProcessing,
    required this.postProcessingStageKey,
    required this.postProcessingCurrent,
    required this.postProcessingTotal,
    required this.scanRunState,
    required this.isManualScanActive,
    required this.isCheckingPool,
    required this.scannedTargets,
    required this.totalTargets,
    required this.items,
    required this.segments,
    required this.knownMinerIpsByScope,
    required this.ignoredMinerIps,
    required this.hashrateHistory,
    required this.ledActiveIps,
    required this.sessions,
    required this.error,
    required this.lastScanAt,
    required this.lastRequest,
    required this.lastPoolCheckAt,
    required this.lastPoolWorkerCount,
    required this.poolCheckError,
    required this.generatedAt,
    required this.nextScheduledAt,
    required this.nextGlobalScanAt,
    required this.nextScheduledIsGlobalAllViews,
    required this.serverMinerCount,
    required this.serverOnlineCount,
    required this.serverUnresponsiveCount,
    required this.serverOfflineCount,
    required this.serverPendingRetireCount,
    required this.serverDiagnosisCount,
    required this.serverRepeatedOfflineCount,
    required this.isServerSyncing,
    required this.serverSyncLabel,
    required this.serverSyncStatus,
    required this.serverSyncCurrent,
    required this.serverSyncTotal,
    required this.lastServerSyncAt,
  });

  final bool isScanning;
  final bool isPostProcessing;
  final String? postProcessingStageKey;
  final int postProcessingCurrent;
  final int postProcessingTotal;
  final String scanRunState;
  final bool isManualScanActive;
  final bool isCheckingPool;
  final int scannedTargets;
  final int totalTargets;
  final List<MinerScanItem> items;
  final List<ScanSegmentRecord> segments;
  final Map<String, Set<String>> knownMinerIpsByScope;
  final Set<String> ignoredMinerIps;
  final List<HashrateSample> hashrateHistory;
  final Set<String> ledActiveIps;
  final List<ScanSession> sessions;
  final String? error;
  final DateTime? lastScanAt;
  final SearchRequest? lastRequest;
  final DateTime? lastPoolCheckAt;
  final int? lastPoolWorkerCount;
  final String? poolCheckError;
  final DateTime? generatedAt;
  final DateTime? nextScheduledAt;
  final DateTime? nextGlobalScanAt;
  final bool nextScheduledIsGlobalAllViews;
  final int? serverMinerCount;
  final int? serverOnlineCount;
  final int? serverUnresponsiveCount;
  final int? serverOfflineCount;
  final int? serverPendingRetireCount;
  final int? serverDiagnosisCount;
  final int? serverRepeatedOfflineCount;
  final bool isServerSyncing;
  final String? serverSyncLabel;
  final String? serverSyncStatus;
  final int serverSyncCurrent;
  final int serverSyncTotal;
  final DateTime? lastServerSyncAt;

  factory ScanState.initial() => const ScanState(
    isScanning: false,
    isPostProcessing: false,
    postProcessingStageKey: null,
    postProcessingCurrent: 0,
    postProcessingTotal: 0,
    scanRunState: ScanRunState.idle,
    isManualScanActive: false,
    isCheckingPool: false,
    scannedTargets: 0,
    totalTargets: 0,
    items: [],
    segments: [],
    knownMinerIpsByScope: {},
    ignoredMinerIps: {},
    hashrateHistory: [],
    ledActiveIps: {},
    sessions: [],
    error: null,
    lastScanAt: null,
    lastRequest: null,
    lastPoolCheckAt: null,
    lastPoolWorkerCount: null,
    poolCheckError: null,
    generatedAt: null,
    nextScheduledAt: null,
    nextGlobalScanAt: null,
    nextScheduledIsGlobalAllViews: false,
    serverMinerCount: null,
    serverOnlineCount: null,
    serverUnresponsiveCount: null,
    serverOfflineCount: null,
    serverPendingRetireCount: null,
    serverDiagnosisCount: null,
    serverRepeatedOfflineCount: null,
    isServerSyncing: false,
    serverSyncLabel: null,
    serverSyncStatus: null,
    serverSyncCurrent: 0,
    serverSyncTotal: 0,
    lastServerSyncAt: null,
  );

  ScanState copyWith({
    bool? isScanning,
    bool? isPostProcessing,
    String? postProcessingStageKey,
    bool clearPostProcessingStageKey = false,
    int? postProcessingCurrent,
    int? postProcessingTotal,
    String? scanRunState,
    bool? isManualScanActive,
    bool? isCheckingPool,
    int? scannedTargets,
    int? totalTargets,
    List<MinerScanItem>? items,
    List<ScanSegmentRecord>? segments,
    Map<String, Set<String>>? knownMinerIpsByScope,
    Set<String>? ignoredMinerIps,
    List<HashrateSample>? hashrateHistory,
    Set<String>? ledActiveIps,
    List<ScanSession>? sessions,
    String? error,
    bool clearError = false,
    DateTime? lastScanAt,
    SearchRequest? lastRequest,
    DateTime? lastPoolCheckAt,
    int? lastPoolWorkerCount,
    String? poolCheckError,
    bool clearPoolCheckError = false,
    DateTime? generatedAt,
    DateTime? nextScheduledAt,
    DateTime? nextGlobalScanAt,
    bool? nextScheduledIsGlobalAllViews,
    int? serverMinerCount,
    int? serverOnlineCount,
    int? serverUnresponsiveCount,
    int? serverOfflineCount,
    int? serverPendingRetireCount,
    int? serverDiagnosisCount,
    int? serverRepeatedOfflineCount,
    bool? isServerSyncing,
    String? serverSyncLabel,
    String? serverSyncStatus,
    bool clearServerSyncLabel = false,
    bool clearServerSyncStatus = false,
    int? serverSyncCurrent,
    int? serverSyncTotal,
    DateTime? lastServerSyncAt,
  }) {
    return ScanState(
      isScanning: isScanning ?? this.isScanning,
      isPostProcessing: isPostProcessing ?? this.isPostProcessing,
      postProcessingStageKey: clearPostProcessingStageKey
          ? null
          : (postProcessingStageKey ?? this.postProcessingStageKey),
      postProcessingCurrent:
          postProcessingCurrent ?? this.postProcessingCurrent,
      postProcessingTotal: postProcessingTotal ?? this.postProcessingTotal,
      scanRunState: scanRunState ?? this.scanRunState,
      isManualScanActive: isManualScanActive ?? this.isManualScanActive,
      isCheckingPool: isCheckingPool ?? this.isCheckingPool,
      scannedTargets: scannedTargets ?? this.scannedTargets,
      totalTargets: totalTargets ?? this.totalTargets,
      items: items ?? this.items,
      segments: segments ?? this.segments,
      knownMinerIpsByScope: knownMinerIpsByScope ?? this.knownMinerIpsByScope,
      ignoredMinerIps: ignoredMinerIps ?? this.ignoredMinerIps,
      hashrateHistory: hashrateHistory ?? this.hashrateHistory,
      ledActiveIps: ledActiveIps ?? this.ledActiveIps,
      sessions: sessions ?? this.sessions,
      error: clearError ? null : (error ?? this.error),
      lastScanAt: lastScanAt ?? this.lastScanAt,
      lastRequest: lastRequest ?? this.lastRequest,
      lastPoolCheckAt: lastPoolCheckAt ?? this.lastPoolCheckAt,
      lastPoolWorkerCount: lastPoolWorkerCount ?? this.lastPoolWorkerCount,
      poolCheckError: clearPoolCheckError
          ? null
          : (poolCheckError ?? this.poolCheckError),
      generatedAt: generatedAt ?? this.generatedAt,
      nextScheduledAt: nextScheduledAt ?? this.nextScheduledAt,
      nextGlobalScanAt: nextGlobalScanAt ?? this.nextGlobalScanAt,
      nextScheduledIsGlobalAllViews:
          nextScheduledIsGlobalAllViews ?? this.nextScheduledIsGlobalAllViews,
      serverMinerCount: serverMinerCount ?? this.serverMinerCount,
      serverOnlineCount: serverOnlineCount ?? this.serverOnlineCount,
      serverUnresponsiveCount:
          serverUnresponsiveCount ?? this.serverUnresponsiveCount,
      serverOfflineCount: serverOfflineCount ?? this.serverOfflineCount,
      serverPendingRetireCount:
          serverPendingRetireCount ?? this.serverPendingRetireCount,
      serverDiagnosisCount: serverDiagnosisCount ?? this.serverDiagnosisCount,
      serverRepeatedOfflineCount:
          serverRepeatedOfflineCount ?? this.serverRepeatedOfflineCount,
      isServerSyncing: isServerSyncing ?? this.isServerSyncing,
      serverSyncLabel: clearServerSyncLabel
          ? null
          : (serverSyncLabel ?? this.serverSyncLabel),
      serverSyncStatus: clearServerSyncStatus
          ? null
          : (serverSyncStatus ?? this.serverSyncStatus),
      serverSyncCurrent: serverSyncCurrent ?? this.serverSyncCurrent,
      serverSyncTotal: serverSyncTotal ?? this.serverSyncTotal,
      lastServerSyncAt: lastServerSyncAt ?? this.lastServerSyncAt,
    );
  }
}

class ScanController extends StateNotifier<ScanState> {
  static const double _maxReasonableTotalHashrateGh = 1000000;
  static const Duration _uiProgressThrottle = Duration(milliseconds: 500);

  ScanController(
    this._searchPoolWorkersUseCase,
    this._fetchMinerDetailUseCase,
    this._toggleIndicatorUseCase,
    this._clearRefineUseCase,
    this._rebootMinerUseCase,
    this._applyPoolConfigUseCase,
    this._localDataSource, [
    AggregatorRemoteDataSource? aggregatorRemoteDataSource,
  ]) : _aggregatorRemoteDataSource =
           aggregatorRemoteDataSource ??
           AggregatorRemoteDataSource(http.Client()),
       super(ScanState.initial());

  final SearchPoolWorkersUseCase _searchPoolWorkersUseCase;
  final FetchMinerDetailUseCase _fetchMinerDetailUseCase;
  final ToggleIndicatorUseCase _toggleIndicatorUseCase;
  final ClearRefineUseCase _clearRefineUseCase;
  final RebootMinerUseCase _rebootMinerUseCase;
  final ApplyPoolConfigUseCase _applyPoolConfigUseCase;
  final IsarLocalDataSource _localDataSource;
  final AggregatorRemoteDataSource _aggregatorRemoteDataSource;
  final Map<String, String> _knownMinerIdsByIp = <String, String>{};
  Future<void>? _knownMinerDeleteQueue;

  static const String _serverUrlKey = 'aggregator_server_url';
  bool get _supportsExtendedAbnormalRecovery => !kIsWeb;

  Timer? _autoRefreshTimer;
  Timer? _serverSyncResultTimer;
  Future<List<_IssueRule>>? _issueRulesFuture;
  Future<void>? _serverRefreshFuture;
  Future<void>? _serverSummaryRefreshFuture;
  _ManualScanControl? _manualScanControl;
  DateTime? _lastScanProgressAt;
  int _lastScanProgressValue = -1;
  DateTime? _lastPostProgressAt;
  int _lastPostProgressValue = -1;
  int _lastPostProgressTotal = -1;
  String? _lastPostProgressStageKey;

  Future<void> loadPersistedState() async {
    try {
      final persisted = await _localDataSource.loadScanState();
      if (persisted != null) {
        _applyPersistedState(persisted);
      }
      final String serverUrl = await _getServerUrl();
      if (serverUrl.isNotEmpty) {
        unawaited(_refreshServerState(serverUrl));
        return;
      }
      if (persisted == null) {
        return;
      }
      if (state.hashrateHistory.length != persisted.hashrateHistory.length) {
        unawaited(_persistState(scannedAt: persisted.lastScanAt));
      }
    } catch (e) {
      state = state.copyWith(error: ErrorReasonText.serverLoadFailed(e));
    }
  }

  ScanState get snapshot => state;

  Future<String> _getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = (prefs.getString(_serverUrlKey) ?? '').trim();
    if (stored.isNotEmpty) {
      return stored;
    }
    return ServerUrlDefaults.value;
  }

  void _setServerSyncProgress({
    required String label,
    required int current,
    required int total,
  }) {
    _serverSyncResultTimer?.cancel();
    state = state.copyWith(
      isServerSyncing: true,
      serverSyncLabel: label,
      serverSyncStatus: ServerSyncStatus.progress,
      serverSyncCurrent: current,
      serverSyncTotal: total,
      clearServerSyncLabel: false,
      clearServerSyncStatus: false,
    );
  }

  void _setServerSyncCompletion({
    required String label,
    required String status,
  }) {
    _serverSyncResultTimer?.cancel();
    state = state.copyWith(
      isServerSyncing: false,
      serverSyncLabel: label,
      serverSyncStatus: status,
      serverSyncCurrent: 3,
      serverSyncTotal: 3,
      lastServerSyncAt: DateTime.now(),
      clearServerSyncLabel: false,
      clearServerSyncStatus: false,
    );
    _serverSyncResultTimer = Timer(const Duration(seconds: 2), () {
      state = state.copyWith(
        clearServerSyncLabel: true,
        clearServerSyncStatus: true,
        serverSyncCurrent: 0,
        serverSyncTotal: 0,
      );
    });
  }

  Future<void> refreshServerSnapshot() async {
    final String serverUrl = await _getServerUrl();
    if (serverUrl.isEmpty) {
      return;
    }
    await _refreshServerState(serverUrl);
  }

  Future<void> _loadServerState(String serverUrl) async {
    _setServerSyncProgress(
      label: LegacyZhTexts.serverLoadSummary,
      current: 1,
      total: 3,
    );
    final snapshot = await _aggregatorRemoteDataSource.loadSnapshot(serverUrl);
    final Map<String, List<TrackedMiner>> minersBySegment =
        <String, List<TrackedMiner>>{};
    final Map<String, Set<String>> knownByScope = <String, Set<String>>{};
    final bool shouldReplaceSegments =
        snapshot.miners.isNotEmpty || snapshot.minerCount == 0;
    final bool shouldReplaceKnownMiners =
        snapshot.knownMiners.isNotEmpty || snapshot.minerCount == 0;
    _setServerSyncProgress(
      label: LegacyZhTexts.serverLoadKnownMiners,
      current: 2,
      total: 3,
    );
    if (shouldReplaceKnownMiners) {
      _knownMinerIdsByIp
        ..clear()
        ..addEntries(
          snapshot.knownMiners.map(
            (AggregatorKnownMiner miner) =>
                MapEntry<String, String>(miner.ip, miner.id),
          ),
        );

      for (final AggregatorKnownMiner miner in snapshot.knownMiners) {
        final String scope = _scopeFromIp(miner.ip);
        knownByScope.putIfAbsent(scope, () => <String>{}).add(miner.ip);
      }
    }

    for (final AggregatorServerMiner miner in snapshot.miners) {
      final TrackedMiner trackedMiner = _mapServerMiner(miner);
      minersBySegment
          .putIfAbsent(miner.segment, () => <TrackedMiner>[])
          .add(trackedMiner);
    }

    final List<ScanSegmentRecord> refreshedSegments =
        minersBySegment.entries
            .map(
              (MapEntry<String, List<TrackedMiner>> entry) => ScanSegmentRecord(
                scope: entry.key,
                updatedAt: snapshot.generatedAt ?? DateTime.now(),
                miners: entry.value
                  ..sort(
                    (TrackedMiner left, TrackedMiner right) => IpUtils.ipToInt(
                      left.ip,
                    ).compareTo(IpUtils.ipToInt(right.ip)),
                  ),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => IpUtils.compareIpBlocks(a.scope, b.scope));
    final List<ScanSegmentRecord> segments = shouldReplaceSegments
        ? refreshedSegments
        : state.segments;
    final Map<String, Set<String>> effectiveKnownByScope =
        shouldReplaceKnownMiners ? knownByScope : state.knownMinerIpsByScope;

    final AggregatorServerTask? task = snapshot.task;
    final bool isScanning = task?.shouldDriveManualUi ?? false;
    _setServerSyncProgress(
      label: LegacyZhTexts.serverWriteLocalCache,
      current: 3,
      total: 3,
    );
    state = state.copyWith(
      isScanning: isScanning,
      isPostProcessing: false,
      scanRunState: isScanning ? ScanRunState.running : ScanRunState.idle,
      isManualScanActive: task?.shouldDriveManualUi ?? false,
      scannedTargets: _progressToScanned(task),
      totalTargets: task?.totalTargets ?? 0,
      segments: segments,
      knownMinerIpsByScope: effectiveKnownByScope,
      lastScanAt: snapshot.generatedAt,
      generatedAt: snapshot.generatedAt,
      nextScheduledAt: snapshot.nextScheduledAt,
      nextGlobalScanAt: snapshot.nextGlobalScanAt,
      nextScheduledIsGlobalAllViews: snapshot.nextScheduledIsGlobalAllViews,
      serverMinerCount: snapshot.minerCount,
      serverOnlineCount: snapshot.onlineCount,
      serverUnresponsiveCount: snapshot.unresponsiveCount,
      serverOfflineCount: snapshot.offlineCount,
      serverPendingRetireCount: snapshot.pendingRetireCount,
      serverDiagnosisCount: snapshot.diagnosisCount,
      serverRepeatedOfflineCount: snapshot.repeatedOfflineCount,
      lastServerSyncAt: DateTime.now(),
      error: null,
      clearError: true,
      clearPoolCheckError: true,
    );
    unawaited(_persistState(scannedAt: snapshot.generatedAt));
  }

  void _applyPersistedState(PersistedScanState persisted) {
    final cleanedHashrateHistory = _sanitizeHashrateHistory(
      persisted.hashrateHistory,
    );
    state = state.copyWith(
      segments: persisted.segments,
      knownMinerIpsByScope: persisted.knownMinerIpsByScope,
      ignoredMinerIps: persisted.ignoredMinerIps,
      hashrateHistory: cleanedHashrateHistory,
      ledActiveIps: persisted.ledActiveIps,
      lastScanAt: persisted.lastScanAt,
      generatedAt: persisted.generatedAt,
      nextScheduledAt: persisted.nextScheduledAt,
      nextGlobalScanAt: persisted.nextGlobalScanAt,
      nextScheduledIsGlobalAllViews: persisted.nextScheduledIsGlobalAllViews,
      serverMinerCount: persisted.serverMinerCount,
      serverOnlineCount: persisted.serverOnlineCount,
      serverUnresponsiveCount: persisted.serverUnresponsiveCount,
      serverOfflineCount: persisted.serverOfflineCount,
      serverPendingRetireCount: persisted.serverPendingRetireCount,
      serverDiagnosisCount: persisted.serverDiagnosisCount,
      serverRepeatedOfflineCount: persisted.serverRepeatedOfflineCount,
      clearError: true,
    );
  }

  Future<void> _refreshServerState(String serverUrl) async {
    final existing = _serverRefreshFuture;
    if (existing != null) {
      return existing;
    }
    final guardedRefresh = () async {
      try {
        _setServerSyncProgress(
          label: LegacyZhTexts.serverConnecting,
          current: 0,
          total: 3,
        );
        await _loadServerState(serverUrl);
        _setServerSyncCompletion(
          label: LegacyZhTexts.serverSyncSuccess,
          status: ServerSyncStatus.success,
        );
      } catch (e) {
        _setServerSyncCompletion(
          label: LegacyZhTexts.serverSyncFailure,
          status: ServerSyncStatus.error,
        );
        state = state.copyWith(error: ErrorReasonText.serverSyncFailure(e));
      } finally {
        _serverRefreshFuture = null;
      }
    }();
    _serverRefreshFuture = guardedRefresh;
    return guardedRefresh;
  }

  Future<void> refreshServerSummary() async {
    final String serverUrl = await _getServerUrl();
    if (serverUrl.isEmpty) {
      return;
    }
    await _refreshServerSummary(serverUrl);
  }

  Future<void> _refreshServerSummary(String serverUrl) async {
    final existing = _serverSummaryRefreshFuture;
    if (existing != null) {
      return existing;
    }
    final guardedRefresh = () async {
      try {
        _setServerSyncProgress(
          label: LegacyZhTexts.serverConnecting,
          current: 0,
          total: 2,
        );
        final summary = await _aggregatorRemoteDataSource.loadDashboardSummary(
          serverUrl,
        );
        _setServerSyncProgress(
          label: LegacyZhTexts.serverLoadDashboardSummary,
          current: 1,
          total: 2,
        );
        state = state.copyWith(
          generatedAt: summary.generatedAt ?? state.generatedAt,
          nextScheduledAt: summary.nextScheduledAt ?? state.nextScheduledAt,
          nextGlobalScanAt: summary.nextGlobalScanAt ?? state.nextGlobalScanAt,
          serverMinerCount: summary.minerCount,
          serverOnlineCount: summary.onlineCount,
          serverUnresponsiveCount: summary.unresponsiveCount,
          serverOfflineCount: summary.offlineCount,
          serverPendingRetireCount: summary.pendingRetireCount,
          serverDiagnosisCount: summary.diagnosisCount,
          serverRepeatedOfflineCount: summary.repeatedOfflineCount,
          lastServerSyncAt: DateTime.now(),
          error: null,
          clearError: true,
        );
        _setServerSyncCompletion(
          label: LegacyZhTexts.serverSyncSuccess,
          status: ServerSyncStatus.success,
        );
      } catch (e) {
        _setServerSyncCompletion(
          label: LegacyZhTexts.serverSyncFailure,
          status: ServerSyncStatus.error,
        );
        state = state.copyWith(error: ErrorReasonText.serverSyncFailure(e));
      } finally {
        _serverSummaryRefreshFuture = null;
      }
    }();
    _serverSummaryRefreshFuture = guardedRefresh;
    return guardedRefresh;
  }

  TrackedMiner _mapServerMiner(AggregatorServerMiner miner) {
    final DateTime seenAt = miner.lastSeenAt ?? DateTime.now();
    final String stateValue = _trackedStateFromServer(miner);
    final MinerIssueDiagnosis? diagnosis = miner.diagnosis == null
        ? null
        : MinerIssueDiagnosis(
            code: miner.diagnosis!.code,
            category: miner.diagnosis!.category,
            reason: miner.diagnosis!.reason,
            solution: miner.diagnosis!.solution,
            logSnippet: miner.diagnosis!.logSnippet,
            detectedAt: miner.diagnosis!.detectedAt ?? seenAt,
            secondaryCode: miner.diagnosis!.secondaryCode,
            secondaryReason: miner.diagnosis!.secondaryReason,
          );

    return TrackedMiner(
      ip: miner.ip,
      lastSeenAt: seenAt,
      missedScans: switch (stateValue) {
        TrackedMinerState.online => 0,
        TrackedMinerState.unresponsive => 1,
        _ => 2,
      },
      offlineEventCount: stateValue == TrackedMinerState.offline ? 1 : 0,
      retiredAt: stateValue == TrackedMinerState.pendingRetire ? seenAt : null,
      forcedOfflineAt: stateValue == TrackedMinerState.offline ? seenAt : null,
      diagnosis: diagnosis,
      lastItem: MinerScanItem(
        worker: PoolWorker(
          workerName: miner.name,
          ip: miner.ip,
          status: miner.status,
          lastShareTime: '',
          dailyHashrate: '',
          rejectRate: '',
        ),
        runtime: MinerRuntime(
          ip: miner.ip,
          onlineStatus: switch (stateValue) {
            TrackedMinerState.online => MinerRuntimeStatus.online,
            TrackedMinerState.unresponsive => MinerRuntimeStatus.timeout,
            _ => MinerRuntimeStatus.offline,
          },
          ghs5s: _formatServerHashrate(mine: miner.hashrateRtMh),
          ghsav: _formatServerHashrate(mine: miner.hashrateAvgMh),
          ambientTemp: _formatServerNumber(
            value: miner.maxTemperatureC,
            suffix: LegacyZhTexts.celsiusSuffix,
          ),
          power: '--',
          fan1: _formatServerNumber(
            value: miner.averageFanRpm,
            suffix: ' RPM',
            decimals: 0,
          ),
          fan2: '--',
          fan3: '--',
          fan4: '--',
          runningMode: _formatRunningMode(miner.runningMode),
          chains: miner.chains
              .map(
                (AggregatorServerMinerChain chain) => MinerChainStatus(
                  index: chain.index,
                  chainRate: _formatServerHashrate(mine: chain.chainRateMh),
                  temp: _formatServerNumber(
                    value: chain.tempC,
                    suffix: LegacyZhTexts.celsiusSuffix,
                    decimals: 0,
                  ),
                  freq: chain.freq,
                  hw: chain.hw,
                  chainAcn: chain.chainAcn,
                  chainAcs: chain.chainAcs,
                ),
              )
              .toList(growable: false),
          logSnippet: '',
          fetchedAt: seenAt,
        ),
      ),
    );
  }

  String _trackedStateFromServer(AggregatorServerMiner miner) {
    final String lifecycle = (miner.lifecycle ?? '').trim();
    if (lifecycle == TrackedMinerState.pendingRetire ||
        lifecycle == 'pending-retire') {
      return TrackedMinerState.pendingRetire;
    }
    if (lifecycle == TrackedMinerState.offline) {
      return TrackedMinerState.offline;
    }
    if (lifecycle == TrackedMinerState.unresponsive) {
      return TrackedMinerState.unresponsive;
    }
    if (miner.online) {
      return TrackedMinerState.online;
    }
    if (miner.status == 'error') {
      return TrackedMinerState.unresponsive;
    }
    return TrackedMinerState.offline;
  }

  String _formatServerHashrate({required double mine}) {
    final double gh = mine / 1000;
    if (gh <= 0) {
      return '--';
    }
    return '${gh.toStringAsFixed(2)} GH/s';
  }

  String _formatServerNumber({
    required double? value,
    required String suffix,
    int decimals = 0,
  }) {
    if (value == null || value <= 0) {
      return '--';
    }
    return '${value.toStringAsFixed(decimals)}$suffix';
  }

  String _formatRunningMode(String? raw) {
    return switch ((raw ?? '').trim()) {
      '0' => LegacyZhTexts.runningModeNormal,
      '1' => LegacyZhTexts.runningModeOverclock,
      '2' => LegacyZhTexts.runningModeLowPower,
      '3' => LegacyZhTexts.runningModeSuperLowPower,
      '4' => LegacyZhTexts.runningModeSleep,
      '' || '--' => '--',
      final value => value,
    };
  }

  String _scopeFromIp(String ip) {
    final parts = ip.split('.');
    if (parts.length < 3) {
      return ip;
    }
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  int _progressToScanned(AggregatorServerTask? task) {
    if (task == null || task.totalTargets <= 0) {
      return 0;
    }
    return ((task.progress / 100) * task.totalTargets).round().clamp(
      0,
      task.totalTargets,
    );
  }

  void _resetScanProgressThrottle() {
    _lastScanProgressAt = null;
    _lastScanProgressValue = -1;
  }

  void _emitScanProgress({
    required int scanned,
    required int total,
    bool force = false,
  }) {
    final now = DateTime.now();
    final shouldEmit =
        force ||
        scanned <= 1 ||
        scanned >= total ||
        _lastScanProgressAt == null ||
        _lastScanProgressValue < 0 ||
        now.difference(_lastScanProgressAt!) >= _uiProgressThrottle;
    if (!shouldEmit) {
      return;
    }
    _lastScanProgressAt = now;
    _lastScanProgressValue = scanned;
    state = state.copyWith(scannedTargets: scanned, totalTargets: total);
  }

  void _resetPostProcessingProgressThrottle({String? stageKey}) {
    _lastPostProgressAt = null;
    _lastPostProgressValue = -1;
    _lastPostProgressTotal = -1;
    _lastPostProgressStageKey = stageKey;
  }

  void _emitPostProcessingProgress({
    required String stageKey,
    required int current,
    required int total,
    bool force = false,
  }) {
    final now = DateTime.now();
    final stageChanged = _lastPostProgressStageKey != stageKey;
    final shouldEmit =
        force ||
        stageChanged ||
        current <= 1 ||
        current >= total ||
        total != _lastPostProgressTotal ||
        _lastPostProgressAt == null ||
        _lastPostProgressValue < 0 ||
        now.difference(_lastPostProgressAt!) >= _uiProgressThrottle;
    if (!shouldEmit) {
      return;
    }
    _lastPostProgressAt = now;
    _lastPostProgressValue = current;
    _lastPostProgressTotal = total;
    _lastPostProgressStageKey = stageKey;
    state = state.copyWith(
      postProcessingCurrent: current,
      postProcessingTotal: total,
    );
  }

  void pauseManualScan() {
    final control = _manualScanControl;
    if (control == null || state.scanRunState != ScanRunState.running) {
      return;
    }
    control.pause();
    state = state.copyWith(scanRunState: ScanRunState.paused);
  }

  void resumeManualScan() {
    final control = _manualScanControl;
    if (control == null || state.scanRunState != ScanRunState.paused) {
      return;
    }
    control.resume();
    state = state.copyWith(scanRunState: ScanRunState.running);
  }

  void cancelManualScan() {
    unawaited(_stopServerScanIfNeeded());
    final control = _manualScanControl;
    if (control == null || !state.isManualScanActive || !state.isScanning) {
      return;
    }
    control.cancel();
    state = state.copyWith(scanRunState: ScanRunState.cancelling);
  }

  Future<void> _stopServerScanIfNeeded() async {
    final String serverUrl = await _getServerUrl();
    if (serverUrl.isEmpty || !state.isScanning) {
      return;
    }
    state = state.copyWith(scanRunState: ScanRunState.cancelling);
    await _aggregatorRemoteDataSource.stopScan(serverUrl);
    await loadPersistedState();
  }

  Future<void> checkPoolOnly({
    required List<ScanView> selectedViews,
    required String accountUsername,
    required String accountPassword,
  }) async {
    final request = _buildRequest(
      selectedViews: selectedViews,
      accountUsername: accountUsername,
      accountPassword: accountPassword,
      targetMode: ScanTargetMode.full,
      onError: (message) => state = state.copyWith(poolCheckError: message),
    );
    if (request == null) {
      return;
    }

    state = state.copyWith(
      isCheckingPool: true,
      lastRequest: request,
      clearPoolCheckError: true,
    );
    try {
      final workers = await _searchPoolWorkersUseCase.execute(request);
      state = state.copyWith(
        isCheckingPool: false,
        lastPoolCheckAt: DateTime.now(),
        lastPoolWorkerCount: workers.length,
      );
    } catch (e) {
      state = state.copyWith(
        isCheckingPool: false,
        poolCheckError: ErrorReasonText.poolCheckFailed(e),
      );
    }
  }

  Future<void> startScan({
    required List<ScanView> selectedViews,
    required String accountUsername,
    required String accountPassword,
    required MinerCredential minerCredential,
    required bool collectLogs,
    required ScanTargetMode targetMode,
    int concurrency = 20,
  }) async {
    final String serverUrl = await _getServerUrl();
    if (serverUrl.isNotEmpty) {
      await _startServerScan(
        serverUrl: serverUrl,
        selectedViews: selectedViews,
        targetMode: targetMode,
      );
      return;
    }
    final request = _buildRequest(
      selectedViews: selectedViews,
      accountUsername: accountUsername,
      accountPassword: accountPassword,
      targetMode: targetMode,
      onError: (message) => state = state.copyWith(error: message),
    );
    if (request == null) {
      return;
    }

    await _runScan(
      request: request,
      selectedViews: selectedViews,
      minerCredential: minerCredential,
      collectLogs: collectLogs,
      concurrency: concurrency,
      updateKnownIndex: true,
      preferPoolLookup: targetMode == ScanTargetMode.full,
      manualControllable: true,
    );
  }

  Future<void> _startServerScan({
    required String serverUrl,
    required List<ScanView> selectedViews,
    required ScanTargetMode targetMode,
  }) async {
    if (selectedViews.isEmpty && targetMode == ScanTargetMode.full) {
      state = state.copyWith(
        error: AppStrings.english('controller.scan.selectOne'),
      );
      return;
    }
    state = state.copyWith(
      isScanning: true,
      scanRunState: ScanRunState.running,
      isManualScanActive: true,
      clearError: true,
      scannedTargets: 0,
      totalTargets: 0,
    );
    await _aggregatorRemoteDataSource.startScan(
      serverUrl,
      mode: targetMode == ScanTargetMode.known ? 'known-list' : 'global',
      scanViews: targetMode == ScanTargetMode.known
          ? const <Map<String, dynamic>>[]
          : selectedViews.map(_encodeServerScanView).toList(growable: false),
    );
    await loadPersistedState();
  }

  Future<void> startAutoRefreshScan({
    required List<ScanView> allViews,
    required String accountUsername,
    required String accountPassword,
    required MinerCredential minerCredential,
    required int concurrency,
  }) async {
    final request = _buildAutoRefreshRequest(
      allViews: allViews,
      accountUsername: accountUsername,
      accountPassword: accountPassword,
    );
    if (request == null) {
      return;
    }
    await _runScan(
      request: request,
      selectedViews: allViews,
      minerCredential: minerCredential,
      collectLogs: false,
      concurrency: concurrency,
      updateKnownIndex: false,
      preferPoolLookup: false,
      manualControllable: false,
    );
  }

  Future<bool> refreshMinerIp({
    required String ip,
    required MinerCredential minerCredential,
    int concurrency = 20,
    bool rediagnoseLog = false,
  }) async {
    final String serverUrl = await _getServerUrl();
    if (serverUrl.isNotEmpty) {
      final String knownMinerIdentifier = _knownMinerIdsByIp[ip] ?? ip;
      final refreshed = await _aggregatorRemoteDataSource.refreshKnownMiner(
        serverUrl,
        knownMinerIdentifier,
      );
      _applyRefreshedServerMiner(
        refreshed.miner,
        generatedAt: refreshed.generatedAt,
      );
      if (rediagnoseLog) {
        await rediagnoseMinerLog(ip: ip, minerCredential: minerCredential);
      }
      return _findMinerByIp(ip) != null;
    }
    final beforeFetchedAt = _findMinerByIp(ip)?.runtime.fetchedAt;
    final request = SearchRequest(
      ips: [ip],
      accountUsername: '',
      accountPassword: '',
    );
    await _runScan(
      request: request,
      selectedViews: const [],
      minerCredential: minerCredential,
      collectLogs: false,
      concurrency: concurrency,
      updateKnownIndex: true,
      preferPoolLookup: false,
      manualControllable: false,
    );
    final afterMiner = _findMinerByIp(ip);
    if (afterMiner == null) {
      return false;
    }
    final afterFetchedAt = afterMiner.runtime.fetchedAt;
    if (beforeFetchedAt == null) {
      final refreshed = afterMiner.missedScans == 0;
      if (refreshed && rediagnoseLog) {
        await rediagnoseMinerLogs(ips: [ip], minerCredential: minerCredential);
      }
      return refreshed;
    }
    final refreshed = afterFetchedAt.isAfter(beforeFetchedAt);
    if (refreshed && rediagnoseLog) {
      await rediagnoseMinerLogs(ips: [ip], minerCredential: minerCredential);
    }
    return refreshed;
  }

  Future<void> refreshMinerIps({
    required List<String> ips,
    required MinerCredential minerCredential,
    int concurrency = 20,
    bool rediagnoseLogs = false,
  }) async {
    final String serverUrl = await _getServerUrl();
    if (serverUrl.isNotEmpty) {
      await loadPersistedState();
      return;
    }
    if (ips.isEmpty) {
      return;
    }
    final request = SearchRequest(
      ips: ips,
      accountUsername: '',
      accountPassword: '',
    );
    await _runScan(
      request: request,
      selectedViews: const [],
      minerCredential: minerCredential,
      collectLogs: false,
      concurrency: concurrency,
      updateKnownIndex: true,
      preferPoolLookup: false,
      manualControllable: false,
    );
    if (rediagnoseLogs) {
      await rediagnoseMinerLogs(ips: ips, minerCredential: minerCredential);
    }
  }

  Future<int> rediagnoseMinerLogs({
    required List<String> ips,
    required MinerCredential minerCredential,
    int concurrency = 8,
  }) async {
    if (state.isScanning || state.isPostProcessing || ips.isEmpty) {
      return 0;
    }
    final targetIps = ips
        .map((ip) => ip.trim())
        .where((ip) => ip.isNotEmpty && _findMinerByIp(ip) != null)
        .toSet()
        .toList(growable: false);
    if (targetIps.isEmpty) {
      return 0;
    }
    final rules = await _loadIssueRules();
    final diagnoses = <String, MinerIssueDiagnosis>{};
    var index = 0;
    final limit = targetIps.length < concurrency
        ? targetIps.length
        : concurrency;

    Future<void> loop() async {
      while (true) {
        final current = index;
        if (current >= targetIps.length) {
          return;
        }
        index += 1;
        final ip = targetIps[current];
        try {
          final log = await _fetchMinerDetailUseCase.getKernelLog(
            ip,
            minerCredential,
          );
          diagnoses[ip] = _analyzeLog(log, rules);
        } catch (_) {
          // Ignore per-IP log failures so other miners can still be re-diagnosed.
        }
      }
    }

    await Future.wait(List.generate(limit == 0 ? 1 : limit, (_) => loop()));
    if (diagnoses.isEmpty) {
      return 0;
    }

    var updatedCount = 0;
    final nextSegments = state.segments
        .map(
          (segment) => segment.copyWith(
            miners: segment.miners
                .map((miner) {
                  final diagnosis = diagnoses[miner.ip];
                  if (diagnosis == null) {
                    return miner;
                  }
                  updatedCount += 1;
                  return miner.copyWith(diagnosis: diagnosis);
                })
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
    state = state.copyWith(segments: nextSegments);
    await _persistState(scannedAt: state.lastScanAt);
    return updatedCount;
  }

  Future<bool> rediagnoseMinerLog({
    required String ip,
    required MinerCredential minerCredential,
  }) async {
    final updated = await rediagnoseMinerLogs(
      ips: [ip],
      minerCredential: minerCredential,
      concurrency: 1,
    );
    return updated > 0;
  }

  TrackedMiner? _findMinerByIp(String ip) {
    for (final segment in state.segments) {
      for (final miner in segment.miners) {
        if (miner.ip == ip) {
          return miner;
        }
      }
    }
    return null;
  }

  void _applyRefreshedServerMiner(
    AggregatorServerMiner miner, {
    DateTime? generatedAt,
  }) {
    final TrackedMiner trackedMiner = _mapServerMiner(miner);
    bool segmentFound = false;
    final List<ScanSegmentRecord> mappedSegments = state.segments
        .map((segment) {
          if (segment.scope != miner.segment) {
            return segment;
          }
          segmentFound = true;
          final List<TrackedMiner> updatedMiners =
              segment.miners
                  .map(
                    (existing) => existing.ip == trackedMiner.ip
                        ? trackedMiner
                        : existing,
                  )
                  .toList(growable: false)
                ..sort(
                  (TrackedMiner left, TrackedMiner right) => IpUtils.ipToInt(
                    left.ip,
                  ).compareTo(IpUtils.ipToInt(right.ip)),
                );
          return segment.copyWith(
            updatedAt: generatedAt ?? segment.updatedAt,
            miners: updatedMiners,
          );
        })
        .toList(growable: false);
    final List<ScanSegmentRecord> nextSegments =
        segmentFound
              ? mappedSegments
              : <ScanSegmentRecord>[
                  ...mappedSegments,
                  ScanSegmentRecord(
                    scope: miner.segment,
                    updatedAt: generatedAt ?? DateTime.now(),
                    miners: <TrackedMiner>[trackedMiner],
                  ),
                ]
          ..sort(
            (left, right) => IpUtils.compareIpBlocks(left.scope, right.scope),
          );

    final _ServerSummaryCounts summary = _computeServerSummaryCounts(
      nextSegments,
    );

    state = state.copyWith(
      segments: nextSegments,
      lastScanAt: generatedAt ?? state.lastScanAt,
      generatedAt: generatedAt ?? state.generatedAt,
      serverMinerCount: summary.minerCount,
      serverOnlineCount: summary.onlineCount,
      serverUnresponsiveCount: summary.unresponsiveCount,
      serverOfflineCount: summary.offlineCount,
      serverPendingRetireCount: summary.pendingRetireCount,
      serverDiagnosisCount: summary.diagnosisCount,
      lastServerSyncAt: DateTime.now(),
    );
    unawaited(_persistState(scannedAt: generatedAt ?? state.lastScanAt));
  }

  _ServerSummaryCounts _computeServerSummaryCounts(
    List<ScanSegmentRecord> segments,
  ) {
    int minerCount = 0;
    int onlineCount = 0;
    int unresponsiveCount = 0;
    int offlineCount = 0;
    int pendingRetireCount = 0;
    int diagnosisCount = 0;

    for (final ScanSegmentRecord segment in segments) {
      for (final TrackedMiner miner in segment.miners) {
        minerCount += 1;
        switch (miner.state) {
          case TrackedMinerState.online:
            onlineCount += 1;
            break;
          case TrackedMinerState.unresponsive:
            unresponsiveCount += 1;
            break;
          case TrackedMinerState.offline:
            offlineCount += 1;
            break;
          case TrackedMinerState.pendingRetire:
            pendingRetireCount += 1;
            break;
        }
        if (miner.hasIssue) {
          diagnosisCount += 1;
        }
      }
    }

    return _ServerSummaryCounts(
      minerCount: minerCount,
      onlineCount: onlineCount,
      unresponsiveCount: unresponsiveCount,
      offlineCount: offlineCount,
      pendingRetireCount: pendingRetireCount,
      diagnosisCount: diagnosisCount,
    );
  }

  Future<void> _runScan({
    required SearchRequest request,
    required List<ScanView> selectedViews,
    required MinerCredential minerCredential,
    required bool collectLogs,
    required int concurrency,
    required bool updateKnownIndex,
    required bool preferPoolLookup,
    required bool manualControllable,
  }) async {
    if (state.isScanning || state.isPostProcessing) {
      return;
    }
    final manualControl = manualControllable ? _ManualScanControl() : null;
    _manualScanControl = manualControl;
    state = state.copyWith(
      isScanning: true,
      isPostProcessing: false,
      clearPostProcessingStageKey: true,
      postProcessingCurrent: 0,
      postProcessingTotal: 0,
      scanRunState: manualControllable
          ? ScanRunState.running
          : ScanRunState.idle,
      isManualScanActive: manualControllable,
      scannedTargets: 0,
      totalTargets: 0,
      clearError: true,
      lastRequest: request,
    );
    try {
      List<PoolWorker> workers;
      if (preferPoolLookup) {
        try {
          workers = await _searchPoolWorkersUseCase.execute(request);
        } catch (_) {
          workers = request.ips
              .map(
                (ip) => PoolWorker(
                  workerName: ip,
                  ip: ip,
                  status: '',
                  lastShareTime: '',
                  dailyHashrate: '',
                  rejectRate: '',
                ),
              )
              .toList(growable: false);
        }
      } else {
        workers = request.ips
            .map(
              (ip) => PoolWorker(
                workerName: ip,
                ip: ip,
                status: '',
                lastShareTime: '',
                dailyHashrate: '',
                rejectRate: '',
              ),
            )
            .toList(growable: false);
      }
      workers = _dedupeWorkersByIp(workers);

      final fetchResult = await _fetchAllMinerDetails(
        workers,
        minerCredential,
        collectLogs: collectLogs,
        concurrency: concurrency,
        control: manualControl,
      );
      final items = fetchResult.items;
      state = state.copyWith(
        isScanning: false,
        isPostProcessing: true,
        postProcessingStageKey: 'app.scan.finalizing.logs',
        postProcessingCurrent: 0,
        postProcessingTotal: items
            .where(
              (item) =>
                  item.runtime.onlineStatus == MinerRuntimeStatus.online &&
                  HashrateUtils.effectiveGh(
                        item.runtime.ghs5s,
                        item.runtime.ghsav,
                      ) <=
                      0,
            )
            .length,
        scanRunState: ScanRunState.idle,
        isManualScanActive: false,
        scannedTargets: fetchResult.completedCount,
        totalTargets: workers.length,
      );
      final diagnoses = await _collectZeroHashDiagnoses(
        items,
        minerCredential,
        concurrency: concurrency,
      );
      final allBoardFailureRebootTargets = _collectAllBoardFailureRebootTargets(
        existing: state.segments,
        diagnoses: diagnoses,
      );
      final droppedBoardRebootTargets = _collectDroppedBoardRebootTargets(
        existing: state.segments,
        items: items,
      );
      state = state.copyWith(
        isPostProcessing: true,
        postProcessingStageKey: 'app.scan.finalizing.allBoardReboot',
        postProcessingCurrent: 0,
        postProcessingTotal: allBoardFailureRebootTargets.length,
      );
      await _autoRebootAllBoardFailureTargets(
        allBoardFailureRebootTargets,
        minerCredential,
      );
      state = state.copyWith(
        isPostProcessing: true,
        postProcessingStageKey: 'app.scan.finalizing.droppedBoardReboot',
        postProcessingCurrent: 0,
        postProcessingTotal: droppedBoardRebootTargets.length,
      );
      await _autoRebootDroppedBoardTargets(
        droppedBoardRebootTargets,
        minerCredential,
      );
      final zeroHashRebootTargets = _collectImmediateZeroHashRebootTargets(
        existing: state.segments,
        items: items,
      );
      state = state.copyWith(
        isPostProcessing: true,
        postProcessingStageKey: 'app.scan.finalizing.reboot',
        postProcessingCurrent: 0,
        postProcessingTotal: zeroHashRebootTargets.length,
      );
      final rebootedZeroHashIps = await _autoRebootImmediateZeroHashTargets(
        zeroHashRebootTargets,
        minerCredential,
      );
      final requestedIps = fetchResult.attemptedIps;
      final pendingClearRefineCount = _countPendingClearRefineTargets(
        requestedIps: requestedIps,
        seenItems: items,
        maxTargets: manualControllable ? 30 : 10,
      );
      state = state.copyWith(
        isPostProcessing: true,
        postProcessingStageKey: 'app.scan.finalizing.clearRefine',
        postProcessingCurrent: 0,
        postProcessingTotal: pendingClearRefineCount,
      );
      final clearRefinedIps = await _autoClearRefineForRequestedMisses(
        requestedIps: requestedIps,
        seenItems: items,
        credential: minerCredential,
        maxTargets: manualControllable ? 30 : 10,
      );
      final scannedAt = DateTime.now();
      final session = ScanSession(
        id: scannedAt.microsecondsSinceEpoch.toString(),
        scannedAt: scannedAt,
        searchScopes: _buildSearchScopes(request.ips),
        items: items,
        requestedTargetCount: workers.length,
      );
      final rediscoveredIps = items
          .where(
            (item) => item.runtime.onlineStatus == MinerRuntimeStatus.online,
          )
          .map((item) => item.worker.ip)
          .toSet();
      final nextIgnoredIps = {...state.ignoredMinerIps}
        ..removeAll(rediscoveredIps);
      final nextKnownIndex = updateKnownIndex
          ? _mergeKnownMinerIps(state.knownMinerIpsByScope, items)
          : state.knownMinerIpsByScope;
      final nextSegments = _mergeSegments(
        existing: state.segments,
        items: items,
        scopes: session.searchScopes,
        requestedIps: requestedIps,
        rebootedZeroHashIps: rebootedZeroHashIps,
        clearRefinedIps: clearRefinedIps,
        scannedAt: scannedAt,
        diagnoses: diagnoses,
      );
      state = state.copyWith(
        isPostProcessing: true,
        postProcessingStageKey: 'app.scan.finalizing.recheck',
        postProcessingCurrent: 0,
        postProcessingTotal: _countPendingZeroHashRechecks(
          nextSegments,
          scannedAt,
        ),
      );
      final reconciledSegments = await _runDueZeroHashRechecks(
        segments: nextSegments,
        credential: minerCredential,
        scannedAt: scannedAt,
      );
      final totalHashrateGh = items
          .where(
            (item) => item.runtime.onlineStatus == MinerRuntimeStatus.online,
          )
          .fold<double>(
            0,
            (sum, item) =>
                sum +
                HashrateUtils.effectiveGh(
                  item.runtime.ghs5s,
                  item.runtime.ghsav,
                ),
          );
      final nextHashrateHistory = _appendHashrateSample(
        state.hashrateHistory,
        HashrateSample(recordedAt: scannedAt, totalHashrateGh: totalHashrateGh),
      );

      state = state.copyWith(
        isScanning: false,
        isPostProcessing: true,
        postProcessingStageKey: 'app.scan.finalizing.persist',
        postProcessingCurrent: 0,
        postProcessingTotal: 1,
        scanRunState: ScanRunState.idle,
        isManualScanActive: false,
        scannedTargets: fetchResult.completedCount,
        totalTargets: workers.length,
        items: items,
        segments: reconciledSegments,
        knownMinerIpsByScope: nextKnownIndex,
        ignoredMinerIps: nextIgnoredIps,
        hashrateHistory: nextHashrateHistory,
        sessions: [session, ...state.sessions],
        lastScanAt: scannedAt,
      );
      await _localDataSource.saveSnapshot(items);
      state = state.copyWith(postProcessingCurrent: 1, postProcessingTotal: 1);
      await _persistState(scannedAt: scannedAt);
      state = state.copyWith(
        isPostProcessing: false,
        clearPostProcessingStageKey: true,
        postProcessingCurrent: 0,
        postProcessingTotal: 0,
      );
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        isPostProcessing: false,
        clearPostProcessingStageKey: true,
        postProcessingCurrent: 0,
        postProcessingTotal: 0,
        scanRunState: ScanRunState.idle,
        isManualScanActive: false,
        error: ErrorReasonText.scanFailed(e),
      );
    } finally {
      if (identical(_manualScanControl, manualControl)) {
        _manualScanControl = null;
      }
    }
  }

  Future<LedToggleResult> toggleLedForIp(
    String ip,
    bool on,
    MinerCredential credential,
  ) async {
    final result = await _toggleIndicatorUseCase.execute([ip], on, credential);
    _updateLedState(result, on);
    return result;
  }

  Future<LedToggleResult> toggleLedForIps(
    List<String> ips,
    bool on,
    MinerCredential credential,
  ) async {
    final result = await _toggleIndicatorUseCase.execute(ips, on, credential);
    _updateLedState(result, on);
    return result;
  }

  Future<LedToggleResult> clearRefineForIps(
    List<String> ips,
    MinerCredential credential,
  ) async {
    final String serverUrl = await _getServerUrl();
    if (serverUrl.isNotEmpty) {
      final result = await _aggregatorRemoteDataSource.clearRefineKnownMiners(
        serverUrl,
        ips,
      );
      return result.toLedToggleResult();
    }
    return _clearRefineUseCase.execute(ips, credential);
  }

  Future<LedToggleResult> rebootForIps(
    List<String> ips,
    MinerCredential credential,
  ) {
    return _rebootMinerUseCase.execute(ips, credential);
  }

  Future<LedToggleResult> applyPoolConfigForIps(
    List<String> ips,
    MinerPoolConfigSnapshot snapshot,
    MinerCredential credential,
  ) {
    return _applyPoolConfigUseCase.execute(ips, snapshot, credential);
  }

  Future<LedToggleResult> applyPoolConfigTemplateForIps(
    List<String> ips,
    MinerPoolConfigSnapshot baseSnapshot,
    String Function(String ip, int slotNo) workerCodeBuilder,
    MinerCredential credential,
  ) async {
    final succeeded = <String>[];
    final failed = <String>[];

    for (final ip in ips) {
      final snapshot = baseSnapshot.copyWith(
        poolSlots: baseSnapshot.poolSlots
            .map(
              (slot) =>
                  slot.copyWith(workerCode: workerCodeBuilder(ip, slot.slotNo)),
            )
            .toList(growable: false),
      );
      final result = await _applyPoolConfigUseCase.execute(
        [ip],
        snapshot,
        credential,
      );
      if (result.success) {
        succeeded.add(ip);
      } else {
        failed.add(ip);
      }
    }

    if (failed.isEmpty) {
      return LedToggleResult(
        success: true,
        message: 'Pool configuration applied.',
        targets: succeeded,
      );
    }

    return LedToggleResult(
      success: succeeded.isNotEmpty,
      message: 'Failed: ${failed.join(', ')}',
      targets: [...succeeded, ...failed],
    );
  }

  void deleteSession(String sessionId) {
    state = state.copyWith(
      sessions: state.sessions
          .where((session) => session.id != sessionId)
          .toList(growable: false),
    );
  }

  void deleteSegmentMiner(String scope, String ip) {
    final segments = state.segments
        .map((segment) {
          if (segment.scope != scope) {
            return segment;
          }
          return segment.copyWith(
            miners: segment.miners
                .where((miner) => miner.ip != ip)
                .toList(growable: false),
          );
        })
        .where((segment) => segment.miners.isNotEmpty)
        .toList(growable: false);
    final knownMinerIpsByScope = <String, Set<String>>{
      for (final entry in state.knownMinerIpsByScope.entries)
        entry.key: {...entry.value},
    };
    final scopeIps = knownMinerIpsByScope[scope];
    if (scopeIps != null) {
      scopeIps.remove(ip);
      if (scopeIps.isEmpty) {
        knownMinerIpsByScope.remove(scope);
      }
    }
    state = state.copyWith(
      segments: segments,
      knownMinerIpsByScope: knownMinerIpsByScope,
    );
    unawaited(_persistState(scannedAt: state.lastScanAt));
  }

  Future<void> removeMinerByIp(String ip) async {
    await removeMinerIps([ip]);
  }

  Future<void> removeMinerIps(List<String> ips) async {
    final normalizedIps = ips
        .map((ip) => ip.trim())
        .where(IpUtils.isValidIpv4)
        .toSet()
        .toList(growable: false);
    if (normalizedIps.isEmpty) {
      return;
    }

    _removeMinerIpsLocally(normalizedIps);

    final String serverUrl = await _getServerUrl();
    final Map<String, String> knownMinerIdsByIp = <String, String>{};
    if (serverUrl.isNotEmpty) {
      for (final ip in normalizedIps) {
        final knownMinerId = _knownMinerIdsByIp[ip];
        if (knownMinerId != null) {
          knownMinerIdsByIp[ip] = knownMinerId;
        }
      }
    }
    if (serverUrl.isNotEmpty && knownMinerIdsByIp.isNotEmpty) {
      _enqueueKnownMinerDeleteRequests(
        serverUrl: serverUrl,
        knownMinerIdsByIp: knownMinerIdsByIp,
      );
    }
  }

  void _removeMinerIpsLocally(Iterable<String> ips) {
    final removalSet = ips.toSet();
    final segments = state.segments
        .map(
          (segment) => segment.copyWith(
            miners: segment.miners
                .where((miner) => !removalSet.contains(miner.ip))
                .toList(growable: false),
          ),
        )
        .where((segment) => segment.miners.isNotEmpty)
        .toList(growable: false);
    final knownMinerIpsByScope = <String, Set<String>>{};
    for (final entry in state.knownMinerIpsByScope.entries) {
      final nextIps = {...entry.value}..removeAll(removalSet);
      if (nextIps.isNotEmpty) {
        knownMinerIpsByScope[entry.key] = nextIps;
      }
    }
    final nextLedIps = {...state.ledActiveIps}..removeAll(removalSet);
    final nextIgnoredIps = {...state.ignoredMinerIps, ...removalSet};
    state = state.copyWith(
      segments: segments,
      knownMinerIpsByScope: knownMinerIpsByScope,
      ledActiveIps: nextLedIps,
      ignoredMinerIps: nextIgnoredIps,
    );
    unawaited(_persistState(scannedAt: state.lastScanAt));
  }

  void _enqueueKnownMinerDeleteRequests({
    required String serverUrl,
    required Map<String, String> knownMinerIdsByIp,
  }) {
    final queue = (_knownMinerDeleteQueue ?? Future<void>.value())
        .catchError((_) {});
    _knownMinerDeleteQueue = queue.then((_) async {
      for (final knownMinerId in knownMinerIdsByIp.values) {
        try {
          await _aggregatorRemoteDataSource.deleteKnownMiner(
            serverUrl,
            knownMinerId,
          );
        } catch (_) {
          continue;
        }
      }
    });
    unawaited(_knownMinerDeleteQueue);
  }

  void clearUnstableMinerFlag(String ip) {
    state = state.copyWith(
      segments: state.segments
          .map(
            (segment) => segment.copyWith(
              miners: segment.miners
                  .map(
                    (miner) => miner.ip == ip
                        ? miner.copyWith(
                            offlineEventCount: 0,
                            clearStableOnlineSince: true,
                          )
                        : miner,
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
    unawaited(_persistState(scannedAt: state.lastScanAt));
  }

  bool addKnownMinerIp(String ip) {
    if (_knownMinerIdsByIp.isNotEmpty) {
      return false;
    }
    final normalized = ip.trim();
    if (!IpUtils.isValidIpv4(normalized)) {
      return false;
    }
    final scope = _scopeOfIp(normalized);
    final known = <String, Set<String>>{
      for (final entry in state.knownMinerIpsByScope.entries)
        entry.key: {...entry.value},
    };
    final scopeIps = known.putIfAbsent(scope, () => <String>{});
    final inserted = scopeIps.add(normalized);
    if (!inserted) {
      return false;
    }
    final ignoredMinerIps = {...state.ignoredMinerIps}..remove(normalized);
    state = state.copyWith(
      knownMinerIpsByScope: known,
      ignoredMinerIps: ignoredMinerIps,
    );
    unawaited(_persistState(scannedAt: state.lastScanAt));
    return true;
  }

  Map<String, dynamic> _encodeServerScanView(ScanView view) {
    final String subnetPrefix = IpUtils.formatIpBlockLabel(
      view.cidr.isNotEmpty ? view.cidr : view.startIp,
    );
    final List<String> startParts = view.startIp.split('.');
    final List<String> endParts = view.endIp.split('.');
    final int startHost = startParts.length == 4
        ? (int.tryParse(startParts[3]) ?? 1)
        : 1;
    final int endHost = endParts.length == 4
        ? (int.tryParse(endParts[3]) ?? 255)
        : 255;
    return <String, dynamic>{
      'id': view.id,
      'label': view.name,
      'subnetPrefix': subnetPrefix,
      'startHost': startHost,
      'endHost': endHost,
      'username': 'root',
      'password': 'ltc@dog',
      'timeoutSeconds': 5,
      'mode': 'global',
    };
  }

  void setupAutoRefresh({
    required bool enabled,
    required int intervalSeconds,
    required Future<void> Function() onTick,
  }) {
    _autoRefreshTimer?.cancel();
    if (!enabled) {
      return;
    }
    _autoRefreshTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      unawaited(onTick());
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _serverSyncResultTimer?.cancel();
    super.dispose();
  }

  SearchRequest? _buildRequest({
    required List<ScanView> selectedViews,
    required String accountUsername,
    required String accountPassword,
    required ScanTargetMode targetMode,
    required void Function(String message) onError,
  }) {
    if (selectedViews.isEmpty) {
      onError(AppStrings.english('controller.scan.selectOne'));
      return null;
    }

    final ips = targetMode == ScanTargetMode.known
        ? _buildKnownIpTargets(selectedViews)
        : _buildFullIpTargets(selectedViews);
    if (ips.isEmpty) {
      onError(
        targetMode == ScanTargetMode.known
            ? AppStrings.english('controller.scan.knownEmpty')
            : AppStrings.english('controller.scan.invalidRange'),
      );
      return null;
    }

    return SearchRequest(
      ips: ips.toList(growable: false)
        ..sort((a, b) => IpUtils.ipToInt(a).compareTo(IpUtils.ipToInt(b))),
      accountUsername: accountUsername,
      accountPassword: accountPassword,
    );
  }

  SearchRequest? _buildAutoRefreshRequest({
    required List<ScanView> allViews,
    required String accountUsername,
    required String accountPassword,
  }) {
    if (allViews.isEmpty) {
      return null;
    }
    final ips = _buildKnownIpTargets(allViews);
    if (ips.isEmpty) {
      return null;
    }
    return SearchRequest(
      ips: ips.toList(growable: false)
        ..sort((a, b) => IpUtils.ipToInt(a).compareTo(IpUtils.ipToInt(b))),
      accountUsername: accountUsername,
      accountPassword: accountPassword,
    );
  }

  Set<String> _buildFullIpTargets(List<ScanView> selectedViews) {
    final ips = <String>{};
    for (final view in selectedViews) {
      ips.addAll(
        IpUtils.expandAll(
          cidr: view.cidr,
          startIp: view.startIp,
          endIp: view.endIp,
        ),
      );
    }
    return ips;
  }

  Set<String> _buildKnownIpTargets(List<ScanView> selectedViews) {
    final scopes = <String>{};
    for (final view in selectedViews) {
      final expanded = IpUtils.expandAll(
        cidr: view.cidr,
        startIp: view.startIp,
        endIp: view.endIp,
      );
      for (final ip in expanded) {
        scopes.add(_scopeOfIp(ip));
      }
    }

    final ips = <String>{};
    for (final scope in scopes) {
      ips.addAll(state.knownMinerIpsByScope[scope] ?? const <String>{});
    }
    ips.removeAll(state.ignoredMinerIps);
    return ips;
  }

  Future<_FetchBatchResult> _fetchAllMinerDetails(
    List<PoolWorker> workers,
    MinerCredential credential, {
    required bool collectLogs,
    int concurrency = 20,
    _ManualScanControl? control,
  }) async {
    if (workers.isEmpty) {
      return const _FetchBatchResult(
        items: [],
        attemptedIps: {},
        completedCount: 0,
      );
    }
    _resetScanProgressThrottle();
    _emitScanProgress(scanned: 0, total: workers.length, force: true);

    final results = List<MinerScanItem?>.filled(workers.length, null);
    final attemptedIps = <String>{};
    var index = 0;
    var scanned = 0;

    Future<void> workerLoop() async {
      while (true) {
        if (index >= workers.length) {
          return;
        }
        if (control != null) {
          final canContinue = await control.waitUntilRunnable();
          if (!canContinue) {
            return;
          }
        }
        final current = index;
        if (current >= workers.length) {
          return;
        }
        index += 1;

        final poolWorker = workers[current];
        attemptedIps.add(poolWorker.ip);
        final runtime = await _fetchMinerDetailUseCase.getRuntime(
          poolWorker.ip,
          credential,
          collectLog: collectLogs,
        );
        scanned += 1;
        _emitScanProgress(
          scanned: scanned,
          total: workers.length,
          force: scanned >= workers.length,
        );

        final normalized = collectLogs
            ? runtime
            : MinerRuntime(
                ip: runtime.ip,
                onlineStatus: runtime.onlineStatus,
                ghs5s: runtime.ghs5s,
                ghsav: runtime.ghsav,
                ambientTemp: runtime.ambientTemp,
                power: runtime.power,
                chains: runtime.chains,
                fan1: runtime.fan1,
                fan2: runtime.fan2,
                fan3: runtime.fan3,
                fan4: runtime.fan4,
                runningMode: runtime.runningMode,
                logSnippet: '--',
                fetchedAt: runtime.fetchedAt,
              );
        results[current] = MinerScanItem(
          worker: poolWorker,
          runtime: normalized,
        );
      }
    }

    final loops = List.generate(
      concurrency < workers.length ? concurrency : workers.length,
      (_) => workerLoop(),
    );
    await Future.wait(loops);
    _emitScanProgress(scanned: scanned, total: workers.length, force: true);

    final items =
        results
            .whereType<MinerScanItem>()
            .where(
              (item) =>
                  item.runtime.onlineStatus != MinerRuntimeStatus.notMiner &&
                  item.runtime.onlineStatus != MinerRuntimeStatus.timeout,
            )
            .toList(growable: false)
          ..sort(
            (a, b) => IpUtils.ipToInt(
              a.worker.ip,
            ).compareTo(IpUtils.ipToInt(b.worker.ip)),
          );
    return _FetchBatchResult(
      items: items,
      attemptedIps: attemptedIps,
      completedCount: scanned,
    );
  }

  Future<Map<String, MinerIssueDiagnosis>> _collectZeroHashDiagnoses(
    List<MinerScanItem> items,
    MinerCredential credential, {
    required int concurrency,
  }) async {
    final targets = items
        .where(
          (item) =>
              item.runtime.onlineStatus == MinerRuntimeStatus.online &&
              ((HashrateUtils.currentGh(item.runtime.ghs5s) <= 0 &&
                      HashrateUtils.averageGh(item.runtime.ghsav) <= 0) ||
                  (_supportsExtendedAbnormalRecovery &&
                      HashrateUtils.currentGh(item.runtime.ghs5s) > 0 &&
                      HashrateUtils.currentGh(item.runtime.ghs5s) < 15)),
        )
        .toList(growable: false);
    if (targets.isEmpty) {
      return const {};
    }

    final rules = await _loadIssueRules();
    final diagnoses = <String, MinerIssueDiagnosis>{};
    var index = 0;
    var completed = 0;
    final limit = targets.length < 8 ? targets.length : 8;
    _resetPostProcessingProgressThrottle(stageKey: 'app.scan.finalizing.logs');
    _emitPostProcessingProgress(
      stageKey: 'app.scan.finalizing.logs',
      current: 0,
      total: targets.length,
      force: true,
    );

    Future<void> loop() async {
      while (true) {
        final current = index;
        if (current >= targets.length) {
          return;
        }
        index += 1;
        final item = targets[current];
        final log = await _fetchMinerDetailUseCase.getKernelLog(
          item.worker.ip,
          credential,
        );
        diagnoses[item.worker.ip] = _analyzeLog(log, rules);
        completed += 1;
        _emitPostProcessingProgress(
          stageKey: 'app.scan.finalizing.logs',
          current: completed,
          total: targets.length,
          force: completed >= targets.length,
        );
      }
    }

    await Future.wait(List.generate(limit == 0 ? 1 : limit, (_) => loop()));
    return diagnoses;
  }

  Future<List<_IssueRule>> _loadIssueRules() {
    return _issueRulesFuture ??= _readIssueRules();
  }

  Future<List<_IssueRule>> _readIssueRules() async {
    try {
      final raw = await rootBundle.loadString('assets/error_code_map.json');
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map((entry) => _IssueRule.fromJson(Map<String, dynamic>.from(entry)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  MinerIssueDiagnosis _analyzeLog(String log, List<_IssueRule> rules) {
    final normalizedLog = log.trim().isEmpty ? '--' : log.trim();
    final authenRecoveryMatch = _matchAuthenRecoveryWait(normalizedLog, rules);
    if (authenRecoveryMatch != null) {
      final hasEarlierKernelError = normalizedLog
          .substring(
            0,
            authenRecoveryMatch.start < 0 ? 0 : authenRecoveryMatch.start,
          )
          .toLowerCase()
          .contains('errormsg');
      return MinerIssueDiagnosis(
        code: authenRecoveryMatch.rule.code,
        category: authenRecoveryMatch.rule.category,
        reason: authenRecoveryMatch.rule.reason,
        solution: authenRecoveryMatch.rule.solution,
        logSnippet: _trimSnippet(authenRecoveryMatch.snippet),
        detectedAt: DateTime.now(),
        secondaryCode: hasEarlierKernelError ? 'ERRORMSG' : null,
        secondaryReason: hasEarlierKernelError
            ? 'Kernel error occurred before the miner restarted authentication.'
            : null,
      );
    }
    final allBoardFailureMatch = _matchAllBoardFailure(normalizedLog);
    if (allBoardFailureMatch != null) {
      return MinerIssueDiagnosis(
        code: 'HASHBOARD_ALL_FAILED_RESTARTING',
        category: 'all_board_failure',
        reason:
            'All hash boards reported ASIC errors. Miner is rebooting before confirmation.',
        solution:
            'Wait for the next scan to confirm whether the miner recovers after reboot.',
        logSnippet: _trimSnippet(allBoardFailureMatch.snippet),
        detectedAt: DateTime.now(),
      );
    }
    final tempFullSpeedMatch = _matchFullSpeedDueToTemperature(normalizedLog);
    if (tempFullSpeedMatch != null) {
      return MinerIssueDiagnosis(
        code: 'TEMP_FULL_SPEED_RECOVERING',
        category: 'temperature',
        reason:
            'Miner temperature is too high and full-speed protection has been triggered.',
        solution:
            'Improve cooling and monitor the miner over the next scans until hashrate returns to normal.',
        logSnippet: _trimSnippet(tempFullSpeedMatch.snippet),
        detectedAt: DateTime.now(),
      );
    }
    final primaryMatch = _findChunkedPrimaryMatch(
      normalizedLog,
      rules.where(
        (rule) => rule.code != 'AUTHEN_START_WAIT' && rule.code != 'ERRORMSG',
      ),
    );
    if (primaryMatch != null) {
      final primaryRule = primaryMatch.rule;
      if (primaryRule.code == 'CHAIN_BREAK' &&
          primaryRule.inspectEarlierForCategories.isNotEmpty) {
        final earlierLog = normalizedLog.substring(0, primaryMatch.start);
        final rootCauseMatch = _findChunkedPrimaryMatch(
          earlierLog,
          rules.where(
            (rule) =>
                primaryRule.inspectEarlierForCategories.contains(rule.category),
          ),
        );
        if (rootCauseMatch != null) {
          return MinerIssueDiagnosis(
            code: rootCauseMatch.rule.code,
            category: rootCauseMatch.rule.category,
            reason: rootCauseMatch.rule.reason,
            solution: rootCauseMatch.rule.solution,
            logSnippet: _trimSnippet(
              '${rootCauseMatch.snippet}\n...\n${primaryMatch.snippet}',
            ),
            detectedAt: DateTime.now(),
            secondaryCode: primaryRule.code,
            secondaryReason: primaryRule.reason,
          );
        }
      }
      return MinerIssueDiagnosis(
        code: primaryRule.code,
        category: primaryRule.category,
        reason: primaryRule.reason,
        solution: primaryRule.solution,
        logSnippet: _trimSnippet(primaryMatch.snippet),
        detectedAt: DateTime.now(),
      );
    }
    return MinerIssueDiagnosis(
      code: 'UNKNOWN_ZERO_HASH',
      category: 'generic',
      reason: 'Unknown zero-hash issue',
      solution:
          'Inspect the miner log, fan speed, temperature, and pool status.',
      logSnippet: _trimSnippet(normalizedLog),
      detectedAt: DateTime.now(),
    );
  }

  MinerIssueDiagnosis _buildZeroHashRestartingDiagnosis() {
    return MinerIssueDiagnosis(
      code: 'ZERO_HASH_RESTARTING',
      category: 'zero_hash_reboot',
      reason:
          'Hashrate is abnormal. The miner is marked for reboot verification.',
      solution:
          'Wait for the next scan and check whether the current hashrate returns to normal.',
      logSnippet:
          'Current hashrate is 0 while average hashrate is still above 0.',
      detectedAt: DateTime.now(),
    );
  }

  MinerIssueDiagnosis _buildZeroHashRestartFailedDiagnosis() {
    return MinerIssueDiagnosis(
      code: 'ZERO_HASH_RESTART_FAILED',
      category: 'zero_hash_reboot',
      reason:
          'Hashrate is still abnormal after reboot verification and the miner has not recovered.',
      solution:
          'Check the miner power, hash board status, and pool connection, then inspect the full kernel log if needed.',
      logSnippet:
          'Current hashrate remains 0 while average hashrate is still above 0 after reboot verification.',
      detectedAt: DateTime.now(),
    );
  }

  MinerIssueDiagnosis _buildDroppedBoardRestartingDiagnosis(
    List<int> boardIndexes,
  ) {
    final boards = boardIndexes.map((index) => '$index').join(', ');
    return MinerIssueDiagnosis(
      code: 'HASHBOARD_DROPPED_RESTARTING',
      category: 'dropped_board',
      reason:
          'Detected dropped hash board. Miner is rebooting before confirmation.',
      solution:
          'Wait for the next scan to confirm whether the dropped board has recovered.',
      logSnippet: 'BOARD_INDEX:$boards',
      detectedAt: DateTime.now(),
    );
  }

  MinerIssueDiagnosis _buildDroppedBoardRestartFailedDiagnosis(
    List<int> boardIndexes,
  ) {
    final boards = boardIndexes.map((index) => '$index').join(', ');
    return MinerIssueDiagnosis(
      code: 'HASHBOARD_DROPPED_RESTART_FAILED',
      category: 'dropped_board',
      reason: 'Dropped hash board did not recover after reboot.',
      solution:
          'Replace the affected hash board and inspect related power and ribbon cable connections.',
      logSnippet: 'BOARD_INDEX:$boards',
      detectedAt: DateTime.now(),
    );
  }

  MinerIssueDiagnosis _buildAllBoardFailureRestartingDiagnosis() {
    return MinerIssueDiagnosis(
      code: 'HASHBOARD_ALL_FAILED_RESTARTING',
      category: 'all_board_failure',
      reason:
          'All hash boards reported ASIC errors. Miner is rebooting before confirmation.',
      solution:
          'Wait for the next scan to confirm whether the miner recovers after reboot.',
      logSnippet: 'BOARD_INDEX:0,1,2',
      detectedAt: DateTime.now(),
    );
  }

  MinerIssueDiagnosis _buildAllBoardFailureNeedsReplacementDiagnosis() {
    return MinerIssueDiagnosis(
      code: 'HASHBOARD_ALL_FAILED_NEEDS_REPLACEMENT',
      category: 'all_board_failure',
      reason:
          'All hash boards still report errors after reboot and likely need replacement.',
      solution:
          'Replace the affected hash boards and inspect related power, ribbon cable, and controller connections.',
      logSnippet: 'BOARD_INDEX:0,1,2',
      detectedAt: DateTime.now(),
    );
  }

  MinerIssueDiagnosis _buildTempFullSpeedRecoveringDiagnosis() {
    return MinerIssueDiagnosis(
      code: 'TEMP_FULL_SPEED_RECOVERING',
      category: 'temperature',
      reason:
          'Miner temperature is too high and full-speed protection has been triggered.',
      solution:
          'Improve cooling and monitor the miner over the next scans until hashrate returns to normal.',
      logSnippet: 'full speed due to temperature',
      detectedAt: DateTime.now(),
    );
  }

  MinerIssueDiagnosis _buildTempFullSpeedPersistedDiagnosis() {
    return MinerIssueDiagnosis(
      code: 'TEMP_FULL_SPEED_PERSISTED',
      category: 'temperature',
      reason:
          'Miner temperature protection has stayed active for multiple scans and hashrate has not recovered.',
      solution:
          'Inspect ambient temperature, airflow, fan operation, and heat dissipation. Resolve the thermal issue before returning the miner to service.',
      logSnippet: 'full speed due to temperature',
      detectedAt: DateTime.now(),
    );
  }

  bool _hasRecoveredNormalHashrate(MinerRuntime runtime) {
    return HashrateUtils.currentGh(runtime.ghs5s) >= 15;
  }

  bool _isTempFullSpeedDiagnosis(MinerIssueDiagnosis? diagnosis) {
    final code = diagnosis?.code;
    return code == 'TEMP_FULL_SPEED_RECOVERING' ||
        code == 'TEMP_FULL_SPEED_PERSISTED';
  }

  bool _isAllBoardFailureDiagnosis(MinerIssueDiagnosis? diagnosis) {
    final code = diagnosis?.code;
    return code == 'HASHBOARD_ALL_FAILED_RESTARTING' ||
        code == 'HASHBOARD_ALL_FAILED_NEEDS_REPLACEMENT';
  }

  List<String> _collectAllBoardFailureRebootTargets({
    required List<ScanSegmentRecord> existing,
    required Map<String, MinerIssueDiagnosis> diagnoses,
  }) {
    if (!_supportsExtendedAbnormalRecovery) {
      return const [];
    }
    final existingByIp = <String, TrackedMiner>{
      for (final segment in existing)
        for (final miner in segment.miners) miner.ip: miner,
    };
    final targets = <String>[];
    for (final entry in diagnoses.entries) {
      if (entry.value.code != 'HASHBOARD_ALL_FAILED_RESTARTING') {
        continue;
      }
      final existingMiner = existingByIp[entry.key];
      if (existingMiner == null ||
          (!existingMiner.allBoardFailureRestartPending &&
              existingMiner.diagnosis?.code !=
                  'HASHBOARD_ALL_FAILED_NEEDS_REPLACEMENT')) {
        targets.add(entry.key);
      }
    }
    targets.sort((a, b) => IpUtils.ipToInt(a).compareTo(IpUtils.ipToInt(b)));
    return targets;
  }

  bool _isDroppedBoardCandidate(MinerRuntime runtime) {
    final currentGh = HashrateUtils.currentGh(runtime.ghs5s);
    if (currentGh <= 0 || currentGh >= 15) {
      return false;
    }
    return runtime.chains.any((chain) => chain.chainRateValue <= 0);
  }

  List<int> _droppedBoardIndexes(MinerRuntime runtime) {
    return runtime.chains
        .where((chain) => chain.chainRateValue <= 0)
        .map((chain) => chain.index)
        .toList(growable: false)
      ..sort();
  }

  List<String> _collectDroppedBoardRebootTargets({
    required List<ScanSegmentRecord> existing,
    required List<MinerScanItem> items,
  }) {
    if (!_supportsExtendedAbnormalRecovery) {
      return const [];
    }
    final existingByIp = <String, TrackedMiner>{
      for (final segment in existing)
        for (final miner in segment.miners) miner.ip: miner,
    };
    final targets = <String>[];
    for (final item in items) {
      if (!_isDroppedBoardCandidate(item.runtime)) {
        continue;
      }
      final existingMiner = existingByIp[item.worker.ip];
      if (existingMiner == null ||
          (!existingMiner.droppedBoardRestartPending &&
              existingMiner.diagnosis?.code !=
                  'HASHBOARD_DROPPED_RESTART_FAILED')) {
        targets.add(item.worker.ip);
      }
    }
    targets.sort((a, b) => IpUtils.ipToInt(a).compareTo(IpUtils.ipToInt(b)));
    return targets;
  }

  bool _isImmediateZeroHashRestartCase(MinerScanItem item) {
    return item.runtime.onlineStatus == MinerRuntimeStatus.online &&
        HashrateUtils.currentGh(item.runtime.ghs5s) <= 0 &&
        HashrateUtils.averageGh(item.runtime.ghsav) > 0;
  }

  List<String> _collectImmediateZeroHashRebootTargets({
    required List<ScanSegmentRecord> existing,
    required List<MinerScanItem> items,
  }) {
    final existingByIp = <String, TrackedMiner>{
      for (final segment in existing)
        for (final miner in segment.miners) miner.ip: miner,
    };
    final targets = <String>[];
    for (final item in items) {
      if (_isDroppedBoardCandidate(item.runtime)) {
        continue;
      }
      if (!_isImmediateZeroHashRestartCase(item)) {
        continue;
      }
      final existingMiner = existingByIp[item.worker.ip];
      if (existingMiner == null ||
          (!existingMiner.zeroHashRestartPending &&
              existingMiner.diagnosis?.code != 'ZERO_HASH_RESTART_FAILED')) {
        targets.add(item.worker.ip);
      }
    }
    targets.sort((a, b) => IpUtils.ipToInt(a).compareTo(IpUtils.ipToInt(b)));
    return targets;
  }

  Future<Set<String>> _autoRebootImmediateZeroHashTargets(
    List<String> ips,
    MinerCredential credential,
  ) async {
    if (ips.isEmpty) {
      return const <String>{};
    }
    final succeeded = <String>{};
    var completed = 0;
    _resetPostProcessingProgressThrottle(
      stageKey: 'app.scan.finalizing.reboot',
    );
    _emitPostProcessingProgress(
      stageKey: 'app.scan.finalizing.reboot',
      current: 0,
      total: ips.length,
      force: true,
    );
    for (final ip in ips) {
      final result = await _rebootMinerUseCase.execute([ip], credential);
      if (result.success) {
        succeeded.add(ip);
      }
      completed += 1;
      _emitPostProcessingProgress(
        stageKey: 'app.scan.finalizing.reboot',
        current: completed,
        total: ips.length,
        force: completed >= ips.length,
      );
    }
    return succeeded;
  }

  Future<Set<String>> _autoRebootDroppedBoardTargets(
    List<String> ips,
    MinerCredential credential,
  ) async {
    if (ips.isEmpty) {
      return const <String>{};
    }
    final succeeded = <String>{};
    var completed = 0;
    _resetPostProcessingProgressThrottle(
      stageKey: 'app.scan.finalizing.droppedBoardReboot',
    );
    _emitPostProcessingProgress(
      stageKey: 'app.scan.finalizing.droppedBoardReboot',
      current: 0,
      total: ips.length,
      force: true,
    );
    for (final ip in ips) {
      final result = await _rebootMinerUseCase.execute([ip], credential);
      if (result.success) {
        succeeded.add(ip);
      }
      completed += 1;
      _emitPostProcessingProgress(
        stageKey: 'app.scan.finalizing.droppedBoardReboot',
        current: completed,
        total: ips.length,
        force: completed >= ips.length,
      );
    }
    return succeeded;
  }

  Future<Set<String>> _autoRebootAllBoardFailureTargets(
    List<String> ips,
    MinerCredential credential,
  ) async {
    if (!_supportsExtendedAbnormalRecovery || ips.isEmpty) {
      return const <String>{};
    }
    final succeeded = <String>{};
    var completed = 0;
    _resetPostProcessingProgressThrottle(
      stageKey: 'app.scan.finalizing.allBoardReboot',
    );
    _emitPostProcessingProgress(
      stageKey: 'app.scan.finalizing.allBoardReboot',
      current: 0,
      total: ips.length,
      force: true,
    );
    for (final ip in ips) {
      final result = await _rebootMinerUseCase.execute([ip], credential);
      if (result.success) {
        succeeded.add(ip);
      }
      completed += 1;
      _emitPostProcessingProgress(
        stageKey: 'app.scan.finalizing.allBoardReboot',
        current: completed,
        total: ips.length,
        force: completed >= ips.length,
      );
    }
    return succeeded;
  }

  String _trimSnippet(String value) {
    final normalized = value.replaceAll('\r', '').trim();
    if (normalized.length <= 240) {
      return normalized;
    }
    return '${normalized.substring(0, 240)}...';
  }

  _RuleMatch? _findChunkedPrimaryMatch(String log, Iterable<_IssueRule> rules) {
    final normalized = log.replaceAll('\r', '');
    final lines = normalized.split('\n');
    if (lines.isEmpty) {
      return null;
    }
    _RuleMatch? bestMatch;
    var chunkEnd = lines.length;
    while (chunkEnd > 0) {
      final chunkStart = chunkEnd - 20 < 0 ? 0 : chunkEnd - 20;
      final chunkLines = lines.sublist(chunkStart, chunkEnd);
      final hasErrorLine = chunkLines.any(
        (line) => line.trimLeft().toLowerCase().startsWith('errormsg'),
      );
      if (hasErrorLine) {
        final chunkText = chunkLines.join('\n');
        final match = _findBestRuleMatchInLines(chunkText, chunkLines, rules);
        if (match != null) {
          final absoluteStart = normalized.indexOf(chunkText);
          final candidate = _RuleMatch(
            rule: match.rule,
            start: absoluteStart < 0
                ? match.start
                : absoluteStart + match.start,
            snippet: match.snippet,
          );
          if (bestMatch == null ||
              candidate.rule.priority > bestMatch.rule.priority ||
              (candidate.rule.priority == bestMatch.rule.priority &&
                  candidate.start > bestMatch.start)) {
            bestMatch = candidate;
          }
        }
      }
      chunkEnd = chunkStart;
    }
    return bestMatch;
  }

  _RuleMatch? _matchAllBoardFailure(String log) {
    final normalized = log.replaceAll('\r', '');
    final lines = normalized.split('\n');
    if (lines.isEmpty) {
      return null;
    }
    var chunkEnd = lines.length;
    while (chunkEnd > 0) {
      final chunkStart = chunkEnd - 20 < 0 ? 0 : chunkEnd - 20;
      final chunkLines = lines.sublist(chunkStart, chunkEnd);
      final hasErrorLine = chunkLines.any(
        (line) => line.trimLeft().toLowerCase().startsWith('errormsg'),
      );
      if (hasErrorLine) {
        final chunkText = chunkLines.join('\n');
        final lowerChunk = chunkText.toLowerCase();
        if (lowerChunk.contains('chain j0 has wrong asic') &&
            lowerChunk.contains('chain j1 has wrong asic') &&
            lowerChunk.contains('chain j2 has wrong asic')) {
          final absoluteStart = normalized.indexOf(chunkText);
          return _RuleMatch(
            rule: const _IssueRule(
              code: 'HASHBOARD_ALL_FAILED_RESTARTING',
              category: 'all_board_failure',
              priority: 85,
              matches: ['chain j0 has wrong asic'],
              reason: '',
              solution: '',
              inspectEarlierForCategories: [],
            ),
            start: absoluteStart < 0 ? 0 : absoluteStart,
            snippet: chunkText.trim(),
          );
        }
      }
      chunkEnd = chunkStart;
    }
    return null;
  }

  _RuleMatch? _matchFullSpeedDueToTemperature(String log) {
    final normalized = log.replaceAll('\r', '');
    final lines = normalized.split('\n');
    if (lines.isEmpty) {
      return null;
    }
    var chunkEnd = lines.length;
    while (chunkEnd > 0) {
      final chunkStart = chunkEnd - 20 < 0 ? 0 : chunkEnd - 20;
      final chunkLines = lines.sublist(chunkStart, chunkEnd);
      final chunkText = chunkLines.join('\n');
      if (chunkText.toLowerCase().contains('full speed due to temperature')) {
        final absoluteStart = normalized.indexOf(chunkText);
        return _RuleMatch(
          rule: const _IssueRule(
            code: 'TEMP_FULL_SPEED_RECOVERING',
            category: 'temperature',
            priority: 75,
            matches: ['full speed due to temperature'],
            reason: '',
            solution: '',
            inspectEarlierForCategories: [],
          ),
          start: absoluteStart < 0 ? 0 : absoluteStart,
          snippet: chunkText.trim(),
        );
      }
      chunkEnd = chunkStart;
    }
    return null;
  }

  _RuleMatch? _findBestRuleMatchInLines(
    String normalized,
    List<String> lines,
    Iterable<_IssueRule> rules,
  ) {
    _RuleMatch? bestMatch;
    for (var lineIndex = lines.length - 1; lineIndex >= 0; lineIndex--) {
      final line = lines[lineIndex];
      final lowerLine = line.toLowerCase();
      for (final rule in rules) {
        for (final matcher in rule.matches) {
          if (!lowerLine.contains(matcher.toLowerCase())) {
            continue;
          }
          final candidate = _RuleMatch(
            rule: rule,
            start: normalized.indexOf(line),
            snippet: lines
                .sublist(
                  lineIndex - 6 < 0 ? 0 : lineIndex - 6,
                  lineIndex + 3 >= lines.length
                      ? lines.length - 1
                      : lineIndex + 3,
                )
                .join('\n')
                .trim(),
          );
          if (bestMatch == null ||
              rule.priority > bestMatch.rule.priority ||
              (rule.priority == bestMatch.rule.priority &&
                  matcher.length >
                      (bestMatch.rule.matches.isNotEmpty
                          ? bestMatch.rule.matches.first.length
                          : 0)) ||
              (rule.priority == bestMatch.rule.priority &&
                  matcher.length ==
                      (bestMatch.rule.matches.isNotEmpty
                          ? bestMatch.rule.matches.first.length
                          : 0) &&
                  lineIndex > 0)) {
            bestMatch = candidate;
          }
        }
      }
    }
    return bestMatch;
  }

  _RuleMatch? _matchAuthenRecoveryWait(String log, List<_IssueRule> rules) {
    _IssueRule? authRule;
    for (final rule in rules) {
      if (rule.code == 'AUTHEN_START_WAIT') {
        authRule = rule;
        break;
      }
    }
    if (authRule == null) {
      return null;
    }

    final normalized = log.replaceAll('\r', '');
    final lines = normalized.split('\n');
    if (lines.isEmpty) {
      return null;
    }
    final recentWindowStart = lines.length > 20 ? lines.length - 20 : 0;
    var lineIndex = -1;
    for (var i = lines.length - 1; i >= recentWindowStart; i--) {
      if (lines[i].toLowerCase().contains('authen start !!!!!')) {
        lineIndex = i;
        break;
      }
    }
    if (lineIndex == -1) {
      return null;
    }
    final start = lineIndex - 6 < 0 ? 0 : lineIndex - 6;
    final end = lineIndex + 3 >= lines.length
        ? lines.length - 1
        : lineIndex + 3;
    var authIndex = 0;
    for (var i = 0; i < lineIndex; i++) {
      authIndex += lines[i].length + 1;
    }
    return _RuleMatch(
      rule: authRule,
      start: authIndex,
      snippet: lines.sublist(start, end + 1).join('\n').trim(),
    );
  }

  List<PoolWorker> _dedupeWorkersByIp(List<PoolWorker> workers) {
    final map = <String, PoolWorker>{};
    for (final worker in workers) {
      if (worker.ip.trim().isEmpty) {
        continue;
      }
      map.putIfAbsent(worker.ip, () => worker);
    }
    return map.values.toList(growable: false);
  }

  List<String> _buildSearchScopes(List<String> ips) {
    final scopes = <String>{};
    for (final ip in ips) {
      final parts = ip.split('.');
      if (parts.length != 4) {
        continue;
      }
      scopes.add('${parts[0]}.${parts[1]}.${parts[2]}');
    }
    final sorted = scopes.toList(growable: false)
      ..sort((a, b) => IpUtils.compareIpBlocks(a, b));
    return sorted;
  }

  Map<String, Set<String>> _mergeKnownMinerIps(
    Map<String, Set<String>> existing,
    List<MinerScanItem> items,
  ) {
    final next = <String, Set<String>>{
      for (final entry in existing.entries) entry.key: {...entry.value},
    };
    for (final item in items) {
      if (item.runtime.onlineStatus != MinerRuntimeStatus.online) {
        continue;
      }
      final scope = _scopeOfIp(item.worker.ip);
      next.putIfAbsent(scope, () => <String>{}).add(item.worker.ip);
    }
    return next;
  }

  List<ScanSegmentRecord> _mergeSegments({
    required List<ScanSegmentRecord> existing,
    required List<MinerScanItem> items,
    required List<String> scopes,
    required Set<String> requestedIps,
    required Set<String> rebootedZeroHashIps,
    required Set<String> clearRefinedIps,
    required DateTime scannedAt,
    required Map<String, MinerIssueDiagnosis> diagnoses,
  }) {
    final segmentMap = {for (final segment in existing) segment.scope: segment};
    final onlineByScope = <String, Map<String, MinerScanItem>>{};

    for (final item in items) {
      if (item.runtime.onlineStatus != MinerRuntimeStatus.online) {
        continue;
      }
      final scope = _scopeOfIp(item.worker.ip);
      final miners = onlineByScope.putIfAbsent(
        scope,
        () => <String, MinerScanItem>{},
      );
      miners[item.worker.ip] = item;
    }

    for (final scope in scopes) {
      final existingSegment = segmentMap[scope];
      final existingMiners = {
        for (final miner in existingSegment?.miners ?? const <TrackedMiner>[])
          miner.ip: miner,
      };
      final seenMiners =
          onlineByScope[scope] ?? const <String, MinerScanItem>{};
      final merged = <TrackedMiner>[];

      for (final entry in existingMiners.entries) {
        final current = seenMiners[entry.key];
        if (current != null) {
          final droppedBoardCandidate = _isDroppedBoardCandidate(
            current.runtime,
          );
          final droppedBoardIndexes = _droppedBoardIndexes(current.runtime);
          final immediateZeroHashRestart = _isImmediateZeroHashRestartCase(
            current,
          );
          final diagnosis = diagnoses[entry.key];
          final currentAllBoardFailure =
              diagnosis?.code == 'HASHBOARD_ALL_FAILED_RESTARTING';
          final currentTempFullSpeed =
              diagnosis?.code == 'TEMP_FULL_SPEED_RECOVERING';
          final currentHashrateGh = HashrateUtils.currentGh(
            current.runtime.ghs5s,
          );
          final hasVisibleHashrate = currentHashrateGh > 0;
          final hasRecoveredHashrate = _hasRecoveredNormalHashrate(
            current.runtime,
          );
          final stableOnlineSince =
              entry.value.state == TrackedMinerState.online &&
                  entry.value.stableOnlineSince != null
              ? entry.value.stableOnlineSince!
              : scannedAt;
          final shouldClearUnstable =
              entry.value.offlineEventCount >= 3 &&
              scannedAt.difference(stableOnlineSince) >=
                  const Duration(hours: 3);
          final shouldWaitForZeroHashRecovery = _shouldWaitForZeroHashRecovery(
            diagnosis,
          );
          if (_supportsExtendedAbnormalRecovery &&
              entry.value.allBoardFailureRestartPending) {
            if (hasRecoveredHashrate && !currentAllBoardFailure) {
              merged.add(
                entry.value.copyWith(
                  lastItem: current,
                  lastSeenAt: scannedAt,
                  missedScans: 0,
                  stableOnlineSince: scannedAt,
                  clearRefineAttempted: false,
                  offlineScanMisses: 0,
                  clearOfflineSince: true,
                  clearRetiredAt: true,
                  allBoardFailureRestartPending: false,
                  clearForcedOfflineAt: true,
                  diagnosis: diagnosis,
                  clearDiagnosis:
                      diagnosis == null &&
                      _isAllBoardFailureDiagnosis(entry.value.diagnosis),
                ),
              );
            } else {
              merged.add(
                entry.value.copyWith(
                  lastItem: current,
                  lastSeenAt: scannedAt,
                  missedScans: 0,
                  stableOnlineSince: scannedAt,
                  clearRefineAttempted: false,
                  offlineScanMisses: 0,
                  clearOfflineSince: true,
                  clearRetiredAt: true,
                  allBoardFailureRestartPending: false,
                  clearForcedOfflineAt: true,
                  diagnosis: _buildAllBoardFailureNeedsReplacementDiagnosis(),
                ),
              );
            }
            continue;
          }
          if (_supportsExtendedAbnormalRecovery && currentAllBoardFailure) {
            merged.add(
              entry.value.copyWith(
                lastItem: current,
                lastSeenAt: scannedAt,
                missedScans: 0,
                stableOnlineSince: scannedAt,
                clearRefineAttempted: false,
                offlineScanMisses: 0,
                clearOfflineSince: true,
                clearRetiredAt: true,
                allBoardFailureRestartPending: true,
                clearForcedOfflineAt: true,
                diagnosis: _buildAllBoardFailureRestartingDiagnosis(),
              ),
            );
            continue;
          }
          if (droppedBoardCandidate && _supportsExtendedAbnormalRecovery) {
            if (entry.value.droppedBoardRestartPending) {
              merged.add(
                entry.value.copyWith(
                  lastItem: current,
                  lastSeenAt: scannedAt,
                  missedScans: 0,
                  stableOnlineSince: scannedAt,
                  clearRefineAttempted: false,
                  offlineScanMisses: 0,
                  clearOfflineSince: true,
                  clearRetiredAt: true,
                  droppedBoardRestartPending: false,
                  clearZeroHashWaitUntil: true,
                  zeroHashRestartPending: false,
                  clearForcedOfflineAt: true,
                  diagnosis: _buildDroppedBoardRestartFailedDiagnosis(
                    droppedBoardIndexes,
                  ),
                ),
              );
            } else {
              merged.add(
                entry.value.copyWith(
                  lastItem: current,
                  lastSeenAt: scannedAt,
                  missedScans: 0,
                  stableOnlineSince: scannedAt,
                  clearRefineAttempted: false,
                  offlineScanMisses: 0,
                  clearOfflineSince: true,
                  clearRetiredAt: true,
                  droppedBoardRestartPending: true,
                  clearZeroHashWaitUntil: true,
                  zeroHashRestartPending: false,
                  clearForcedOfflineAt: true,
                  diagnosis: _buildDroppedBoardRestartingDiagnosis(
                    droppedBoardIndexes,
                  ),
                ),
              );
            }
            continue;
          }
          if (_supportsExtendedAbnormalRecovery &&
              (entry.value.tempFullSpeedMarkedAt != null ||
                  currentTempFullSpeed)) {
            if (hasRecoveredHashrate && !currentTempFullSpeed) {
              merged.add(
                entry.value.copyWith(
                  lastItem: current,
                  lastSeenAt: scannedAt,
                  missedScans: 0,
                  stableOnlineSince: scannedAt,
                  clearRefineAttempted: false,
                  offlineScanMisses: 0,
                  clearOfflineSince: true,
                  clearRetiredAt: true,
                  clearTempFullSpeedMarkedAt: true,
                  tempFullSpeedScanMisses: 0,
                  clearForcedOfflineAt: true,
                  diagnosis: diagnosis,
                  clearDiagnosis:
                      diagnosis == null &&
                      _isTempFullSpeedDiagnosis(entry.value.diagnosis),
                ),
              );
            } else {
              final nextMisses = entry.value.tempFullSpeedMarkedAt == null
                  ? 0
                  : entry.value.tempFullSpeedScanMisses + 1;
              merged.add(
                entry.value.copyWith(
                  lastItem: current,
                  lastSeenAt: scannedAt,
                  missedScans: 0,
                  stableOnlineSince: scannedAt,
                  clearRefineAttempted: false,
                  offlineScanMisses: 0,
                  clearOfflineSince: true,
                  clearRetiredAt: true,
                  tempFullSpeedMarkedAt:
                      entry.value.tempFullSpeedMarkedAt ?? scannedAt,
                  tempFullSpeedScanMisses: nextMisses,
                  clearForcedOfflineAt: true,
                  diagnosis: nextMisses >= 4
                      ? _buildTempFullSpeedPersistedDiagnosis()
                      : _buildTempFullSpeedRecoveringDiagnosis(),
                ),
              );
            }
            continue;
          }
          if (immediateZeroHashRestart) {
            if (entry.value.zeroHashRestartPending ||
                entry.value.diagnosis?.code == 'ZERO_HASH_RESTART_FAILED') {
              merged.add(
                entry.value.copyWith(
                  lastItem: current,
                  lastSeenAt: scannedAt,
                  missedScans: 2,
                  offlineEventCount:
                      entry.value.state == TrackedMinerState.offline ||
                          entry.value.state == TrackedMinerState.pendingRetire
                      ? entry.value.offlineEventCount
                      : entry.value.offlineEventCount + 1,
                  clearStableOnlineSince: true,
                  clearRefineAttempted: false,
                  offlineSince: entry.value.offlineSince ?? scannedAt,
                  offlineScanMisses: entry.value.offlineScanMisses,
                  zeroHashRestartPending: false,
                  clearZeroHashWaitUntil: true,
                  diagnosis: _buildZeroHashRestartFailedDiagnosis(),
                ),
              );
            } else {
              merged.add(
                entry.value.copyWith(
                  lastItem: current,
                  lastSeenAt: scannedAt,
                  missedScans: 1,
                  clearStableOnlineSince: true,
                  clearRefineAttempted: false,
                  clearOfflineSince: true,
                  clearRetiredAt: true,
                  zeroHashRestartPending: rebootedZeroHashIps.contains(
                    entry.key,
                  ),
                  clearZeroHashWaitUntil: true,
                  clearForcedOfflineAt: true,
                  diagnosis: _buildZeroHashRestartingDiagnosis(),
                ),
              );
            }
            continue;
          }
          merged.add(
            entry.value.copyWith(
              lastItem: current,
              lastSeenAt: scannedAt,
              missedScans: 0,
              offlineEventCount: shouldClearUnstable
                  ? 0
                  : entry.value.offlineEventCount,
              stableOnlineSince: stableOnlineSince,
              clearRefineAttempted: false,
              offlineScanMisses: 0,
              clearOfflineSince: true,
              clearRetiredAt: true,
              allBoardFailureRestartPending: false,
              droppedBoardRestartPending: false,
              clearTempFullSpeedMarkedAt: hasRecoveredHashrate,
              tempFullSpeedScanMisses: hasRecoveredHashrate
                  ? 0
                  : entry.value.tempFullSpeedScanMisses,
              zeroHashWaitUntil: shouldWaitForZeroHashRecovery
                  ? (entry.value.zeroHashWaitUntil ??
                        scannedAt.add(const Duration(minutes: 10)))
                  : null,
              clearZeroHashWaitUntil: !shouldWaitForZeroHashRecovery,
              zeroHashRestartPending: false,
              clearForcedOfflineAt: hasVisibleHashrate,
              diagnosis: diagnosis,
              clearDiagnosis:
                  diagnosis == null &&
                  (entry.value.hasDroppedBoardIssue ||
                      _isTempFullSpeedDiagnosis(entry.value.diagnosis) ||
                      _isAllBoardFailureDiagnosis(entry.value.diagnosis)),
            ),
          );
        } else if (requestedIps.contains(entry.key)) {
          final updated = _advanceMissingMinerState(
            entry.value,
            scannedAt,
            clearRefinedIps.contains(entry.key),
          );
          merged.add(updated);
        } else {
          merged.add(entry.value);
        }
      }

      for (final entry in seenMiners.entries) {
        if (existingMiners.containsKey(entry.key)) {
          continue;
        }
        final droppedBoardCandidate = _isDroppedBoardCandidate(
          entry.value.runtime,
        );
        final droppedBoardIndexes = _droppedBoardIndexes(entry.value.runtime);
        final immediateZeroHashRestart = _isImmediateZeroHashRestartCase(
          entry.value,
        );
        final diagnosis = diagnoses[entry.key];
        final currentAllBoardFailure =
            diagnosis?.code == 'HASHBOARD_ALL_FAILED_RESTARTING';
        final currentTempFullSpeed =
            diagnosis?.code == 'TEMP_FULL_SPEED_RECOVERING';
        merged.add(
          TrackedMiner(
            ip: entry.key,
            lastItem: entry.value,
            lastSeenAt: scannedAt,
            missedScans: immediateZeroHashRestart ? 1 : 0,
            stableOnlineSince: immediateZeroHashRestart ? null : scannedAt,
            clearRefineAttempted: false,
            offlineScanMisses: 0,
            allBoardFailureRestartPending:
                _supportsExtendedAbnormalRecovery && currentAllBoardFailure,
            droppedBoardRestartPending:
                _supportsExtendedAbnormalRecovery &&
                !currentAllBoardFailure &&
                droppedBoardCandidate,
            zeroHashRestartPending:
                immediateZeroHashRestart &&
                rebootedZeroHashIps.contains(entry.key),
            zeroHashWaitUntil:
                _shouldWaitForZeroHashRecovery(diagnoses[entry.key])
                ? scannedAt.add(const Duration(minutes: 10))
                : null,
            tempFullSpeedMarkedAt:
                _supportsExtendedAbnormalRecovery && currentTempFullSpeed
                ? scannedAt
                : null,
            tempFullSpeedScanMisses:
                _supportsExtendedAbnormalRecovery && currentTempFullSpeed
                ? 0
                : 0,
            diagnosis:
                _supportsExtendedAbnormalRecovery && currentAllBoardFailure
                ? _buildAllBoardFailureRestartingDiagnosis()
                : _supportsExtendedAbnormalRecovery && droppedBoardCandidate
                ? _buildDroppedBoardRestartingDiagnosis(droppedBoardIndexes)
                : immediateZeroHashRestart
                ? _buildZeroHashRestartingDiagnosis()
                : _supportsExtendedAbnormalRecovery && currentTempFullSpeed
                ? _buildTempFullSpeedRecoveringDiagnosis()
                : diagnosis,
          ),
        );
      }

      merged.sort(
        (a, b) => IpUtils.ipToInt(a.ip).compareTo(IpUtils.ipToInt(b.ip)),
      );
      final normalizedMerged = _isScopeWideOutageCandidate(merged)
          ? merged
                .map(
                  (miner) => miner.offlineEventCount > 0
                      ? miner.copyWith(
                          offlineEventCount: 0,
                          clearStableOnlineSince: true,
                        )
                      : miner,
                )
                .toList(growable: false)
          : merged;
      segmentMap[scope] = ScanSegmentRecord(
        scope: scope,
        updatedAt: scannedAt,
        miners: normalizedMerged,
      );
    }

    return segmentMap.values.toList(growable: false)
      ..sort((a, b) => IpUtils.compareIpBlocks(a.scope, b.scope));
  }

  String _scopeOfIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) {
      return ip;
    }
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  static const int _scopeWideOutageOfflineThreshold = 10;
  static const int _scopeWideOutageUnresolvedScanThreshold = 2;

  bool _isScopeWideOutageCandidate(List<TrackedMiner> miners) {
    var unresolvedOfflineCount = 0;
    for (final miner in miners) {
      final isStillOffline =
          miner.state == TrackedMinerState.offline ||
          miner.state == TrackedMinerState.pendingRetire;
      if (!isStillOffline) {
        continue;
      }
      if (miner.offlineScanMisses >= _scopeWideOutageUnresolvedScanThreshold) {
        unresolvedOfflineCount += 1;
      }
      if (unresolvedOfflineCount > _scopeWideOutageOfflineThreshold) {
        return true;
      }
    }
    return false;
  }

  Future<Set<String>> _autoClearRefineForRequestedMisses({
    required Set<String> requestedIps,
    required List<MinerScanItem> seenItems,
    required MinerCredential credential,
    required int maxTargets,
  }) async {
    final seenIps = seenItems.map((item) => item.worker.ip).toSet();
    final targets = <String>[];
    for (final segment in state.segments) {
      for (final miner in segment.miners) {
        if (!requestedIps.contains(miner.ip) || seenIps.contains(miner.ip)) {
          continue;
        }
        if (miner.retiredAt != null) {
          continue;
        }
        final shouldClear =
            miner.missedScans == 1 && !miner.clearRefineAttempted;
        if (shouldClear) {
          targets.add(miner.ip);
        }
      }
    }
    if (targets.isEmpty) {
      return const <String>{};
    }
    targets.sort((a, b) => IpUtils.ipToInt(a).compareTo(IpUtils.ipToInt(b)));
    final limitedTargets = targets.length <= maxTargets
        ? targets
        : targets.take(maxTargets).toList(growable: false);
    _resetPostProcessingProgressThrottle(
      stageKey: 'app.scan.finalizing.clearRefine',
    );
    _emitPostProcessingProgress(
      stageKey: 'app.scan.finalizing.clearRefine',
      current: 0,
      total: limitedTargets.length,
      force: true,
    );

    final result = await _clearRefineUseCase.execute(
      limitedTargets,
      credential,
    );
    _emitPostProcessingProgress(
      stageKey: 'app.scan.finalizing.clearRefine',
      current: limitedTargets.length,
      total: limitedTargets.length,
      force: true,
    );
    return result.success ? result.targets.toSet() : limitedTargets.toSet();
  }

  int _countPendingClearRefineTargets({
    required Set<String> requestedIps,
    required List<MinerScanItem> seenItems,
    required int maxTargets,
  }) {
    final seenIps = seenItems.map((item) => item.worker.ip).toSet();
    var count = 0;
    for (final segment in state.segments) {
      for (final miner in segment.miners) {
        if (!requestedIps.contains(miner.ip) || seenIps.contains(miner.ip)) {
          continue;
        }
        if (miner.retiredAt != null) {
          continue;
        }
        final shouldClear =
            miner.missedScans == 1 && !miner.clearRefineAttempted;
        if (shouldClear) {
          count += 1;
          if (count >= maxTargets) {
            return maxTargets;
          }
        }
      }
    }
    return count;
  }

  TrackedMiner _advanceMissingMinerState(
    TrackedMiner miner,
    DateTime scannedAt,
    bool clearRefineTriggered,
  ) {
    if (miner.retiredAt != null) {
      return miner;
    }

    if (miner.missedScans <= 0) {
      return miner.copyWith(
        missedScans: 1,
        clearStableOnlineSince: true,
        clearRefineAttempted: miner.clearRefineAttempted,
      );
    }

    if (miner.missedScans == 1) {
      if (clearRefineTriggered) {
        return miner.copyWith(
          missedScans: 1,
          clearStableOnlineSince: true,
          clearRefineAttempted: true,
        );
      }
      if (miner.clearRefineAttempted) {
        return miner.copyWith(
          missedScans: 2,
          offlineEventCount: miner.offlineEventCount + 1,
          clearStableOnlineSince: true,
          clearRefineAttempted: true,
          offlineSince: miner.offlineSince ?? scannedAt,
          offlineScanMisses: 0,
        );
      }
      return miner.copyWith(
        missedScans: 1,
        clearStableOnlineSince: true,
        clearRefineAttempted: false,
      );
    }

    final offlineSince = miner.offlineSince ?? scannedAt;
    final offlineScanMisses = miner.offlineScanMisses + 1;
    final shouldRetire =
        scannedAt.difference(offlineSince) >= const Duration(hours: 24) &&
        offlineScanMisses >= 12;

    return miner.copyWith(
      missedScans: miner.missedScans + 1,
      clearStableOnlineSince: true,
      clearRefineAttempted: true,
      offlineSince: offlineSince,
      offlineScanMisses: offlineScanMisses,
      retiredAt: shouldRetire ? scannedAt : null,
    );
  }

  void _updateLedState(LedToggleResult result, bool on) {
    if (!result.success) {
      return;
    }
    final next = {...state.ledActiveIps};
    if (on) {
      next.addAll(result.targets);
    } else {
      next.removeAll(result.targets);
    }
    state = state.copyWith(ledActiveIps: next);
    unawaited(_persistState(scannedAt: state.lastScanAt));
  }

  Future<void> _persistState({DateTime? scannedAt}) {
    return _localDataSource.saveScanState(
      segments: state.segments,
      ledActiveIps: state.ledActiveIps,
      knownMinerIpsByScope: state.knownMinerIpsByScope,
      ignoredMinerIps: state.ignoredMinerIps,
      hashrateHistory: state.hashrateHistory,
      lastScanAt: scannedAt,
      generatedAt: state.generatedAt,
      nextScheduledAt: state.nextScheduledAt,
      nextGlobalScanAt: state.nextGlobalScanAt,
      nextScheduledIsGlobalAllViews: state.nextScheduledIsGlobalAllViews,
      serverMinerCount: state.serverMinerCount,
      serverOnlineCount: state.serverOnlineCount,
      serverUnresponsiveCount: state.serverUnresponsiveCount,
      serverOfflineCount: state.serverOfflineCount,
      serverPendingRetireCount: state.serverPendingRetireCount,
      serverDiagnosisCount: state.serverDiagnosisCount,
      serverRepeatedOfflineCount: state.serverRepeatedOfflineCount,
    );
  }

  bool _shouldWaitForZeroHashRecovery(MinerIssueDiagnosis? diagnosis) {
    return diagnosis?.code == 'AUTHEN_START_WAIT';
  }

  int _countPendingZeroHashRechecks(
    List<ScanSegmentRecord> segments,
    DateTime scannedAt,
  ) {
    var count = 0;
    for (final segment in segments) {
      for (final miner in segment.miners) {
        final waitUntil = miner.zeroHashWaitUntil;
        if (waitUntil != null &&
            (waitUntil.isBefore(scannedAt) ||
                waitUntil.isAtSameMomentAs(scannedAt))) {
          count += 1;
        }
      }
    }
    return count;
  }

  Future<List<ScanSegmentRecord>> _runDueZeroHashRechecks({
    required List<ScanSegmentRecord> segments,
    required MinerCredential credential,
    required DateTime scannedAt,
  }) async {
    final dueIps = <String>[];
    for (final segment in segments) {
      for (final miner in segment.miners) {
        final waitUntil = miner.zeroHashWaitUntil;
        if (waitUntil != null &&
            (waitUntil.isBefore(scannedAt) ||
                waitUntil.isAtSameMomentAs(scannedAt))) {
          dueIps.add(miner.ip);
        }
      }
    }
    if (dueIps.isEmpty) {
      return segments;
    }

    final refreshedByIp = <String, MinerScanItem>{};
    _resetPostProcessingProgressThrottle(
      stageKey: 'app.scan.finalizing.recheck',
    );
    _emitPostProcessingProgress(
      stageKey: 'app.scan.finalizing.recheck',
      current: 0,
      total: dueIps.length,
      force: true,
    );
    var completed = 0;
    for (final ip in dueIps) {
      final runtime = await _fetchMinerDetailUseCase.getRuntime(
        ip,
        credential,
        collectLog: false,
      );
      refreshedByIp[ip] = MinerScanItem(
        worker: PoolWorker(
          workerName: ip,
          ip: ip,
          status: '',
          lastShareTime: '',
          dailyHashrate: '',
          rejectRate: '',
        ),
        runtime: MinerRuntime(
          ip: runtime.ip,
          onlineStatus: runtime.onlineStatus,
          ghs5s: runtime.ghs5s,
          ghsav: runtime.ghsav,
          ambientTemp: runtime.ambientTemp,
          power: runtime.power,
          chains: runtime.chains,
          fan1: runtime.fan1,
          fan2: runtime.fan2,
          fan3: runtime.fan3,
          fan4: runtime.fan4,
          runningMode: runtime.runningMode,
          logSnippet: '--',
          fetchedAt: runtime.fetchedAt,
        ),
      );
      completed += 1;
      _emitPostProcessingProgress(
        stageKey: 'app.scan.finalizing.recheck',
        current: completed,
        total: dueIps.length,
        force: completed >= dueIps.length,
      );
    }

    return [
      for (final segment in segments)
        segment.copyWith(
          miners: [
            for (final miner in segment.miners)
              _reconcileDueZeroHashRecheck(
                miner,
                refreshedByIp[miner.ip],
                scannedAt,
              ),
          ],
        ),
    ];
  }

  TrackedMiner _reconcileDueZeroHashRecheck(
    TrackedMiner miner,
    MinerScanItem? refreshed,
    DateTime scannedAt,
  ) {
    if (miner.zeroHashWaitUntil == null) {
      return miner;
    }
    if (refreshed == null) {
      final bool wasOffline =
          miner.state == TrackedMinerState.offline ||
          miner.state == TrackedMinerState.pendingRetire;
      return miner.copyWith(
        clearZeroHashWaitUntil: true,
        forcedOfflineAt: scannedAt,
        clearStableOnlineSince: true,
        offlineEventCount: wasOffline
            ? miner.offlineEventCount
            : miner.offlineEventCount + 1,
      );
    }

    final currentGh = HashrateUtils.currentGh(refreshed.runtime.ghs5s);
    if (refreshed.runtime.onlineStatus == MinerRuntimeStatus.online &&
        currentGh > 0 &&
        _hasRecoveredNormalHashrate(refreshed.runtime)) {
      return miner.copyWith(
        lastItem: refreshed,
        lastSeenAt: refreshed.runtime.fetchedAt,
        missedScans: 0,
        clearRefineAttempted: false,
        offlineScanMisses: 0,
        clearOfflineSince: true,
        clearRetiredAt: true,
        stableOnlineSince: scannedAt,
        clearZeroHashWaitUntil: true,
        clearForcedOfflineAt: true,
        clearDiagnosis: true,
      );
    }

    if (refreshed.runtime.onlineStatus == MinerRuntimeStatus.online &&
        currentGh > 0) {
      return miner.copyWith(
        lastItem: refreshed,
        lastSeenAt: refreshed.runtime.fetchedAt,
        missedScans: 0,
        clearRefineAttempted: false,
        offlineScanMisses: 0,
        clearOfflineSince: true,
        clearRetiredAt: true,
        stableOnlineSince: scannedAt,
        clearZeroHashWaitUntil: true,
        clearForcedOfflineAt: true,
        diagnosis: miner.diagnosis,
      );
    }

    return miner.copyWith(
      lastItem: refreshed,
      lastSeenAt: refreshed.runtime.fetchedAt,
      missedScans: 2,
      clearStableOnlineSince: true,
      offlineEventCount:
          miner.state == TrackedMinerState.offline ||
              miner.state == TrackedMinerState.pendingRetire
          ? miner.offlineEventCount
          : miner.offlineEventCount + 1,
      offlineSince: miner.offlineSince ?? scannedAt,
      clearZeroHashWaitUntil: true,
      forcedOfflineAt: scannedAt,
    );
  }

  List<HashrateSample> _appendHashrateSample(
    List<HashrateSample> history,
    HashrateSample next,
  ) {
    if (!_isReasonableHashrateSample(next)) {
      return _sanitizeHashrateHistory(history);
    }
    final cutoff = next.recordedAt.subtract(const Duration(days: 7));
    final updated = [
      ...history
          .where((sample) => sample.recordedAt.isAfter(cutoff))
          .where(_isReasonableHashrateSample),
      next,
    ];
    if (updated.length <= 2000) {
      return updated;
    }
    return updated.sublist(updated.length - 2000);
  }

  List<HashrateSample> _sanitizeHashrateHistory(List<HashrateSample> history) {
    return history.where(_isReasonableHashrateSample).toList(growable: false);
  }

  bool _isReasonableHashrateSample(HashrateSample sample) {
    return sample.totalHashrateGh >= 0 &&
        sample.totalHashrateGh <= _maxReasonableTotalHashrateGh;
  }
}

class _IssueRule {
  const _IssueRule({
    required this.code,
    required this.category,
    required this.priority,
    required this.matches,
    required this.reason,
    required this.solution,
    required this.inspectEarlierForCategories,
  });

  final String code;
  final String category;
  final int priority;
  final List<String> matches;
  final String reason;
  final String solution;
  final List<String> inspectEarlierForCategories;

  factory _IssueRule.fromJson(Map<String, dynamic> json) {
    final rawMatches = json['matches'];
    final matches = rawMatches is List
        ? rawMatches
              .map((entry) => '$entry')
              .where((entry) => entry.trim().isNotEmpty)
              .toList(growable: false)
        : ['${json['match'] ?? ''}'];
    final rawCategories = json['inspectEarlierForCategories'];
    return _IssueRule(
      code:
          '${json['code'] ?? (matches.isNotEmpty ? matches.first : 'UNKNOWN')}',
      category: '${json['category'] ?? 'generic'}',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      matches: matches,
      reason: '${json['reason'] ?? ''}',
      solution: '${json['solution'] ?? ''}',
      inspectEarlierForCategories: rawCategories is List
          ? rawCategories.map((entry) => '$entry').toList(growable: false)
          : const [],
    );
  }
}

class _RuleMatch {
  const _RuleMatch({
    required this.rule,
    required this.start,
    required this.snippet,
  });

  final _IssueRule rule;
  final int start;
  final String snippet;
}

class _FetchBatchResult {
  const _FetchBatchResult({
    required this.items,
    required this.attemptedIps,
    required this.completedCount,
  });

  final List<MinerScanItem> items;
  final Set<String> attemptedIps;
  final int completedCount;
}

class _ManualScanControl {
  bool _paused = false;
  bool _cancelled = false;
  Completer<void>? _resumeCompleter;

  bool get isCancelled => _cancelled;

  void pause() {
    if (_cancelled || _paused) {
      return;
    }
    _paused = true;
    _resumeCompleter = Completer<void>();
  }

  void resume() {
    if (_cancelled || !_paused) {
      return;
    }
    _paused = false;
    _resumeCompleter?.complete();
    _resumeCompleter = null;
  }

  void cancel() {
    _cancelled = true;
    if (_paused) {
      resume();
    }
  }

  Future<bool> waitUntilRunnable() async {
    while (_paused && !_cancelled) {
      final completer = _resumeCompleter;
      if (completer == null) {
        return !_cancelled;
      }
      await completer.future;
    }
    return !_cancelled;
  }
}
