import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/domain/entities/app_settings.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';
import 'package:volcminer/domain/repositories/settings_repository.dart';

class SettingsState {
  const SettingsState({
    required this.settings,
    required this.poolSlots,
    required this.poolSearchPassword,
    required this.minerAuthPassword,
    required this.slotPasswords,
    required this.loading,
    required this.error,
  });

  final AppSettings settings;
  final List<PoolSlotConfig> poolSlots;
  final String poolSearchPassword;
  final String minerAuthPassword;
  final Map<int, String> slotPasswords;
  final bool loading;
  final String? error;

  factory SettingsState.initial() => const SettingsState(
    settings: AppSettings.defaults,
    poolSlots: [
      PoolSlotConfig(slotNo: 1, poolUrl: '', workerCode: ''),
      PoolSlotConfig(slotNo: 2, poolUrl: '', workerCode: ''),
      PoolSlotConfig(slotNo: 3, poolUrl: '', workerCode: ''),
    ],
    poolSearchPassword: '',
    minerAuthPassword: 'ltc@dog',
    slotPasswords: {1: '', 2: '', 3: ''},
    loading: false,
    error: null,
  );

  SettingsState copyWith({
    AppSettings? settings,
    List<PoolSlotConfig>? poolSlots,
    String? poolSearchPassword,
    String? minerAuthPassword,
    Map<int, String>? slotPasswords,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      poolSlots: poolSlots ?? this.poolSlots,
      poolSearchPassword: poolSearchPassword ?? this.poolSearchPassword,
      minerAuthPassword: minerAuthPassword ?? this.minerAuthPassword,
      slotPasswords: slotPasswords ?? this.slotPasswords,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._repository) : super(SettingsState.initial()) {
    load();
  }

  final SettingsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final settings = await _repository.getSettings();
      final poolSlots = await _repository.getPoolSlots();
      final poolPass = await _repository.getCredential(
        CredentialType.poolSearchPassword,
      );
      final minerPass = await _repository.getCredential(
        CredentialType.minerAuthPassword,
      );
      final s1 = await _repository.getCredential(
        CredentialType.poolSlot1Password,
      );
      final s2 = await _repository.getCredential(
        CredentialType.poolSlot2Password,
      );
      final s3 = await _repository.getCredential(
        CredentialType.poolSlot3Password,
      );

      state = state.copyWith(
        settings: settings,
        poolSlots: poolSlots,
        poolSearchPassword: _normalizeSecret(poolPass?.value ?? ''),
        minerAuthPassword: _normalizeSecret(minerPass?.value ?? 'ltc@dog'),
        slotPasswords: {
          1: _normalizeSecret(s1?.value ?? ''),
          2: _normalizeSecret(s2?.value ?? ''),
          3: _normalizeSecret(s3?.value ?? ''),
        },
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '读取设置失败: $e');
    }
  }

  Future<void> updateSettings(AppSettings settings) async {
    await _repository.saveSettings(settings);
    state = state.copyWith(settings: settings);
  }

  Future<void> updatePoolSlot(PoolSlotConfig slot) async {
    await _repository.savePoolSlot(slot);
    final next = [
      for (final item in state.poolSlots)
        if (item.slotNo == slot.slotNo) slot else item,
    ]..sort((a, b) => a.slotNo.compareTo(b.slotNo));
    state = state.copyWith(poolSlots: next);
  }

  Future<void> savePoolSearchPassword(String value) async {
    final normalized = _normalizeSecret(value);
    await _repository.saveCredential(
      CredentialType.poolSearchPassword,
      SecretCredential(normalized),
    );
    state = state.copyWith(poolSearchPassword: normalized);
  }

  Future<void> saveMinerAuthPassword(String value) async {
    final normalized = _normalizeSecret(value);
    await _repository.saveCredential(
      CredentialType.minerAuthPassword,
      SecretCredential(normalized),
    );
    state = state.copyWith(minerAuthPassword: normalized);
  }

  Future<void> saveSlotPassword(int slotNo, String value) async {
    final normalized = _normalizeSecret(value);
    final type = switch (slotNo) {
      1 => CredentialType.poolSlot1Password,
      2 => CredentialType.poolSlot2Password,
      _ => CredentialType.poolSlot3Password,
    };
    await _repository.saveCredential(type, SecretCredential(normalized));
    final next = {...state.slotPasswords, slotNo: normalized};
    state = state.copyWith(slotPasswords: next);
  }

  String _normalizeSecret(String value) {
    return value
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F\u200B\uFEFF]'), '')
        .trim();
  }
}
