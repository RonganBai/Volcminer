import 'dart:convert';

class VolcMinerParsedChain {
  const VolcMinerParsedChain({
    required this.index,
    required this.chainAcn,
    required this.hw,
    required this.chainAcs,
    required this.freq,
    required this.temp,
    required this.chainRate,
  });

  final int index;
  final String chainAcn;
  final String hw;
  final String chainAcs;
  final String freq;
  final String temp;
  final String chainRate;
}

List<VolcMinerParsedChain> parseVolcMinerChains(dynamic raw) {
  final dynamic candidate = _extractChainsCandidate(raw);
  if (candidate == null) {
    return const <VolcMinerParsedChain>[];
  }
  if (candidate is List) {
    return _parseVolcMinerChainList(candidate);
  }
  if (candidate is String) {
    final String trimmed = candidate.trim();
    if (trimmed.isEmpty || trimmed == '--') {
      return const <VolcMinerParsedChain>[];
    }

    for (final String attempt in <String>{
      trimmed,
      _decodeEscapedVolcText(trimmed),
    }) {
      final dynamic decoded = _tryDecodeJson(attempt);
      if (decoded is List) {
        final List<VolcMinerParsedChain> parsed = _parseVolcMinerChainList(
          decoded,
        );
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }
      if (decoded is Map) {
        final List<VolcMinerParsedChain> parsed = parseVolcMinerChains(decoded);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }
    }

    return _parseVolcMinerChainsFromText(trimmed);
  }
  return const <VolcMinerParsedChain>[];
}

dynamic _extractChainsCandidate(dynamic raw) {
  if (raw == null) {
    return null;
  }
  if (raw is List) {
    return raw;
  }
  if (raw is Map) {
    final Map<dynamic, dynamic> map = raw;
    if (map.containsKey('chains')) {
      return map['chains'];
    }
    if (map['data'] != null) {
      final dynamic nested = _extractChainsCandidate(map['data']);
      if (nested != null) {
        return nested;
      }
    }
    return null;
  }
  if (raw is! String) {
    return null;
  }

  final String trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '--') {
    return null;
  }

  for (final String attempt in <String>{
    trimmed,
    _decodeEscapedVolcText(trimmed),
  }) {
    final dynamic decoded = _tryDecodeJson(attempt);
    if (decoded is List) {
      return decoded;
    }
    if (decoded is Map) {
      final dynamic nested = _extractChainsCandidate(decoded);
      if (nested != null) {
        return nested;
      }
    }

    final String? embedded = _extractEmbeddedChainsText(attempt);
    if (embedded != null) {
      return embedded;
    }
  }

  return trimmed;
}

dynamic _tryDecodeJson(String text) {
  try {
    return jsonDecode(text);
  } catch (_) {
    return null;
  }
}

