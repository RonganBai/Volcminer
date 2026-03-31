import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

enum _EntryType { subAccount, miningUrl }

class SubAccountPage extends ConsumerWidget {
  const SubAccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final l10n = AppLocalizer(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('settings.subAccountTitle')),
        actions: [
          IconButton(
            onPressed: () => _showAddDialog(context, ref),
            icon: const Icon(Icons.add_rounded),
            tooltip: l10n.t('settings.addEntry'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: l10n.t('settings.subAccountSection'),
            icon: Icons.person_outline_rounded,
            color: const Color(0xFF2F67D8),
            emptyText: l10n.t('settings.emptySubAccounts'),
            children: state.settings.subAccounts
                .map(
                  (entry) => _EntryTile(
                    value: entry,
                    onDelete: () => _confirmDelete(
                      context: context,
                      l10n: l10n,
                      title: l10n.t('settings.deleteSubAccountTitle'),
                      body: l10n.t(
                        'settings.deleteSubAccountBody',
                        params: {'value': entry},
                      ),
                      onConfirm: () => controller.removeSubAccount(entry),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: l10n.t('settings.miningUrlSection'),
            icon: Icons.link_rounded,
            color: const Color(0xFF14A38B),
            emptyText: l10n.t('settings.emptyMiningUrls'),
            children: state.settings.miningUrls
                .map(
                  (entry) => _EntryTile(
                    value: entry,
                    onDelete: () => _confirmDelete(
                      context: context,
                      l10n: l10n,
                      title: l10n.t('settings.deleteMiningUrlTitle'),
                      body: l10n.t(
                        'settings.deleteMiningUrlBody',
                        params: {'value': entry},
                      ),
                      onConfirm: () => controller.removeMiningUrl(entry),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizer(ref);
    final controller = ref.read(settingsControllerProvider.notifier);
    final textController = TextEditingController();
    _EntryType type = _EntryType.subAccount;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.t('settings.addEntryTitle')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<_EntryType>(
                    initialValue: type,
                    decoration: InputDecoration(
                      labelText: l10n.t('settings.addEntryType'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: _EntryType.subAccount,
                        child: Text(
                          l10n.t('settings.addEntryType.subAccount'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: _EntryType.miningUrl,
                        child: Text(
                          l10n.t('settings.addEntryType.miningUrl'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => type = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    keyboardType: type == _EntryType.miningUrl
                        ? TextInputType.url
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: l10n.t('settings.addEntryValue'),
                      hintText: l10n.t(
                        type == _EntryType.subAccount
                            ? 'settings.addEntryValueHint.subAccount'
                            : 'settings.addEntryValueHint.miningUrl',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: () async {
                    final value = textController.text.trim();
                    if (value.isEmpty) {
                      return;
                    }
                    if (type == _EntryType.subAccount) {
                      await controller.addSubAccount(value);
                    } else {
                      await controller.addMiningUrl(value);
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(l10n.t('common.confirm')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete({
    required BuildContext context,
    required AppLocalizer l10n,
    required String title,
    required String body,
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('common.delete')),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await onConfirm();
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (children.isEmpty)
              Text(
                emptyText,
                style: const TextStyle(
                  color: Color(0xFF6F748B),
                  fontSize: 13,
                ),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.value,
    required this.onDelete,
  });

  final String value;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
