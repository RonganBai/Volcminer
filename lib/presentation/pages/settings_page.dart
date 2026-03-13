import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final settings = state.settings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Font Scale', style: TextStyle(fontWeight: FontWeight.w600)),
        Wrap(
          spacing: 8,
          children: [0.85, 1.0, 1.15, 1.3]
              .map(
                (value) => ChoiceChip(
                  label: Text('${(value * 100).round()}%'),
                  selected: settings.fontScale == value,
                  onSelected: (_) => controller.updateSettings(
                    settings.copyWith(fontScale: value),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Auto Refresh'),
          value: settings.autoRefreshEnabled,
          onChanged: (value) => controller.updateSettings(
            settings.copyWith(autoRefreshEnabled: value),
          ),
        ),
        SwitchListTile(
          title: const Text('Show Offline Miners'),
          value: settings.showOfflineEnabled,
          onChanged: (value) => controller.updateSettings(
            settings.copyWith(showOfflineEnabled: value),
          ),
        ),
        SwitchListTile(
          title: const Text('Collect Logs'),
          value: settings.collectLogsEnabled,
          onChanged: (value) => controller.updateSettings(
            settings.copyWith(collectLogsEnabled: value),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: settings.refreshIntervalSec.toString(),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Auto refresh interval (sec)',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            final parsed = int.tryParse(value) ?? settings.refreshIntervalSec;
            controller.updateSettings(
              settings.copyWith(refreshIntervalSec: parsed.clamp(10, 600)),
            );
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Scan Concurrency',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [20, 30, 40, 50]
              .map(
                (value) => ChoiceChip(
                  label: Text('$value'),
                  selected: settings.scanConcurrency == value,
                  onSelected: (_) => controller.updateSettings(
                    settings.copyWith(scanConcurrency: value),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
