import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/hashrate_utils.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/data/datasources/isar_local_data_source.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/led_toggle_result.dart';
import 'package:volcminer/domain/entities/miner_issue_diagnosis.dart';
import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/entities/miner_scan_item.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';
import 'package:volcminer/domain/entities/pool_worker.dart';
import 'package:volcminer/domain/entities/hashrate_sample.dart';
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

class ScanRunState {
  static const String idle = 'idle';
  static const String running = 'running';
  static const String paused = 'paused';
  static const String cancelling = 'cancelling';
}

class ScanState {
  const ScanState({
    required this.isScanning,
    required this.isPostProcessing,
    required this.scanRunState,
    required this.isManualScanActive,
    required this.isCheckingPool,
    required this.scannedTargets,
    required this.totalTargets,
    required this.items,
    required this.segments,
    required this.knownMinerIpsByScope,
    required this.hashrateHistory,
    required this.ledActiveIps,
    required this.sessions,
    required this.error,
    required this.lastScanAt,
    required this.lastRequest,
    required this.lastPoolCheckAt,
    required this.lastPoolWorkerCount,
    required this.poolCheckError,
  });

  final bool isScanning;
  final bool isPostProcessing;
  final String scanRunState;
  final bool isManualScanActive;
  final bool isCheckingPool;
  final int scannedTargets;
  final int totalTargets;
  final List<MinerScanItem> items;
  final List<ScanSegmentRecord> segments;
  final Map<String, Set<String>> knownMinerIpsByScope;
  final List<HashrateSample> hashrateHistory;
  final Set<String> ledActiveIps;
  final List<ScanSession> sessions;
  final String? error;
  final DateTime? lastScanAt;
  final SearchRequest? lastRequest;
  final DateTime? lastPoolCheckAt;
  final int? lastPoolWorkerCount;
  final String? poolCheckError;

  factory ScanState.initial() => const ScanState(
        isScanning: false,
        isPostProcessing: false,
        scanRunState: ScanRunState.idle,
        isManualScanActive: false,
        isCheckingPool: false,
        scannedTargets: 0,
        totalTargets: 0,
        items: [],
        segments: [],
        knownMinerIpsByScope: {},
        hashrateHistory: [],
        ledActiveIps: {},
        sessions: [],
        error: null,
        lastScanAt: null,
        lastRequest: null,
        lastPoolCheckAt: null,
        lastPoolWorkerCount: null,
        poolCheckError: null,
      );

  ScanState copyWith({
    bool? isScanning,
    bool? isPostProcessing,
    String? scanRunState,
    bool? isManualScanActive,
    bool? isCheckingPool,
    int? scannedTargets,
    int? totalTargets,
    List<MinerScanItem>? items,
    List<ScanSegmentRecord>? segments,
    Map<String, Set<String>>? knownMinerIpsByScope,
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
  }) {
    return ScanState(
      isScanning: isScanning ?? this.isScanning,
      isPostProcessing: isPostProcessing ?? this.isPostProcessing,
      scanRunState: scanRunState ?? this.scanRunState,
      isManualScanActive: isManualScanActive ?? this.isManualScanActive,
      isCheckingPool: isCheckingPool ?? this.isCheckingPool,
      scannedTargets: scannedTargets ?? this.scannedTargets,
      totalTargets: totalTargets ?? this.totalTargets,
      items: items ?? this.items,
      segments: segments ?? this.segments,
      knownMinerIpsByScope: knownMinerIpsByScope ?? this.knownMinerIpsByScope,
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
    );
  }
}

class ScanController extends StateNotifier<ScanState> {
  ScanController(
    this._searchPoolWorkersUseCase,
    this._fetchMinerDetailUseCase,
    this._toggleIndicatorUseCase,
    this._clearRefineUseCase,
    this._rebootMinerUseCase,
    this._applyPoolConfigUseCase,
    this._localDataSource,
  ) : super(ScanState.initial());

