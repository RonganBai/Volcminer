import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

Timer? _backgroundTimer;
bool _backgroundScanBusy = false;
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

  static Future<DateTime?> getLastAutoScanAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastAutoScanAtKey);
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static Future<DateTime?> getLastAutoScanAttemptAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastAutoScanAttemptAtKey);
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static Future<DateTime?> getNextAutoScanAtStored() async {
    final prefs = await SharedPreferences.getInstance();
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
    return lastAutoScanAt.add(Duration(seconds: intervalSeconds));
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

  final shouldRunNow = await _shouldRunImmediately(intervalSeconds);
  await _markNextAutoScanAt(DateTime.now().add(Duration(seconds: intervalSeconds)));
  if (shouldRunNow) {
    unawaited(_runBackgroundScan(service));
  } else {
    await _showNotification(
      title: 'VolcMiner Auto Scan',
      body: 'Next scan in ${_formatInterval(intervalSeconds)}',
    );
  }

  _backgroundTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
    unawaited(_runBackgroundScan(service));
  });
}

Future<void> _runBackgroundScan(ServiceInstance service) async {
  if (_backgroundScanBusy) {
    return;
  }
  _backgroundScanBusy = true;

  try {
    await _markAutoScanAttempted();
    final context = await _loadBackgroundContext();
    if (context == null) {
      await _showNotification(
        title: 'VolcMiner Auto Scan',
        body: 'Background storage unavailable',
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

    if (context.views.isEmpty) {
      await _showNotification(
        title: 'VolcMiner Auto Scan',
        body: 'No scan views available',
      );
      return;
    }

    await context.controller.loadPersistedState();
    if (context.controller.snapshot.knownMinerIpsByScope.isEmpty) {
      await _showNotification(
        title: 'VolcMiner Auto Scan',
        body: 'No known miner IPs yet. Run one full scan first.',
      );
      return;
    }

    await _showNotification(
      title: 'VolcMiner Auto Scan',
      body: 'Scanning known miners in the background...',
    );

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
    await _showNotification(
      title: 'VolcMiner Auto Scan',
      body: 'Last scan complete. Online miners: $onlineCount',
    );
    service.invoke(
      'scanUpdated',
      {'timestamp': DateTime.now().toIso8601String()},
    );
  } catch (e) {
    await _showNotification(
      title: 'VolcMiner Auto Scan',
      body: 'Auto-refresh failed: $e',
    );
  } finally {
    _backgroundScanBusy = false;
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

String _formatInterval(int seconds) {
  if (seconds % 3600 == 0) {
    return '${seconds ~/ 3600}h';
  }
  if (seconds % 60 == 0) {
    return '${seconds ~/ 60}m';
  }
  return '${seconds}s';
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
