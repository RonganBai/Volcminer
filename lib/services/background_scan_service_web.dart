import 'dart:async';

import 'package:volcminer/data/datasources/isar_local_data_source.dart';
import 'package:volcminer/domain/entities/app_settings.dart';
import 'package:volcminer/domain/entities/scan_view.dart';

class BackgroundScanService {
  BackgroundScanService._();

  static Future<void> initialize() async {}

  static Future<void> sync({required bool enabled}) async {}

  static Stream<Map<String, dynamic>?> on(String event) =>
      const Stream<Map<String, dynamic>?>.empty();

  static void updateWindowsForegroundState({
    required AppSettings settings,
    required List<ScanView> views,
    required String minerAuthPassword,
    required String poolSearchPassword,
    required IsarLocalDataSource localDataSource,
  }) {}

  static Future<List<AutoScanLogEntry>> getAutoScanLogs() async => const [];

  static Future<AutoScanProgress> getAutoScanProgress() async =>
      const AutoScanProgress(
        isRunning: false,
        scannedTargets: 0,
        totalTargets: 0,
        phase: 'idle',
      );

  static Future<DateTime?> getLastAutoScanAt() async => null;

  static Future<DateTime?> getLastAutoScanAttemptAt() async => null;

  static Future<DateTime?> getNextAutoScanAtStored() async => null;

  static DateTime? getNextAutoScanAt({
    required AppSettings settings,
    required DateTime? lastAutoScanAt,
  }) {
    return null;
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
    return (scannedTargets / totalTargets).clamp(0, 1).toDouble();
  }
}
