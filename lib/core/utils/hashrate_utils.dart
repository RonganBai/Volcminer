class HashrateUtils {
  HashrateUtils._();

  static double parseToGh(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty || normalized == '--') {
      return 0;
    }

    final numberMatch = RegExp(r'([0-9][0-9,]*\.?[0-9]*)').firstMatch(normalized);
    if (numberMatch == null) {
      return 0;
    }
    final number = double.tryParse(numberMatch.group(1)!.replaceAll(',', '')) ?? 0;
    if (number <= 0) {
      return 0;
    }

    if (normalized.contains('PH')) {
      return number * 1000000;
    }
    if (normalized.contains('TH')) {
      return number * 1000;
    }
    if (normalized.contains('MH')) {
      return number / 1000;
    }
    if (normalized.contains('KH')) {
      return number / 1000000;
    }
    return number;
  }

  static double effectiveGh(String current, String average) {
    final currentValue = parseToGh(current);
    if (currentValue > 0) {
      return currentValue;
    }
    return parseToGh(average);
  }
}
