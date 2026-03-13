import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/entities/miner_scan_item.dart';
import 'package:volcminer/presentation/pages/pool_config_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class MinerDetailPage extends ConsumerStatefulWidget {
  const MinerDetailPage({super.key, required this.item});

  final MinerScanItem item;

  @override
  ConsumerState<MinerDetailPage> createState() => _MinerDetailPageState();
}

class _MinerDetailPageState extends ConsumerState<MinerDetailPage> {
  bool _ledOn = false;
  bool _ledBusy = false;
  bool _rebootBusy = false;
  bool _clearBusy = false;
  bool _logExpanded = false;
  bool _logLoading = false;
  String? _kernelLog;
  String? _kernelLogError;
  final ScrollController _logVerticalController = ScrollController();
  final ScrollController _logHorizontalController = ScrollController();

  @override
  void dispose() {
    _logVerticalController.dispose();
    _logHorizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = widget.item.runtime;
    final settingsState = ref.watch(settingsControllerProvider);
    final credential = MinerCredential(
      username: settingsState.settings.minerUsername,
      password: settingsState.minerAuthPassword,
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.item.worker.ip)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status: ${_statusLabel(runtime.onlineStatus)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Hashrate 5s: ${runtime.ghs5s}'),
                  Text('Hashrate avg: ${runtime.ghsav}'),
                  Text('Ambient temp: ${runtime.ambientTemp}'),
                  Text('Power: ${runtime.power}'),
                  Text(
                    'Fans: ${runtime.fan1}, ${runtime.fan2}, ${runtime.fan3}, ${runtime.fan4}',
                  ),
                  Text('Running mode: ${runtime.runningMode}'),
                  Text(
                    'Updated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(runtime.fetchedAt)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _ledOn,
                    onChanged: _ledBusy
                        ? null
                        : (value) => _toggleLed(context, credential, value),
                    title: const Text('Indicator switch'),
                    subtitle: Text(
                      _ledBusy
                          ? 'Sending command...'
                          : 'Uses diagnostics backend to control the miner LED.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clearBusy
                              ? null
                              : () => _confirmAndRun(
                                  context: context,
                                  title: 'Clear Refine',
                                  message:
                                      'Clear refine for ${widget.item.worker.ip}?',
                                  busySetter: (value) =>
                                      setState(() => _clearBusy = value),
                                  action: () => ref
                                      .read(scanControllerProvider.notifier)
                                      .clearRefineForIps(
                                        [widget.item.worker.ip],
                                        credential,
                                      ),
                                ),
                          icon: _clearBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cleaning_services_outlined),
                          label: const Text('Clear Refine'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _rebootBusy
                              ? null
                              : () => _confirmAndRun(
                                  context: context,
                                  title: 'Reboot Miner',
                                  message:
                                      'Reboot ${widget.item.worker.ip} now?',
                                  busySetter: (value) =>
                                      setState(() => _rebootBusy = value),
                                  action: () => ref
                                      .read(scanControllerProvider.notifier)
                                      .rebootForIps(
                                        [widget.item.worker.ip],
                                        credential,
                                      ),
                                ),
                          icon: _rebootBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.restart_alt),
                          label: const Text('Reboot'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PoolConfigPage(
                              targetIps: [widget.item.worker.ip],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.swap_horiz_outlined),
                      label: const Text('Pool Config'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ExpansionTile(
              title: const Text('工作日志'),
              subtitle: Text(
                _logLoading
                    ? '正在读取完整 kernel log...'
                    : _kernelLogError != null
                    ? '读取失败'
                    : _kernelLog == null
                    ? '展开后单独读取完整日志'
                    : '已加载完整日志，可拖动滚动条查看',
              ),
              initiallyExpanded: _logExpanded,
              onExpansionChanged: (expanded) {
                setState(() => _logExpanded = expanded);
                if (expanded) {
                  _loadKernelLog(credential);
                }
              },
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _buildLogContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogContent() {
    if (_logLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_kernelLogError != null) {
      return Text(
        _kernelLogError!,
        style: const TextStyle(color: Colors.red),
      );
    }
    final text = _kernelLog ?? '展开后单独查找完整工作日志。';
    final lines = text.split('\n');
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Scrollbar(
        controller: _logVerticalController,
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: _logVerticalController,
          child: Scrollbar(
            controller: _logHorizontalController,
            thumbVisibility: true,
            interactive: true,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _logHorizontalController,
              scrollDirection: Axis.horizontal,
              child: SelectableText.rich(
                TextSpan(
                  children: [
                    for (var i = 0; i < lines.length; i++) ...[
                      _buildLogLineSpan(lines[i]),
                      if (i != lines.length - 1) const TextSpan(text: '\n'),
                    ],
                  ],
                ),
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextSpan _buildLogLineSpan(String line) {
    if (!line.toUpperCase().contains('ERRORMSG')) {
      return TextSpan(text: line);
    }
    final pattern = RegExp('ERRORMSG', caseSensitive: false);
    final matches = pattern.allMatches(line).toList(growable: false);
    if (matches.isEmpty) {
      return TextSpan(text: line);
    }

    final children = <InlineSpan>[];
    var start = 0;
    for (final match in matches) {
      if (match.start > start) {
        children.add(TextSpan(text: line.substring(start, match.start)));
      }
      children.add(
        TextSpan(
          text: line.substring(match.start, match.end),
          style: const TextStyle(
            color: Colors.red,
            backgroundColor: Color(0xFFFFE0E0),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      start = match.end;
    }
    if (start < line.length) {
      children.add(TextSpan(text: line.substring(start)));
    }

    return TextSpan(
      style: const TextStyle(
        backgroundColor: Color(0xFFFFF4F4),
      ),
      children: children,
    );
  }

  Future<void> _toggleLed(
    BuildContext context,
    MinerCredential credential,
    bool value,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _ledBusy = true);
    final result = await ref
        .read(scanControllerProvider.notifier)
        .toggleLedForIp(widget.item.worker.ip, value, credential);
    if (!mounted) {
      return;
    }
    setState(() {
      _ledBusy = false;
      if (result.success) {
        _ledOn = value;
      }
    });
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _confirmAndRun({
    required BuildContext context,
    required String title,
    required String message,
    required void Function(bool value) busySetter,
    required Future<dynamic> Function() action,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    busySetter(true);
    final result = await action();
    if (!mounted) {
      return;
    }
    busySetter(false);
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _loadKernelLog(MinerCredential credential) async {
    if (_logLoading || _kernelLog != null) {
      return;
    }
    setState(() {
      _logLoading = true;
      _kernelLogError = null;
    });
    try {
      final log = await ref
          .read(fetchMinerDetailUseCaseProvider)
          .getKernelLog(widget.item.worker.ip, credential);
      if (!mounted) {
        return;
      }
      setState(() {
        _kernelLog = log;
        _logLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _logLoading = false;
        _kernelLogError = '工作日志读取失败: $e';
      });
    }
  }

  String _statusLabel(String value) {
    return switch (value) {
      MinerRuntimeStatus.online => 'Online',
      MinerRuntimeStatus.offline => 'Offline',
      _ => value,
    };
  }
}
