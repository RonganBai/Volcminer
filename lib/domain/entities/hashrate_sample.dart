class HashrateSample {
  const HashrateSample({
    required this.recordedAt,
    required this.totalHashrateGh,
  });

  final DateTime recordedAt;
  final double totalHashrateGh;

  HashrateSample copyWith({
    DateTime? recordedAt,
    double? totalHashrateGh,
  }) {
    return HashrateSample(
      recordedAt: recordedAt ?? this.recordedAt,
      totalHashrateGh: totalHashrateGh ?? this.totalHashrateGh,
    );
  }
}
