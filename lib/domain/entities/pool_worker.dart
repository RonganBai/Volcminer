class PoolWorker {
  const PoolWorker({
    required this.workerName,
    required this.ip,
    required this.status,
    required this.lastShareTime,
    required this.dailyHashrate,
    required this.rejectRate,
  });

  final String workerName;
  final String ip;
  final String status;
  final String lastShareTime;
  final String dailyHashrate;
  final String rejectRate;
}