List<VolcMinerParsedChain> _parseVolcMinerChainList(List<dynamic> rawList) {
  final List<VolcMinerParsedChain> chains = <VolcMinerParsedChain>[];
  for (var i = 0; i < rawList.length; i++) {
    final dynamic entry = rawList[i];
    if (entry is! Map) {
      continue;
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(entry);
    final int index = _parseIndex(map['index'], fallback: i + 1);
    if (index < 0) {
      continue;
    }
    chains.add(
      VolcMinerParsedChain(
        index: index,
        chainAcn: _normalizeChainValue(map['chain_acn']),
        hw: _normalizeChainValue(map['hw']),
        chainAcs: _normalizeChainValue(map['chain_acs']),
        freq: _normalizeChainValue(map['freq']),
        temp: _normalizeChainValue(map['temp']),
        chainRate: _normalizeChainValue(map['chain_rate']),
      ),
    );
  }
  return List<VolcMinerParsedChain>.unmodifiable(chains);
}

List<VolcMinerParsedChain> _parseVolcMinerChainsFromText(String raw) {
  final String normalized = _decodeEscapedVolcText(raw).replaceAll('\r', '');
  final String scoped = _sliceLikelyChainsArray(normalized);
  final Iterable<RegExpMatch> matches = RegExp(
    r'\{[^{}]*\}',
    dotAll: true,
  ).allMatches(scoped);
  final List<VolcMinerParsedChain> chains = <VolcMinerParsedChain>[];

  for (final RegExpMatch match in matches) {
    final String block = match.group(0) ?? '';
    final String? indexRaw = _extractFieldValue(block, 'index');
    final String? chainAcn = _extractFieldValue(block, 'chain_acn');
    final String? hw = _extractFieldValue(block, 'hw');
    final String? chainAcs = _extractFieldValue(block, 'chain_acs');
    final String? freq = _extractFieldValue(block, 'freq');
    final String? temp = _extractFieldValue(block, 'temp');
    final String? chainRate = _extractFieldValue(block, 'chain_rate');

    if (<String?>[
      indexRaw,
      chainAcn,
      hw,
      chainAcs,
      freq,
      temp,
      chainRate,
    ].every((String? value) => value == null)) {
      continue;
    }

    final int index = _parseIndex(indexRaw, fallback: chains.length + 1);
    if (index < 0) {
      continue;
    }

    chains.add(
      VolcMinerParsedChain(
        index: index,
        chainAcn: _normalizeChainValue(chainAcn),
        hw: _normalizeChainValue(hw),
        chainAcs: _normalizeChainValue(chainAcs),
        freq: _normalizeChainValue(freq),
        temp: _normalizeChainValue(temp),
        chainRate: _normalizeChainValue(chainRate),
      ),
    );
  }

  return List<VolcMinerParsedChain>.unmodifiable(chains);
}

String _sliceLikelyChainsArray(String text) {
  final String? embedded = _extractEmbeddedChainsText(text);
  if (embedded != null) {
    return embedded;
  }
  final int start = text.indexOf('[');
  final int end = text.lastIndexOf(']');
  if (start >= 0 && end > start) {
    return text.substring(start, end + 1);
  }
  return text;
}

String? _extractEmbeddedChainsText(String text) {
  final RegExp quotedPattern = RegExp(
    r'"chains"\s*:\s*"((?:\\.|[^"])*)"',
    dotAll: true,
  );
  final RegExpMatch? quotedMatch = quotedPattern.firstMatch(text);
  if (quotedMatch != null) {
    return _decodeEscapedVolcText(quotedMatch.group(1) ?? '');
  }

  final RegExp arrayPattern = RegExp(
    r'"chains"\s*:\s*(\[[\s\S]*?\])',
    dotAll: true,
  );
  final RegExpMatch? arrayMatch = arrayPattern.firstMatch(text);
  if (arrayMatch != null) {
    return arrayMatch.group(1)?.trim();
  }
  return null;
}

String? _extractFieldValue(String block, String key) {
  final RegExp pattern = RegExp(
    '"${RegExp.escape(key)}"\\s*:\\s*("(?:\\\\.|[^"])*"|[^,}\\]]+)',
    dotAll: true,
  );
  final RegExpMatch? match = pattern.firstMatch(block);
  if (match == null) {
    return null;
  }
  var value = (match.group(1) ?? '').trim();
  if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
    value = value.substring(1, value.length - 1);
  }
  value = _decodeEscapedVolcText(value);
  return value.isEmpty ? null : value;
}

int _parseIndex(dynamic raw, {required int fallback}) {
  if (raw is num) {
    return raw.toInt();
  }
  final int? parsed = int.tryParse('${raw ?? ''}'.trim());
  return parsed ?? fallback;
}

String _normalizeChainValue(dynamic value) {
  final String normalized = _decodeEscapedVolcText('${value ?? ''}'.trim());
  return normalized.isEmpty ? '--' : normalized;
}

String _decodeEscapedVolcText(String value) {
  return value
      .replaceAll(r'\"', '"')
      .replaceAll(r'\/', '/')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '')
      .trim();
}
