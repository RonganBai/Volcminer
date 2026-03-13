import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:volcminer/data/datasources/hash7_remote_data_source.dart';
import 'package:volcminer/data/datasources/isar_local_data_source.dart';
import 'package:volcminer/data/datasources/miner_local_data_source.dart';
import 'package:volcminer/data/repositories/miner_repository_impl.dart';
import 'package:volcminer/data/repositories/pool_search_repository_impl.dart';
import 'package:volcminer/data/repositories/scan_view_repository_impl.dart';
import 'package:volcminer/data/repositories/settings_repository_impl.dart';
import 'package:volcminer/domain/repositories/miner_repository.dart';
import 'package:volcminer/domain/repositories/pool_search_repository.dart';
import 'package:volcminer/domain/repositories/scan_view_repository.dart';
import 'package:volcminer/domain/repositories/settings_repository.dart';
import 'package:volcminer/domain/entities/scan_target_mode.dart';
import 'package:volcminer/domain/usecases/apply_pool_config_usecase.dart';
import 'package:volcminer/domain/usecases/fetch_miner_detail_usecase.dart';
import 'package:volcminer/domain/usecases/clear_refine_usecase.dart';
import 'package:volcminer/domain/usecases/manage_scan_view_usecase.dart';
import 'package:volcminer/domain/usecases/reboot_miner_usecase.dart';
import 'package:volcminer/domain/usecases/search_pool_workers_usecase.dart';
import 'package:volcminer/domain/usecases/toggle_indicator_usecase.dart';
import 'package:volcminer/presentation/controllers/scan_controller.dart';
import 'package:volcminer/presentation/controllers/scan_view_controller.dart';
import 'package:volcminer/presentation/controllers/settings_controller.dart';

final isarProvider = Provider<Isar>((_) {
  throw UnimplementedError('isarProvider must be overridden in main()');
});

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((_) {
  return const FlutterSecureStorage();
});

final scanTargetModeProvider = StateProvider<ScanTargetMode>((_) {
  return ScanTargetMode.full;
});

final isarLocalDataSourceProvider = Provider<IsarLocalDataSource>((ref) {
  return IsarLocalDataSource(ref.watch(isarProvider));
});

final hash7RemoteDataSourceProvider = Provider<Hash7RemoteDataSource>((ref) {
  return Hash7RemoteDataSource(ref.watch(httpClientProvider));
});

final minerLocalDataSourceProvider = Provider<MinerLocalDataSource>((ref) {
  return MinerLocalDataSource();
});

final scanViewRepositoryProvider = Provider<ScanViewRepository>((ref) {
  return ScanViewRepositoryImpl(ref.watch(isarLocalDataSourceProvider));
});

final poolSearchRepositoryProvider = Provider<PoolSearchRepository>((ref) {
  return PoolSearchRepositoryImpl(ref.watch(hash7RemoteDataSourceProvider));
});

final minerRepositoryProvider = Provider<MinerRepository>((ref) {
  return MinerRepositoryImpl(ref.watch(minerLocalDataSourceProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(
    ref.watch(isarLocalDataSourceProvider),
    ref.watch(secureStorageProvider),
  );
});

final manageScanViewUseCaseProvider = Provider<ManageScanViewUseCase>((ref) {
  return ManageScanViewUseCase(ref.watch(scanViewRepositoryProvider));
});

final searchPoolWorkersUseCaseProvider = Provider<SearchPoolWorkersUseCase>((
  ref,
) {
  return SearchPoolWorkersUseCase(ref.watch(poolSearchRepositoryProvider));
});

final fetchMinerDetailUseCaseProvider = Provider<FetchMinerDetailUseCase>((
  ref,
) {
  return FetchMinerDetailUseCase(ref.watch(minerRepositoryProvider));
});

final toggleIndicatorUseCaseProvider = Provider<ToggleIndicatorUseCase>((ref) {
  return ToggleIndicatorUseCase(ref.watch(minerRepositoryProvider));
});

final clearRefineUseCaseProvider = Provider<ClearRefineUseCase>((ref) {
  return ClearRefineUseCase(ref.watch(minerRepositoryProvider));
});

final rebootMinerUseCaseProvider = Provider<RebootMinerUseCase>((ref) {
  return RebootMinerUseCase(ref.watch(minerRepositoryProvider));
});

final applyPoolConfigUseCaseProvider = Provider<ApplyPoolConfigUseCase>((ref) {
  return ApplyPoolConfigUseCase(ref.watch(minerRepositoryProvider));
});

final scanViewControllerProvider =
    StateNotifierProvider<ScanViewController, ScanViewState>((ref) {
      return ScanViewController(ref.watch(manageScanViewUseCaseProvider));
    });

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
      return SettingsController(ref.watch(settingsRepositoryProvider));
    });

final scanControllerProvider = StateNotifierProvider<ScanController, ScanState>(
  (ref) {
    return ScanController(
      ref.watch(searchPoolWorkersUseCaseProvider),
      ref.watch(fetchMinerDetailUseCaseProvider),
      ref.watch(toggleIndicatorUseCaseProvider),
      ref.watch(clearRefineUseCaseProvider),
      ref.watch(rebootMinerUseCaseProvider),
      ref.watch(applyPoolConfigUseCaseProvider),
      ref.watch(isarLocalDataSourceProvider),
    );
  },
);
