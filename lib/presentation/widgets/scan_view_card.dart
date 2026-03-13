import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/ip_utils.dart';
import 'package:volcminer/domain/entities/scan_view.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';

class ScanViewCard extends ConsumerWidget {
  const ScanViewCard({
    super.key,
    required this.view,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final ScanView view;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayBlock = IpUtils.formatIpBlockLabel(
      view.cidr.isNotEmpty ? view.cidr : view.startIp,
    );
    final l10n = AppLocalizer(ref);
    return Card(
      color: selected ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      displayBlock,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Checkbox(value: selected, onChanged: (_) => onTap()),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              if (view.cidr.isNotEmpty)
                Text(l10n.t('view.ipBlock', params: {'scope': displayBlock})),
              if (view.startIp.isNotEmpty || view.endIp.isNotEmpty)
                Text(
                  l10n.t(
                    'view.range',
                    params: {
                      'start': view.startIp.isEmpty ? '--' : view.startIp,
                      'end': view.endIp.isEmpty ? '--' : view.endIp,
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
