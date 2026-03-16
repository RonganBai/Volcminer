import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/data/datasources/isar_local_data_source.dart';
import 'package:volcminer/data/datasources/miner_local_data_source.dart';
import 'package:volcminer/data/isar_factory.dart';
import 'package:volcminer/data/repositories/miner_repository_impl.dart';
import 'package:volcminer/domain/entities/app_settings.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/pool_worker.dart';
import 'package:volcminer/domain/entities/scan_view.dart';
import 'package:volcminer/domain/entities/search_request.dart';
import 'package:volcminer/domain/repositories/pool_search_repository.dart';
import 'package:volcminer/domain/usecases/apply_pool_config_usecase.dart';
import 'package:volcminer/domain/usecases/clear_refine_usecase.dart';
import 'package:volcminer/domain/usecases/fetch_miner_detail_usecase.dart';
import 'package:volcminer/domain/usecases/reboot_miner_usecase.dart';
import 'package:volcminer/domain/usecases/search_pool_workers_usecase.dart';
import 'package:volcminer/domain/usecases/toggle_indicator_usecase.dart';
import 'package:volcminer/presentation/controllers/scan_controller.dart';

const String _channelId = 'volcminer_auto_scan';
const int _notificationId = 8842;
const String _lastAutoScanAtKey = 'background_auto_scan_last_at';
const String _lastAutoScanAttemptAtKey = 'background_auto_scan_last_attempt_at';
const String _nextAutoScanAtKey = 'background_auto_scan_next_at';
const String _autoScanLogsKey = 'background_auto_scan_logs';
const String _autoScanProgressKey = 'background_auto_scan_progress';

Timer? _backgroundTimer;
bool _backgroundScanBusy = false;
bool _backgroundRunPending = false;
Isar? _backgroundIsar;

class BackgroundScanService {
  BackgroundScanService._();

  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      'VolcMiner Auto Scan',
      description: 'Keeps known miner auto-refresh running in the background.',
      importance: Importance.low,
    );

    const androidInit = AndroidInitializationSettings('ic_bg_service_small');
    const initSettings = InitializationSettings(android: androidInit);
    await _notifications.initialize(initSettings);
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onServiceStart,
        onBackground: _onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'VolcMiner Auto Scan',
        initialNotificationContent: 'Preparing background auto-refresh',
        foregroundServiceNotificationId: _notificationId,
        foregroundServiceTypes: const [AndroidForegroundType.dataSync],
        onStart: _onServiceStart,
      ),
    );
  }

  static Future<void> sync({required bool enabled}) async {
    final running = await _service.isRunning();
    if (!enabled) {
      if (running) {
        _service.invoke('stop');
      }
      return;
    }

    if (!running) {
      await _service.startService();
    } else {
      _service.invoke('reload');
    }
  }

  static Stream<Map<String, dynamic>?> on(String event) => _service.on(event);

  static Future<List<AutoScanLogEntry>> getAutoScanLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_autoScanLogsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      final logs = decoded
          .whereType<Map>()
          .map((entry) => AutoScanLogEntry.fromJson(Map<String, dynamic>.from(entry)))
          .toList(growable: false);
      logs.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return logs;
    } catch (_) {
      return const [];
    }
  }

  static Future<AutoScanProgress> getAutoScanProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_autoScanProgressKey);
    if (raw == null || raw.trim().isEmpty) {
      return const AutoScanProgress(
        isRunning: false,
        scannedTargets: 0,
        totalTargets: 0,
        phase: 'idle',
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const AutoScanProgress(
          isRunning: false,
          scannedTargets: 0,
          totalTargets: 0,
          phase: 'idle',
        );
      }
      return AutoScanProgress.fromJson(decoded);
    } catch (_) {
      return const AutoScanProgress(
        isRunning: false,
        scannedTargets: 0,
        totalTargets: 0,
        phase: 'idle',
      );
    }
  }

  static Future<DateTime?> getLastAutoScanAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_lastAutoScanAtKey);
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static Future<DateTime?> getLastAutoScanAttemptAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_lastAutoScanAttemptAtKey);
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static Future<DateTime?> getNextAutoScanAtStored() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_nextAutoScanAtKey);
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static DateTime? getNextAutoScanAt({
    required AppSettings settings,
    required DateTime? lastAutoScanAt,
  }) {
    if (!settings.autoRefreshEnabled || lastAutoScanAt == null) {
      return null;
    }
    final intervalSeconds = settings.refreshIntervalSec <= 0
        ? 900
        : settings.refreshIntervalSec;
    return _alignToAllowedWindow(
      settings,
      lastAutoScanAt.add(Duration(seconds: intervalSeconds)),
    );
  }
}

