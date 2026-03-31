import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/presentation/controllers/scan_controller.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/localization/legacy_zh_texts.dart';
import 'package:volcminer/presentation/pages/barcode_scanner_page.dart';
import 'package:volcminer/presentation/pages/dashboard_page.dart';
import 'package:volcminer/presentation/pages/known_miner_page.dart';
import 'package:volcminer/presentation/pages/repeated_offline_page.dart';
import 'package:volcminer/presentation/pages/scan_result_page.dart';
import 'package:volcminer/presentation/pages/scan_page.dart';
import 'package:volcminer/presentation/pages/settings_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';
import 'package:volcminer/presentation/widgets/server_sync_status_banner.dart';
import 'package:volcminer/services/background_scan_service.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;
  StreamSubscription<Map<String, dynamic>?>? _serviceSubscription;
  bool _refreshingServerData = false;
  String _lastLoadedServerUrl = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref
        .read(scanControllerProvider.notifier)
        .setupAutoRefresh(
          enabled: true,
          intervalSeconds: 600,
          onTick: () async {
            await ref
                .read(scanControllerProvider.notifier)
                .refreshServerSnapshot();
          },
        );
    _serviceSubscription = BackgroundScanService.on('scanUpdated').listen((_) {
      ref.read(scanControllerProvider.notifier).loadPersistedState();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(scanControllerProvider.notifier).loadPersistedState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanControllerProvider);
    final settingsState = ref.watch(settingsControllerProvider);
    final l10n = AppLocalizer(ref);
    _syncServerSource(settingsState.serverUrl);

    final pages = [
      const DashboardPage(),
      const ScanPage(),
      const ScanResultPage(),
      const SettingsPage(),
    ];

    final title = switch (_index) {
      0 => l10n.t('app.title.dashboard'),
      1 => l10n.t('app.title.scan'),
      2 => l10n.t('app.title.results'),
      _ => l10n.t('app.title.settings'),
    };
    final bool manualBusy =
        scanState.isManualScanActive || scanState.isPostProcessing;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: _buildTopBanner(scanState, l10n),
        actions: [
          IconButton(
            onPressed: _refreshingServerData ? null : _refreshServerData,
            icon: _refreshingServerData
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: LegacyZhTexts.refreshPage,
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const KnownMinerPage()),
              );
            },
            icon: const Icon(Icons.storage_outlined),
            tooltip: l10n.t('app.knownMiners.open'),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RepeatedOfflinePage(),
                ),
              );
            },
            icon: _HeaderBadgeIcon(
              icon: Icons.warning_amber_rounded,
              count: scanState.serverRepeatedOfflineCount ?? 0,
            ),
            tooltip: '多次离线IP',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BarcodeScannerPage(),
                ),
              );
            },
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: l10n.t('app.scanner.open'),
          ),
        ],
      ),
      body: pages[_index],
      floatingActionButton: _index == 1
          ? FloatingActionButton.extended(
              onPressed: manualBusy ? null : () => _startScan(),
              icon: const Icon(Icons.search),
              label: Text(
                manualBusy
                    ? l10n.t('app.scan.action.scanning')
                    : l10n.t('app.scan.action.scan'),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: l10n.t('app.nav.dashboard'),
          ),
          NavigationDestination(
            icon: Icon(Icons.radar_outlined),
            label: l10n.t('app.nav.scan'),
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            label: l10n.t('app.nav.results'),
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: l10n.t('app.nav.settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _startScan() async {
    final scanViewState = ref.read(scanViewControllerProvider);
    final settingsState = ref.read(settingsControllerProvider);
    final targetMode = ref.read(scanTargetModeProvider);
    final settings = settingsState.settings;
    final selectedViews = scanViewState.views
        .where((v) => scanViewState.selectedIds.contains(v.id))
        .toList(growable: false);
    final minerCredential = MinerCredential(
      username: settings.minerUsername,
      password: settingsState.minerAuthPassword,
    );

    await ref
        .read(scanControllerProvider.notifier)
        .startScan(
          selectedViews: selectedViews,
          accountUsername: settings.poolSearchUsername,
          accountPassword: settingsState.poolSearchPassword,
          minerCredential: minerCredential,
          collectLogs: false,
          targetMode: targetMode,
          concurrency: settings.scanConcurrency,
        );
  }

  Future<void> _refreshServerData() async {
    if (_refreshingServerData) {
      return;
    }
    setState(() => _refreshingServerData = true);
    try {
      await ref.read(scanControllerProvider.notifier).refreshServerSnapshot();
    } finally {
      if (mounted) {
        setState(() => _refreshingServerData = false);
      }
    }
  }

  PreferredSizeWidget? _buildTopBanner(ScanState scanState, AppLocalizer l10n) {
    if (scanState.isPostProcessing || scanState.isManualScanActive) {
      return PreferredSize(
        preferredSize: Size.fromHeight(scanState.isManualScanActive ? 90 : 52),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                scanState.isPostProcessing
                    ? l10n.t(
                        scanState.postProcessingStageKey ??
                            'app.scan.finalizing',
                      )
                    : scanState.scanRunState == ScanRunState.paused
                    ? l10n.t(
                        'app.scan.paused',
                        params: {
                          'current': scanState.scannedTargets.toString(),
                          'total': scanState.totalTargets.toString(),
                        },
                      )
                    : l10n.t(
                        'app.scan.progress',
                        params: {
                          'current': scanState.scannedTargets.toString(),
                          'total': scanState.totalTargets.toString(),
                        },
                      ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: scanState.isPostProcessing
                    ? (scanState.postProcessingTotal > 0
                          ? (scanState.postProcessingCurrent /
                                    scanState.postProcessingTotal)
                                .clamp(0, 1)
                                .toDouble()
                          : 0)
                    : scanState.totalTargets > 0
                    ? scanState.scannedTargets / scanState.totalTargets
                    : null,
              ),
              if (scanState.isPostProcessing) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    scanState.postProcessingTotal > 0
                        ? '${scanState.postProcessingCurrent}/${scanState.postProcessingTotal}  ${(((scanState.postProcessingCurrent / scanState.postProcessingTotal) * 100)).round()}%'
                        : '0/0  0%',
                  ),
                ),
              ],
              if (scanState.isManualScanActive &&
                  !scanState.isPostProcessing) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (scanState.scanRunState == ScanRunState.running)
                      FilledButton.tonalIcon(
                        onPressed: () => ref
                            .read(scanControllerProvider.notifier)
                            .pauseManualScan(),
                        icon: const Icon(Icons.pause_circle_outline),
                        label: Text(l10n.t('app.scan.action.pause')),
                      ),
                    if (scanState.scanRunState == ScanRunState.paused)
                      FilledButton.icon(
                        onPressed: () => ref
                            .read(scanControllerProvider.notifier)
                            .resumeManualScan(),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l10n.t('app.scan.action.resume')),
                      ),
                    if (scanState.scanRunState == ScanRunState.cancelling)
                      Chip(
                        avatar: const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        label: Text(l10n.t('app.scan.action.cancelling')),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(scanControllerProvider.notifier)
                            .cancelManualScan(),
                        icon: const Icon(Icons.close),
                        label: Text(l10n.t('app.scan.action.cancel')),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (scanState.isServerSyncing || scanState.serverSyncLabel != null) {
      return PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ServerSyncStatusBanner(scanState: scanState, l10n: l10n),
        ),
      );
    }

    return null;
  }

  void _syncServerSource(String serverUrl) {
    final normalized = serverUrl.trim();
    if (normalized == _lastLoadedServerUrl) {
      return;
    }
    _lastLoadedServerUrl = normalized;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(ref.read(scanControllerProvider.notifier).loadPersistedState());
    });
  }
}

class _HeaderBadgeIcon extends StatelessWidget {
  const _HeaderBadgeIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: Icon(icon)),
          if (count > 0)
            Positioned(
              right: -4,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE15B64),
                  borderRadius: BorderRadius.circular(999),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
