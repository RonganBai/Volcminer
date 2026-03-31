import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/led_toggle_result.dart';
import 'package:volcminer/domain/entities/miner_pool_config_snapshot.dart';
import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/presentation/localization/legacy_zh_texts.dart';

class MinerLocalDataSource {
  Future<MinerRuntime> fetchRuntime(
    String ip,
    MinerCredential credential, {
    bool collectLog = true,
  }) async {
    return MinerRuntime.offline(ip);
  }

  Future<String> fetchKernelLog(String ip, MinerCredential credential) async {
    return LegacyZhTexts.webUnsupportedKernelLog;
  }

  Future<MinerPoolConfigSnapshot?> fetchPoolConfig(
    String ip,
    MinerCredential credential,
  ) async {
    return null;
  }

  Future<LedToggleResult> toggleLed(
    String ip,
    bool on,
    MinerCredential credential,
  ) async {
    return LedToggleResult(
      success: false,
      message: LegacyZhTexts.webUnsupportedToggleLed,
      targets: [ip],
    );
  }

  Future<LedToggleResult> clearRefine(
    String ip,
    MinerCredential credential,
  ) async {
    return LedToggleResult(
      success: false,
      message: LegacyZhTexts.webUnsupportedClearRefine,
      targets: [ip],
    );
  }

  Future<LedToggleResult> reboot(String ip, MinerCredential credential) async {
    return LedToggleResult(
      success: false,
      message: LegacyZhTexts.webUnsupportedReboot,
      targets: [ip],
    );
  }

  Future<LedToggleResult> applyPoolConfig(
    String ip,
    MinerPoolConfigSnapshot snapshot,
    MinerCredential credential,
  ) async {
    return LedToggleResult(
      success: false,
      message: LegacyZhTexts.webUnsupportedPoolConfig,
      targets: [ip],
    );
  }
}
