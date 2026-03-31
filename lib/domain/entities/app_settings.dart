class AppSettings {
  const AppSettings({
    required this.fontScale,
    required this.autoRefreshEnabled,
    required this.autoScanStartMinute,
    required this.autoScanStopMinute,
    required this.showOfflineEnabled,
    required this.collectLogsEnabled,
    required this.minerDetailChainsCollapsedByDefault,
    required this.minerDetailLogsCollapsedByDefault,
    required this.refreshIntervalSec,
    required this.scanConcurrency,
    required this.poolSearchUsername,
    required this.minerUsername,
    required this.subAccounts,
    required this.miningUrls,
  });

  final double fontScale;
  final bool autoRefreshEnabled;
  final int autoScanStartMinute;
  final int autoScanStopMinute;
  final bool showOfflineEnabled;
  final bool collectLogsEnabled;
  final bool minerDetailChainsCollapsedByDefault;
  final bool minerDetailLogsCollapsedByDefault;
  final int refreshIntervalSec;
  final int scanConcurrency;
  final String poolSearchUsername;
  final String minerUsername;
  final List<String> subAccounts;
  final List<String> miningUrls;

  static const AppSettings defaults = AppSettings(
    fontScale: 1.0,
    autoRefreshEnabled: false,
    autoScanStartMinute: 0,
    autoScanStopMinute: 1439,
    showOfflineEnabled: true,
    collectLogsEnabled: true,
    minerDetailChainsCollapsedByDefault: false,
    minerDetailLogsCollapsedByDefault: true,
    refreshIntervalSec: 900,
    scanConcurrency: 50,
    poolSearchUsername: '',
    minerUsername: 'root',
    subAccounts: [],
    miningUrls: [],
  );

  AppSettings copyWith({
    double? fontScale,
    bool? autoRefreshEnabled,
    int? autoScanStartMinute,
    int? autoScanStopMinute,
    bool? showOfflineEnabled,
    bool? collectLogsEnabled,
    bool? minerDetailChainsCollapsedByDefault,
    bool? minerDetailLogsCollapsedByDefault,
    int? refreshIntervalSec,
    int? scanConcurrency,
    String? poolSearchUsername,
    String? minerUsername,
    List<String>? subAccounts,
    List<String>? miningUrls,
  }) {
    return AppSettings(
      fontScale: fontScale ?? this.fontScale,
      autoRefreshEnabled: autoRefreshEnabled ?? this.autoRefreshEnabled,
      autoScanStartMinute: autoScanStartMinute ?? this.autoScanStartMinute,
      autoScanStopMinute: autoScanStopMinute ?? this.autoScanStopMinute,
      showOfflineEnabled: showOfflineEnabled ?? this.showOfflineEnabled,
      collectLogsEnabled: collectLogsEnabled ?? this.collectLogsEnabled,
      minerDetailChainsCollapsedByDefault:
          minerDetailChainsCollapsedByDefault ??
          this.minerDetailChainsCollapsedByDefault,
      minerDetailLogsCollapsedByDefault:
          minerDetailLogsCollapsedByDefault ??
          this.minerDetailLogsCollapsedByDefault,
      refreshIntervalSec: refreshIntervalSec ?? this.refreshIntervalSec,
      scanConcurrency: scanConcurrency ?? this.scanConcurrency,
      poolSearchUsername: poolSearchUsername ?? this.poolSearchUsername,
      minerUsername: minerUsername ?? this.minerUsername,
      subAccounts: subAccounts ?? this.subAccounts,
      miningUrls: miningUrls ?? this.miningUrls,
    );
  }
}
