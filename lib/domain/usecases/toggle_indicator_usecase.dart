import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/led_toggle_result.dart';
import 'package:volcminer/domain/repositories/miner_repository.dart';

class ToggleIndicatorUseCase {
  ToggleIndicatorUseCase(this._repository);

  final MinerRepository _repository;

  Future<LedToggleResult> execute(
    List<String> ips,
    bool on,
    MinerCredential credential,
  ) {
    return _repository.toggleLed(ips, on, credential);
  }
}