  final SearchPoolWorkersUseCase _searchPoolWorkersUseCase;
  final FetchMinerDetailUseCase _fetchMinerDetailUseCase;
  final ToggleIndicatorUseCase _toggleIndicatorUseCase;
  final ClearRefineUseCase _clearRefineUseCase;
  final RebootMinerUseCase _rebootMinerUseCase;
  final ApplyPoolConfigUseCase _applyPoolConfigUseCase;
  final IsarLocalDataSource _localDataSource;

  Timer? _autoRefreshTimer;
  Future<List<_IssueRule>>? _issueRulesFuture;
  _ManualScanControl? _manualScanControl;

  Future<void> loadPersistedState() async {
    final persisted = await _localDataSource.loadScanState();
    if (persisted == null) {
      return;
    }
    state = state.copyWith(
      segments: persisted.segments,
      knownMinerIpsByScope: persisted.knownMinerIpsByScope,
      hashrateHistory: persisted.hashrateHistory,
      ledActiveIps: persisted.ledActiveIps,
      lastScanAt: persisted.lastScanAt,
    );
  }

  ScanState get snapshot => state;

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
    final control = _manualScanControl;
    if (control == null || !state.isManualScanActive || !state.isScanning) {
      return;
    }
    control.cancel();
    state = state.copyWith(scanRunState: ScanRunState.cancelling);
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
        poolCheckError: AppStrings.english(
          'controller.scan.poolCheckFailed',
          params: {'error': '$e'},
        ),
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

  Future<void> refreshMinerIp({
    required String ip,
    required MinerCredential minerCredential,
    int concurrency = 20,
  }) async {
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
      scanRunState: manualControllable ? ScanRunState.running : ScanRunState.idle,
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
      final requestedIps = fetchResult.attemptedIps;
      final clearRefinedIps = await _autoClearRefineForRequestedMisses(
        requestedIps: requestedIps,
        seenItems: items,
        credential: minerCredential,
      );
      final scannedAt = DateTime.now();
      final session = ScanSession(
        id: scannedAt.microsecondsSinceEpoch.toString(),
        scannedAt: scannedAt,
        searchScopes: _buildSearchScopes(request.ips),
        items: items,
        requestedTargetCount: workers.length,
      );
      final nextKnownIndex = updateKnownIndex
          ? _mergeKnownMinerIps(
              state.knownMinerIpsByScope,
              items,
            )
          : state.knownMinerIpsByScope;
      final nextSegments = _mergeSegments(
        existing: state.segments,
        items: items,
        scopes: session.searchScopes,
        requestedIps: requestedIps,
        clearRefinedIps: clearRefinedIps,
        scannedAt: scannedAt,
        diagnoses: diagnoses,
      );
      final totalHashrateGh = items
          .where((item) => item.runtime.onlineStatus == MinerRuntimeStatus.online)
          .fold<double>(
            0,
            (sum, item) =>
                sum + HashrateUtils.effectiveGh(item.runtime.ghs5s, item.runtime.ghsav),
          );
      final nextHashrateHistory = _appendHashrateSample(
        state.hashrateHistory,
        HashrateSample(
          recordedAt: scannedAt,
          totalHashrateGh: totalHashrateGh,
        ),
      );

      state = state.copyWith(
        isScanning: false,
        isPostProcessing: false,
        scanRunState: ScanRunState.idle,
        isManualScanActive: false,
        scannedTargets: fetchResult.completedCount,
        totalTargets: workers.length,
        items: items,
        segments: nextSegments,
        knownMinerIpsByScope: nextKnownIndex,
        hashrateHistory: nextHashrateHistory,
        sessions: [session, ...state.sessions],
        lastScanAt: scannedAt,
      );
      await _localDataSource.saveSnapshot(items);
      await _persistState(scannedAt: scannedAt);
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        isPostProcessing: false,
        scanRunState: ScanRunState.idle,
        isManualScanActive: false,
        error: AppStrings.english(
          'controller.scan.scanFailed',
          params: {'error': '$e'},
        ),
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
  ) {
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
    List<PoolSlotConfig> poolSlots,
    Map<int, String> slotPasswords,
    MinerCredential credential,
  ) {
    return _applyPoolConfigUseCase.execute(
      ips,
      poolSlots,
      slotPasswords,
      credential,
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
      if (state.isScanning) {
        return;
      }
      unawaited(onTick());
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
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
    state = state.copyWith(scannedTargets: 0, totalTargets: workers.length);

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
        state = state.copyWith(
          scannedTargets: scanned,
          totalTargets: workers.length,
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
                fan1: runtime.fan1,
                fan2: runtime.fan2,
                fan3: runtime.fan3,
                fan4: runtime.fan4,
                runningMode: runtime.runningMode,
                logSnippet: '--',
                fetchedAt: runtime.fetchedAt,
              );
        results[current] = MinerScanItem(worker: poolWorker, runtime: normalized);
      }
    }

