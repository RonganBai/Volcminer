import 'package:flutter_test/flutter_test.dart';
import 'package:volcminer/core/utils/ip_utils.dart';

void main() {
  group('IpUtils', () {
    test('expands cidr range', () {
      final ips = IpUtils.expandCidr('192.168.1.0/30');
      expect(
        ips,
        equals(['192.168.1.0', '192.168.1.1', '192.168.1.2', '192.168.1.3']),
      );
    });

    test('expands start-end range', () {
      final ips = IpUtils.expandRange('10.0.0.1', '10.0.0.3');
      expect(ips, equals(['10.0.0.1', '10.0.0.2', '10.0.0.3']));
    });

    test('uses explicit range when both cidr and range are set', () {
      final set = IpUtils.expandAll(
        cidr: '10.0.0.0/30',
        startIp: '10.0.0.2',
        endIp: '10.0.0.5',
      );
      expect(set.length, 4);
      expect(set.contains('10.0.0.2'), isTrue);
      expect(set.contains('10.0.0.5'), isTrue);
    });

    test('uses explicit range when cidr and range are both provided', () {
      final set = IpUtils.expandAll(
        cidr: '172.100.1.0/24',
        startIp: '172.100.1.4',
        endIp: '172.100.1.4',
      );
      expect(set.length, 1);
      expect(set.first, '172.100.1.4');
    });

    test('normalizes shorthand cidr input', () {
      expect(IpUtils.normalizeCidrInput('172.100.1'), equals('172.100.1.0/24'));
      expect(IpUtils.normalizeCidrInput('172.100'), equals('172.100.0.0/16'));
      expect(IpUtils.normalizeCidrInput('172'), equals('172.0.0.0/8'));
      expect(
        IpUtils.normalizeCidrInput('172.100.1.4'),
        equals('172.100.1.4/32'),
      );
    });

    test('normalizes partial ip with cidr base', () {
      const baseIp = '172.100.1.0';
      expect(
        IpUtils.normalizeIpv4WithBase('1', baseIp: baseIp),
        equals('172.100.1.1'),
      );
      expect(
        IpUtils.normalizeIpv4WithBase('1.255', baseIp: baseIp),
        equals('172.100.1.255'),
      );
      expect(
        IpUtils.normalizeIpv4WithBase('172.100.1.200', baseIp: baseIp),
        equals('172.100.1.200'),
      );
      expect(IpUtils.normalizeIpv4WithBase('999', baseIp: baseIp), isNull);
    });
  });
}
