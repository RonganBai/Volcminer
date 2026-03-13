import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/led_toggle_result.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';
import 'package:volcminer/domain/repositories/miner_repository.dart';

class ApplyPoolConfigUseCase {
  ApplyPoolConfigUseCase(this._repository);

  final MinerRepository _repository;

  Future<LedToggleResult> execute(
    List<String> ips,
    List<PoolSlotConfig> poolSlots,
    Map<int, String> slotPasswords,
    MinerCredential credential,
  ) {
    return _repository.applyPoolConfig(
      ips,
      poolSlots,
      slotPasswords,
      credential,
    );
  }
}
