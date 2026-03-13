import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/entities/tracked_miner.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/pages/pool_config_page.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class MinerDetailPage extends ConsumerStatefulWidget {
  const MinerDetailPage({super.key, required this.miner});

  final TrackedMiner miner;

  @override
  ConsumerState<MinerDetailPage> createState() => _MinerDetailPageState();
}

class _MinerDetailPageState extends ConsumerState<MinerDetailPage> {
  bool _ledBusy = false;
  bool _rebootBusy = false;
  bool _clearBusy = false;
  bool _refreshBusy = false;
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
    final currentMiner = ref.watch(
      scanControllerProvider.select((state) {
        for (final segment in state.segments) {
          for (final miner in segment.miners) {
            if (miner.ip == widget.miner.ip) {
              return miner;
            }
          }
        }
        return widget.miner;
      }),
    );
    final runtime = currentMiner.runtime;
    final settingsState = ref.watch(settingsControllerProvider);
    final ledOn = ref.watch(
      scanControllerProvider.select(
        (state) => state.ledActiveIps.contains(widget.miner.ip),
      ),
    );
    final credential = MinerCredential(
      username: settingsState.settings.minerUsername,
      password: settingsState.minerAuthPassword,
    );
    final l10n = AppLocalizer(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(currentMiner.ip),
        actions: [
          IconButton(
            onPressed: _refreshBusy
                ? null
                : () => _refreshMiner(
                    context,
                    credential,
                    settingsState.settings.scanConcurrency,
                    l10n,
                  ),
            tooltip: l10n.t('miner.refresh'),
            icon: _refreshBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
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
                    l10n.t(
                      'miner.status',
                      params: {'status': _statusLabel(runtime.onlineStatus, l10n)},
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.t('miner.hashrate5s', params: {'value': runtime.ghs5s})),
                  Text(l10n.t('miner.hashrateAvg', params: {'value': runtime.ghsav})),
                  Text(
                    l10n.t(
                      'miner.ambientTemp',
                      params: {'value': runtime.ambientTemp},
                    ),
                  ),
                  Text(l10n.t('miner.power', params: {'value': runtime.power})),
                  Text(
                    l10n.t(
                      'miner.fans',
                      params: {
                        'value':
                            '${runtime.fan1}, ${runtime.fan2}, ${runtime.fan3}, ${runtime.fan4}',
                      },
                    ),
                  ),
                  Text(
                    l10n.t(
                      'miner.runningMode',
                      params: {'value': runtime.runningMode},
                    ),
                  ),
                  Text(
                    l10n.t(
                      'miner.updated',
                      params: {
                        'time':
                            DateFormat('yyyy-MM-dd HH:mm:ss').format(runtime.fetchedAt),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (currentMiner.diagnosis != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.orange.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('miner.issueCardTitle'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t(
                        'miner.issueCode',
                        params: {'code': currentMiner.diagnosis!.code},
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.t(
                        'miner.issueReason',
                        params: {'reason': currentMiner.diagnosis!.reason},
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.t(
                        'miner.issueSolution',
                        params: {'solution': currentMiner.diagnosis!.solution},
                      ),
                    ),
                    if (currentMiner.diagnosis!.secondaryReason != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.t(
                          'miner.issueSecondary',
                          params: {
                            'reason': currentMiner.diagnosis!.secondaryReason!,
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SwitchListTile(
                    value: ledOn,
                    onChanged: _ledBusy
                        ? null
                        : (value) => _toggleLed(context, credential, value),
                    title: Text(l10n.t('miner.indicatorSwitch')),
                    subtitle: Text(
                      _ledBusy
                          ? l10n.t('miner.sendingCommand')
                          : l10n.t('miner.indicatorHint'),
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
                                  title: l10n.t('miner.clearRefine'),
                                  message: l10n.t(
                                    'miner.clearRefineMessage',
                                    params: {'ip': widget.miner.ip},
                                  ),
                                  cancelLabel: l10n.t('common.cancel'),
                                  confirmLabel: l10n.t('common.confirm'),
                                  busySetter: (value) =>
                                      setState(() => _clearBusy = value),
                                  action: () => ref
                                      .read(scanControllerProvider.notifier)
                                      .clearRefineForIps([widget.miner.ip], credential),
                                ),
                          icon: _clearBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cleaning_services_outlined),
                          label: Text(l10n.t('miner.clearRefine')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _rebootBusy
                              ? null
                              : () => _confirmAndRun(
                                  context: context,
                                  title: l10n.t('miner.rebootMiner'),
                                  message: l10n.t(
                                    'miner.rebootMinerMessage',
                                    params: {'ip': widget.miner.ip},
                                  ),
                                  cancelLabel: l10n.t('common.cancel'),
                                  confirmLabel: l10n.t('common.confirm'),
                                  busySetter: (value) =>
                                      setState(() => _rebootBusy = value),
                                  action: () => ref
                                      .read(scanControllerProvider.notifier)
                                      .rebootForIps([widget.miner.ip], credential),
                                ),
                          icon: _rebootBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.restart_alt),
                          label: Text(l10n.t('miner.rebootMiner')),
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
                            builder: (_) => PoolConfigPage(targetIps: [widget.miner.ip]),
                          ),
                        );
                      },
                      icon: const Icon(Icons.swap_horiz_outlined),
                      label: Text(l10n.t('miner.poolConfig')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ExpansionTile(
              title: Text(l10n.t('miner.kernelLog')),
              subtitle: Text(
                _logLoading
                    ? l10n.t('miner.kernelLogLoading')
                    : _kernelLogError != null
                        ? l10n.t('miner.kernelLogFailed')
                        : _kernelLog == null
                            ? l10n.t('miner.kernelLogCollapsed')
                            : l10n.t('miner.kernelLogReady'),
              ),
              initiallyExpanded: _logExpanded,
              onExpansionChanged: (expanded) {
                setState(() => _logExpanded = expanded);
                if (expanded) {
                  _loadKernelLog(credential, l10n);
                }
              },
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _buildLogContent(l10n),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogContent(AppLocalizer l10n) {
    if (_logLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_kernelLogError != null) {
      return Text(_kernelLogError!, style: const TextStyle(color: Colors.red));
    }
    final text = _kernelLog ?? l10n.t('miner.kernelLogPlaceholder');
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
      style: const TextStyle(backgroundColor: Color(0xFFFFF4F4)),
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
        .toggleLedForIp(widget.miner.ip, value, credential);
    if (!mounted) {
      return;
    }
    setState(() => _ledBusy = false);
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _refreshMiner(
    BuildContext context,
    MinerCredential credential,
    int concurrency,
    AppLocalizer l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _refreshBusy = true);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.t('miner.refreshing'))),
    );
    try {
      await ref.read(scanControllerProvider.notifier).refreshMinerIp(
            ip: widget.miner.ip,
            minerCredential: credential,
            concurrency: concurrency,
          );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.t('miner.refreshDone', params: {'ip': widget.miner.ip}),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.t('miner.refreshFailed', params: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _refreshBusy = false);
      }
    }
  }

  Future<void> _confirmAndRun({
    required BuildContext context,
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
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
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
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

  Future<void> _loadKernelLog(
    MinerCredential credential,
    AppLocalizer l10n,
  ) async {
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
          .getKernelLog(widget.miner.ip, credential);
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
        _kernelLogError =
            l10n.t('miner.kernelLogError', params: {'error': '$e'});
      });
    }
  }

  String _statusLabel(String value, AppLocalizer l10n) {
    return switch (value) {
      MinerRuntimeStatus.online => l10n.t('status.online'),
      MinerRuntimeStatus.offline => l10n.t('status.offline'),
      _ => value,
    };
  }
}