    final loops = List.generate(
      concurrency < workers.length ? concurrency : workers.length,
      (_) => workerLoop(),
    );
    await Future.wait(loops);

    final items = results
        .whereType<MinerScanItem>()
        .where(
          (item) =>
              item.runtime.onlineStatus != MinerRuntimeStatus.notMiner &&
              item.runtime.onlineStatus != MinerRuntimeStatus.timeout,
        )
        .toList(growable: false)
      ..sort(
        (a, b) =>
            IpUtils.ipToInt(a.worker.ip).compareTo(IpUtils.ipToInt(b.worker.ip)),
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
              HashrateUtils.effectiveGh(item.runtime.ghs5s, item.runtime.ghsav) <= 0,
        )
        .toList(growable: false);
    if (targets.isEmpty) {
      return const {};
    }

    final rules = await _loadIssueRules();
    final diagnoses = <String, MinerIssueDiagnosis>{};
    var index = 0;
    final limit = targets.length < 8 ? targets.length : 8;

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
    final primaryMatch = _findFirstRuleMatch(normalizedLog, rules);
    if (primaryMatch != null) {
      final primaryRule = primaryMatch.rule;
      if (primaryRule.inspectEarlierForCategories.isNotEmpty) {
        final earlierLog = normalizedLog.substring(0, primaryMatch.start);
        final rootCauseMatch = _findFirstRuleMatch(
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
      solution: 'Inspect the miner log, fan speed, temperature, and pool status.',
      logSnippet: _trimSnippet(normalizedLog),
      detectedAt: DateTime.now(),
    );
  }

  String _trimSnippet(String value) {
    final normalized = value.replaceAll('\r', '').trim();
    if (normalized.length <= 240) {
      return normalized;
    }
    return '${normalized.substring(0, 240)}...';
  }

  _RuleMatch? _findFirstRuleMatch(String log, Iterable<_IssueRule> rules) {
    final normalized = log.replaceAll('\r', '');
    final lines = normalized.split('\n');
    for (var lineIndex = lines.length - 1; lineIndex >= 0; lineIndex--) {
      final line = lines[lineIndex];
      final lowerLine = line.toLowerCase();
      for (final rule in rules) {
        for (final matcher in rule.matches) {
          if (lowerLine.contains(matcher.toLowerCase())) {
            final start = lineIndex - 6 < 0 ? 0 : lineIndex - 6;
            final end = lineIndex + 3 >= lines.length ? lines.length - 1 : lineIndex + 3;
            return _RuleMatch(
              rule: rule,
              start: normalized.indexOf(line),
              snippet: lines.sublist(start, end + 1).join('\n').trim(),
            );
          }
        }
      }
    }
    return null;
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
      final miners = onlineByScope.putIfAbsent(scope, () => <String, MinerScanItem>{});
      miners[item.worker.ip] = item;
    }

    for (final scope in scopes) {
      final existingSegment = segmentMap[scope];
      final existingMiners = {
        for (final miner in existingSegment?.miners ?? const <TrackedMiner>[])
          miner.ip: miner,
      };
      final seenMiners = onlineByScope[scope] ?? const <String, MinerScanItem>{};
      final merged = <TrackedMiner>[];

      for (final entry in existingMiners.entries) {
        final current = seenMiners[entry.key];
        if (current != null) {
          final diagnosis = diagnoses[entry.key];
          merged.add(
            entry.value.copyWith(
              lastItem: current,
              lastSeenAt: scannedAt,
              missedScans: 0,
              clearRefineAttempted: false,
              offlineScanMisses: 0,
              clearOfflineSince: true,
              clearRetiredAt: true,
              diagnosis: diagnosis,
              clearDiagnosis: diagnosis == null,
            ),
          );
        } else if (requestedIps.contains(entry.key)) {
          final updated = _advanceMissingMinerState(
            entry.value,
            scannedAt,
            clearRefinedIps.contains(entry.key),
          );
          merged.add(
            updated,
          );
        } else {
          merged.add(entry.value);
        }
      }

      for (final entry in seenMiners.entries) {
        if (existingMiners.containsKey(entry.key)) {
          continue;
        }
        merged.add(
          TrackedMiner(
            ip: entry.key,
            lastItem: entry.value,
            lastSeenAt: scannedAt,
            missedScans: 0,
            clearRefineAttempted: false,
            offlineScanMisses: 0,
            diagnosis: diagnoses[entry.key],
          ),
        );
      }

      merged.sort((a, b) => IpUtils.ipToInt(a.ip).compareTo(IpUtils.ipToInt(b.ip)));
      segmentMap[scope] = ScanSegmentRecord(
        scope: scope,
        updatedAt: scannedAt,
        miners: merged,
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

  Future<Set<String>> _autoClearRefineForRequestedMisses({
    required Set<String> requestedIps,
    required List<MinerScanItem> seenItems,
    required MinerCredential credential,
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
            miner.missedScans == 0 ||
            (miner.missedScans == 1 && !miner.clearRefineAttempted);
        if (shouldClear) {
          targets.add(miner.ip);
        }
      }
    }
    if (targets.isEmpty) {
      return const <String>{};
    }

    final result = await _clearRefineUseCase.execute(targets, credential);
    return result.success ? result.targets.toSet() : const <String>{};
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
        clearRefineAttempted: clearRefineTriggered || miner.clearRefineAttempted,
      );
    }

    if (miner.missedScans == 1) {
      if (miner.clearRefineAttempted || clearRefineTriggered) {
        return miner.copyWith(
          missedScans: 2,
          clearRefineAttempted: true,
          offlineSince: miner.offlineSince ?? scannedAt,
          offlineScanMisses: 0,
        );
      }
      return miner.copyWith(
        missedScans: 1,
        clearRefineAttempted: clearRefineTriggered,
      );
    }

    final offlineSince = miner.offlineSince ?? scannedAt;
    final offlineScanMisses = miner.offlineScanMisses + 1;
    final shouldRetire =
        scannedAt.difference(offlineSince) >= const Duration(hours: 1) &&
        offlineScanMisses >= 2;

    return miner.copyWith(
      missedScans: miner.missedScans + 1,
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
      hashrateHistory: state.hashrateHistory,
      lastScanAt: scannedAt,
    );
  }

