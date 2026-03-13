import 'package:flutter/material.dart';
import 'package:volcminer/domain/entities/scan_view.dart';

class ScanViewCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
                      view.cidr.isNotEmpty ? view.cidr : view.startIp,
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
              if (view.cidr.isNotEmpty) Text('IP Block: ${view.cidr}'),
              if (view.startIp.isNotEmpty || view.endIp.isNotEmpty)
                Text(
                  'Range: ${view.startIp.isEmpty ? '--' : view.startIp} - ${view.endIp.isEmpty ? '--' : view.endIp}',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
