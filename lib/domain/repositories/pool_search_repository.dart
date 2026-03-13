import 'package:volcminer/domain/entities/pool_worker.dart';
import 'package:volcminer/domain/entities/search_request.dart';

abstract class PoolSearchRepository {
  Future<List<PoolWorker>> searchWorkers(SearchRequest request);
}