class AutoScanLogEntry {
  const AutoScanLogEntry({
    required this.id,
    required this.startedAt,
    this.finishedAt,
    required this.status,
    this.onlineCount,
    this.note,
    this.stageDurationsMs = const {},
  });

  final String id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String status;
  final int? onlineCount;
  final String? note;
  final Map<String, int> stageDurationsMs;

  factory AutoScanLogEntry.fromJson(Map<String, dynamic> json) {
    return AutoScanLogEntry(
      id: '${json['id'] ?? ''}',
      startedAt: DateTime.tryParse('${json['startedAt'] ?? ''}') ?? DateTime.now(),
      finishedAt: json['finishedAt'] == null
          ? null
          : DateTime.tryParse('${json['finishedAt']}'),
      status: '${json['status'] ?? 'unknown'}',
      onlineCount: (json['onlineCount'] as num?)?.toInt(),
      note: json['note'] as String?,
      stageDurationsMs: ((json['stageDurationsMs'] as Map?) ?? const {})
          .map(
            (key, value) => MapEntry(
              '$key',
              (value as num?)?.toInt() ?? 0,
            ),
          ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
      'status': status,
      'onlineCount': onlineCount,
      'note': note,
      'stageDurationsMs': stageDurationsMs,
    };
  }
}

class AutoScanProgress {
  const AutoScanProgress({
    required this.isRunning,
    required this.scannedTargets,
    required this.totalTargets,
    this.phase = 'idle',
    this.stageKey,
    this.stageCurrent = 0,
    this.stageTotal = 0,
    this.startedAt,
  });

  final bool isRunning;
  final int scannedTargets;
  final int totalTargets;
  final String phase;
  final String? stageKey;
  final int stageCurrent;
  final int stageTotal;
  final DateTime? startedAt;

  double? get ratio {
    if (totalTargets <= 0) {
      return null;
    }
    final value = scannedTargets / totalTargets;
    return value.clamp(0, 1).toDouble();
  }

