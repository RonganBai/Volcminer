import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/presentation/localization/app_language.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/localization/legacy_zh_texts.dart';
import 'package:volcminer/presentation/pages/personalization_settings_page.dart';
import 'package:volcminer/presentation/pages/sub_account_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const List<double> _fontScaleOptions = [0.85, 1.0, 1.15, 1.3];

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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SettingsSectionHeader(
                  icon: Icons.dns_rounded,
                  color: Color(0xFF2F67D8),
                  title: LegacyZhTexts.settingsServerUrl,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: state.serverUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: LegacyZhTexts.settingsServerUrl,
                    hintText: 'http://10.0.0.52:18080',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: controller.updateServerUrl,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const _SettingsSectionIcon(
              icon: Icons.manage_accounts_outlined,
              color: Color(0xFF7C3AED),
            ),
            title: Text(l10n.t('settings.subAccountCard')),
            subtitle: Text(l10n.t('settings.subAccountCardHint')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SubAccountPage()),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const _SettingsSectionIcon(
              icon: Icons.style_rounded,
              color: Color(0xFF2F67D8),
            ),
            title: Text(l10n.t('settings.personalizationCard')),
            subtitle: Text(l10n.t('settings.personalizationCardHint')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PersonalizationSettingsPage(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            secondary: const _SettingsSectionIcon(
              icon: Icons.language_rounded,
              color: Color(0xFF14A38B),
            ),
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
        ),
        _SelectionTile(
          title: l10n.t('settings.fontScale'),
          value: '${(settings.fontScale * 100).round()}%',
          icon: Icons.format_size_rounded,
          color: const Color(0xFFE07A14),
          onTap: () => _pickFontScale(context, ref),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: settings.fontScale == value
                        ? Theme.of(dialogContext).colorScheme.primaryContainer
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
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _SettingsSectionIcon(icon: icon, color: color),
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

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({
    required this.icon,
    required this.color,
    required this.title,
  });

  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SettingsSectionIcon(icon: icon, color: color),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _SettingsSectionIcon extends StatelessWidget {
  const _SettingsSectionIcon({required this.icon, required this.color});

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
