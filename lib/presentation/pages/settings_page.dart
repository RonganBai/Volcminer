import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/presentation/localization/app_language.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

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
        Text(
          l10n.t('settings.fontScale'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
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
          title: Text(l10n.t('settings.autoRefresh')),
          value: settings.autoRefreshEnabled,
          onChanged: (value) => controller.updateSettings(
            settings.copyWith(autoRefreshEnabled: value),
          ),
        ),
        SwitchListTile(
          title: Text(l10n.t('settings.showOffline')),
          value: settings.showOfflineEnabled,
          onChanged: (value) => controller.updateSettings(
            settings.copyWith(showOfflineEnabled: value),
          ),
        ),
        SwitchListTile(
          title: Text(l10n.t('settings.collectLogs')),
          value: settings.collectLogsEnabled,
          onChanged: (value) => controller.updateSettings(
            settings.copyWith(collectLogsEnabled: value),
          ),
        ),
        const SizedBox(height: 8),
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
        Text(
          l10n.t('settings.scanConcurrency'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [20, 30, 40, 50, 60]
              .map(
                (value) => ChoiceChip(
                  label: Text('$value'),
                  selected: settings.scanConcurrency == value,
                  onSelected: (_) async {
                    if (value == 60) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            title: Text(l10n.t('settings.scanConcurrencyWarningTitle')),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.t('settings.scanConcurrencyWarningBody')),
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
                      settings.copyWith(scanConcurrency: value),
                    );
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