  factory AutoScanProgress.fromJson(Map<String, dynamic> json) {
    return AutoScanProgress(
      isRunning: json['isRunning'] == true,
      scannedTargets: (json['scannedTargets'] as num?)?.toInt() ?? 0,
      totalTargets: (json['totalTargets'] as num?)?.toInt() ?? 0,
      phase: '${json['phase'] ?? 'idle'}',
      stageKey: json['stageKey'] as String?,
      stageCurrent: (json['stageCurrent'] as num?)?.toInt() ?? 0,
      stageTotal: (json['stageTotal'] as num?)?.toInt() ?? 0,
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.tryParse('${json['startedAt']}'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isRunning': isRunning,
      'scannedTargets': scannedTargets,
      'totalTargets': totalTargets,
      'phase': phase,
      'stageKey': stageKey,
      'stageCurrent': stageCurrent,
      'stageTotal': stageTotal,
      'startedAt': startedAt?.toIso8601String(),
    };
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
Future<void> _onServiceStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await _ensureNotificationsReady();

  service.on('stop').listen((_) async {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    await _showNotification(
      title: 'VolcMiner Auto Scan',
      body: 'Background auto-refresh stopped',
    );
    service.stopSelf();
  });

  service.on('reload').listen((_) {
    unawaited(_restartSchedule(service));
  });

  await _restartSchedule(service);
}

Future<void> _restartSchedule(ServiceInstance service) async {
  _backgroundTimer?.cancel();

  final context = await _loadBackgroundContext();
  if (context == null) {
    await _showNotification(
      title: 'VolcMiner Auto Scan',
      body: 'Auto-refresh unavailable',
    );
    return;
  }

  if (!context.settings.autoRefreshEnabled) {
    await _showNotification(
      title: 'VolcMiner Auto Scan',
      body: 'Auto-refresh disabled',
    );
    return;
  }

  final intervalSeconds = context.settings.refreshIntervalSec <= 0
      ? 900
      : context.settings.refreshIntervalSec;

  final now = DateTime.now();
  final nextAllowed = _alignToAllowedWindow(
    context.settings,
    now.add(Duration(seconds: intervalSeconds)),
  );
  final shouldRunNow =
      _isWithinAutoScanWindow(context.settings, now) &&
      await _shouldRunImmediately(intervalSeconds);
  await _markNextAutoScanAt(nextAllowed);
  if (shouldRunNow) {
    unawaited(_runBackgroundScan(service));
  } else {
    await _showNotification(
      title: 'VolcMiner Auto Scan',
      body: 'Next scan at ${_formatClock(nextAllowed)}',
    );
  }

  _backgroundTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
    unawaited(_runBackgroundScan(service));
  });
}

Future<void> _runBackgroundScan(ServiceInstance service) async {
  if (_backgroundScanBusy) {
    _backgroundRunPending = true;
    return;
  }
  _backgroundScanBusy = true;
  _backgroundRunPending = false;
  final startedAt = DateTime.now();
  final logId = startedAt.microsecondsSinceEpoch.toString();
  final stageDurationsMs = <String, int>{};
  String? lastStageKey;
  DateTime? lastStageStartedAt;
  await _appendAutoScanLog(
    AutoScanLogEntry(
      id: logId,
      startedAt: startedAt,
      status: 'running',
    ),
  );

  try {
    await _markAutoScanAttempted();
    final context = await _loadBackgroundContext();
    if (context == null) {
      await _finishAutoScanLog(
        logId,
        status: 'failed',
        note: 'Background storage unavailable',
      );
      await _showNotification(
        title: 'VolcMiner Auto Scan',
        body: 'Background storage unavailable',
      );
      return;
    }

    if (!context.settings.autoRefreshEnabled) {
      await _finishAutoScanLog(
        logId,
        status: 'skipped',
        note: 'Auto-refresh disabled',
      );
      await _showNotification(
        title: 'VolcMiner Auto Scan',
        body: 'Auto-refresh disabled',
      );
      return;
    }

    if (!_isWithinAutoScanWindow(context.settings, startedAt)) {
      await _markNextAutoScanAt(
        _alignToAllowedWindow(
          context.settings,
          startedAt.add(
            Duration(
              seconds: context.settings.refreshIntervalSec <= 0
                  ? 900
                  : context.settings.refreshIntervalSec,
            ),
          ),
        ),
      );
      await _finishAutoScanLog(
        logId,
        status: 'skipped',
        note: 'Outside auto scan time window',
      );
      await _showNotification(
        title: 'VolcMiner Auto Scan',
        body: 'Current time is outside the active auto scan window',
      );
      return;
    }

    if (context.views.isEmpty) {
      await _finishAutoScanLog(
        logId,
        status: 'skipped',
        note: 'No scan views available',
      );
      await _showNotification(
        title: 'VolcMiner Auto Scan',
        body: 'No scan views available',
      );
      return;
    }

    await context.controller.loadPersistedState();
    if (context.controller.snapshot.knownMinerIpsByScope.isEmpty) {
      await _finishAutoScanLog(
        logId,
        status: 'skipped',
        note: 'No known miner IPs yet',
      );
      await _showNotification(
        title: 'VolcMiner Auto Scan',
        body: 'No known miner IPs yet. Run one full scan first.',
      );
      return;
    }

    final totalTargets = _countKnownTargetsForViews(
      context.views,
      context.controller.snapshot.knownMinerIpsByScope,
    );
    await _saveAutoScanProgress(
      AutoScanProgress(
        isRunning: true,
        scannedTargets: 0,
        totalTargets: totalTargets,
        phase: 'scanning',
        stageKey: null,
        stageCurrent: 0,
        stageTotal: 0,
        startedAt: startedAt,
      ),
    );
    final progressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final snapshot = context.controller.snapshot;
      final stageKey = snapshot.isPostProcessing
          ? (snapshot.postProcessingStageKey ?? 'app.scan.finalizing')
          : 'app.scan.progress';
      final now = DateTime.now();
      if (lastStageKey == null) {
        lastStageKey = stageKey;
        lastStageStartedAt = now;
      } else if (lastStageKey != stageKey) {
        final started = lastStageStartedAt ?? now;
        stageDurationsMs[lastStageKey!] =
            (stageDurationsMs[lastStageKey!] ?? 0) +
            now.difference(started).inMilliseconds;
        lastStageKey = stageKey;
        lastStageStartedAt = now;
      }
      unawaited(
        _saveAutoScanProgress(
          AutoScanProgress(
            isRunning: true,
            scannedTargets: snapshot.scannedTargets,
            totalTargets: snapshot.totalTargets > 0
                ? snapshot.totalTargets
                : totalTargets,
            phase: snapshot.isPostProcessing ? 'finalizing' : 'scanning',
            stageKey: snapshot.postProcessingStageKey,
            stageCurrent: snapshot.postProcessingCurrent,
            stageTotal: snapshot.postProcessingTotal,
            startedAt: startedAt,
          ),
        ),
      );
    });

