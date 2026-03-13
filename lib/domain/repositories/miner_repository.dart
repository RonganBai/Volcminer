import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/led_toggle_result.dart';
import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';

abstract class MinerRepository {
  Future<MinerRuntime> getRuntime(
    String ip,
    MinerCredential credential, {
    bool collectLog = true,
  });
  Future<String> getKernelLog(String ip, MinerCredential credential);
  Future<LedToggleResult> toggleLed(
    List<String> ips,
    bool on,
    MinerCredential credential,
  );
  Future<LedToggleResult> clearRefine(
    List<String> ips,
    MinerCredential credential,
  );
  Future<LedToggleResult> reboot(List<String> ips, MinerCredential credential);
  Future<LedToggleResult> applyPoolConfig(
    List<String> ips,
    List<PoolSlotConfig> poolSlots,
    Map<int, String> slotPasswords,
    MinerCredential credential,
  );
}
