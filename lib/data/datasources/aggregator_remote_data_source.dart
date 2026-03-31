import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:volcminer/core/utils/volcminer_chain_parser.dart';
import 'package:volcminer/domain/entities/scan_view.dart';
import 'package:volcminer/domain/entities/led_toggle_result.dart';

class AggregatorServerTask {
  const AggregatorServerTask({
    required this.scanState,
    required this.progress,
    required this.matchedCount,
    required this.failedCount,
    required this.nonMinerCount,
    required this.totalTargets,
    required this.lastScanStartedAt,
    required this.lastScanFinishedAt,
    required this.nextScheduledAt,
    required this.warningReason,
    required this.isManualTask,
  });

  final String scanState;
  final double progress;
  final int matchedCount;
  final int failedCount;
  final int nonMinerCount;
  final int totalTargets;
  final DateTime? lastScanStartedAt;
  final DateTime? lastScanFinishedAt;
  final DateTime? nextScheduledAt;
  final String? warningReason;
  final bool isManualTask;

  bool get isActive =>
      scanState == 'running' ||
      scanState == 'waiting' ||
      scanState == 'waiting-stop' ||
      scanState == 'queued';

  bool get shouldDriveManualUi => isManualTask && isActive;
}

class AggregatorServerMiner {
  const AggregatorServerMiner({
    required this.id,
    required this.name,
    required this.ip,
    required this.segment,
    required this.lifecycle,
    required this.status,
    required this.online,
    required this.hashrateRtMh,
    required this.hashrateAvgMh,
    required this.maxTemperatureC,
    required this.averageFanRpm,
    required this.ambientTempC,
    required this.runningMode,
    required this.lastSeenAt,
    required this.chains,
    required this.alertCount,
    required this.diagnosis,
    required this.abnormalGroup,
    required this.abnormalType,
    required this.isRepeatedOffline,
    required this.repeatedOfflineMarkedAt,
  });

  final String id;
  final String name;
  final String ip;
  final String segment;
  final String? lifecycle;
  final String status;
  final bool online;
  final double hashrateRtMh;
  final double hashrateAvgMh;
  final double? maxTemperatureC;
  final double? averageFanRpm;
  final double? ambientTempC;
  final String? runningMode;
  final DateTime? lastSeenAt;
  final List<AggregatorServerMinerChain> chains;
  final int alertCount;
  final AggregatorServerDiagnosis? diagnosis;
  final String? abnormalGroup;
  final String? abnormalType;
  final bool isRepeatedOffline;
  final DateTime? repeatedOfflineMarkedAt;
}

class AggregatorServerMinerChain {
  const AggregatorServerMinerChain({
    required this.index,
    required this.chainRateMh,
    required this.tempC,
    required this.freq,
    required this.hw,
    required this.chainAcn,
    required this.chainAcs,
  });

  final int index;
  final double chainRateMh;
  final double? tempC;
  final String freq;
  final String hw;
  final String chainAcn;
  final String chainAcs;
}

class AggregatorServerDiagnosis {
  const AggregatorServerDiagnosis({
    required this.code,
    required this.category,
    required this.reason,
    required this.solution,
    required this.logSnippet,
    required this.detectedAt,
    required this.secondaryCode,
    required this.secondaryReason,
  });

  final String code;
  final String category;
  final String reason;
  final String solution;
  final String logSnippet;
  final DateTime? detectedAt;
  final String? secondaryCode;
  final String? secondaryReason;
}

class AggregatorKnownMiner {
  const AggregatorKnownMiner({
    required this.id,
    required this.ip,
    required this.name,
  });

  final String id;
  final String ip;
  final String name;
}

class AggregatorServerSnapshot {
  const AggregatorServerSnapshot({
    required this.generatedAt,
    required this.nextScheduledAt,
    required this.nextGlobalScanAt,
    required this.nextScheduledIsGlobalAllViews,
    required this.task,
    required this.miners,
    required this.knownMiners,
    required this.minerCount,
    required this.onlineCount,
    required this.unresponsiveCount,
    required this.offlineCount,
    required this.pendingRetireCount,
    required this.diagnosisCount,
    required this.repeatedOfflineCount,
  });