  List<HashrateSample> _appendHashrateSample(
    List<HashrateSample> history,
    HashrateSample next,
  ) {
    final cutoff = next.recordedAt.subtract(const Duration(days: 7));
    final updated = [
      ...history.where((sample) => sample.recordedAt.isAfter(cutoff)),
      next,
    ];
    if (updated.length <= 2000) {
      return updated;
    }
    return updated.sublist(updated.length - 2000);
  }
}

class _IssueRule {
  const _IssueRule({
    required this.code,
    required this.category,
    required this.matches,
    required this.reason,
    required this.solution,
    required this.inspectEarlierForCategories,
  });

  final String code;
  final String category;
  final List<String> matches;
  final String reason;
  final String solution;
  final List<String> inspectEarlierForCategories;

  factory _IssueRule.fromJson(Map<String, dynamic> json) {
    final rawMatches = json['matches'];
    final matches = rawMatches is List
        ? rawMatches.map((entry) => '$entry').where((entry) => entry.trim().isNotEmpty).toList(growable: false)
        : ['${json['match'] ?? ''}'];
    final rawCategories = json['inspectEarlierForCategories'];
    return _IssueRule(
      code: '${json['code'] ?? (matches.isNotEmpty ? matches.first : 'UNKNOWN')}',
      category: '${json['category'] ?? 'generic'}',
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
