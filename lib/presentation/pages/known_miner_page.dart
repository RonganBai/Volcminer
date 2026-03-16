import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class KnownMinerPage extends ConsumerStatefulWidget {
  const KnownMinerPage({super.key});

  @override
  ConsumerState<KnownMinerPage> createState() => _KnownMinerPageState();
}

class _KnownMinerPageState extends ConsumerState<KnownMinerPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizer(ref);
    final knownIps = ref.watch(
      scanControllerProvider.select((state) {
        final ips = <String>[
          for (final entry in state.knownMinerIpsByScope.entries) ...entry.value,
        ];
        ips.sort((a, b) => IpUtils.ipToInt(a).compareTo(IpUtils.ipToInt(b)));
        return ips;
      }),
    );
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          IconButton(
            onPressed: () => _showAddKnownIpDialog(context, l10n, knownIps.toSet()),
            icon: const Icon(Icons.add),
            tooltip: l10n.t('app.knownMiners.add'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: l10n.t('app.knownMiners.searchHint'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.t('common.clearInput'),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      l10n.t('app.knownMiners.empty'),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final ip = filtered[index];
                      final parts = ip.split('.');
                      final scope = parts.length == 4
                          ? '${parts[0]}.${parts[1]}.${parts[2]}'
                          : ip;
                      return ListTile(
                        title: Text(ip),
                        subtitle: Text(IpUtils.formatIpBlockLabel(scope)),
                      );
                    },
                  ),
          ),
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
      final added = ref.read(scanControllerProvider.notifier).addKnownMinerIp(ip);
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
