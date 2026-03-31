import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/miner_pool_config_snapshot.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';
import 'package:volcminer/presentation/controllers/settings_controller.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class PoolConfigPage extends ConsumerStatefulWidget {
  const PoolConfigPage({super.key, this.targetIps = const []});

  final List<String> targetIps;

  bool get isApplyMode => targetIps.length > 1;
  bool get isSingleTarget => targetIps.length == 1;

  @override
  ConsumerState<PoolConfigPage> createState() => _PoolConfigPageState();
}

class _PoolConfigPageState extends ConsumerState<PoolConfigPage> {
  static const List<String> _runningModeValues = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
  ];

  bool _applyBusy = false;
  bool _loadingCurrentConfig = false;
  bool _initialized = false;
  String _runningMode = '0';
  MinerPoolConfigSnapshot? _loadedSnapshot;
  final Map<int, TextEditingController> _urlControllers = {
    1: TextEditingController(),
    2: TextEditingController(),
    3: TextEditingController(),
  };
  final Map<int, TextEditingController> _workerControllers = {
    1: TextEditingController(),
    2: TextEditingController(),
    3: TextEditingController(),
  };
  final Map<int, TextEditingController> _passwordControllers = {
    1: TextEditingController(),
    2: TextEditingController(),
    3: TextEditingController(),
  };

  @override
  void dispose() {
    for (final controller in _urlControllers.values) {
      controller.dispose();
    }
    for (final controller in _workerControllers.values) {
      controller.dispose();
    }
    for (final controller in _passwordControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsControllerProvider);
    final l10n = AppLocalizer(ref);
    if (!_initialized) {
      _syncControllersFromSettings(settingsState);
      _initialized = true;
      if (widget.isSingleTarget) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadCurrentMinerConfig();
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isApplyMode ? l10n.t('pool.applyTitle') : l10n.t('pool.title'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(context, l10n),
          const SizedBox(height: 8),
          _buildSectionLabel(context, l10n.t('pool.runningModeTitle')),
          const SizedBox(height: 8),
          _buildRunningModeCard(context, l10n),
          const SizedBox(height: 14),
          _buildSectionLabel(context, l10n.t('pool.slots')),
          const SizedBox(height: 8),
          for (final slotNo in [1, 2, 3]) _buildPoolSlotCard(context, slotNo, l10n),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: _applyBusy ? null : () => _applyToTargets(context, l10n),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_applyBusy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(Icons.cloud_upload_outlined),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _applyBusy
                        ? l10n.t('pool.applying')
                        : widget.targetIps.length == 1
                            ? l10n.t('pool.applySingle')
                            : l10n.t('pool.applyMulti'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, AppLocalizer l10n) {
    return Card(
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
                    color: const Color(0xFF2F67D8).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF2F67D8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.isApplyMode
                        ? l10n.t('pool.applyTitle')
                        : l10n.t('pool.title'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.targetIps.length == 1
                  ? l10n.t(
                      'pool.targetSingle',
                      params: {'ip': widget.targetIps.first},
                    )
                  : l10n.t(
                      'pool.targetMulti',
                      params: {'count': widget.targetIps.length.toString()},
                    ),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.targetIps.length == 1
                  ? l10n.t('pool.singleHint')
                  : l10n.t('pool.multiHint'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6F748B),
                    height: 1.4,
                  ),
            ),
            if (_loadingCurrentConfig) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const LinearProgressIndicator(minHeight: 5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _buildRunningModeCard(BuildContext context, AppLocalizer l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6F748B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF6F748B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.t('pool.runningModeSubtitle'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6F748B),
                          height: 1.35,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _runningModeValues
                  .map((value) => _buildRunningModeChip(context, l10n, value))
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunningModeChip(
    BuildContext context,
    AppLocalizer l10n,
    String value,
  ) {
    final bool selected = _runningMode == value;
    return ChoiceChip(
      label: Text(
        _runningModeLabel(l10n, value),
        overflow: TextOverflow.ellipsis,
      ),
      selected: selected,
      onSelected: (_) => setState(() => _runningMode = value),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF2F67D8) : const Color(0xFF333333),
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF2F67D8).withValues(alpha: 0.12),
      side: BorderSide(
        color: selected
            ? const Color(0xFF2F67D8)
            : const Color(0xFFD8DCE6),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -1.5, vertical: -1.5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  Widget _buildPoolSlotCard(
    BuildContext context,
    int slotNo,
    AppLocalizer l10n,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14A38B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.hub_rounded,
                    color: Color(0xFF14A38B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.t('pool.slotTitle', params: {'slot': '$slotNo'}),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlControllers[slotNo],
              decoration: InputDecoration(
                labelText: l10n.t('pool.url'),
                prefixIcon: const Icon(Icons.link_rounded),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _persistSlot(slotNo),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _workerControllers[slotNo],
              decoration: InputDecoration(
                labelText: l10n.t('pool.workerCode'),
                prefixIcon: const Icon(Icons.badge_rounded),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _persistSlot(slotNo),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordControllers[slotNo],
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.t('pool.password'),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _persistSlot(slotNo),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadCurrentMinerConfig() async {
    if (_loadingCurrentConfig || !widget.isSingleTarget) {
      return;
    }
    setState(() => _loadingCurrentConfig = true);
    final settingsState = ref.read(settingsControllerProvider);
    final credential = MinerCredential(
      username: settingsState.settings.minerUsername,
      password: settingsState.minerAuthPassword,
    );
    final snapshot = await ref
        .read(minerLocalDataSourceProvider)
        .fetchPoolConfig(widget.targetIps.first, credential);
    if (!mounted) {
      return;
    }
    if (snapshot != null) {
      _loadedSnapshot = snapshot;
      for (final slot in snapshot.poolSlots) {
        _urlControllers[slot.slotNo]!.text = slot.poolUrl;
        _workerControllers[slot.slotNo]!.text = slot.workerCode;
        _passwordControllers[slot.slotNo]!.text =
            snapshot.slotPasswords[slot.slotNo] ?? '';
      }
      _runningMode = snapshot.runningMode;
      final notifier = ref.read(settingsControllerProvider.notifier);
      for (final slot in snapshot.poolSlots) {
        await notifier.updatePoolSlot(slot);
        await notifier.saveSlotPassword(
          slot.slotNo,
          snapshot.slotPasswords[slot.slotNo] ?? '',
        );
      }
    }
    setState(() => _loadingCurrentConfig = false);
  }

  Future<void> _applyToTargets(BuildContext context, AppLocalizer l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final snapshot = _currentSnapshot();
    final poolSlots = snapshot.poolSlots;
    if (!_hasConfiguredPool(poolSlots)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.t('pool.fillOneSlot'))),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final count = widget.targetIps.length;
        return AlertDialog(
          title: Text(l10n.t('pool.confirmSwitch')),
          content: Text(
            count == 1
                ? l10n.t(
                    'pool.confirmSwitchSingle',
                    params: {'ip': widget.targetIps.first},
                  )
                : l10n.t(
                    'pool.confirmSwitchMulti',
                    params: {'count': '$count'},
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

    setState(() => _applyBusy = true);
    final settingsState = ref.read(settingsControllerProvider);
    final credential = MinerCredential(
      username: settingsState.settings.minerUsername,
      password: settingsState.minerAuthPassword,
    );
    final result = await ref
        .read(scanControllerProvider.notifier)
        .applyPoolConfigForIps(
          widget.targetIps,
          snapshot,
          credential,
        );
    if (!mounted) {
      return;
    }
    setState(() => _applyBusy = false);
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }

  void _syncControllersFromSettings(SettingsState settingsState) {
    for (final slot in settingsState.poolSlots) {
      _urlControllers[slot.slotNo]!.text = slot.poolUrl;
      _workerControllers[slot.slotNo]!.text = slot.workerCode;
      _passwordControllers[slot.slotNo]!.text =
          settingsState.slotPasswords[slot.slotNo] ?? '';
    }
  }

  void _persistSlot(int slotNo) {
    ref.read(settingsControllerProvider.notifier).updatePoolSlot(
          PoolSlotConfig(
            slotNo: slotNo,
            poolUrl: _urlControllers[slotNo]!.text,
            workerCode: _workerControllers[slotNo]!.text,
          ),
        );
    ref
        .read(settingsControllerProvider.notifier)
        .saveSlotPassword(slotNo, _passwordControllers[slotNo]!.text);
  }

  List<PoolSlotConfig> _currentPoolSlots() {
    return [1, 2, 3]
        .map(
          (slotNo) => PoolSlotConfig(
            slotNo: slotNo,
            poolUrl: _urlControllers[slotNo]!.text.trim(),
            workerCode: _workerControllers[slotNo]!.text.trim(),
          ),
        )
        .toList(growable: false);
  }

  Map<int, String> _currentSlotPasswords() {
    return {
      for (final slotNo in [1, 2, 3])
        slotNo: _passwordControllers[slotNo]!.text.trim(),
    };
  }

  MinerPoolConfigSnapshot _currentSnapshot() {
    final base = _loadedSnapshot ??
        MinerPoolConfigSnapshot(
          poolSlots: const [],
          slotPasswords: const {},
          runningMode: '0',
          algorithm: 'ltc',
          keepPower: false,
          stopRunOnOverTemp: true,
          fanCustomizeEnabled: false,
          fanSpeedFront: '',
          fanSpeedBack: '',
          frequency: '2200',
          voltageCustomizeValue: '',
          memParam: '3',
          debugEnabled: false,
          noBeeper: '',
        );
    return base.copyWith(
      poolSlots: _currentPoolSlots(),
      slotPasswords: _currentSlotPasswords(),
      runningMode: _runningMode,
    );
  }

  bool _hasConfiguredPool(List<PoolSlotConfig> slots) {
    return slots.any(
      (slot) =>
          slot.poolUrl.trim().isNotEmpty || slot.workerCode.trim().isNotEmpty,
    );
  }

  String _runningModeLabel(AppLocalizer l10n, String value) {
    switch (value) {
      case '0':
        return l10n.t('pool.mode.normal');
      case '1':
        return l10n.t('pool.mode.overclock');
      case '2':
        return l10n.t('pool.mode.custom');
      case '3':
        return l10n.t('pool.mode.debug');
      case '4':
        return l10n.t('pool.mode.lowPower');
      case '5':
        return l10n.t('pool.mode.superLowPower');
      case '6':
        return l10n.t('pool.mode.sleep');
      default:
        return value;
    }
  }
}
