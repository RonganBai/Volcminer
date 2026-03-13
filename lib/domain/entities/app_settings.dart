class AppSettings {
  const AppSettings({
    required this.fontScale,
    required this.autoRefreshEnabled,
    required this.showOfflineEnabled,
    required this.collectLogsEnabled,
    required this.refreshIntervalSec,
    required this.scanConcurrency,
    required this.poolSearchUsername,
    required this.minerUsername,
  });

  final double fontScale;
  final bool autoRefreshEnabled;
  final bool showOfflineEnabled;
  final bool collectLogsEnabled;
  final int refreshIntervalSec;
  final int scanConcurrency;
  final String poolSearchUsername;
  final String minerUsername;

  static const AppSettings defaults = AppSettings(
    fontScale: 1.0,
    autoRefreshEnabled: false,
    showOfflineEnabled: true,
    collectLogsEnabled: true,
    refreshIntervalSec: 900,
    scanConcurrency: 20,
    poolSearchUsername: '',
    minerUsername: 'root',
  );

  AppSettings copyWith({
    double? fontScale,
    bool? autoRefreshEnabled,
    bool? showOfflineEnabled,
    bool? collectLogsEnabled,
    int? refreshIntervalSec,
    int? scanConcurrency,
    String? poolSearchUsername,
    String? minerUsername,
  }) {
    return AppSettings(
      fontScale: fontScale ?? this.fontScale,
      autoRefreshEnabled: autoRefreshEnabled ?? this.autoRefreshEnabled,
      showOfflineEnabled: showOfflineEnabled ?? this.showOfflineEnabled,
      collectLogsEnabled: collectLogsEnabled ?? this.collectLogsEnabled,
      refreshIntervalSec: refreshIntervalSec ?? this.refreshIntervalSec,
      scanConcurrency: scanConcurrency ?? this.scanConcurrency,
      poolSearchUsername: poolSearchUsername ?? this.poolSearchUsername,
      minerUsername: minerUsername ?? this.minerUsername,
    );
  }
}
