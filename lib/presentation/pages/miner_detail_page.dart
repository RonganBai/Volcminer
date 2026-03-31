import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/core/utils/eastern_time_utils.dart';
import 'package:volcminer/domain/entities/app_settings.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/miner_issue_diagnosis.dart';
import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/entities/tracked_miner.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/localization/legacy_zh_texts.dart';
import 'package:volcminer/presentation/localization/issue_localizer.dart';
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
  bool _rediagnoseBusy = false;
  bool _hydratingDetails = false;
  bool _chainExpanded =
      !AppSettings.defaults.minerDetailChainsCollapsedByDefault;
  bool _logExpanded = !AppSettings.defaults.minerDetailLogsCollapsedByDefault;
  bool _detailPrefsApplied = false;
  bool _detailPrefsApplying = false;
  bool _logLoading = false;
  String? _kernelLog;
  String? _kernelLogError;
  final ScrollController _logVerticalController = ScrollController();
  final ScrollController _logHorizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateMinerDetailsIfNeeded();
    });
  }

  @override
  void dispose() {
    _logVerticalController.dispose();
    _logHorizontalController.dispose();
    super.dispose();
  }

  Future<void> _hydrateMinerDetailsIfNeeded() async {
    if (_hydratingDetails || !mounted) {
      return;
    }
    final currentMiner = ref.read(
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
    if (currentMiner.runtime.chains.isNotEmpty) {
      return;
    }
    final settingsState = ref.read(settingsControllerProvider);
    if (settingsState.serverUrl.trim().isEmpty) {
      return;
    }
    _hydratingDetails = true;
    try {
      await ref
          .read(scanControllerProvider.notifier)
          .refreshMinerIp(
            ip: widget.miner.ip,
            minerCredential: MinerCredential(
              username: settingsState.settings.minerUsername,
              password: settingsState.minerAuthPassword,
            ),
            concurrency: settingsState.settings.scanConcurrency,
            rediagnoseLog: false,
          );
    } catch (_) {
      // Keep the page usable even if the silent server refresh fails.
    } finally {
      _hydratingDetails = false;
    }
  }

  void _applyDetailPreferencesIfReady(
    MinerCredential credential,
    AppLocalizer l10n,
  ) {
    if (_detailPrefsApplied || _detailPrefsApplying) {
      return;
    }
    final settingsState = ref.read(settingsControllerProvider);
    if (settingsState.loading) {
      return;
    }
    _detailPrefsApplying = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _detailPrefsApplying = false;
      if (!mounted || _detailPrefsApplied) {
        return;
      }
      final latest = ref.read(settingsControllerProvider);
      if (latest.loading) {
        return;
      }
      final collapseChains =
          latest.settings.minerDetailChainsCollapsedByDefault;
      final collapseLogs = latest.settings.minerDetailLogsCollapsedByDefault;
      setState(() {
        _chainExpanded = !collapseChains;
        _logExpanded = !collapseLogs;
        _detailPrefsApplied = true;
      });
      if (!collapseLogs) {
        await _openKernelLog(credential, l10n);
      }
    });
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
    final settingsState = ref.watch(settingsControllerProvider);
    final runtime = currentMiner.runtime;
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
    final rediagnoseLabel = l10n.text(
      'Re-diagnose Log',
      LegacyZhTexts.rediagnoseDone,
    );
    final rediagnosingText = l10n.text(
      'Re-diagnosing miner log...',
      LegacyZhTexts.rediagnoseWorking,
    );
    final rediagnoseDoneText = l10n.text(
      'Miner log re-diagnosed',
      LegacyZhTexts.rediagnoseDone,
    );
    final rediagnoseFailedText = l10n.text(
      'Miner log re-diagnosis failed',
      LegacyZhTexts.rediagnoseFailed,
    );

    _applyDetailPreferencesIfReady(credential, l10n);

    return Scaffold(
      appBar: AppBar(
        title: Text(currentMiner.ip),
        actions: [
          IconButton(
            onPressed: () =>
                _confirmRetireMiner(context, currentMiner.ip, l10n),
            tooltip: l10n.t('miner.retire'),
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            onPressed: _rediagnoseBusy
                ? null
                : () => _rediagnoseMinerLog(
                    context,
                    credential,
                    rediagnosingText,
                    rediagnoseDoneText,
                    rediagnoseFailedText,
                  ),
            tooltip: rediagnoseLabel,
            icon: _rediagnoseBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fact_check_outlined),
          ),
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
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2F67D8,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.memory_rounded,
                          color: Color(0xFF2F67D8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          LegacyZhTexts.minerInfo,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(
                            runtime.onlineStatus,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _statusLabel(runtime.onlineStatus, l10n),
                          style: TextStyle(
                            color: _statusColor(runtime.onlineStatus),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.45,
                    children: [
                      _DetailMetricCard(
                        icon: Icons.flash_on_rounded,
                        label: LegacyZhTexts.minerFiveSecondHashrate,
                        value: runtime.ghs5s,
                        color: const Color(0xFF2F67D8),
                      ),
                      _DetailMetricCard(
                        icon: Icons.thermostat_rounded,
                        label: LegacyZhTexts.minerTemperature,
                        value: runtime.ambientTemp,
                        color: const Color(0xFFE07A14),
                      ),
                      _DetailMetricCard(
                        icon: Icons.air_rounded,
                        label: LegacyZhTexts.minerFan,
                        value: _fanSummary(runtime),
                        color: const Color(0xFF14A38B),
                      ),
                      _DetailMetricCard(
                        icon: Icons.tune_rounded,
                        label: LegacyZhTexts.minerRunningMode,
                        value: runtime.runningMode,
                        color: const Color(0xFF6F748B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    LegacyZhTexts.minerUpdatedAt,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF6F748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.update_rounded,
                        size: 16,
                        color: Color(0xFF6F748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        EasternTimeUtils.format(
                          runtime.fetchedAt,
                          pattern: 'yyyy-MM-dd HH:mm:ss',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildChainStatusCard(
            context,
            runtime,
            currentMiner.diagnosis,
            expanded: _chainExpanded,
            onToggle: () => setState(() => _chainExpanded = !_chainExpanded),
          ),
          if (currentMiner.diagnosis != null) ...[
            const SizedBox(height: 12),
            _buildDiagnosisCard(context, l10n, currentMiner.diagnosis!),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0F8B6D,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Color(0xFF0F8B6D),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.t('miner.indicatorSwitch'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _ledBusy
                                  ? l10n.t('miner.sendingCommand')
                                  : l10n.t('miner.indicatorHint'),
                              style: const TextStyle(
                                color: Color(0xFF6F748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: ledOn,
                        onChanged: _ledBusy
                            ? null
                            : (value) => _toggleLed(context, credential, value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailActionButton(
                          label: l10n.t('miner.clearRefine'),
                          icon: Icons.cleaning_services_outlined,
                          outlined: true,
                          busy: _clearBusy,
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
                                      .clearRefineForIps([
                                        widget.miner.ip,
                                      ], credential),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DetailActionButton(
                          label: l10n.t('miner.rebootMiner'),
                          icon: Icons.restart_alt,
                          busy: _rebootBusy,
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
                                      .rebootForIps([
                                        widget.miner.ip,
                                      ], credential),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _DetailActionButton(
                    label: l10n.t('miner.poolConfig'),
                    icon: Icons.swap_horiz_outlined,
                    fullWidth: true,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PoolConfigPage(targetIps: [widget.miner.ip]),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      final expanded = !_logExpanded;
                      setState(() => _logExpanded = expanded);
                      if (expanded) {
                        unawaited(_openKernelLog(credential, l10n));
                      }
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF6F748B,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            color: Color(0xFF6F748B),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.t('miner.kernelLog'),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _logLoading
                                    ? l10n.t('miner.kernelLogLoading')
                                    : _kernelLogError != null
                                    ? l10n.t('miner.kernelLogFailed')
                                    : _kernelLog == null
                                    ? l10n.t('miner.kernelLogCollapsed')
                                    : l10n.t('miner.kernelLogReady'),
                                style: const TextStyle(
                                  color: Color(0xFF6F748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: _logExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF6F748B),
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_logExpanded) ...[
                    const SizedBox(height: 14),
                    _buildLogContent(l10n),
                  ],
                ],
              ),
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
    messenger.showSnackBar(SnackBar(content: Text(l10n.t('miner.refreshing'))));
    try {
      final refreshed = await ref
          .read(scanControllerProvider.notifier)
          .refreshMinerIp(
            ip: widget.miner.ip,
            minerCredential: credential,
            concurrency: concurrency,
            rediagnoseLog: true,
          );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            refreshed
                ? l10n.t('miner.refreshDone', params: {'ip': widget.miner.ip})
                : l10n.t('miner.refreshFailed', params: {'error': 'timeout'}),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.t('miner.refreshFailed', params: {'error': '$e'})),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _refreshBusy = false);
      }
    }
  }

  Future<void> _rediagnoseMinerLog(
    BuildContext context,
    MinerCredential credential,
    String workingText,
    String successText,
    String failureText,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _rediagnoseBusy = true);
    messenger.showSnackBar(SnackBar(content: Text(workingText)));
    try {
      final rediagnosed = await ref
          .read(scanControllerProvider.notifier)
          .rediagnoseMinerLog(ip: widget.miner.ip, minerCredential: credential);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            rediagnosed
                ? '$successText: ${widget.miner.ip}'
                : '$failureText: no diagnosis',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('$failureText: $e')));
    } finally {
      if (mounted) {
        setState(() => _rediagnoseBusy = false);
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
        _kernelLogError = l10n.t(
          'miner.kernelLogError',
          params: {'error': '$e'},
        );
      });
    }
  }

  Future<void> _openKernelLog(
    MinerCredential credential,
    AppLocalizer l10n,
  ) async {
    if (!mounted) {
      return;
    }
    if (!_logExpanded) {
      setState(() => _logExpanded = true);
    }
    await _loadKernelLog(credential, l10n);
    if (!mounted) {
      return;
    }
    final settingsState = ref.read(settingsControllerProvider);
    await ref
        .read(scanControllerProvider.notifier)
        .refreshMinerIp(
          ip: widget.miner.ip,
          minerCredential: credential,
          concurrency: settingsState.settings.scanConcurrency,
          rediagnoseLog: true,
        );
  }

  String _statusLabel(String value, AppLocalizer l10n) {
    return switch (value) {
      MinerRuntimeStatus.online => l10n.t('status.online'),
      MinerRuntimeStatus.offline => l10n.t('status.offline'),
      _ => value,
    };
  }

  Color _statusColor(String value) {
    return switch (value) {
      MinerRuntimeStatus.online => const Color(0xFF2EAF62),
      MinerRuntimeStatus.offline => const Color(0xFFE15B64),
      _ => const Color(0xFFF0A21C),
    };
  }

  Widget _buildChainStatusCard(
    BuildContext context,
    MinerRuntime runtime,
    MinerIssueDiagnosis? diagnosis, {
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    final List<MinerChainStatus> chains = [...runtime.chains]
      ..sort((a, b) => a.index.compareTo(b.index));
    final double maxRate = chains
        .map((chain) => chain.chainRateValue)
        .fold<double>(0, (prev, value) => value > prev ? value : prev);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onToggle,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E5CF7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.developer_board_rounded,
                      color: Color(0xFF8E5CF7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '运算板状态',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          expanded ? '点击收起运算板状态' : '点击展开运算板状态',
                          style: const TextStyle(
                            color: Color(0xFF6F748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF6F748B),
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 2, child: _ChainHeader(label: '运算板')),
                    Expanded(flex: 4, child: _ChainHeader(label: '频率')),
                    Expanded(flex: 4, child: _ChainHeader(label: '实时算力')),
                    Expanded(flex: 3, child: _ChainHeader(label: '温度')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (chains.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE6E8EF)),
                  ),
                  child: const Text(
                    '暂无运算板状态数据',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6F748B),
                    ),
                  ),
                )
              else
                for (var i = 0; i < chains.length; i++) ...[
                  _ChainStatusRow(
                    chain: chains[i],
                    isAbnormal: _isChainAbnormal(
                      chain: chains[i],
                      diagnosis: diagnosis,
                      maxRate: maxRate,
                    ),
                  ),
                  if (i != chains.length - 1) const SizedBox(height: 8),
                ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosisCard(
    BuildContext context,
    AppLocalizer l10n,
    MinerIssueDiagnosis diagnosis,
  ) {
    final accent = _diagnosisAccentColor(diagnosis);
    final snippet = IssueLocalizer.snippetSummary(l10n, diagnosis);
    final secondaryReason = IssueLocalizer.secondaryReason(l10n, diagnosis);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _diagnosisIcon(diagnosis),
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('miner.issueCardTitle'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.t(
                          'miner.issueCode',
                          params: {'code': diagnosis.code},
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF4A5161),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _IssueDetailLine(
              label: l10n.t('miner.issueReason'),
              value: IssueLocalizer.reason(l10n, diagnosis),
              accent: accent,
            ),
            const SizedBox(height: 10),
            _IssueDetailLine(
              label: l10n.t('miner.issueSolution'),
              value: IssueLocalizer.solution(l10n, diagnosis),
              accent: accent,
            ),
            if (snippet != null) ...[
              const SizedBox(height: 10),
              _IssueDetailLine(
                label: l10n.text('Location hint', '瀹氫綅鎻愮ず'),
                value: snippet,
                accent: accent,
              ),
            ],
            if (secondaryReason != null) ...[
              const SizedBox(height: 10),
              _IssueDetailLine(
                label: l10n.t('miner.issueSecondary'),
                value: secondaryReason,
                accent: accent,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fanSummary(MinerRuntime runtime) {
    final fans = [
      runtime.fan1,
      runtime.fan2,
      runtime.fan3,
      runtime.fan4,
    ].where((fan) => fan.trim().isNotEmpty && fan.trim() != '--').toList();
    if (fans.isEmpty) {
      return '--';
    }
    return fans.join(' / ');
  }

  bool _isChainAbnormal({
    required MinerChainStatus chain,
    required MinerIssueDiagnosis? diagnosis,
    required double maxRate,
  }) {
    return chain.chainRateValue <= 0;
  }

  Color _diagnosisAccentColor(MinerIssueDiagnosis diagnosis) {
    return switch (diagnosis.category) {
      'power' => const Color(0xFFD95050),
      'fan' => const Color(0xFF0F8B6D),
      'temperature' => const Color(0xFFD77700),
      'all_board_failure' => const Color(0xFFD95050),
      'hashboard' => const Color(0xFF8E5CF7),
      'zero_hash' => const Color(0xFF2F67D8),
      _ => const Color(0xFFD77700),
    };
  }

  IconData _diagnosisIcon(MinerIssueDiagnosis diagnosis) {
    return switch (diagnosis.category) {
      'power' => Icons.power_settings_new_rounded,
      'fan' => Icons.toys_rounded,
      'temperature' => Icons.thermostat_rounded,
      'all_board_failure' => Icons.memory_rounded,
      'hashboard' => Icons.developer_board_rounded,
      'zero_hash' => Icons.bolt_rounded,
      _ => Icons.warning_amber_rounded,
    };
  }

  Future<void> _confirmRetireMiner(
    BuildContext context,
    String ip,
    AppLocalizer l10n,
  ) async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.t('miner.retire')),
          content: Text(l10n.t('miner.retireMessage', params: {'ip': ip})),
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
    if (confirmed != true || !mounted) {
      return;
    }

    await ref.read(scanControllerProvider.notifier).removeMinerByIp(ip);
    if (!mounted) {
      return;
    }
    navigator.pop();
  }
}

class _DetailMetricCard extends StatelessWidget {
  const _DetailMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A5161),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChainHeader extends StatelessWidget {
  const _ChainHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4A5161),
      ),
    );
  }
}

class _IssueDetailLine extends StatelessWidget {
  const _IssueDetailLine({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF4A5161),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF6F748B),
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ChainStatusRow extends StatelessWidget {
  const _ChainStatusRow({required this.chain, required this.isAbnormal});

  final MinerChainStatus chain;
  final bool isAbnormal;

  @override
  Widget build(BuildContext context) {
    final Color accent = isAbnormal
        ? const Color(0xFFD95050)
        : const Color(0xFF2F67D8);
    final int displayIndex = chain.index == 0 ? 1 : chain.index;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isAbnormal ? const Color(0xFFFFF4F4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAbnormal ? const Color(0xFFFFD7D7) : const Color(0xFFE6E8EF),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              displayIndex.toString(),
              style: TextStyle(fontWeight: FontWeight.w700, color: accent),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              _displayFrequency(chain.freq),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              chain.chainRate,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              chain.temp,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _displayFrequency(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  final int asciiParenIndex = trimmed.indexOf('(');
  final int fullWidthParenIndex = trimmed.indexOf('（');
  final int cutIndex =
      [
        if (asciiParenIndex >= 0) asciiParenIndex,
        if (fullWidthParenIndex >= 0) fullWidthParenIndex,
      ].fold<int>(
        trimmed.length,
        (current, next) => next < current ? next : current,
      );

  return trimmed.substring(0, cutIndex).trim();
}

class _DetailActionButton extends StatelessWidget {
  const _DetailActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.outlined = false,
    this.fullWidth = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool outlined;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style =
        (outlined ? OutlinedButton.styleFrom() : FilledButton.styleFrom())
            .copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            );

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );

    final button = outlined
        ? OutlinedButton(onPressed: onPressed, style: style, child: child)
        : FilledButton(onPressed: onPressed, style: style, child: child);

    if (!fullWidth) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}
