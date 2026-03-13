class MinerIssueDiagnosis {
  const MinerIssueDiagnosis({
    required this.code,
    required this.category,
    required this.reason,
    required this.solution,
    required this.logSnippet,
    required this.detectedAt,
    this.secondaryCode,
    this.secondaryReason,
  });

  final String code;
  final String category;
  final String reason;
  final String solution;
  final String logSnippet;
  final DateTime detectedAt;
  final String? secondaryCode;
  final String? secondaryReason;

  MinerIssueDiagnosis copyWith({
    String? code,
    String? category,
    String? reason,
    String? solution,
    String? logSnippet,
    DateTime? detectedAt,
    String? secondaryCode,
    String? secondaryReason,
  }) {
    return MinerIssueDiagnosis(
      code: code ?? this.code,
      category: category ?? this.category,
      reason: reason ?? this.reason,
      solution: solution ?? this.solution,
      logSnippet: logSnippet ?? this.logSnippet,
      detectedAt: detectedAt ?? this.detectedAt,
      secondaryCode: secondaryCode ?? this.secondaryCode,
      secondaryReason: secondaryReason ?? this.secondaryReason,
    );
  }
}
