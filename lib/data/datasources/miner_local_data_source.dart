import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:volcminer/domain/entities/credential.dart';
import 'package:volcminer/domain/entities/led_toggle_result.dart';
import 'package:volcminer/domain/entities/miner_pool_config_snapshot.dart';
import 'package:volcminer/domain/entities/miner_runtime.dart';
import 'package:volcminer/domain/entities/pool_slot_config.dart';

class MinerLocalDataSource {
  static const Duration _runtimeTimeout = Duration(seconds: 6);
  static const Duration _logTimeout = Duration(seconds: 6);

  Future<MinerRuntime> fetchRuntime(
    String ip,
    MinerCredential credential, {
    bool collectLog = true,
  }) async {
    try {
      _log(
        'scan.start ip=$ip endpoint=status timeout=${_runtimeTimeout.inSeconds}s',
      );
      final runtimeResp = await _getWithAuth(
        ip: ip,
        path: '/cgi-bin/get_miner_statusV1.cgi',
        credential: credential,
        timeout: _runtimeTimeout,
      );
      if (runtimeResp == null) {
        _log('scan.no_response ip=$ip');
        return MinerRuntime.offline(ip);
      }
      _log(
        'scan.http ip=$ip status=${runtimeResp.statusCode} bodyLen=${runtimeResp.body.length}',
      );

      if (runtimeResp.statusCode == 401 || runtimeResp.statusCode == 403) {
        _log('scan.not_miner_by_auth ip=$ip');
        return MinerRuntime.notMiner(ip);
      }
      if (runtimeResp.statusCode != 200) {
        _log('scan.offline_by_status ip=$ip status=${runtimeResp.statusCode}');
        return MinerRuntime.offline(ip);
      }

      final parsed = _parseRuntime(runtimeResp.body, ip);
      _log(
        'scan.parsed ip=$ip result=${parsed.onlineStatus} ghs5s=${parsed.ghs5s} ghsav=${parsed.ghsav}',
      );
      if (parsed.onlineStatus == MinerRuntimeStatus.notMiner) {
        return parsed;
      }

      final shouldCollect = collectLog && _shouldCollectLog(parsed);
      String logSnippet = '--';
      if (shouldCollect) {
        _log('scan.log_collect ip=$ip');
        final logResp = await _getWithAuth(
          ip: ip,
          path: '/cgi-bin/get_kernel_log.cgi',
          credential: credential,
          timeout: _logTimeout,
        );
        if (logResp != null && logResp.statusCode == 200) {
          logSnippet = _extractLatestError(logResp.body);
        }
      }
      _log('scan.done ip=$ip final=${parsed.onlineStatus}');
      return parsed.copyWith(logSnippet: logSnippet);
    } on TimeoutException {
      _log('scan.timeout ip=$ip');
      return MinerRuntime.timeout(ip);
    } catch (e) {
      _log('scan.exception ip=$ip err=$e');
      return MinerRuntime.offline(ip);
    }
  }

  Future<String> fetchKernelLog(String ip, MinerCredential credential) async {
    try {
      final raw = await _getWithAuth(
        ip: ip,
        path: '/cgi-bin/get_kernel_log.cgi',
        credential: credential,
        timeout: _logTimeout,
      );
      if (raw == null || raw.statusCode != 200) {
        return '--';
      }
      return _normalizeLogText(raw.body);
    } on TimeoutException {
      return 'Log timeout';
    } catch (_) {
      return '--';
    }
  }

