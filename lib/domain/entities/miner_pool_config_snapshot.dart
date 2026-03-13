import 'package:volcminer/domain/entities/pool_slot_config.dart';

class MinerPoolConfigSnapshot {
  const MinerPoolConfigSnapshot({
    required this.poolSlots,
    required this.slotPasswords,
  });

  final List<PoolSlotConfig> poolSlots;
  final Map<int, String> slotPasswords;
}
