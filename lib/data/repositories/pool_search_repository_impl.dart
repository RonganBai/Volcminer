import 'package:volcminer/data/datasources/hash7_remote_data_source.dart';
import 'package:volcminer/domain/entities/pool_worker.dart';
import 'package:volcminer/domain/entities/search_request.dart';
import 'package:volcminer/domain/repositories/pool_search_repository.dart';

class PoolSearchRepositoryImpl implements PoolSearchRepository {
  PoolSearchRepositoryImpl(this._remote);

  final Hash7RemoteDataSource _remote;

  @override
  Future<List<PoolWorker>> searchWorkers(SearchRequest request) {
    return _remote.searchWorkers(request);
  }
}
