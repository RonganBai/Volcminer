import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/led_toggle_result.dart';
import 'package:volcminer/domain/entities/miner_pool_config_snapshot.dart';
import 'package:volcminer/domain/repositories/miner_repository.dart';

class ApplyPoolConfigUseCase {
  ApplyPoolConfigUseCase(this._repository);

  final MinerRepository _repository;

  Future<LedToggleResult> execute(
    List<String> ips,
    MinerPoolConfigSnapshot snapshot,
    MinerCredential credential,
  ) {
    return _repository.applyPoolConfig(
      ips,
      snapshot,
      credential,
    );
  }
}
