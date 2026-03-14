import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/presentation/controllers/scan_controller.dart';
import 'package:volcminer/presentation/controllers/scan_view_controller.dart';
import 'package:volcminer/presentation/controllers/settings_controller.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/pages/auto_scan_log_page.dart';
import 'package:volcminer/presentation/pages/barcode_scanner_page.dart';
import 'package:volcminer/presentation/pages/dashboard_page.dart';
import 'package:volcminer/presentation/pages/known_miner_page.dart';
import 'package:volcminer/presentation/pages/scan_result_page.dart';
import 'package:volcminer/presentation/pages/scan_page.dart';
import 'package:volcminer/presentation/pages/settings_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';
import 'package:volcminer/services/background_scan_service.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  String _autoRefreshSignature = '';
  StreamSubscription<Map<String, dynamic>?>? _serviceSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    final scanViewState = ref.watch(scanViewControllerProvider);
    final l10n = AppLocalizer(ref);
    _syncAutoRefresh(scanState, settingsState, scanViewState);

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

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: (scanState.isScanning || scanState.isPostProcessing)
            ? PreferredSize(
                preferredSize: Size.fromHeight(
                  scanState.isManualScanActive ? 90 : 52,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scanState.isPostProcessing
                            ? l10n.t('app.scan.finalizing')
                            : scanState.scanRunState == ScanRunState.paused
                                ? l10n.t(
                                    'app.scan.paused',
                                    params: {
                                      'current':
                                          scanState.scannedTargets.toString(),
                                      'total':
                                          scanState.totalTargets.toString(),
                                    },
                                  )
                                : l10n.t(
                                    'app.scan.progress',
                                    params: {
                                      'current':
                                          scanState.scannedTargets.toString(),
                                      'total':
                                          scanState.totalTargets.toString(),
                                    },
                                  ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: scanState.isPostProcessing
                            ? null
                            : scanState.totalTargets > 0
                                ? scanState.scannedTargets /
                                    scanState.totalTargets
                                : null,
                      ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                label: Text(
                                  l10n.t('app.scan.action.cancelling'),
                                ),
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
              )
            : null,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const KnownMinerPage(),
                ),
              );
            },
            icon: const Icon(Icons.storage_outlined),
            tooltip: l10n.t('app.knownMiners.open'),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AutoScanLogPage(),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: l10n.t('app.autoScanLog.open'),
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
          PopupMenuButton<int>(
            onSelected: (value) => setState(() => _index = value),
            itemBuilder: (context) => [
              PopupMenuItem(value: 0, child: Text(l10n.t('app.nav.dashboard'))),
              PopupMenuItem(value: 1, child: Text(l10n.t('app.nav.scan'))),
              PopupMenuItem(value: 2, child: Text(l10n.t('app.nav.results'))),
              PopupMenuItem(value: 3, child: Text(l10n.t('app.nav.settings'))),
            ],
          ),
        ],
      ),
      body: pages[_index],
      floatingActionButton: _index == 1
          ? FloatingActionButton.extended(
              onPressed: (scanState.isScanning || scanState.isPostProcessing)
                  ? null
                  : () => _startScan(),
              icon: const Icon(Icons.search),
              label: Text(
                (scanState.isScanning || scanState.isPostProcessing)
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

    await ref.read(scanControllerProvider.notifier).startScan(
          selectedViews: selectedViews,
          accountUsername: settings.poolSearchUsername,
          accountPassword: settingsState.poolSearchPassword,
          minerCredential: minerCredential,
          collectLogs: false,
          targetMode: targetMode,
          concurrency: settings.scanConcurrency,
        );
    _configureAutoRefresh();
  }

  void _syncAutoRefresh(
    ScanState scanState,
    SettingsState settingsState,
    ScanViewState scanViewState,
  ) {
    final settings = settingsState.settings;
    final signature = [
      settings.autoRefreshEnabled,
      settings.refreshIntervalSec,
      settings.scanConcurrency,
      settings.minerUsername,
      settingsState.minerAuthPassword,
      settings.poolSearchUsername,
      settingsState.poolSearchPassword,
      scanViewState.views.map((view) => view.id).join(','),
      scanState.knownMinerIpsByScope.length,
    ].join('|');
    if (signature == _autoRefreshSignature) {
      return;
    }
    _autoRefreshSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _configureAutoRefresh();
    });
  }

  void _configureAutoRefresh() {
    final enabled = ref.read(settingsControllerProvider).settings.autoRefreshEnabled;
    unawaited(BackgroundScanService.sync(enabled: enabled));
  }
}
