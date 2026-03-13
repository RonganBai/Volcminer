import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/presentation/pages/dashboard_page.dart';
import 'package:volcminer/presentation/pages/scan_result_page.dart';
import 'package:volcminer/presentation/pages/settings_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanControllerProvider);

    final pages = [
      const DashboardPage(),
      const ScanResultPage(),
      const SettingsPage(),
    ];

    final title = switch (_index) {
      0 => 'VolcMiner Dashboard',
      1 => 'Scan Results',
      _ => 'Settings',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: scanState.isScanning
            ? PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: [
                      Text(
                        'Scanning ${scanState.scannedTargets}/${scanState.totalTargets}',
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: scanState.totalTargets > 0
                            ? scanState.scannedTargets / scanState.totalTargets
                            : null,
                      ),
                    ],
                  ),
                ),
              )
            : null,
        actions: [
          IconButton(
            onPressed: scanState.isScanning ? null : () => _startScan(),
            icon: const Icon(Icons.search),
            tooltip: 'Start Scan',
          ),
          PopupMenuButton<int>(
            onSelected: (value) => setState(() => _index = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 0, child: Text('Dashboard')),
              PopupMenuItem(value: 1, child: Text('Results')),
              PopupMenuItem(value: 2, child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            label: 'Results',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
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
    ref.read(scanControllerProvider.notifier).setupAutoRefresh(
          enabled: settings.autoRefreshEnabled,
          intervalSeconds: settings.refreshIntervalSec,
          selectedViews: selectedViews,
          accountUsername: settings.poolSearchUsername,
          accountPassword: settingsState.poolSearchPassword,
          minerCredential: minerCredential,
          collectLogs: false,
          targetMode: targetMode,
          concurrency: settings.scanConcurrency,
        );
  }
}