    await _showNotification(
      title: 'VolcMiner Auto Scan',
      body: 'Scanning known miners in the background...',
    );

    try {
      await context.controller.startAutoRefreshScan(
        allViews: context.views,
        accountUsername: context.settings.poolSearchUsername,
        accountPassword: context.poolSearchPassword,
        minerCredential: MinerCredential(
          username: context.settings.minerUsername,
          password: context.minerAuthPassword,
        ),
        concurrency: context.settings.scanConcurrency,
      );

      final onlineCount = context.controller.snapshot.segments
          .expand((segment) => segment.miners)
          .where((miner) => miner.state == 'online')
          .length;
      await _markAutoScanRan();
      await _markNextAutoScanAt(
        DateTime.now().add(Duration(seconds: context.settings.refreshIntervalSec <= 0 ? 900 : context.settings.refreshIntervalSec)),
      );
      await _finishAutoScanLog(
        logId,
        status: 'success',
        onlineCount: onlineCount,
        stageDurationsMs: _finalizeStageDurations(
          stageDurationsMs: stageDurationsMs,
          lastStageKey: lastStageKey,
          lastStageStartedAt: lastStageStartedAt,
        ),
      );
      await _saveAutoScanProgress(
        AutoScanProgress(
          isRunning: true,
          scannedTargets: context.controller.snapshot.totalTargets > 0
              ? context.controller.snapshot.totalTargets
              : totalTargets,
          totalTargets: context.controller.snapshot.totalTargets > 0
              ? context.controller.snapshot.totalTargets
              : totalTargets,
          phase: 'finalizing',
          stageKey: context.controller.snapshot.postProcessingStageKey,
          stageCurrent: context.controller.snapshot.postProcessingCurrent,
          stageTotal: context.controller.snapshot.postProcessingTotal,
          startedAt: startedAt,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await _saveAutoScanProgress(
        AutoScanProgress(
          isRunning: false,
          scannedTargets: context.controller.snapshot.totalTargets > 0
              ? context.controller.snapshot.totalTargets
              : totalTargets,
          totalTargets: context.controller.snapshot.totalTargets > 0
              ? context.controller.snapshot.totalTargets
              : totalTargets,
          phase: 'idle',
          stageKey: null,
          stageCurrent: 0,
          stageTotal: 0,
          startedAt: startedAt,
        ),
      );
      await _showNotification(
        title: 'VolcMiner Auto Scan',
        body: 'Last scan complete. Online miners: $onlineCount',
      );
      service.invoke(
        'scanUpdated',
        {'timestamp': DateTime.now().toIso8601String()},
      );
    } finally {
      progressTimer.cancel();
    }
  } catch (e) {
    await _finishAutoScanLog(
      logId,
      status: 'failed',
      note: '$e',
      stageDurationsMs: _finalizeStageDurations(
        stageDurationsMs: stageDurationsMs,
        lastStageKey: lastStageKey,
        lastStageStartedAt: lastStageStartedAt,
      ),
    );
    await _saveAutoScanProgress(
      const AutoScanProgress(
        isRunning: false,
        scannedTargets: 0,
        totalTargets: 0,
        phase: 'idle',
        stageKey: null,
        stageCurrent: 0,
        stageTotal: 0,
      ),
    );
    await _showNotification(
      title: 'VolcMiner Auto Scan',
      body: 'Auto-refresh failed: $e',
    );
  } finally {
    _backgroundScanBusy = false;
    if (_backgroundRunPending) {
      _backgroundRunPending = false;
      unawaited(_runBackgroundScan(service));
    }
  }
}

Future<_BackgroundContext?> _loadBackgroundContext() async {
  try {
    final isar = _backgroundIsar ??= await openVolcMinerIsar();
    final local = IsarLocalDataSource(isar);
    final secureStorage = const FlutterSecureStorage();
    final settings = await local.getSettings();
    final views = await local.getScanViews();
    final minerAuthPassword =
        await secureStorage.read(key: 'miner_auth_password') ?? 'ltc@dog';
    final poolSearchPassword =
        await secureStorage.read(key: 'pool_search_account_password') ?? '';

    final minerRepository = MinerRepositoryImpl(MinerLocalDataSource());
    final controller = ScanController(
      SearchPoolWorkersUseCase(_NoopPoolSearchRepository()),
      FetchMinerDetailUseCase(minerRepository),
      ToggleIndicatorUseCase(minerRepository),
      ClearRefineUseCase(minerRepository),
      RebootMinerUseCase(minerRepository),
      ApplyPoolConfigUseCase(minerRepository),
      local,
    );

    return _BackgroundContext(
      controller: controller,
      settings: settings,
      views: views,
      minerAuthPassword: minerAuthPassword,
      poolSearchPassword: poolSearchPassword,
    );
  } catch (_) {
    return null;
  }
}

Future<void> _ensureNotificationsReady() async {
  const androidInit = AndroidInitializationSettings('ic_bg_service_small');
  const initSettings = InitializationSettings(android: androidInit);
  await BackgroundScanService._notifications.initialize(initSettings);
}

Future<bool> _shouldRunImmediately(int intervalSeconds) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_lastAutoScanAtKey);
  if (raw == null) {
    return true;
  }
  final lastRun = DateTime.tryParse(raw);
  if (lastRun == null) {
    return true;
  }
  return DateTime.now().difference(lastRun).inSeconds >= intervalSeconds;
}

