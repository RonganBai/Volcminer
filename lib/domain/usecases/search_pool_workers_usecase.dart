import 'package:volcminer/domain/entities/pool_worker.dart';
import 'package:volcminer/domain/entities/search_request.dart';
import 'package:volcminer/domain/repositories/pool_search_repository.dart';

class SearchPoolWorkersUseCase {
  SearchPoolWorkersUseCase(this._repository);

  final PoolSearchRepository _repository;

  Future<List<PoolWorker>> execute(SearchRequest request) {
    return _repository.searchWorkers(request);
  }
}