  final DateTime? generatedAt;
  final DateTime? nextScheduledAt;
  final DateTime? nextGlobalScanAt;
  final bool nextScheduledIsGlobalAllViews;
  final AggregatorServerTask? task;
  final List<AggregatorServerMiner> miners;
  final List<AggregatorKnownMiner> knownMiners;
  final int minerCount;
  final int onlineCount;
  final int unresponsiveCount;
  final int offlineCount;
  final int pendingRetireCount;
  final int diagnosisCount;
  final int repeatedOfflineCount;
}

class AggregatorDashboardSummary {
  const AggregatorDashboardSummary({
    required this.generatedAt,
    required this.nextScheduledAt,
    required this.nextGlobalScanAt,
    required this.currentTask,
    required this.latestScheduledTask,
    required this.minerCount,
    required this.onlineCount,
    required this.unresponsiveCount,
    required this.offlineCount,
    required this.pendingRetireCount,
    required this.diagnosisCount,
    required this.repeatedOfflineCount,
  });

  final DateTime? generatedAt;
  final DateTime? nextScheduledAt;
  final DateTime? nextGlobalScanAt;
  final AggregatorServerTask? currentTask;
  final AggregatorServerTask? latestScheduledTask;
  final int minerCount;
  final int onlineCount;
  final int unresponsiveCount;
  final int offlineCount;
  final int pendingRetireCount;
  final int diagnosisCount;
  final int repeatedOfflineCount;
}

class _SnapshotDerivedCounts {
  const _SnapshotDerivedCounts({
    required this.onlineCount,
    required this.unresponsiveCount,
    required this.offlineCount,
    required this.pendingRetireCount,
    required this.diagnosisCount,
    required this.repeatedOfflineCount,
  });

  final int onlineCount;
  final int unresponsiveCount;
  final int offlineCount;
  final int pendingRetireCount;
  final int diagnosisCount;
  final int repeatedOfflineCount;
}

class AggregatorRepeatedOfflineSegment {
  const AggregatorRepeatedOfflineSegment({
    required this.segment,
    required this.minerCount,
  });

  final String segment;
  final int minerCount;
}

class AggregatorRepeatedOfflineSummary {
  const AggregatorRepeatedOfflineSummary({
    required this.generatedAt,
    required this.repeatedOfflineCount,
    required this.segments,
  });

  final DateTime? generatedAt;
  final int repeatedOfflineCount;
  final List<AggregatorRepeatedOfflineSegment> segments;
}

class AggregatorRepeatedOfflineSegmentDetails {
  const AggregatorRepeatedOfflineSegmentDetails({
    required this.generatedAt,
    required this.segment,
    required this.minerCount,
    required this.miners,
  });

  final DateTime? generatedAt;
  final String segment;
  final int minerCount;
  final List<AggregatorServerMiner> miners;
}

class AggregatorRefreshedMinerSnapshot {
  const AggregatorRefreshedMinerSnapshot({
    required this.generatedAt,
    required this.miner,
  });

  final DateTime? generatedAt;
  final AggregatorServerMiner miner;
}

class AggregatorBatchCommandResult {
  const AggregatorBatchCommandResult({
    required this.success,
    required this.message,
    required this.targets,
  });

  final bool success;
  final String message;
  final List<String> targets;

  LedToggleResult toLedToggleResult() =>
      LedToggleResult(success: success, message: message, targets: targets);
}

class AggregatorRemoteDataSource {
  AggregatorRemoteDataSource(this._client);

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxRequestAttempts = 2;

  Future<AggregatorServerSnapshot> loadSnapshot(String baseUrl) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    final Map<String, dynamic>? unifiedPayload = await _tryGetJson(
      '$normalizedBaseUrl/api/system/snapshot',
    );
    if (unifiedPayload != null) {
      final unifiedSnapshot = _decodeSnapshotPayload(unifiedPayload);
      if (!_shouldFallbackToLegacySnapshot(unifiedSnapshot)) {
        return unifiedSnapshot;
      }
    }

