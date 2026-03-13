import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/led_toggle_result.dart';
import 'package:volcminer/domain/repositories/miner_repository.dart';

class RebootMinerUseCase {
  RebootMinerUseCase(this._repository);

  final MinerRepository _repository;

  Future<LedToggleResult> execute(
    List<String> ips,
    MinerCredential credential,
  ) {
    return _repository.reboot(ips, credential);
  }
}
