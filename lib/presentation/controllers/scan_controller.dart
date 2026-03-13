import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/data/datasources/isar_local_data_source.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/led_toggle_result.dart';
import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/entities/miner_scan_item.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';
import 'package:volcminer/domain/entities/pool_worker.dart';
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

class ScanState {
  const ScanState({
    required this.isScanning,
    required this.isCheckingPool,
    required this.scannedTargets,
    required this.totalTargets,
    required this.items,
    required this.segments,
    required this.sessions,
    required this.error,
    required this.lastScanAt,
    required this.lastRequest,
    required this.lastPoolCheckAt,
    required this.lastPoolWorkerCount,
    required this.poolCheckError,
  });

  final bool isScanning;
  final bool isCheckingPool;
  final int scannedTargets;
  final int totalTargets;
  final List<MinerScanItem> items;
  final List<ScanSegmentRecord> segments;
  final List<ScanSession> sessions;
  final String? error;
  final DateTime? lastScanAt;
  final SearchRequest? lastRequest;
  final DateTime? lastPoolCheckAt;
  final int? lastPoolWorkerCount;
  final String? poolCheckError;

  factory ScanState.initial() => const ScanState(
    isScanning: false,
    isCheckingPool: false,
    scannedTargets: 0,
    totalTargets: 0,
    items: [],
    segments: [],
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
    bool? isCheckingPool,
    int? scannedTargets,
    int? totalTargets,
    List<MinerScanItem>? items,
    List<ScanSegmentRecord>? segments,
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
      isCheckingPool: isCheckingPool ?? this.isCheckingPool,
      scannedTargets: scannedTargets ?? this.scannedTargets,
      totalTargets: totalTargets ?? this.totalTargets,
      items: items ?? this.items,
      segments: segments ?? this.segments,
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
        poolCheckError: 'Pool check failed: $e',
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

    state = state.copyWith(
      isScanning: true,
      scannedTargets: 0,
      totalTargets: 0,
      clearError: true,
      lastRequest: request,
    );
    try {
      List<PoolWorker> workers;
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
            .toList();
      }
      workers = _dedupeWorkersByIp(workers);

      final items = await _fetchAllMinerDetails(
        workers,
        minerCredential,
        collectLogs: collectLogs,
        concurrency: concurrency,
      );
      final scannedAt = DateTime.now();
      final session = ScanSession(
        id: scannedAt.microsecondsSinceEpoch.toString(),
        scannedAt: scannedAt,
        searchScopes: _buildSearchScopes(request.ips),
        items: items,
        requestedTargetCount: workers.length,
      );

      state = state.copyWith(
        isScanning: false,
        scannedTargets: workers.length,
        totalTargets: workers.length,
        items: items,
        segments: _mergeSegments(
          existing: state.segments,
          items: items,
          scopes: session.searchScopes,
          scannedAt: scannedAt,
        ),
        sessions: [session, ...state.sessions],
        lastScanAt: scannedAt,
      );
      await _localDataSource.saveSnapshot(items);
    } catch (e) {
      state = state.copyWith(isScanning: false, error: 'Scan failed: $e');
    }
  }

  Future<LedToggleResult> toggleLedForIp(
    String ip,
    bool on,
    MinerCredential credential,
  ) {
    return _toggleIndicatorUseCase.execute([ip], on, credential);
  }

  Future<LedToggleResult> toggleLedForIps(
    List<String> ips,
    bool on,
    MinerCredential credential,
  ) {
    return _toggleIndicatorUseCase.execute(ips, on, credential);
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
    state = state.copyWith(segments: segments);
  }

  void setupAutoRefresh({
    required bool enabled,
    required int intervalSeconds,
    required List<ScanView> selectedViews,
    required String accountUsername,
    required String accountPassword,
    required MinerCredential minerCredential,
    required bool collectLogs,
    required ScanTargetMode targetMode,
    required int concurrency,
  }) {
    _autoRefreshTimer?.cancel();
    if (!enabled) {
      return;
    }
    _autoRefreshTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      if (state.isScanning) {
        return;
      }
      unawaited(
        startScan(
          selectedViews: selectedViews,
          accountUsername: accountUsername,
          accountPassword: accountPassword,
          minerCredential: minerCredential,
          collectLogs: collectLogs,
          targetMode: targetMode,
          concurrency: concurrency,
        ),
      );
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
      onError('Please select at least one scan view.');
      return null;
    }

    final ips = targetMode == ScanTargetMode.known
        ? _buildKnownIpTargets(selectedViews)
        : _buildFullIpTargets(selectedViews);
    if (ips.isEmpty) {
      onError(
        targetMode == ScanTargetMode.known
            ? 'Selected IP blocks do not have known miners yet.'
            : 'Selected views do not contain valid IP ranges.',
      );
      return null;
    }

    return SearchRequest(
      ips: ips.toList()..sort(),
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
    for (final segment in state.segments) {
      if (!scopes.contains(segment.scope)) {
        continue;
      }
      for (final miner in segment.miners) {
        ips.add(miner.ip);
      }
    }
    return ips;
  }

  Future<List<MinerScanItem>> _fetchAllMinerDetails(
    List<PoolWorker> workers,
    MinerCredential credential, {
    required bool collectLogs,
    int concurrency = 20,
  }) async {
    if (workers.isEmpty) {
      return const [];
    }
    state = state.copyWith(scannedTargets: 0, totalTargets: workers.length);

    final results = List<MinerScanItem?>.filled(workers.length, null);
    var index = 0;
    var scanned = 0;

    Future<void> workerLoop() async {
      while (true) {
        final current = index;
        if (current >= workers.length) {
          return;
        }
        index += 1;

        final poolWorker = workers[current];
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

    final visible =
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
    return visible;
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
      ..sort((a, b) {
        final left = a.split('.');
        final right = b.split('.');
        final first = int.parse(left[0]).compareTo(int.parse(right[0]));
        if (first != 0) {
          return first;
        }
        return int.parse(left[1]).compareTo(int.parse(right[1]));
      });
    return sorted;
  }

  List<ScanSegmentRecord> _mergeSegments({
    required List<ScanSegmentRecord> existing,
    required List<MinerScanItem> items,
    required List<String> scopes,
    required DateTime scannedAt,
  }) {
    final segmentMap = {
      for (final segment in existing) segment.scope: segment,
    };
    final onlineByScope = <String, Map<String, MinerScanItem>>{};

    for (final item in items) {
      if (item.runtime.onlineStatus != MinerRuntimeStatus.online) {
        continue;
      }
      final scope = _scopeOfIp(item.worker.ip);
      final miners = onlineByScope.putIfAbsent(scope, () => {});
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
          merged.add(
            entry.value.copyWith(
              lastItem: current,
              lastSeenAt: scannedAt,
              missedScans: 0,
            ),
          );
        } else {
          merged.add(
            entry.value.copyWith(missedScans: entry.value.missedScans + 1),
          );
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

    final segments = segmentMap.values.toList(growable: false)
      ..sort((a, b) => a.scope.compareTo(b.scope));
    return segments;
  }

  String _scopeOfIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) {
      return ip;
    }
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }
}
