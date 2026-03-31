class MinerChainStatus {
  const MinerChainStatus({
    required this.index,
    required this.chainRate,
    required this.temp,
    required this.freq,
    required this.hw,
    required this.chainAcn,
    required this.chainAcs,
  });

  final int index;
  final String chainRate;
  final String temp;
  final String freq;
  final String hw;
  final String chainAcn;
  final String chainAcs;

  double get chainRateValue {
    return _parseNumericValue(chainRate).toDouble();
  }

  double get tempValue {
    return _parseNumericValue(temp).toDouble();
  }

  int get hwValue {
    return _parseNumericValue(hw).toInt();
  }

  bool get hasAcsIssue {
    final normalized = chainAcs.trim().toLowerCase();
    return normalized.contains('x') ||
        normalized.contains('-') ||
        normalized.contains('*');
  }
}

num _parseNumericValue(String raw) {
  final String normalized = raw.replaceAll(',', '').trim();
  if (normalized.isEmpty) {
    return 0;
  }

  final RegExpMatch? match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(normalized);
  if (match == null) {
    return 0;
  }

  final String numericText = match.group(0) ?? '0';
  if (numericText.contains('.')) {
    return double.tryParse(numericText) ?? 0;
  }
  return int.tryParse(numericText) ?? 0;
}

class MinerRuntimeStatus {
  static const String online = 'online';
  static const String offline = 'offline';
  static const String timeout = 'timeout';
  static const String notMiner = 'not_miner';
}

class MinerRuntime {
  const MinerRuntime({
    required this.ip,
    required this.onlineStatus,
    required this.ghs5s,
    required this.ghsav,
    required this.ambientTemp,
    required this.power,
    required this.fan1,
    required this.fan2,
    required this.fan3,
    required this.fan4,
    required this.runningMode,
    required this.chains,
    required this.logSnippet,
    required this.fetchedAt,
  });

  final String ip;
  final String onlineStatus;
  final String ghs5s;
  final String ghsav;
  final String ambientTemp;
  final String power;
  final String fan1;
  final String fan2;
  final String fan3;
  final String fan4;
  final String runningMode;
  final List<MinerChainStatus> chains;
  final String logSnippet;
  final DateTime fetchedAt;

  static MinerRuntime offline(String ip) =>
      _base(ip: ip, status: MinerRuntimeStatus.offline, log: '--');

  static MinerRuntime timeout(String ip) =>
      _base(ip: ip, status: MinerRuntimeStatus.timeout, log: 'Request timeout');

  static MinerRuntime notMiner(String ip) =>
      _base(ip: ip, status: MinerRuntimeStatus.notMiner, log: '--');

  static MinerRuntime _base({
    required String ip,
    required String status,
    required String log,
  }) {
    return MinerRuntime(
      ip: ip,
      onlineStatus: status,
      ghs5s: '--',
      ghsav: '--',
      ambientTemp: '--',
      power: '--',
      fan1: '--',
      fan2: '--',
      fan3: '--',
      fan4: '--',
      runningMode: '--',
      chains: const [],
      logSnippet: log,
      fetchedAt: DateTime.now(),
    );
  }
}
