import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/miner_pool_config_snapshot.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class MultiPoolConfigPage extends ConsumerStatefulWidget {
  const MultiPoolConfigPage({
    super.key,
    required this.targetIps,
  });

  final List<String> targetIps;

  @override
  ConsumerState<MultiPoolConfigPage> createState() =>
      _MultiPoolConfigPageState();
}

class _MultiPoolConfigPageState extends ConsumerState<MultiPoolConfigPage> {
  final Map<int, String?> _selectedSubAccounts = {1: null, 2: null, 3: null};
  final Map<int, String?> _selectedMiningUrls = {1: null, 2: null, 3: null};
  bool _applyBusy = false;
  String _runningMode = '0';

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsControllerProvider);
    final l10n = AppLocalizer(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('pool.multiTitle')),
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2F67D8).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.hub_rounded,
                          color: Color(0xFF2F67D8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.t(
                            'pool.targetMulti',
                            params: {'count': widget.targetIps.length.toString()},
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.t('pool.multiHintDetailed'),
                    style: const TextStyle(
                      color: Color(0xFF6F748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('pool.runningModeTitle'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _runningMode,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '0',
                        child: Text('0 ${l10n.t('pool.mode.normal')}'),
                      ),
                      DropdownMenuItem(
                        value: '1',
                        child: Text('1 ${l10n.t('pool.mode.overclock')}'),
                      ),
                      DropdownMenuItem(
                        value: '2',
                        child: Text('2 ${l10n.t('pool.mode.custom')}'),
                      ),
                      DropdownMenuItem(
                        value: '3',
                        child: Text('3 ${l10n.t('pool.mode.debug')}'),
                      ),
                      DropdownMenuItem(
                        value: '4',
                        child: Text('4 ${l10n.t('pool.mode.lowPower')}'),
                      ),
                      DropdownMenuItem(
                        value: '5',
                        child: Text('5 ${l10n.t('pool.mode.superLowPower')}'),
                      ),
                      DropdownMenuItem(
                        value: '6',
                        child: Text('6 ${l10n.t('pool.mode.sleep')}'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _runningMode = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final slotNo in [1, 2, 3]) ...[
            _BatchPoolSlotCard(
              slotNo: slotNo,
              l10n: l10n,
              selectedSubAccount: _selectedSubAccounts[slotNo],
              selectedMiningUrl: _selectedMiningUrls[slotNo],
              subAccounts: settingsState.settings.subAccounts,
              miningUrls: settingsState.settings.miningUrls,
              firstTargetIp: widget.targetIps.first,
              onSubAccountChanged: (value) =>
                  setState(() => _selectedSubAccounts[slotNo] = value),
              onMiningUrlChanged: (value) =>
                  setState(() => _selectedMiningUrls[slotNo] = value),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _applyBusy ? null : () => _apply(context, l10n),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _applyBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.t('pool.multiApply')),
          ),
        ],
      ),
    );
  }

  Future<void> _apply(BuildContext context, AppLocalizer l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final settingsState = ref.read(settingsControllerProvider);

    if (settingsState.settings.subAccounts.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.t('pool.needSubAccount'))),
      );
      return;
    }
    if (settingsState.settings.miningUrls.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.t('pool.needMiningUrl'))),
      );
      return;
    }

    final poolSlots = [1, 2, 3]
        .map(
          (slotNo) => PoolSlotConfig(
            slotNo: slotNo,
            poolUrl: (_selectedMiningUrls[slotNo] ?? '').trim(),
            workerCode: (_selectedSubAccounts[slotNo] ?? '').trim(),
          ),
        )
        .where((slot) => slot.poolUrl.isNotEmpty && slot.workerCode.isNotEmpty)
        .toList(growable: false);

    if (poolSlots.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.t('pool.fillOneSlot'))),
      );
      return;
    }

    final snapshot = MinerPoolConfigSnapshot(
      poolSlots: poolSlots,
      slotPasswords: {
        for (final slot in poolSlots)
          slot.slotNo:
              (settingsState.slotPasswords[slot.slotNo] ?? '123').trim().isEmpty
                  ? '123'
                  : (settingsState.slotPasswords[slot.slotNo] ?? '123').trim(),
      },
      runningMode: _runningMode,
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

    final credential = MinerCredential(
      username: settingsState.settings.minerUsername,
      password: settingsState.minerAuthPassword,
    );

    setState(() => _applyBusy = true);
    final result = await ref
        .read(scanControllerProvider.notifier)
        .applyPoolConfigTemplateForIps(
          widget.targetIps,
          snapshot,
          (ip, slotNo) =>
              _buildWorkerName(_selectedSubAccounts[slotNo] ?? '', ip),
          credential,
        );
    if (!mounted) {
      return;
    }
    setState(() => _applyBusy = false);
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }

  String _buildWorkerName(String subAccount, String ip) {
    final suffix = ip.replaceAll('.', 'x');
    return '$subAccount.$suffix';
  }
}

