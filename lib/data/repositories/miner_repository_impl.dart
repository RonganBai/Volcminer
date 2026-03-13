import 'package:volcminer/data/datasources/miner_local_data_source.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/led_toggle_result.dart';
import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';
import 'package:volcminer/domain/repositories/miner_repository.dart';

class MinerRepositoryImpl implements MinerRepository {
  MinerRepositoryImpl(this._local);

  final MinerLocalDataSource _local;

  @override
  Future<String> getKernelLog(String ip, MinerCredential credential) {
    return _local.fetchKernelLog(ip, credential);
  }

  @override
  Future<MinerRuntime> getRuntime(
    String ip,
    MinerCredential credential, {
    bool collectLog = true,
  }) {
    return _local.fetchRuntime(ip, credential, collectLog: collectLog);
  }

  @override
  Future<LedToggleResult> toggleLed(
    List<String> ips,
    bool on,
    MinerCredential credential,
  ) async {
    return _runForIps(
      ips: ips,
      command: (ip) => _local.toggleLed(ip, on, credential),
      successMessage: on ? 'Indicator turned on.' : 'Indicator turned off.',
    );
  }

  @override
  Future<LedToggleResult> clearRefine(
    List<String> ips,
    MinerCredential credential,
  ) async {
    return _runForIps(
      ips: ips,
      command: (ip) => _local.clearRefine(ip, credential),
      successMessage: 'Clear refine command sent.',
    );
  }

  @override
  Future<LedToggleResult> reboot(
    List<String> ips,
    MinerCredential credential,
  ) async {
    return _runForIps(
      ips: ips,
      command: (ip) => _local.reboot(ip, credential),
      successMessage: 'Reboot command sent.',
    );
  }

  @override
  Future<LedToggleResult> applyPoolConfig(
    List<String> ips,
    List<PoolSlotConfig> poolSlots,
    Map<int, String> slotPasswords,
    MinerCredential credential,
  ) async {
    return _runForIps(
      ips: ips,
      command: (ip) =>
          _local.applyPoolConfig(ip, poolSlots, slotPasswords, credential),
      successMessage: 'Pool configuration applied.',
    );
  }

  Future<LedToggleResult> _runForIps({
    required List<String> ips,
    required Future<LedToggleResult> Function(String ip) command,
    required String successMessage,
  }) async {
    final succeeded = <String>[];
    final failed = <String>[];

    for (final ip in ips) {
      final result = await command(ip);
      if (result.success) {
        succeeded.add(ip);
      } else {
        failed.add(ip);
      }
    }

    if (failed.isEmpty) {
      return LedToggleResult(
        success: true,
        message: successMessage,
        targets: succeeded,
      );
    }

    return LedToggleResult(
      success: succeeded.isNotEmpty,
      message: 'Failed: ${failed.join(', ')}',
      targets: [...succeeded, ...failed],
    );
  }
}
