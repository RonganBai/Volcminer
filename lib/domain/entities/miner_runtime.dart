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
      logSnippet: log,
      fetchedAt: DateTime.now(),
    );
  }
}
