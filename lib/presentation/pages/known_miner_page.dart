import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/localization/legacy_zh_texts.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';
import 'package:volcminer/presentation/widgets/server_sync_status_banner.dart';

class KnownMinerPage extends ConsumerStatefulWidget {
  const KnownMinerPage({super.key});

  @override
  ConsumerState<KnownMinerPage> createState() => _KnownMinerPageState();
}

class _KnownMinerPageState extends ConsumerState<KnownMinerPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(scanControllerProvider);
      final knownCount = current.knownMinerIpsByScope.values.fold<int>(
        0,
        (sum, set) => sum + set.length,
      );
      if (knownCount == 0) {
        unawaited(
          ref.read(scanControllerProvider.notifier).refreshServerSnapshot(),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizer(ref);
    final scanState = ref.watch(scanControllerProvider);
    final settingsState = ref.watch(settingsControllerProvider);
    final bool serverMode = settingsState.serverUrl.trim().isNotEmpty;
    final knownIps = <String>[
      for (final entry in scanState.knownMinerIpsByScope.entries)
        ...entry.value,
    ]..sort((a, b) => IpUtils.ipToInt(a).compareTo(IpUtils.ipToInt(b)));
    final filtered = knownIps
        .where((ip) => ip.contains(_query.trim()))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('app.knownMiners.title')),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${knownIps.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          if (!serverMode)
            IconButton(
              onPressed: () =>
                  _showAddKnownIpDialog(context, l10n, knownIps.toSet()),
              icon: const Icon(Icons.add),
              tooltip: l10n.t('app.knownMiners.add'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _KnownMinerSummaryCard(
            totalCount: knownIps.length,
            visibleCount: filtered.length,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                keyboardType: TextInputType.phone,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: l10n.t('app.knownMiners.searchHint'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear_rounded),
                          tooltip: l10n.t('common.clearInput'),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: const Color(0xFF2F67D8).withValues(alpha: 0.16),
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FBFF),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty &&
              (scanState.isServerSyncing || scanState.serverSyncLabel != null))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ServerSyncStatusBanner(
                  scanState: scanState,
                  l10n: l10n,
                  compact: true,
                ),
              ),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  l10n.t('app.knownMiners.empty'),
                  style: const TextStyle(
                    color: Color(0xFF6F748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            ...filtered.map((ip) {
              final parts = ip.split('.');
              final scope = parts.length == 4
                  ? '${parts[0]}.${parts[1]}.${parts[2]}'
                  : ip;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _KnownMinerCard(
                  ip: ip,
                  scope: IpUtils.formatIpBlockLabel(scope),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showAddKnownIpDialog(
    BuildContext context,
    AppLocalizer l10n,
    Set<String> knownIps,
  ) async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(l10n.t('app.knownMiners.addTitle')),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: l10n.t('app.knownMiners.addHint'),
                border: const OutlineInputBorder(),
              ),
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
      if (confirmed != true || !mounted) {
        return;
      }
      final ip = controller.text.trim();
      if (!IpUtils.isValidIpv4(ip)) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.t('app.knownMiners.addInvalid'))),
        );
        return;
      }
      if (knownIps.contains(ip)) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.t('app.knownMiners.addDuplicate'))),
        );
        return;
      }
      final added = ref
          .read(scanControllerProvider.notifier)
          .addKnownMinerIp(ip);
      if (!mounted) {
        return;
      }
      if (!added) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.t('app.knownMiners.addDuplicate'))),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.t('app.knownMiners.addSuccess', params: {'ip': ip}),
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}

class _KnownMinerSummaryCard extends StatelessWidget {
  const _KnownMinerSummaryCard({
    required this.totalCount,
    required this.visibleCount,
  });

  final int totalCount;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF2F67D8).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.dns_rounded,
                color: Color(0xFF2F67D8),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    LegacyZhTexts.knownMinerTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF30343F),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    LegacyZhTexts.knownMinerVisibleCount(
                      visibleCount,
                      totalCount,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6F748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F8F1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$totalCount',
                style: const TextStyle(
                  color: Color(0xFF2EAF62),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KnownMinerCard extends StatelessWidget {
  const _KnownMinerCard({required this.ip, required this.scope});

  final String ip;
  final String scope;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2F67D8).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lan_rounded,
                color: Color(0xFF2F67D8),
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ip,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF22252E),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.travel_explore_outlined,
                          size: 14,
                          color: Color(0xFF6F748B),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            scope,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6F748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
