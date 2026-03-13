import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:volcminer/data/datasources/isar_local_data_source.dart';
import 'package:volcminer/domain/entities/app_settings.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';
import 'package:volcminer/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._local, this._secureStorage);

  final IsarLocalDataSource _local;
  final FlutterSecureStorage _secureStorage;

  @override
  Future<SecretCredential?> getCredential(CredentialType type) async {
    final value = await _secureStorage.read(key: _key(type));
    if (value == null) {
      return null;
    }
    return SecretCredential(value);
  }

  @override
  Future<AppSettings> getSettings() => _local.getSettings();

  @override
  Future<List<PoolSlotConfig>> getPoolSlots() => _local.getPoolSlots();

  @override
  Future<void> saveCredential(CredentialType type, SecretCredential value) {
    return _secureStorage.write(key: _key(type), value: value.value);
  }

  @override
  Future<void> savePoolSlot(PoolSlotConfig config) =>
      _local.savePoolSlot(config);

  @override
  Future<void> saveSettings(AppSettings settings) =>
      _local.saveSettings(settings);

  String _key(CredentialType type) {
    switch (type) {
      case CredentialType.poolSearchPassword:
        return 'pool_search_account_password';
      case CredentialType.poolSlot1Password:
        return 'pool_slot_1_password';
      case CredentialType.poolSlot2Password:
        return 'pool_slot_2_password';
      case CredentialType.poolSlot3Password:
        return 'pool_slot_3_password';
      case CredentialType.minerAuthPassword:
        return 'miner_auth_password';
    }
  }
}