  Future<MinerPoolConfigSnapshot?> fetchPoolConfig(
    String ip,
    MinerCredential credential,
  ) async {
    try {
      _log('poolcfg.start ip=$ip');
      final raw = await _getWithAuth(
        ip: ip,
        path: '/cgi-bin/get_miner_confV1.cgi',
        credential: credential,
        timeout: _runtimeTimeout,
      );
      _log(
        'poolcfg.http ip=$ip status=${raw?.statusCode ?? -1} bodyLen=${raw?.body.length ?? 0}',
      );
      if (raw == null || raw.statusCode != 200) {
        return null;
      }
      final snapshot = _parsePoolConfigSnapshot(raw.body);
      if (snapshot == null) {
        _log('poolcfg.parse_failed ip=$ip body=${_singleLineSnippet(raw.body, 200)}');
      }
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  Future<LedToggleResult> toggleLed(
    String ip,
    bool on,
    MinerCredential credential,
  ) async {
    try {
      final response = await _postFormWithDigestAuth(
        ip: ip,
        path: '/cgi-bin/post_led_onoff.cgi',
        credential: credential,
        timeout: _runtimeTimeout,
        formBody: '_bb_type=${on ? 'rgOn' : 'rgOff'}',
      );
      if (response == null) {
        return LedToggleResult(
          success: false,
          message: 'No response from $ip',
          targets: [ip],
        );
      }
      final ok =
          response.statusCode == 200 &&
          response.body.toLowerCase().contains('ok');
      return LedToggleResult(
        success: ok,
        message: ok ? response.body.trim() : 'HTTP ${response.statusCode}',
        targets: [ip],
      );
    } catch (e) {
      return LedToggleResult(
        success: false,
        message: 'LED request failed: $e',
        targets: [ip],
      );
    }
  }

  Future<LedToggleResult> clearRefine(
    String ip,
    MinerCredential credential,
  ) async {
    return _postAction(
      ip: ip,
      credential: credential,
      path: '/cgi-bin/clear_refine.cgi',
      successMessage: 'Clear refine sent.',
    );
  }

  Future<LedToggleResult> reboot(String ip, MinerCredential credential) async {
    return _postAction(
      ip: ip,
      credential: credential,
      path: '/cgi-bin/reboot.cgi',
      successMessage: 'Reboot sent.',
    );
  }

  Future<LedToggleResult> applyPoolConfig(
    String ip,
    List<PoolSlotConfig> poolSlots,
    Map<int, String> slotPasswords,
    MinerCredential credential,
  ) async {
    final body = _buildPoolConfigFormBody(poolSlots, slotPasswords);
    return _postAction(
      ip: ip,
      credential: credential,
      path: '/cgi-bin/set_miner_conf.cgi',
      successMessage: 'Pool config sent.',
      formBody: body,
    );
  }

  Future<_FetchResult?> _getWithAuth({
    required String ip,
    required String path,
    required MinerCredential credential,
    required Duration timeout,
  }) async {
    try {
      final username = _normalizeCredentialPart(credential.username);
      final password = _normalizeCredentialPart(credential.password);
      if (username != credential.username || password != credential.password) {
        _log(
          'http.cred_trimmed ip=$ip userLen=${credential.username.length}->${username.length} passLen=${credential.password.length}->${password.length}',
        );
      }
      final client = HttpClient()
        ..connectionTimeout = timeout
        ..idleTimeout = timeout;
      try {
        final uri = Uri.parse('http://$ip$path');
        _log(
          'http.try ip=$ip path=$path user=$username passLen=${password.length}',
        );

        final basicAuth =
            'Basic ${base64Encode(utf8.encode('$username:$password'))}';

        // 1) Try anonymous access first because some miner CGI endpoints
        // are readable without auth and may reject explicit auth headers.
        final anonymousResp = await _sendRequest(
          client: client,
          method: 'GET',
          uri: uri,
          timeout: timeout,
        );
        _log(
          'http.resp ip=$ip path=$path attempt=anonymous status=${anonymousResp.statusCode}',
        );
        if (anonymousResp.statusCode == 200) {
          return anonymousResp;
        }

        // 2) Then try Basic for devices that do require credentials.
        final basicResp = await _sendRequest(
          client: client,
          method: 'GET',
          uri: uri,
          timeout: timeout,
          authorization: basicAuth,
        );
        _log(
          'http.resp ip=$ip path=$path attempt=basic status=${basicResp.statusCode}',
        );
        if (basicResp.statusCode == 200) {
          return basicResp;
        }

        // 3) Finally request an unauthenticated challenge for Digest.
        final challengeResp = await _sendRequest(
          client: client,
          method: 'GET',
          uri: uri,
          timeout: timeout,
        );
        _log(
          'http.resp ip=$ip path=$path attempt=challenge status=${challengeResp.statusCode}',
        );
        if (challengeResp.statusCode == 200) {
          return challengeResp;
        }
        if (challengeResp.statusCode != 401) {
          return challengeResp;
        }

        final challenges =
            challengeResp.headers[HttpHeaders.wwwAuthenticateHeader] ??
            const [];
        final digestChallenge = challenges.firstWhere(
          (c) => c.toLowerCase().startsWith('digest'),
          orElse: () => '',
        );
        if (digestChallenge.isEmpty) {
          _log('http.auth ip=$ip path=$path scheme=none');
          _log(
            'http.401 ip=$ip path=$path body=${_singleLineSnippet(challengeResp.body, 160)}',
          );
          return challengeResp;
        }
        _log(
          'http.auth ip=$ip path=$path scheme=Digest realm=${_extractRealm(digestChallenge)}',
        );
        final params = _parseDigestChallenge(digestChallenge);
        _log(
          'http.auth_detail ip=$ip path=$path algorithm=${params['algorithm'] ?? 'MD5'} qop=${params['qop'] ?? ''} nonceLen=${(params['nonce'] ?? '').length}',
        );
        final digestCandidates = _buildDigestAuthorizationCandidates(
          challenge: digestChallenge,
          method: 'GET',
          uri: uri,
          username: username,
          password: password,
        );
        if (digestCandidates.isEmpty) {
          _log('http.auth ip=$ip path=$path digest_build_failed');
          return challengeResp;
        }

        for (var i = 0; i < digestCandidates.length; i++) {
          final digestResp = await _sendRequest(
            client: client,
            method: 'GET',
            uri: uri,
            timeout: timeout,
            authorization: digestCandidates[i],
          );
          _log(
            'http.resp ip=$ip path=$path attempt=digest_get_${i + 1} status=${digestResp.statusCode}',
          );
          if (digestResp.statusCode == 200) {
            return digestResp;
          }
          if (digestResp.statusCode == 401) {
            _log(
              'http.401 ip=$ip path=$path body=${_singleLineSnippet(digestResp.body, 160)}',
            );
          }
        }

        final postChallengeResp = await _sendRequest(
          client: client,
          method: 'POST',
          uri: uri,
          timeout: timeout,
        );
        _log(
          'http.resp ip=$ip path=$path attempt=post_challenge status=${postChallengeResp.statusCode}',
        );
        if (postChallengeResp.statusCode != 401) {
          return postChallengeResp;
        }

        final postChallenges =
            postChallengeResp.headers[HttpHeaders.wwwAuthenticateHeader] ??
            const [];
        final postDigestChallenge = postChallenges.firstWhere(
          (c) => c.toLowerCase().startsWith('digest'),
          orElse: () => '',
        );
        if (postDigestChallenge.isEmpty) {
          _log(
            'http.401 ip=$ip path=$path body=${_singleLineSnippet(postChallengeResp.body, 160)}',
          );
          return postChallengeResp;
        }
        final postCandidates = _buildDigestAuthorizationCandidates(
          challenge: postDigestChallenge,
          method: 'POST',
          uri: uri,
          username: username,
          password: password,
        );
        for (var i = 0; i < postCandidates.length; i++) {
          final postResp = await _sendRequest(
            client: client,
            method: 'POST',
            uri: uri,
            timeout: timeout,
            authorization: postCandidates[i],
          );
          _log(
            'http.resp ip=$ip path=$path attempt=digest_post_${i + 1} status=${postResp.statusCode}',
          );
          if (postResp.statusCode == 200) {
            return postResp;
          }
          if (postResp.statusCode == 401) {
            _log(
              'http.401 ip=$ip path=$path body=${_singleLineSnippet(postResp.body, 160)}',
            );
          }
        }
        return postChallengeResp;
      } finally {
        client.close(force: true);
      }
    } on TimeoutException {
      _log('http.timeout ip=$ip path=$path');
      rethrow;
    } catch (e) {
      _log('http.exception ip=$ip path=$path err=$e');
      return null;
    }
  }

  Future<_FetchResult> _sendRequest({
    required HttpClient client,
    required String method,
    required Uri uri,
    required Duration timeout,
    String? authorization,
    String? requestBody,
    String? contentType,
  }) async {
    final req = await client.openUrl(method, uri).timeout(timeout);
    req.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
    req.headers.set(HttpHeaders.connectionHeader, 'close');
    req.headers.set(HttpHeaders.acceptHeader, '*/*');
    if (contentType != null && contentType.isNotEmpty) {
      req.headers.set(HttpHeaders.contentTypeHeader, contentType);
    }
    if (authorization != null && authorization.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, authorization);
    }
    if (requestBody != null && requestBody.isNotEmpty) {
      final bodyBytes = utf8.encode(requestBody);
      req.headers.set(HttpHeaders.contentLengthHeader, bodyBytes.length);
      req.contentLength = bodyBytes.length;
      req.add(bodyBytes);
    } else if (method == 'POST') {
      req.headers.set(HttpHeaders.contentLengthHeader, 0);
      req.contentLength = 0;
    }
    final resp = await req.close().timeout(timeout);
    final responseBody = await resp.transform(utf8.decoder).join();
    return _FetchResult(
      statusCode: resp.statusCode,
      body: responseBody,
      headers: resp.headers,
    );
  }

  List<String> _buildDigestAuthorizationCandidates({
    required String challenge,
    required String method,
    required Uri uri,
    required String username,
    required String password,
  }) {
    final candidates = <String>{};
    final pathOnly = uri.path.isEmpty ? '/' : uri.path;
    final withQuery = uri.hasQuery ? '${uri.path}?${uri.query}' : pathOnly;
    final absolute = uri.toString();
    final uriCandidates = [withQuery, pathOnly, absolute];

    for (final uriPath in uriCandidates) {
      final normal = _buildDigestAuthorization(
        challenge: challenge,
        method: method,
        uriPath: uriPath,
        username: username,
        password: password,
      );
      if (normal != null) {
        candidates.add(normal);
      }
      final quotedQop = _buildDigestAuthorization(
        challenge: challenge,
        method: method,
        uriPath: uriPath,
        username: username,
        password: password,
        quoteQopValue: true,
      );
      if (quotedQop != null) {
        candidates.add(quotedQop);
      }
    }
    return candidates.toList(growable: false);
  }

  String _extractRealm(String challenge) {
    final m = RegExp(
      r'realm="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(challenge);
    return m?.group(1) ?? '';
  }

  String? _buildDigestAuthorization({
    required String challenge,
    required String method,
    required String uriPath,
    required String username,
    required String password,
    bool quoteQopValue = false,
  }) {
    final params = _parseDigestChallenge(challenge);
    final realm = params['realm'];
    final nonce = params['nonce'];
    if (realm == null || nonce == null) {
      return null;
    }
    final algorithm = (params['algorithm'] ?? 'MD5').toUpperCase();
    final qopRaw = params['qop'] ?? '';
    final qop = qopRaw
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .firstWhere((e) => e == 'auth', orElse: () => '');
    final opaque = params['opaque'];

    final nc = '00000001';
    final cnonce = _randomHex(16);

    final ha1 = _hashHex(algorithm, '$username:$realm:$password');
    if (ha1 == null) {
      _log('http.auth digest_unsupported_algorithm algorithm=$algorithm');
      return null;
    }
    final finalHa1 = algorithm.endsWith('-SESS')
        ? _hashHex(algorithm, '$ha1:$nonce:$cnonce')
        : ha1;
    if (finalHa1 == null) {
      return null;
    }
    final ha2 = _hashHex(algorithm, '$method:$uriPath');
    if (ha2 == null) {
      return null;
    }
    final response = qop.isNotEmpty
        ? _hashHex(algorithm, '$finalHa1:$nonce:$nc:$cnonce:$qop:$ha2')
        : _hashHex(algorithm, '$finalHa1:$nonce:$ha2');
    if (response == null) {
      return null;
    }

    final parts = <String>[
      'Digest username="$username"',
      'realm="$realm"',
      'nonce="$nonce"',
      'uri="$uriPath"',
      'response="$response"',
      'algorithm=$algorithm',
    ];
    if (opaque != null && opaque.isNotEmpty) {
      parts.add('opaque="$opaque"');
    }
    if (qop.isNotEmpty) {
      parts.add(quoteQopValue ? 'qop="$qop"' : 'qop=$qop');
      parts.add('nc=$nc');
      parts.add('cnonce="$cnonce"');
    }
    return parts.join(', ');
  }

  Map<String, String> _parseDigestChallenge(String challenge) {
    final content = challenge.replaceFirst(
      RegExp(r'^\s*Digest\s+', caseSensitive: false),
      '',
    );
    final result = <String, String>{};
    final regex = RegExp(r'(\w+)=("([^"]*)"|[^,]+)');
    for (final m in regex.allMatches(content)) {
      final key = m.group(1)!.toLowerCase();
      final raw = m.group(2)!;
      final value = raw.startsWith('"') && raw.endsWith('"')
          ? raw.substring(1, raw.length - 1)
          : raw.trim();
      result[key] = value;
    }
    return result;
  }

  String? _hashHex(String algorithm, String input) {
    final normalized = algorithm.toUpperCase();
    if (normalized == 'MD5' || normalized == 'MD5-SESS') {
      return md5.convert(utf8.encode(input)).toString();
    }
    if (normalized == 'SHA-256' || normalized == 'SHA-256-SESS') {
      return sha256.convert(utf8.encode(input)).toString();
    }
    return null;
  }

  String _randomHex(int bytes) {
    final r = Random.secure();
    final data = List<int>.generate(bytes, (_) => r.nextInt(256));
    return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  bool _shouldCollectLog(MinerRuntime runtime) {
    return _isZeroOrSlash(runtime.ghs5s) || _isZeroOrSlash(runtime.ghsav);
  }

  bool _isZeroOrSlash(String value) {
    final text = value.trim();
    if (text.isEmpty || text == '--') {
      return false;
    }
    if (text.contains('/')) {
      return true;
    }
    final numeric = text.replaceAll(RegExp(r'[^0-9\.\-]'), '');
    final parsed = double.tryParse(numeric);
    return parsed != null && parsed == 0;
  }

  MinerRuntime _parseRuntime(String body, String ip) {
    final data = _decodeStatusDataMap(body) ?? _extractStatusMapFromRaw(body);
    if (data == null) {
      return MinerRuntime.offline(ip);
    }

    final hasMinerKeys =
        data.containsKey('ghs5s') ||
        data.containsKey('ghsav') ||
        data.containsKey('fan1') ||
        data.containsKey('fan2') ||
        data.containsKey('fan3') ||
        data.containsKey('fan4') ||
        data.containsKey('running_mode');
    if (!hasMinerKeys) {
      return MinerRuntime.notMiner(ip);
    }

    String norm(dynamic value) => value == null || '$value'.trim().isEmpty
        ? '--'
        : '$value'.replaceAll('\n', '').replaceAll('\r', '').trim();

    return MinerRuntime(
      ip: ip,
      onlineStatus: MinerRuntimeStatus.online,
      ghs5s: norm(data['ghs5s']),
      ghsav: norm(data['ghsav']),
      ambientTemp: norm(data['ambient_temp']),
      power: norm(data['power']),
      fan1: norm(data['fan1']),
      fan2: norm(data['fan2']),
      fan3: norm(data['fan3']),
      fan4: norm(data['fan4']),
      runningMode: norm(data['running_mode']),
      logSnippet: '--',
      fetchedAt: DateTime.now(),
    );
  }

  Map<String, dynamic>? _decodeStatusDataMap(String body) {
    try {
      final payload = jsonDecode(body);
      if (payload is! Map<String, dynamic>) {
        return null;
      }

      final rawData = payload['data'];
      if (rawData is Map<String, dynamic>) {
        return _flattenStatusMap(rawData);
      }
      if (rawData is String && rawData.trim().isNotEmpty) {
        try {
          final cleaned = rawData.replaceAll('\r', '').replaceAll('\n', '');
          final decoded = jsonDecode(cleaned);
          if (decoded is Map<String, dynamic>) {
            return _flattenStatusMap(decoded);
          }
        } catch (_) {
          return null;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _flattenStatusMap(Map<String, dynamic> data) {
    final out = <String, dynamic>{...data};
    final fan = data['fan'];
    if (fan is Map) {
      out['fan1'] = fan['fan1'];
      out['fan2'] = fan['fan2'];
      out['fan3'] = fan['fan3'];
      out['fan4'] = fan['fan4'];
    }
    return out;
  }

  Map<String, dynamic>? _extractStatusMapFromRaw(String raw) {
    String? pick(String key) {
      final pattern = RegExp('"${RegExp.escape(key)}"\\s*:\\s*"([^"]*)"');
      final match = pattern.firstMatch(raw);
      return match?.group(1);
    }

    final ghs5s = pick('ghs5s');
    final ghsav = pick('ghsav');
    if (ghs5s == null && ghsav == null) {
      return null;
    }

    return {
      'ghs5s': ghs5s ?? '--',
      'ghsav': ghsav ?? '--',
      'ambient_temp': pick('ambient_temp') ?? '--',
      'power': pick('power') ?? '--',
      'fan1': pick('fan1') ?? '--',
      'fan2': pick('fan2') ?? '--',
      'fan3': pick('fan3') ?? '--',
      'fan4': pick('fan4') ?? '--',
      'running_mode': pick('running_mode') ?? '--',
    };
  }

  String _extractLatestError(String text) {
    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final pattern = RegExp(r'\bERRORMSG\b', caseSensitive: false);
    var lastIndex = -1;
    for (var i = lines.length - 1; i >= 0; i--) {
      if (pattern.hasMatch(lines[i])) {
        lastIndex = i;
        break;
      }
    }
    if (lastIndex == -1) {
      return 'No ERRORMSG found';
    }
    final start = lastIndex - 10 < 0 ? 0 : lastIndex - 10;
    final end = lastIndex + 10 >= lines.length
        ? lines.length - 1
        : lastIndex + 10;
    return lines.sublist(start, end + 1).join('\n').trim();
  }

  String _normalizeLogText(String text) {
    return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  }

  String _normalizeCredentialPart(String value) {
    return value
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F\u200B\uFEFF]'), '')
        .trim();
  }

  String _singleLineSnippet(String text, int maxLen) {
    final line = text.replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
    if (line.length <= maxLen) {
      return line;
    }
    return '${line.substring(0, maxLen)}...';
  }

  void _log(String msg) {
    final line = '[VolcMinerScan] $msg';
    // print goes to flutter run terminal directly.
    // ignore: avoid_print
    print(line);
    debugPrint(line);
  }

  Future<LedToggleResult> _postAction({
    required String ip,
    required MinerCredential credential,
    required String path,
    required String successMessage,
    String formBody = '',
  }) async {
    try {
      final response = await _postFormWithDigestAuth(
        ip: ip,
        path: path,
        credential: credential,
        timeout: _runtimeTimeout,
        formBody: formBody,
      );
      if (response == null) {
        return LedToggleResult(
          success: false,
          message: 'No response from $ip',
          targets: [ip],
        );
      }
      final ok =
          response.statusCode == 200 &&
          (response.body.isEmpty ||
              response.body.contains('"code": "200"') ||
              response.body.toLowerCase().contains('ok'));
      return LedToggleResult(
        success: ok,
        message: ok ? successMessage : 'HTTP ${response.statusCode}',
        targets: [ip],
      );
    } catch (e) {
      return LedToggleResult(
        success: false,
        message: 'Request failed: $e',
        targets: [ip],
      );
    }
  }

  Future<_FetchResult?> _postFormWithDigestAuth({
    required String ip,
    required String path,
    required MinerCredential credential,
    required Duration timeout,
    required String formBody,
  }) async {
    final username = _normalizeCredentialPart(credential.username);
    final password = _normalizeCredentialPart(credential.password);
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = timeout;
    try {
      final uri = Uri.parse('http://$ip$path');
      final challengeResp = await _sendRequest(
        client: client,
        method: 'POST',
        uri: uri,
        timeout: timeout,
        requestBody: formBody,
        contentType: 'application/x-www-form-urlencoded',
      );
      _log(
        'http.resp ip=$ip path=$path attempt=post_challenge status=${challengeResp.statusCode}',
      );
      if (challengeResp.statusCode == 200) {
        return challengeResp;
      }
      if (challengeResp.statusCode != 401) {
        return challengeResp;
      }

      final challenges =
          challengeResp.headers[HttpHeaders.wwwAuthenticateHeader] ?? const [];
      final digestChallenge = challenges.firstWhere(
        (c) => c.toLowerCase().startsWith('digest'),
        orElse: () => '',
      );
      if (digestChallenge.isEmpty) {
        return challengeResp;
      }

      final candidates = _buildDigestAuthorizationCandidates(
        challenge: digestChallenge,
        method: 'POST',
        uri: uri,
        username: username,
        password: password,
      );
      for (final candidate in candidates) {
        final resp = await _sendRequest(
          client: client,
          method: 'POST',
          uri: uri,
          timeout: timeout,
          authorization: candidate,
          requestBody: formBody,
          contentType: 'application/x-www-form-urlencoded',
        );
        if (resp.statusCode == 200) {
          return resp;
        }
      }
      return challengeResp;
    } finally {
      client.close(force: true);
    }
  }

  String _buildPoolConfigFormBody(
    List<PoolSlotConfig> poolSlots,
    Map<int, String> slotPasswords,
  ) {
    final normalized = [...poolSlots]
      ..sort((a, b) => a.slotNo.compareTo(b.slotNo));
    final fields = <String, String>{};
    for (final slot in normalized) {
      fields['_bb_pool${slot.slotNo}url'] = slot.poolUrl.trim();
      fields['_bb_pool${slot.slotNo}user'] = slot.workerCode.trim();
      fields['_bb_pool${slot.slotNo}pw'] =
          (slotPasswords[slot.slotNo] ?? '').trim();
    }
    return fields.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
  }

  MinerPoolConfigSnapshot? _parsePoolConfigSnapshot(String body) {
    final slots = <PoolSlotConfig>[];
    final passwords = <int, String>{};
    final map = _decodeConfigMap(body);
    for (var slotNo = 1; slotNo <= 3; slotNo++) {
      final poolUrl = _readConfigValue(
        map,
        body,
        ['_bb_pool${slotNo}url', 'pool${slotNo}url', 'pool$slotNo.url'],
      );
      final workerCode = _readConfigValue(
        map,
        body,
        ['_bb_pool${slotNo}user', 'pool${slotNo}user', 'pool$slotNo.user'],
      );
      final password = _readConfigValue(
        map,
        body,
        ['_bb_pool${slotNo}pw', 'pool${slotNo}pw', 'pool$slotNo.pw'],
      );
      slots.add(
        PoolSlotConfig(
          slotNo: slotNo,
          poolUrl: poolUrl,
          workerCode: workerCode,
        ),
      );
      passwords[slotNo] = password;
    }
    if (slots.every(
      (slot) => slot.poolUrl.isEmpty && slot.workerCode.isEmpty,
    )) {
      return null;
    }
    return MinerPoolConfigSnapshot(poolSlots: slots, slotPasswords: passwords);
  }

  Map<String, dynamic>? _decodeConfigMap(String body) {
    try {
      final payload = jsonDecode(body);
      if (payload is! Map<String, dynamic>) {
        return null;
      }
      final rawData = payload['data'];
      if (rawData is Map<String, dynamic>) {
        return rawData;
      }
      if (rawData is String && rawData.trim().isNotEmpty) {
        final cleaned = rawData.replaceAll('\r', '').replaceAll('\n', '');
        final decoded = jsonDecode(cleaned);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      return payload;
    } catch (_) {
      return null;
    }
  }

  String _readConfigValue(
    Map<String, dynamic>? map,
    String rawBody,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map?[key];
      if (value != null && '$value'.trim().isNotEmpty) {
        return _decodeEscapedText('$value'.trim());
      }
    }
    for (final key in keys) {
      final pattern = RegExp(
        '"${RegExp.escape(key)}"\\s*:\\s*"((?:\\\\.|[^"])*)"',
      );
      final match = pattern.firstMatch(rawBody);
      if (match != null) {
        return _decodeEscapedText(match.group(1) ?? '');
      }
    }
    return '';
  }

  String _decodeEscapedText(String value) {
    return value
        .replaceAll(r'\"', '"')
        .replaceAll(r'\/', '/')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '')
        .trim();
  }
}

class _FetchResult {
  _FetchResult({
    required this.statusCode,
    required this.body,
    required this.headers,
  });

  final int statusCode;
  final String body;
  final HttpHeaders headers;
}

extension on MinerRuntime {
  MinerRuntime copyWith({String? logSnippet}) {
    return MinerRuntime(
      ip: ip,
      onlineStatus: onlineStatus,
      ghs5s: ghs5s,
      ghsav: ghsav,
      ambientTemp: ambientTemp,
      power: power,
      fan1: fan1,
      fan2: fan2,
      fan3: fan3,
      fan4: fan4,
      runningMode: runningMode,
      logSnippet: logSnippet ?? this.logSnippet,
      fetchedAt: fetchedAt,
    );
  }
}
