import 'package:volcminer/domain/entities/app_settings.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';

abstract class SettingsRepository {
  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);
  Future<List<PoolSlotConfig>> getPoolSlots();
  Future<void> savePoolSlot(PoolSlotConfig config);
  Future<void> saveCredential(CredentialType type, SecretCredential value);
  Future<SecretCredential?> getCredential(CredentialType type);
}