Future<void> _markAutoScanRan() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_lastAutoScanAtKey, DateTime.now().toIso8601String());
}

Future<void> _markAutoScanAttempted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _lastAutoScanAttemptAtKey,
    DateTime.now().toIso8601String(),
  );
}

Future<void> _markNextAutoScanAt(DateTime value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_nextAutoScanAtKey, value.toIso8601String());
}

bool _isWithinAutoScanWindow(AppSettings settings, DateTime when) {
  final minute = when.hour * 60 + when.minute;
  final start = settings.autoScanStartMinute.clamp(0, 1439);
  final stop = settings.autoScanStopMinute.clamp(0, 1439);
  if (start == stop) {
    return true;
  }
  if (start < stop) {
    return minute >= start && minute <= stop;
  }
  return minute >= start || minute <= stop;
}

DateTime _alignToAllowedWindow(AppSettings settings, DateTime candidate) {
  if (_isWithinAutoScanWindow(settings, candidate)) {
    return candidate;
  }
  final start = settings.autoScanStartMinute.clamp(0, 1439);
  final candidateMinute = candidate.hour * 60 + candidate.minute;
  DateTime next = DateTime(
    candidate.year,
    candidate.month,
    candidate.day,
    start ~/ 60,
    start % 60,
  );
  if (settings.autoScanStartMinute == settings.autoScanStopMinute) {
    return candidate;
  }
  if (settings.autoScanStartMinute < settings.autoScanStopMinute) {
    if (candidateMinute > start) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }
  if (candidateMinute > settings.autoScanStopMinute &&
      candidateMinute < settings.autoScanStartMinute) {
    return next;
  }
  return candidate;
}