class _BatchPoolSlotCard extends StatelessWidget {
  const _BatchPoolSlotCard({
    required this.slotNo,
    required this.l10n,
    required this.selectedSubAccount,
    required this.selectedMiningUrl,
    required this.subAccounts,
    required this.miningUrls,
    required this.firstTargetIp,
    required this.onSubAccountChanged,
    required this.onMiningUrlChanged,
  });

  final int slotNo;
  final AppLocalizer l10n;
  final String? selectedSubAccount;
  final String? selectedMiningUrl;
  final List<String> subAccounts;
  final List<String> miningUrls;
  final String firstTargetIp;
  final ValueChanged<String?> onSubAccountChanged;
  final ValueChanged<String?> onMiningUrlChanged;

  @override
  Widget build(BuildContext context) {
    final preview = selectedSubAccount == null || selectedSubAccount!.isEmpty
        ? '--'
        : '${selectedSubAccount!}.${firstTargetIp.replaceAll('.', 'x')}';
    final selectedSubAccountText =
        (selectedSubAccount == null || selectedSubAccount!.isEmpty)
            ? l10n.t('pool.pickSubAccount')
            : selectedSubAccount!;
    final selectedMiningUrlText =
        (selectedMiningUrl == null || selectedMiningUrl!.isEmpty)
            ? l10n.t('pool.pickMiningUrl')
            : selectedMiningUrl!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('pool.slotTitle', params: {'slot': '$slotNo'}),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            _SelectorCard(
              icon: Icons.person_outline_rounded,
              label: l10n.t('pool.subAccount'),
              value: selectedSubAccountText,
              isPlaceholder: selectedSubAccount == null || selectedSubAccount!.isEmpty,
              accentColor: const Color(0xFF2F67D8),
              onTap: () => _showSelectionSheet(
                context,
                title: l10n.t('pool.pickSubAccount'),
                items: subAccounts,
                selectedValue: selectedSubAccount,
                onSelected: onSubAccountChanged,
              ),
            ),
            const SizedBox(height: 10),
            _SelectorCard(
              icon: Icons.link_rounded,
              label: l10n.t('pool.miningUrl'),
              value: selectedMiningUrlText,
              isPlaceholder: selectedMiningUrl == null || selectedMiningUrl!.isEmpty,
              accentColor: const Color(0xFF0F9D8A),
              onTap: () => _showSelectionSheet(
                context,
                title: l10n.t('pool.pickMiningUrl'),
                items: miningUrls,
                selectedValue: selectedMiningUrl,
                onSelected: onMiningUrlChanged,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('pool.workerPreview'),
                    style: const TextStyle(
                      color: Color(0xFF6F748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSelectionSheet(
    BuildContext context, {
    required String title,
    required List<String> items,
    required String? selectedValue,
    required ValueChanged<String?> onSelected,
  }) async {
    if (items.isEmpty) {
      return;
    }
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9DFEA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final bool isSelected = item == selectedValue;
                      return Material(
                        color: isSelected
                            ? const Color(0xFFEEF4FF)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).pop(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: const Color(0xFF30343F),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 20,
                                  color: isSelected
                                      ? const Color(0xFF2F67D8)
                                      : const Color(0xFF9AA3B6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) {
      onSelected(picked);
    }
  }
}

class _SelectorCard extends StatelessWidget {
  const _SelectorCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.isPlaceholder,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isPlaceholder;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6F748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: isPlaceholder
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: isPlaceholder
                            ? const Color(0xFF8E97A8)
                            : const Color(0xFF30343F),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF7A8397),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