    final Map<String, dynamic> dashboard = await _getJson(
      '$normalizedBaseUrl/api/dashboard/summary',
    );
    final responses = await Future.wait([
      _tryGetJson('$normalizedBaseUrl/api/miners'),
      _tryGetJson('$normalizedBaseUrl/api/known-miners'),
      _tryGetJson('$normalizedBaseUrl/api/system/scheduler'),
    ]);

    final Map<String, dynamic> minersPayload =
        responses[0] ?? const <String, dynamic>{};
    final Map<String, dynamic> knownPayload =
        responses[1] ?? const <String, dynamic>{};
    final Map<String, dynamic> schedulerPayload =
        responses[2] ?? const <String, dynamic>{};

    return _buildSnapshot(
      dashboard: dashboard,
      minersPayload: minersPayload,
      knownPayload: knownPayload,
      schedulerPayload: schedulerPayload,
    );
  }

  Future<AggregatorDashboardSummary> loadDashboardSummary(String baseUrl) async {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    final Map<String, dynamic> payload = await _getJson(
      '$normalizedBaseUrl/api/dashboard/summary',
    );
    final Map<String, dynamic>? currentTaskMap = payload['currentTask'] is Map
        ? Map<String, dynamic>.from(payload['currentTask'] as Map)
        : null;
    final Map<String, dynamic>? latestScheduledTaskMap =
        payload['latestScheduledTask'] is Map
        ? Map<String, dynamic>.from(payload['latestScheduledTask'] as Map)
        : null;
    final AggregatorServerTask? currentTask =
        currentTaskMap == null ? null : _decodeTask(currentTaskMap, payload);
    final AggregatorServerTask? latestScheduledTask = latestScheduledTaskMap == null
        ? null
        : _decodeTask(latestScheduledTaskMap, payload);

    return AggregatorDashboardSummary(
      generatedAt: _parseDate(payload['generatedAt']),
      nextScheduledAt: currentTask?.nextScheduledAt ?? latestScheduledTask?.nextScheduledAt,
      nextGlobalScanAt: _parseDate(payload['nextGlobalScanAt']),
      currentTask: currentTask,
      latestScheduledTask: latestScheduledTask,
      minerCount: _resolveCount(payload['minerCount'], 0),
      onlineCount: _resolveCount(payload['onlineCount'], 0),
      unresponsiveCount: _resolveCount(payload['unresponsiveCount'], 0),
      offlineCount: _resolveCount(payload['offlineCount'], 0),
      pendingRetireCount: _resolveCount(payload['pendingRetireCount'], 0),
      diagnosisCount: _resolveCount(payload['diagnosisCount'], 0),
      repeatedOfflineCount: _resolveCount(payload['repeatedOfflineCount'], 0),
    );
  }

  AggregatorServerSnapshot _decodeSnapshotPayload(
    Map<String, dynamic> payload,
  ) {
    final Map<String, dynamic> dashboard = payload['dashboard'] is Map
        ? Map<String, dynamic>.from(payload['dashboard'] as Map)
        : const <String, dynamic>{};
    final Map<String, dynamic> schedulerPayload = payload['scheduler'] is Map
        ? Map<String, dynamic>.from(payload['scheduler'] as Map)
        : const <String, dynamic>{};
    return _buildSnapshot(
      dashboard: dashboard,
      minersPayload: payload,
      knownPayload: payload,
      schedulerPayload: schedulerPayload,
    );
  }

  AggregatorServerSnapshot _buildSnapshot({
    required Map<String, dynamic> dashboard,
    required Map<String, dynamic> minersPayload,
    required Map<String, dynamic> knownPayload,
    required Map<String, dynamic> schedulerPayload,
  }) {
    final List<AggregatorServerMiner> miners =
        ((minersPayload['miners'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (dynamic raw) =>
                  _decodeMiner(Map<String, dynamic>.from(raw as Map)),
            )
            .where((AggregatorServerMiner miner) => miner.ip.isNotEmpty)
            .toList(growable: false);

    final List<AggregatorKnownMiner> knownMiners =
        ((knownPayload['knownMiners'] as List?) ??
                (knownPayload['miners'] as List?) ??
                const <dynamic>[])
            .whereType<Map>()
            .map(
              (dynamic raw) =>
                  _decodeKnownMiner(Map<String, dynamic>.from(raw as Map)),
            )
            .where((AggregatorKnownMiner miner) => miner.ip.isNotEmpty)
            .toList(growable: false);

    final Map<String, dynamic>? manualTaskMap = dashboard['currentTask'] is Map
        ? Map<String, dynamic>.from(dashboard['currentTask'] as Map)
        : null;
    final Map<String, dynamic>? latestScheduledTaskMap =
        dashboard['latestScheduledTask'] is Map
        ? Map<String, dynamic>.from(dashboard['latestScheduledTask'] as Map)
        : (schedulerPayload['latestScheduledTask'] is Map
              ? Map<String, dynamic>.from(
                  schedulerPayload['latestScheduledTask'] as Map,
                )
              : null);
    final Map<String, dynamic>? taskMap =
        (_isActiveTaskMap(manualTaskMap) ? manualTaskMap : null) ??
        latestScheduledTaskMap ??
        (schedulerPayload['scanState'] == null ? null : schedulerPayload);
    final int? scheduledCycleIndex =
        (schedulerPayload['scheduledCycleIndex'] as num?)?.toInt();
    final int? scheduledCycleLength =
        (schedulerPayload['scheduledCycleLength'] as num?)?.toInt();
    final bool nextScheduledIsGlobalAllViews =
        scheduledCycleIndex != null &&
        scheduledCycleLength != null &&
        scheduledCycleLength > 0 &&
        scheduledCycleIndex >= scheduledCycleLength - 1;
    final _SnapshotDerivedCounts derivedCounts = _deriveSnapshotCounts(miners);

    return AggregatorServerSnapshot(
      generatedAt: _parseDate(
        minersPayload['generatedAt'] ?? dashboard['generatedAt'],
      ),
      nextScheduledAt: _parseDate(schedulerPayload['nextScheduledAt']),
      nextGlobalScanAt: _parseDate(
        dashboard['nextGlobalScanAt'] ?? schedulerPayload['nextGlobalScanAt'],
      ),
      nextScheduledIsGlobalAllViews: nextScheduledIsGlobalAllViews,
      task: taskMap == null ? null : _decodeTask(taskMap, schedulerPayload),
      miners: miners,
      knownMiners: knownMiners,
      minerCount: _resolveCount(
        dashboard['minerCount'],
        miners.length,
      ),
      onlineCount: _resolveCount(
        dashboard['onlineCount'],
        derivedCounts.onlineCount,
      ),
      unresponsiveCount: _resolveCount(
        dashboard['unresponsiveCount'],
        derivedCounts.unresponsiveCount,
      ),
      offlineCount: _resolveCount(
        dashboard['offlineCount'],
        derivedCounts.offlineCount,
      ),
      pendingRetireCount:
          _resolveCount(
            dashboard['pendingRetireCount'],
            derivedCounts.pendingRetireCount,
          ),
      diagnosisCount: _resolveCount(
        dashboard['diagnosisCount'],
        derivedCounts.diagnosisCount,
      ),
      repeatedOfflineCount:
          _resolveCount(
            dashboard['repeatedOfflineCount'],
            derivedCounts.repeatedOfflineCount,
          ),
    );
  }

  bool _shouldFallbackToLegacySnapshot(AggregatorServerSnapshot snapshot) {
    return snapshot.generatedAt == null && snapshot.miners.isEmpty;
  }

  int _resolveCount(dynamic rawValue, int fallback) {
    final int? parsed = (rawValue as num?)?.toInt();
    if (parsed == null) {
      return fallback;
    }
    if (parsed == 0 && fallback > 0) {
      return fallback;
    }
    return parsed;
  }

  _SnapshotDerivedCounts _deriveSnapshotCounts(
    List<AggregatorServerMiner> miners,
  ) {
    var onlineCount = 0;
    var unresponsiveCount = 0;
    var offlineCount = 0;
    var pendingRetireCount = 0;
    var diagnosisCount = 0;
    var repeatedOfflineCount = 0;

    for (final miner in miners) {
      final status = miner.status.trim().toLowerCase();
      final lifecycle = (miner.lifecycle ?? '').trim().toLowerCase();
      if (miner.online) {
        onlineCount += 1;
      } else if (status == 'unresponsive' || lifecycle == 'unresponsive') {
        unresponsiveCount += 1;
      } else if (status == 'pending-retire' || lifecycle == 'pending-retire') {
        pendingRetireCount += 1;
      } else if (status == 'offline' || lifecycle == 'offline' || !miner.online) {
        offlineCount += 1;
      }

      if (miner.diagnosis != null) {
        diagnosisCount += 1;
      }
      if (miner.isRepeatedOffline) {
        repeatedOfflineCount += 1;
      }
    }

    return _SnapshotDerivedCounts(
      onlineCount: onlineCount,
      unresponsiveCount: unresponsiveCount,
      offlineCount: offlineCount,
      pendingRetireCount: pendingRetireCount,
      diagnosisCount: diagnosisCount,
      repeatedOfflineCount: repeatedOfflineCount,
    );
  }

  Future<List<ScanView>> loadScanViews(String baseUrl) async {
    final Map<String, dynamic> payload = await _getJson(
      '${_normalizeBaseUrl(baseUrl)}/api/settings',
    );
    final List<dynamic> rawViews =
        (payload['scanViews'] as List?) ?? const <dynamic>[];
    return rawViews
        .whereType<Map>()
        .map(
          (dynamic raw) =>
              _decodeScanView(Map<String, dynamic>.from(raw as Map)),
        )
        .where((ScanView view) => view.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<List<ScanView>> saveScanViews(
    String baseUrl,
    List<ScanView> views,
  ) async {
    final Map<String, dynamic> payload = await _putJson(
      Uri.parse('${_normalizeBaseUrl(baseUrl)}/api/settings'),
      <String, dynamic>{
        'scanViews': views.map(_encodeScanView).toList(growable: false),
      },
    );
    final List<dynamic> rawViews =
        (payload['scanViews'] as List?) ?? const <dynamic>[];
    return rawViews
        .whereType<Map>()
        .map(
          (dynamic raw) =>
              _decodeScanView(Map<String, dynamic>.from(raw as Map)),
        )
        .where((ScanView view) => view.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<AggregatorRepeatedOfflineSummary> loadRepeatedOfflineSummary(
    String baseUrl,
  ) async {
    final Map<String, dynamic> payload = await _getJson(
      '${_normalizeBaseUrl(baseUrl)}/api/repeated-offline',
    );
    final List<AggregatorRepeatedOfflineSegment> segments =
        ((payload['segments'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (dynamic raw) => AggregatorRepeatedOfflineSegment(
                segment: (raw['segment'] ?? '').toString(),
                minerCount: (raw['minerCount'] as num?)?.toInt() ?? 0,
              ),
            )
            .where(
              (AggregatorRepeatedOfflineSegment item) =>
                  item.segment.isNotEmpty,
            )
            .toList(growable: false);
    return AggregatorRepeatedOfflineSummary(
      generatedAt: _parseDate(payload['generatedAt']),
      repeatedOfflineCount:
          (payload['repeatedOfflineCount'] as num?)?.toInt() ?? 0,
      segments: segments,
    );
  }

  Future<AggregatorRepeatedOfflineSegmentDetails> loadRepeatedOfflineSegment(
    String baseUrl,
    String segment,
  ) async {
    final Map<String, dynamic> payload = await _getJson(
      '${_normalizeBaseUrl(baseUrl)}/api/repeated-offline/segments/${Uri.encodeComponent(segment)}/miners',
    );
    final List<AggregatorServerMiner> miners =
        ((payload['miners'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (dynamic raw) =>
                  _decodeMiner(Map<String, dynamic>.from(raw as Map)),
            )
            .where((AggregatorServerMiner miner) => miner.ip.isNotEmpty)
            .toList(growable: false);
    return AggregatorRepeatedOfflineSegmentDetails(
      generatedAt: _parseDate(payload['generatedAt']),
      segment: (payload['segment'] ?? segment).toString(),
      minerCount: (payload['minerCount'] as num?)?.toInt() ?? miners.length,
      miners: miners,
    );
  }

  Future<void> startScan(
    String baseUrl, {
    required String mode,
    required List<Map<String, dynamic>> scanViews,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{'mode': mode};
    if (scanViews.isNotEmpty) {
      body['scanViews'] = scanViews;
    }
    await _sendJson(
      Uri.parse('${_normalizeBaseUrl(baseUrl)}/api/scan/start'),
      body,
    );
  }

  Future<void> stopScan(String baseUrl) async {
    await _sendJson(
      Uri.parse('${_normalizeBaseUrl(baseUrl)}/api/scan/stop'),
      const <String, dynamic>{},
    );
  }

  Future<void> deleteKnownMiner(String baseUrl, String knownMinerId) async {
    final response = await _client
        .delete(
          Uri.parse(
            '${_normalizeBaseUrl(baseUrl)}/api/known-miners/${Uri.encodeComponent(knownMinerId)}',
          ),
          headers: const <String, String>{'Accept': 'application/json'},
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Delete known miner failed: HTTP ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<AggregatorRefreshedMinerSnapshot> refreshKnownMiner(
    String baseUrl,
    String knownMinerIdOrIp,
  ) async {
    final Map<String, dynamic> payload = await _postJson(
      Uri.parse(
        '${_normalizeBaseUrl(baseUrl)}/api/known-miners/${Uri.encodeComponent(knownMinerIdOrIp)}/refresh',
      ),
      const <String, dynamic>{},
    );
    final dynamic rawMiner = payload['miner'];
    if (rawMiner is! Map) {
      throw Exception('Refresh known miner failed: missing miner payload');
    }
    return AggregatorRefreshedMinerSnapshot(
      generatedAt: _parseDate(payload['generatedAt']),
      miner: _decodeMiner(Map<String, dynamic>.from(rawMiner)),
    );
  }

  Future<AggregatorBatchCommandResult> clearRefineKnownMiners(
    String baseUrl,
    List<String> ips,
  ) async {
    final List<String> normalizedIps = ips
        .map((String ip) => ip.trim())
        .where((String ip) => ip.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final Map<String, dynamic> payload = await _postJson(
      Uri.parse('${_normalizeBaseUrl(baseUrl)}/api/known-miners/clear-refine'),
      <String, dynamic>{'ips': normalizedIps},
    );
    final List<String> targets =
        ((payload['targets'] as List?) ?? const <dynamic>[])
            .map((dynamic value) => value.toString())
            .where((String value) => value.trim().isNotEmpty)
            .toList(growable: false);
    return AggregatorBatchCommandResult(
      success: payload['ok'] == true,
      message: (payload['message'] ?? 'Clear auto tune request finished.')
          .toString(),
      targets: targets,
    );
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    return _retryJsonRequest(
      () => _client
          .get(
            Uri.parse(url),
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(_timeout),
      target: url,
    );
  }

  Future<Map<String, dynamic>?> _tryGetJson(String url) async {
    try {
      return await _getJson(url);
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendJson(Uri uri, Map<String, dynamic> body) async {
    await _postJson(uri, body);
  }

  Future<Map<String, dynamic>> _putJson(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    return _retryJsonRequest(
      () => _client
          .put(
            uri,
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout),
      target: uri.toString(),
    );
  }

  Future<Map<String, dynamic>> _retryJsonRequest(
    Future<http.Response> Function() request, {
    required String target,
  }) async {
    Object? lastError;
    for (int attempt = 1; attempt <= _maxRequestAttempts; attempt++) {
      try {
        final response = await request();
        return _decodeJsonResponse(response, target);
      } catch (error) {
        lastError = error;
        if (attempt >= _maxRequestAttempts ||
            !_isRetryableRequestError(error)) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    throw lastError ?? Exception('Request failed: $target');
  }

  Map<String, dynamic> _decodeJsonResponse(
    http.Response response,
    String target,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Request failed: HTTP ${response.statusCode} ${response.body}',
      );
    }
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected payload from $target');
    }
    return decoded;
  }

  bool _isRetryableRequestError(Object error) {
    return error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException;
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(
          uri,
          headers: const <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Request failed: HTTP ${response.statusCode} ${response.body}',
      );
    }
    if (response.body.trim().isEmpty) {
      return const <String, dynamic>{};
    }
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected payload from $uri');
    }
    return decoded;
  }

  bool _isActiveTaskMap(Map<String, dynamic>? raw) {
    if (raw == null) {
      return false;
    }
    final state = '${raw['scanState'] ?? ''}';
    return state == 'running' ||
        state == 'waiting' ||
        state == 'waiting-stop' ||
        state == 'queued' ||
        state == 'delayed';
  }

  AggregatorServerTask _decodeTask(
    Map<String, dynamic> raw,
    Map<String, dynamic> schedulerPayload,
  ) {
    return AggregatorServerTask(
      scanState:
          '${raw['scanState'] ?? schedulerPayload['scanState'] ?? 'idle'}',
      progress: (raw['progress'] as num?)?.toDouble() ?? 0,
      matchedCount:
          (raw['matchedCount'] as num?)?.toInt() ??
          (raw['successCount'] as num?)?.toInt() ??
          0,
      failedCount: (raw['failedCount'] as num?)?.toInt() ?? 0,
      nonMinerCount: (raw['nonMinerCount'] as num?)?.toInt() ?? 0,
      totalTargets: (raw['totalTargets'] as num?)?.toInt() ?? 0,
      lastScanStartedAt: _parseDate(raw['lastScanStartedAt']),
      lastScanFinishedAt: _parseDate(raw['lastScanFinishedAt']),
      nextScheduledAt: _parseDate(
        raw['nextScheduledAt'] ?? schedulerPayload['nextScheduledAt'],
      ),
      warningReason:
          raw['warningReason'] as String? ??
          raw['lastDelayReason'] as String? ??
          schedulerPayload['lastDelayReason'] as String?,
      isManualTask:
          (raw['isManualTask'] as bool?) ??
          ((raw['source']?.toString() == 'scheduler')
              ? false
              : raw['scanTaskId'] != null),
    );
  }

  AggregatorServerMiner _decodeMiner(Map<String, dynamic> raw) {
    final Map<String, dynamic> metrics = raw['metrics'] is Map
        ? Map<String, dynamic>.from(raw['metrics'] as Map)
        : const <String, dynamic>{};
    final dynamic lifecycleRaw = raw['lifecycle'];
    final String? lifecycleState = lifecycleRaw is Map
        ? lifecycleRaw['state']?.toString()
        : lifecycleRaw?.toString();
    final String ip = (raw['ip'] ?? '').toString().trim();
    final Map<String, dynamic>? diagnosisRaw = raw['diagnosis'] is Map
        ? Map<String, dynamic>.from(raw['diagnosis'] as Map)
        : null;
    return AggregatorServerMiner(
      id: (raw['id'] ?? '').toString(),
      name: (raw['name'] ?? ip).toString(),
      ip: ip,
      segment: (raw['segment'] ?? '').toString(),
      lifecycle: lifecycleState,
      status: (raw['status'] ?? '').toString(),
      online: metrics['online'] == true,
      hashrateRtMh: (metrics['hashrateRt'] as num?)?.toDouble() ?? 0,
      hashrateAvgMh: (metrics['hashrateAvg'] as num?)?.toDouble() ?? 0,
      maxTemperatureC: (metrics['maxTemperatureC'] as num?)?.toDouble(),
      averageFanRpm: (metrics['averageFanRpm'] as num?)?.toDouble(),
      ambientTempC: (metrics['ambientTemp'] as num?)?.toDouble(),
      runningMode: metrics['runningMode']?.toString(),
      lastSeenAt: _parseDate(metrics['lastSeenAt']),
      chains: _decodeChains(
        raw['rawStatus'] ?? raw['chains'] ?? metrics['chains'],
      ),
      alertCount: (raw['alertCount'] as num?)?.toInt() ?? 0,
      diagnosis: diagnosisRaw == null ? null : _decodeDiagnosis(diagnosisRaw),
      abnormalGroup: raw['abnormalGroup']?.toString(),
      abnormalType: raw['abnormalType']?.toString(),
      isRepeatedOffline: raw['isRepeatedOffline'] == true,
      repeatedOfflineMarkedAt: _parseDate(raw['repeatedOfflineMarkedAt']),
    );
  }

  List<AggregatorServerMinerChain> _decodeChains(dynamic raw) {
    return parseVolcMinerChains(raw)
        .asMap()
        .entries
        .map((entry) {
          final chain = entry.value;
          return AggregatorServerMinerChain(
            index: chain.index >= 0 ? chain.index : entry.key + 1,
            chainRateMh:
                double.tryParse(chain.chainRate.replaceAll(',', '')) ?? 0,
            tempC: double.tryParse(chain.temp.replaceAll(',', '')),
            freq: chain.freq,
            hw: chain.hw,
            chainAcn: chain.chainAcn,
            chainAcs: chain.chainAcs,
          );
        })
        .where((AggregatorServerMinerChain chain) => chain.index >= 0)
        .toList(growable: false);
  }

  AggregatorServerDiagnosis _decodeDiagnosis(Map<String, dynamic> raw) {
    return AggregatorServerDiagnosis(
      code: (raw['code'] ?? '').toString(),
      category: (raw['category'] ?? '').toString(),
      reason: (raw['reason'] ?? '').toString(),
      solution: (raw['solution'] ?? '').toString(),
      logSnippet: (raw['logSnippet'] ?? '').toString(),
      detectedAt: _parseDate(raw['detectedAt']),
      secondaryCode: raw['secondaryCode']?.toString(),
      secondaryReason: raw['secondaryReason']?.toString(),
    );
  }

  AggregatorKnownMiner _decodeKnownMiner(Map<String, dynamic> raw) {
    return AggregatorKnownMiner(
      id: (raw['id'] ?? '').toString(),
      ip: (raw['ip'] ?? '').toString(),
      name: (raw['name'] ?? '').toString(),
    );
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw.toString());
  }

  String _normalizeBaseUrl(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw Exception('Server URL is empty.');
    }
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  ScanView _decodeScanView(Map<String, dynamic> raw) {
    final subnetPrefix = (raw['subnetPrefix'] ?? '').toString().trim();
    final startHost = (raw['startHost'] as num?)?.toInt() ?? 1;
    final endHost = (raw['endHost'] as num?)?.toInt() ?? 255;
    final cidr = subnetPrefix.isEmpty ? '' : '$subnetPrefix.0/24';
    final startIp = subnetPrefix.isEmpty ? '' : '$subnetPrefix.$startHost';
    final endIp = subnetPrefix.isEmpty ? '' : '$subnetPrefix.$endHost';
    final label = (raw['label'] ?? raw['id'] ?? subnetPrefix).toString();
    final now = DateTime.now();
    return ScanView(
      id: (raw['id'] ?? label).toString(),
      name: label,
      cidr: cidr,
      startIp: startIp,
      endIp: endIp,
      tags: const <String>[],
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> _encodeScanView(ScanView view) {
    final prefix = _resolveSubnetPrefix(view);
    final startHost = _resolveHost(view.startIp, fallback: 1);
    final endHost = _resolveHost(view.endIp, fallback: 255);
    return <String, dynamic>{
      'id': view.id,
      'label': view.name.trim().isEmpty ? prefix : view.name.trim(),
      'subnetPrefix': prefix,
      'startHost': startHost,
      'endHost': endHost,
      'username': 'root',
      'password': 'ltc@dog',
      'timeoutSeconds': 5,
      'mode': 'global',
    };
  }

  String _resolveSubnetPrefix(ScanView view) {
    String candidate = view.cidr.trim();
    if (candidate.isNotEmpty && candidate.contains('/')) {
      candidate = candidate.split('/').first;
    }
    if (candidate.isEmpty) {
      candidate = view.startIp.trim().isNotEmpty
          ? view.startIp.trim()
          : view.endIp.trim();
    }
    final parts = candidate.split('.');
    if (parts.length >= 3) {
      return parts.take(3).join('.');
    }
    return candidate;
  }

  int _resolveHost(String ip, {required int fallback}) {
    final parts = ip.trim().split('.');
    if (parts.length == 4) {
      return int.tryParse(parts.last) ?? fallback;
    }
    return fallback;
  }
}