String _formatClock(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

Future<void> _appendAutoScanLog(AutoScanLogEntry entry) async {
  final prefs = await SharedPreferences.getInstance();
  final current = await BackgroundScanService.getAutoScanLogs();
  final updated = [entry, ...current];
  if (updated.length > 80) {
    updated.removeRange(80, updated.length);
  }
  await prefs.setString(
    _autoScanLogsKey,
    jsonEncode(updated.map((log) => log.toJson()).toList(growable: false)),
  );
}

Future<void> _finishAutoScanLog(
  String id, {
  required String status,
  int? onlineCount,
  String? note,
  Map<String, int>? stageDurationsMs,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final current = await BackgroundScanService.getAutoScanLogs();
  final updated = current
      .map(
        (log) => log.id == id
            ? AutoScanLogEntry(
                id: log.id,
                startedAt: log.startedAt,
                finishedAt: DateTime.now(),
                status: status,
                onlineCount: onlineCount ?? log.onlineCount,
                note: note,
                stageDurationsMs: stageDurationsMs ?? log.stageDurationsMs,
              )
            : log,
      )
      .toList(growable: false);
  await prefs.setString(
    _autoScanLogsKey,
    jsonEncode(updated.map((log) => log.toJson()).toList(growable: false)),
  );
}

Map<String, int> _finalizeStageDurations({
  required Map<String, int> stageDurationsMs,
  required String? lastStageKey,
  required DateTime? lastStageStartedAt,
}) {
  final result = <String, int>{...stageDurationsMs};
  if (lastStageKey != null && lastStageStartedAt != null) {
    result[lastStageKey] =
        (result[lastStageKey] ?? 0) +
        DateTime.now().difference(lastStageStartedAt).inMilliseconds;
  }
  return result;
}

Future<void> _saveAutoScanProgress(AutoScanProgress progress) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_autoScanProgressKey, jsonEncode(progress.toJson()));
}

int _countKnownTargetsForViews(
  List<ScanView> views,
  Map<String, Set<String>> knownMinerIpsByScope,
) {
  final scopes = <String>{};
  for (final view in views) {
    final ips = IpUtils.expandAll(
      cidr: view.cidr,
      startIp: view.startIp,
      endIp: view.endIp,
    );
    for (final ip in ips) {
      final parts = ip.split('.');
      if (parts.length == 4) {
        scopes.add('${parts[0]}.${parts[1]}.${parts[2]}');
      }
    }
  }
  final targets = <String>{};
  for (final scope in scopes) {
    targets.addAll(knownMinerIpsByScope[scope] ?? const <String>{});
  }
  return targets.length;
}

Future<void> _showNotification({
  required String title,
  required String body,
}) async {
  await BackgroundScanService._notifications.show(
    _notificationId,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'VolcMiner Auto Scan',
        channelDescription:
            'Keeps known miner auto-refresh running in the background.',
        icon: 'ic_bg_service_small',
        ongoing: true,
        onlyAlertOnce: true,
      ),
    ),
  );
}

class _BackgroundContext {
  const _BackgroundContext({
    required this.controller,
    required this.settings,
    required this.views,
    required this.minerAuthPassword,
    required this.poolSearchPassword,
  });

  final ScanController controller;
  final AppSettings settings;
  final List<ScanView> views;
  final String minerAuthPassword;
  final String poolSearchPassword;
}

class _NoopPoolSearchRepository implements PoolSearchRepository {
  @override
  Future<List<PoolWorker>> searchWorkers(SearchRequest request) async {
    return const [];
  }
}
