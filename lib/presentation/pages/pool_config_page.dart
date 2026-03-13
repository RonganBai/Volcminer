import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';
import 'package:volcminer/presentation/controllers/settings_controller.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class PoolConfigPage extends ConsumerStatefulWidget {
  const PoolConfigPage({super.key, this.targetIps = const []});

  final List<String> targetIps;

  bool get isApplyMode => targetIps.isNotEmpty;
  bool get isSingleTarget => targetIps.length == 1;

  @override
  ConsumerState<PoolConfigPage> createState() => _PoolConfigPageState();
}

class _PoolConfigPageState extends ConsumerState<PoolConfigPage> {
  bool _applyBusy = false;
  bool _loadingCurrentConfig = false;
  bool _initialized = false;
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
        title: Text(widget.isApplyMode ? 'Apply Pool Config' : 'Pool Config'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.isApplyMode) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.targetIps.length == 1
                          ? 'Target: ${widget.targetIps.first}'
                          : 'Targets: ${widget.targetIps.length} miners',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.targetIps.length == 1
                          ? 'The pool fields below are loaded from the current miner first.'
                          : 'Edit the pool slots below, then apply them to the selected miners.',
                    ),
                    if (_loadingCurrentConfig) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Pool Slots',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final slotNo in [1, 2, 3]) _buildPoolSlotCard(context, slotNo),
          if (widget.isApplyMode) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _applyBusy ? null : () => _applyToTargets(context),
              icon: _applyBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                _applyBusy
                    ? 'Applying...'
                    : widget.targetIps.length == 1
                    ? 'Apply to Miner'
                    : 'Apply to Selected Miners',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPoolSlotCard(BuildContext context, int slotNo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pool Slot $slotNo',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlControllers[slotNo],
              decoration: const InputDecoration(
                labelText: 'Pool URL',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _persistSlot(slotNo),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _workerControllers[slotNo],
              decoration: const InputDecoration(
                labelText: 'Worker Code',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _persistSlot(slotNo),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordControllers[slotNo],
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
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
      for (final slot in snapshot.poolSlots) {
        _urlControllers[slot.slotNo]!.text = slot.poolUrl;
        _workerControllers[slot.slotNo]!.text = slot.workerCode;
        _passwordControllers[slot.slotNo]!.text =
            snapshot.slotPasswords[slot.slotNo] ?? '';
      }
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

  Future<void> _applyToTargets(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final poolSlots = _currentPoolSlots();
    final slotPasswords = _currentSlotPasswords();
    if (!_hasConfiguredPool(poolSlots)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please fill at least one pool slot first.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final count = widget.targetIps.length;
        return AlertDialog(
          title: const Text('Confirm Pool Switch'),
          content: Text(
            count == 1
                ? 'Apply the current pool configuration to ${widget.targetIps.first}?'
                : 'Apply the current pool configuration to $count selected miners?',
          ),
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
          poolSlots,
          slotPasswords,
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

  bool _hasConfiguredPool(List<PoolSlotConfig> slots) {
    return slots.any(
      (slot) =>
          slot.poolUrl.trim().isNotEmpty || slot.workerCode.trim().isNotEmpty,
    );
  }
}
