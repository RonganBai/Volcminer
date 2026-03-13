import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/repositories/miner_repository.dart';

class FetchMinerDetailUseCase {
  FetchMinerDetailUseCase(this._repository);

  final MinerRepository _repository;

  Future<MinerRuntime> getRuntime(
    String ip,
    MinerCredential credential, {
    bool collectLog = true,
  }) {
    return _repository.getRuntime(ip, credential, collectLog: collectLog);
  }

  Future<String> getKernelLog(String ip, MinerCredential credential) {
    return _repository.getKernelLog(ip, credential);
  }
}
