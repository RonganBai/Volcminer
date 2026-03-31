import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volcminer/core/utils/server_url_defaults.dart';
import 'package:volcminer/domain/entities/app_settings.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';
import 'package:volcminer/domain/repositories/settings_repository.dart';
import 'package:volcminer/presentation/localization/error_reason_text.dart';

class SettingsState {
  const SettingsState({
    required this.settings,
    required this.serverUrl,
    required this.poolSlots,
    required this.poolSearchPassword,
    required this.minerAuthPassword,
    required this.slotPasswords,
    required this.loading,
    required this.error,
  });

  final AppSettings settings;
  final String serverUrl;
  final List<PoolSlotConfig> poolSlots;
  final String poolSearchPassword;
  final String minerAuthPassword;
  final Map<int, String> slotPasswords;
  final bool loading;
  final String? error;

  factory SettingsState.initial() => SettingsState(
    settings: AppSettings.defaults,
    serverUrl: ServerUrlDefaults.value,
    poolSlots: const [
      PoolSlotConfig(slotNo: 1, poolUrl: '', workerCode: ''),
      PoolSlotConfig(slotNo: 2, poolUrl: '', workerCode: ''),
      PoolSlotConfig(slotNo: 3, poolUrl: '', workerCode: ''),
    ],
    poolSearchPassword: '',
    minerAuthPassword: 'ltc@dog',
    slotPasswords: const {1: '', 2: '', 3: ''},
    loading: false,
    error: null,
  );

  SettingsState copyWith({
    AppSettings? settings,
    String? serverUrl,
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
      serverUrl: serverUrl ?? this.serverUrl,
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
  static const String _serverUrlKey = 'aggregator_server_url';

  SettingsController(this._repository) : super(SettingsState.initial()) {
    load();
  }

  final SettingsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final prefs = await SharedPreferences.getInstance();
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
        serverUrl: _normalizeServerUrl(
          prefs.getString(_serverUrlKey) ?? ServerUrlDefaults.value,
        ),
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
      state = state.copyWith(
        loading: false,
        error: ErrorReasonText.settingsLoadFailed(e),
      );
    }
  }

  Future<void> updateSettings(AppSettings settings) async {
    await _repository.saveSettings(settings);
    state = state.copyWith(settings: settings);
  }

  Future<void> updateServerUrl(String value) async {
    final normalized = _normalizeServerUrl(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, normalized);
    state = state.copyWith(serverUrl: normalized);
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

  Future<void> addSubAccount(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (state.settings.subAccounts.contains(normalized)) {
      return;
    }
    await updateSettings(
      state.settings.copyWith(
        subAccounts: [...state.settings.subAccounts, normalized]
          ..sort((a, b) => a.compareTo(b)),
      ),
    );
  }

  Future<void> removeSubAccount(String value) async {
    await updateSettings(
      state.settings.copyWith(
        subAccounts: state.settings.subAccounts
            .where((entry) => entry != value)
            .toList(growable: false),
      ),
    );
  }

  Future<void> addMiningUrl(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (state.settings.miningUrls.contains(normalized)) {
      return;
    }
    await updateSettings(
      state.settings.copyWith(
        miningUrls: [...state.settings.miningUrls, normalized],
      ),
    );
  }

  Future<void> removeMiningUrl(String value) async {
    await updateSettings(
      state.settings.copyWith(
        miningUrls: state.settings.miningUrls
            .where((entry) => entry != value)
            .toList(growable: false),
      ),
    );
  }

  String _normalizeSecret(String value) {
    return value
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F\u200B\uFEFF]'), '')
        .trim();
  }

  String _normalizeServerUrl(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'http://10.0.0.52:18080';
    }
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }
}
