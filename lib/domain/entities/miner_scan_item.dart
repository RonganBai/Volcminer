import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/entities/pool_worker.dart';

class MinerScanItem {
  const MinerScanItem({required this.worker, required this.runtime});

  final PoolWorker worker;
  final MinerRuntime runtime;
}
