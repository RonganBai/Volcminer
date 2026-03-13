class PoolSlotConfig {
  const PoolSlotConfig({
    required this.slotNo,
    required this.poolUrl,
    required this.workerCode,
  });

  final int slotNo;
  final String poolUrl;
  final String workerCode;

  PoolSlotConfig copyWith({int? slotNo, String? poolUrl, String? workerCode}) {
    return PoolSlotConfig(
      slotNo: slotNo ?? this.slotNo,
      poolUrl: poolUrl ?? this.poolUrl,
      workerCode: workerCode ?? this.workerCode,
    );
  }
}
