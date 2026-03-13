import 'dart:math';

class IpUtils {
  static final RegExp _ipv4RegExp = RegExp(
    r'^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$',
  );

  static bool isValidIpv4(String value) {
    return _ipv4RegExp.hasMatch(value.trim());
  }

  static bool isValidCidr(String value) {
    return normalizeCidrInput(value) != null;
  }

  static String? normalizeCidrInput(String value) {
    final input = value.trim();
    if (input.isEmpty) {
      return null;
    }

    if (input.contains('/')) {
      final parts = input.split('/');
      if (parts.length != 2) {
        return null;
      }
      final ip = parts[0].trim();
      final prefix = int.tryParse(parts[1].trim());
      if (!isValidIpv4(ip) || prefix == null || prefix < 0 || prefix > 32) {
        return null;
      }
      return '$ip/$prefix';
    }

    final octets = input.split('.');
    if (octets.isEmpty || octets.length > 4) {
      return null;
    }
    final numbers = <int>[];
    for (final octet in octets) {
      final n = int.tryParse(octet.trim());
      if (n == null || n < 0 || n > 255) {
        return null;
      }
      numbers.add(n);
    }

    while (numbers.length < 4) {
      numbers.add(0);
    }
    final ip = '${numbers[0]}.${numbers[1]}.${numbers[2]}.${numbers[3]}';
    final prefix = switch (octets.length) {
      1 => 8,
      2 => 16,
      3 => 24,
      _ => 32,
    };
    return '$ip/$prefix';
  }

  static String? normalizeIpv4WithBase(String value, {String? baseIp}) {
    final input = value.trim();
    if (input.isEmpty) {
      return null;
    }

    if (isValidIpv4(input)) {
      return input;
    }

    if (baseIp == null || !isValidIpv4(baseIp)) {
      return null;
    }

    final parts = input.split('.');
    if (parts.isEmpty || parts.length > 3) {
      return null;
    }

    final tail = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part.trim());
      if (n == null || n < 0 || n > 255) {
        return null;
      }
      tail.add(n);
    }

    final base = baseIp.split('.').map(int.parse).toList();
    final missing = 4 - tail.length;
    final full = <int>[...base.take(missing), ...tail];
    final candidate = '${full[0]}.${full[1]}.${full[2]}.${full[3]}';
    return isValidIpv4(candidate) ? candidate : null;
  }

  static int ipToInt(String ip) {
    final octets = ip.split('.').map(int.parse).toList();
    return (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
  }

  static String intToIp(int value) {
    final a = (value >> 24) & 0xFF;
    final b = (value >> 16) & 0xFF;
    final c = (value >> 8) & 0xFF;
    final d = value & 0xFF;
    return '$a.$b.$c.$d';
  }

  static List<String> expandRange(String startIp, String endIp) {
    if (!isValidIpv4(startIp) || !isValidIpv4(endIp)) {
      return const [];
    }
    final start = ipToInt(startIp);
    final end = ipToInt(endIp);
    if (end < start) {
      return const [];
    }

    final count = end - start + 1;
    return List.generate(count, (index) => intToIp(start + index));
  }

  static List<String> expandCidr(String cidr) {
    final normalized = normalizeCidrInput(cidr);
    if (normalized == null) {
      return const [];
    }

    final parts = normalized.split('/');
    final ip = parts[0];
    final prefix = int.parse(parts[1]);

    final ipInt = ipToInt(ip);
    final mask = prefix == 0 ? 0 : 0xFFFFFFFF << (32 - prefix);
    final network = ipInt & mask;
    final hostBits = 32 - prefix;
    final total = hostBits >= 31 ? pow(2, hostBits).toInt() : (1 << hostBits);

    return List.generate(total, (index) => intToIp(network + index));
  }

  static Set<String> expandAll({String? cidr, String? startIp, String? endIp}) {
    final hasCidr = cidr != null && cidr.trim().isNotEmpty;
    final hasRange =
        startIp != null &&
        startIp.trim().isNotEmpty &&
        endIp != null &&
        endIp.trim().isNotEmpty;
    final safeCidr = cidr?.trim() ?? '';
    final safeStart = startIp?.trim() ?? '';
    final safeEnd = endIp?.trim() ?? '';

    final cidrSet = hasCidr ? expandCidr(safeCidr).toSet() : <String>{};
    final rangeSet = hasRange
        ? expandRange(safeStart, safeEnd).toSet()
        : <String>{};

    if (hasCidr && hasRange) {
      // When both are provided, prefer the explicit start/end subset.
      return rangeSet;
    }
    if (hasRange) {
      return rangeSet;
    }
    return cidrSet;
  }

  static String formatIpBlockLabel(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return '';
    }
    final normalized = normalizeCidrInput(text);
    if (normalized != null && normalized.endsWith('.0/24')) {
      return normalized.replaceFirst('.0/24', '');
    }
    if (text.endsWith('.0/24')) {
      return text.replaceFirst('.0/24', '');
    }
    return text;
  }

  static int compareIpBlocks(String left, String right) {
    final a = _blockParts(left);
    final b = _blockParts(right);
    final second = a[1].compareTo(b[1]);
    if (second != 0) {
      return second;
    }
    final third = a[2].compareTo(b[2]);
    if (third != 0) {
      return third;
    }
    return a[3].compareTo(b[3]);
  }

  static List<int> _blockParts(String value) {
    final formatted = formatIpBlockLabel(value);
    final parts = formatted.split('.');
    final padded = <int>[0, 0, 0, 0];
    for (var i = 0; i < parts.length && i < 4; i++) {
      padded[i] = int.tryParse(parts[i]) ?? 0;
    }
    return padded;
  }
}
