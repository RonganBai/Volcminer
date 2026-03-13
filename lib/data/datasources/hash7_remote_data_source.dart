import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:volcminer/domain/entities/pool_worker.dart';
import 'package:volcminer/domain/entities/search_request.dart';

class Hash7RemoteDataSource {
  Hash7RemoteDataSource(this._client);

  final http.Client _client;

  static const String _baseUrl =
      'https://poolapi.hash7.info/api/public/observer/mining-worker';
  static const String _defaultToken = '76a504a5cd3841a59c27cbd867cec3e8';
  static const int _defaultPuid = 1361410;
  static const Duration _requestTimeout = Duration(seconds: 8);

  Future<List<PoolWorker>> searchWorkers(SearchRequest request) async {
    final workers = <PoolWorker>[];
    var page = 1;
    var totalPage = 1;

    do {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'worker_name': '',
          'puid': '$_defaultPuid',
          'coin': 'LTC',
          'status': '0',
          'token': _defaultToken,
          'page': '$page',
          'page_size': '100',
          'order_by': '',
          'order': '',
          'group_id': '0',
        },
      );

      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json, text/plain, */*',
              'Referer': 'https://pool.hash7.info/',
              'User-Agent': 'VolcMiner/1.0',
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        throw Exception('Pool API failed: HTTP ${response.statusCode}');
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        throw Exception('Pool API payload format error');
      }

      final list = payload['list'];
      if (list is! List) {
        throw Exception('Pool API payload missing list');
      }

      for (final raw in list) {
        if (raw is! Map) {
          continue;
        }
        final map = raw.cast<String, dynamic>();
        final name = (map['worker_name'] ?? '').toString();
        final ip = _workerNameToIp(name);
        workers.add(
          PoolWorker(
            workerName: name,
            ip: ip,
            status: (map['status'] ?? '').toString(),
            lastShareTime: (map['last_share_time'] ?? '').toString(),
            dailyHashrate: (map['daily_hashrate'] ?? '').toString(),
            rejectRate: (map['reject_rate'] ?? '').toString(),
          ),
        );
      }

      final pagination = payload['pagination'];
      if (pagination is Map<String, dynamic>) {
        totalPage = int.tryParse('${pagination['total_page']}') ?? page;
      } else {
        totalPage = page;
      }

      page += 1;
    } while (page <= totalPage);

    if (request.ips.isEmpty) {
      return workers;
    }
    final ipSet = request.ips.toSet();
    return workers.where((e) => ipSet.contains(e.ip)).toList();
  }

  String _workerNameToIp(String workerName) {
    var value = workerName.trim();
    if (value.toLowerCase().startsWith('ak.')) {
      value = value.substring(3);
    }
    return value.replaceAll('x', '.');
  }
}
