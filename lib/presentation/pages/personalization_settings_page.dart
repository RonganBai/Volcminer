import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class PersonalizationSettingsPage extends ConsumerWidget {
  const PersonalizationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final l10n = AppLocalizer(ref);
    final settings = state.settings;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings.personalizationTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              secondary: const _AccentIcon(
                icon: Icons.developer_board_rounded,
                color: Color(0xFF8E5CF7),
              ),
              title: Text(l10n.t('settings.detailChainsCollapsedDefault')),
              subtitle: Text(l10n.t('settings.detailChainsCollapsedHint')),
              value: settings.minerDetailChainsCollapsedByDefault,
              onChanged: (value) {
                controller.updateSettings(
                  settings.copyWith(minerDetailChainsCollapsedByDefault: value),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              secondary: const _AccentIcon(
                icon: Icons.description_outlined,
                color: Color(0xFF6F748B),
              ),
              title: Text(l10n.t('settings.detailLogsCollapsedDefault')),
              subtitle: Text(l10n.t('settings.detailLogsCollapsedHint')),
              value: settings.minerDetailLogsCollapsedByDefault,
              onChanged: (value) {
                controller.updateSettings(
                  settings.copyWith(minerDetailLogsCollapsedByDefault: value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentIcon extends StatelessWidget {
  const _AccentIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
