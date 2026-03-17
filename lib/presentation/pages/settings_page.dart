import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/presentation/localization/app_language.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const List<double> _fontScaleOptions = [0.85, 1.0, 1.15, 1.3];
  static const List<int> _concurrencyOptions = [50, 60, 100, 200];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final language = ref.watch(appLanguageProvider);
    final languageController = ref.read(appLanguageProvider.notifier);
    final l10n = AppLocalizer(ref);
    final settings = state.settings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: Text(l10n.t('settings.language')),
          subtitle: Text(
            language == AppLanguage.zh
                ? l10n.t('settings.language.zh')
                : l10n.t('settings.language.en'),
          ),
          value: language == AppLanguage.zh,
          onChanged: (value) => languageController.setLanguage(
            value ? AppLanguage.zh : AppLanguage.en,
          ),
        ),
        _SelectionTile(
          title: l10n.t('settings.fontScale'),
          value: '${(settings.fontScale * 100).round()}%',
          onTap: () => _pickFontScale(context, ref),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: Text(l10n.t('settings.autoRefresh')),
          value: settings.autoRefreshEnabled,
          onChanged: (value) => controller.updateSettings(
            settings.copyWith(autoRefreshEnabled: value),
          ),
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                title: Text(l10n.t('settings.autoScanWindow')),
              ),
              const Divider(height: 1),
              ListTile(
                title: Text(l10n.t('settings.autoScanStart')),
                trailing: Text(
                  _formatMinuteOfDay(settings.autoScanStartMinute),
                ),
                onTap: () => _pickScanTime(
                  context,
                  ref,
                  isStart: true,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: Text(l10n.t('settings.autoScanStop')),
                trailing: Text(
                  _formatMinuteOfDay(settings.autoScanStopMinute),
                ),
                onTap: () => _pickScanTime(
                  context,
                  ref,
                  isStart: false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: settings.refreshIntervalSec.toString(),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.t('settings.refreshInterval'),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            final parsed = int.tryParse(value) ?? settings.refreshIntervalSec;
            controller.updateSettings(
              settings.copyWith(refreshIntervalSec: parsed.clamp(10, 86400)),
            );
          },
        ),
        const SizedBox(height: 12),
        _SelectionTile(
          title: l10n.t('settings.scanConcurrency'),
          value: '${settings.scanConcurrency}',
          onTap: () => _pickConcurrency(context, ref),
        ),
      ],
    );
  }

  Future<void> _pickFontScale(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(settingsControllerProvider.notifier);
    final settings = ref.read(settingsControllerProvider).settings;
    final l10n = AppLocalizer(ref);
    final selected = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text(l10n.t('settings.fontScale')),
          children: [
            for (final value in _fontScaleOptions)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: settings.fontScale == value
                        ? Theme.of(dialogContext)
                            .colorScheme
                            .primaryContainer
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${(value * 100).round()}%'),
                ),
              ),
          ],
        );
      },
    );
    if (selected == null) {
      return;
    }
    await controller.updateSettings(settings.copyWith(fontScale: selected));
  }

  Future<void> _pickConcurrency(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(settingsControllerProvider.notifier);
    final settings = ref.read(settingsControllerProvider).settings;
    final l10n = AppLocalizer(ref);
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text(l10n.t('settings.scanConcurrency')),
          children: [
            for (final value in _concurrencyOptions)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: settings.scanConcurrency == value
                        ? Theme.of(dialogContext)
                            .colorScheme
                            .primaryContainer
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$value'),
                ),
              ),
          ],
        );
      },
    );
    if (selected == null) {
      return;
    }
    if (selected >= 60) {
      if (!context.mounted) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              l10n.t(
                'settings.scanConcurrencyWarningTitle',
                params: {'value': selected.toString()},
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t(
                    'settings.scanConcurrencyWarningBody',
                    params: {'value': selected.toString()},
                  ),
                ),
                const SizedBox(height: 8),
                Text(l10n.t('settings.scanConcurrencyWarningHint')),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.t('common.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.t('common.confirm')),
              ),
            ],
          );
        },
      );
      if (confirmed != true) {
        return;
      }
    }
    await controller.updateSettings(
      settings.copyWith(scanConcurrency: selected),
    );
  }

  Future<void> _pickScanTime(
    BuildContext context,
    WidgetRef ref, {
    required bool isStart,
  }) async {
    final controller = ref.read(settingsControllerProvider.notifier);
    final settings = ref.read(settingsControllerProvider).settings;
    final initialMinutes = isStart
        ? settings.autoScanStartMinute
        : settings.autoScanStopMinute;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initialMinutes ~/ 60,
        minute: initialMinutes % 60,
      ),
    );
    if (picked == null) {
      return;
    }
    final minutes = picked.hour * 60 + picked.minute;
    await controller.updateSettings(
      isStart
          ? settings.copyWith(autoScanStartMinute: minutes)
          : settings.copyWith(autoScanStopMinute: minutes),
    );
  }

  String _formatMinuteOfDay(int minuteOfDay) {
    final clamped = minuteOfDay.clamp(0, 1439);
    final hour = (clamped ~/ 60).toString().padLeft(2, '0');
    final minute = (clamped % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
