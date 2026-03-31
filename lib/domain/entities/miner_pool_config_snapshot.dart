import 'package:volcminer/domain/entities/pool_slot_config.dart';

class MinerPoolConfigSnapshot {
  const MinerPoolConfigSnapshot({
    required this.poolSlots,
    required this.slotPasswords,
    required this.runningMode,
    required this.algorithm,
    required this.keepPower,
    required this.stopRunOnOverTemp,
    required this.fanCustomizeEnabled,
    required this.fanSpeedFront,
    required this.fanSpeedBack,
    required this.frequency,
    required this.voltageCustomizeValue,
    required this.memParam,
    required this.debugEnabled,
    required this.noBeeper,
  });

  final List<PoolSlotConfig> poolSlots;
  final Map<int, String> slotPasswords;
  final String runningMode;
  final String algorithm;
  final bool keepPower;
  final bool stopRunOnOverTemp;
  final bool fanCustomizeEnabled;
  final String fanSpeedFront;
  final String fanSpeedBack;
  final String frequency;
  final String voltageCustomizeValue;
  final String memParam;
  final bool debugEnabled;
  final String noBeeper;

  MinerPoolConfigSnapshot copyWith({
    List<PoolSlotConfig>? poolSlots,
    Map<int, String>? slotPasswords,
    String? runningMode,
    String? algorithm,
    bool? keepPower,
    bool? stopRunOnOverTemp,
    bool? fanCustomizeEnabled,
    String? fanSpeedFront,
    String? fanSpeedBack,
    String? frequency,
    String? voltageCustomizeValue,
    String? memParam,
    bool? debugEnabled,
    String? noBeeper,
  }) {
    return MinerPoolConfigSnapshot(
      poolSlots: poolSlots ?? this.poolSlots,
      slotPasswords: slotPasswords ?? this.slotPasswords,
      runningMode: runningMode ?? this.runningMode,
      algorithm: algorithm ?? this.algorithm,
      keepPower: keepPower ?? this.keepPower,
      stopRunOnOverTemp: stopRunOnOverTemp ?? this.stopRunOnOverTemp,
      fanCustomizeEnabled: fanCustomizeEnabled ?? this.fanCustomizeEnabled,
      fanSpeedFront: fanSpeedFront ?? this.fanSpeedFront,
      fanSpeedBack: fanSpeedBack ?? this.fanSpeedBack,
      frequency: frequency ?? this.frequency,
      voltageCustomizeValue:
          voltageCustomizeValue ?? this.voltageCustomizeValue,
      memParam: memParam ?? this.memParam,
      debugEnabled: debugEnabled ?? this.debugEnabled,
      noBeeper: noBeeper ?? this.noBeeper,
    );
  }
}
