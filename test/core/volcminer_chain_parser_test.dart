import 'package:flutter_test/flutter_test.dart';
import 'package:volcminer/core/utils/volcminer_chain_parser.dart';

void main() {
  test('extracts chains from rawStatus string before fallback fields', () {
    const rawStatus =
        '{"chains":"['
        '{\\"index\\":\\"1\\",\\"chain_acn\\":\\"30\\",\\"hw\\":\\"0\\",\\"chain_acs\\":\\"oooo\\",\\"freq\\":\\"500\\",\\"temp\\":\\"61\\",\\"chain_rate\\":\\"15.1\\"},'
        '{\\"index\\":\\"2\\",\\"chain_acn\\":\\"31\\",\\"hw\\":\\"1\\",\\"chain_acs\\":\\"ooox\\",\\"freq\\":\\"500\\",\\"temp\\":\\"62\\",\\"chain_rate\\":\\"15.2\\"},'
        '{\\"index\\":\\"3\\",\\"chain_acn\\":\\"32\\",\\"hw\\":\\"2\\",\\"chain_acs\\":\\"oxoo\\",\\"freq\\":\\"500\\",\\"temp\\":\\"63\\",\\"chain_rate\\":\\"15.3\\"}'
        ']"}';

    final chains = parseVolcMinerChains(rawStatus);

    expect(chains, hasLength(3));
    expect(chains[0].index, 1);
    expect(chains[0].chainAcn, '30');
    expect(chains[0].hw, '0');
    expect(chains[0].chainAcs, 'oooo');
    expect(chains[0].freq, '500');
    expect(chains[0].temp, '61');
    expect(chains[0].chainRate, '15.1');
    expect(chains[2].index, 3);
    expect(chains[2].chainAcs, 'oxoo');
  });

  test('keeps zero-based chain indexes when the source uses them', () {
    const rawStatus =
        '{"chains":"['
        '{\\"index\\":\\"0\\",\\"chain_acn\\":\\"96\\",\\"hw\\":\\"5760\\",\\"chain_acs\\":\\"oooo\\",\\"freq\\":\\"2,225(2225.00)\\",\\"temp\\":\\"66\\",\\"chain_rate\\":\\"5373.9152\\"},'
        '{\\"index\\":\\"2\\",\\"chain_acn\\":\\"96\\",\\"hw\\":\\"1704\\",\\"chain_acs\\":\\"oooo\\",\\"freq\\":\\"2,225(2225.00)\\",\\"temp\\":\\"67\\",\\"chain_rate\\":\\"5261.1772\\"},'
        '{\\"index\\":\\"3\\",\\"chain_acn\\":\\"96\\",\\"hw\\":\\"4008\\",\\"chain_acs\\":\\"oooo\\",\\"freq\\":\\"2,225(2225.00)\\",\\"temp\\":\\"68\\",\\"chain_rate\\":\\"5352.4431\\"}'
        ']"}';

    final chains = parseVolcMinerChains(rawStatus);

    expect(chains, hasLength(3));
    expect(chains.map((chain) => chain.index), <int>[0, 2, 3]);
    expect(chains.first.hw, '5760');
  });

  test(
    'extracts chains from whole raw body when chains is not decoded separately',
    () {
      const rawBody =
          '{"ghs5s":"45.6","ghsav":"45.4","chains":"['
          '{\\"index\\":\\"1\\",\\"chain_acn\\":\\"30\\",\\"hw\\":\\"0\\",\\"chain_acs\\":\\"oooo\\",\\"freq\\":\\"500\\",\\"temp\\":\\"61\\",\\"chain_rate\\":\\"15.1\\"},'
          '{\\"index\\":\\"2\\",\\"chain_acn\\":\\"31\\",\\"hw\\":\\"1\\",\\"chain_acs\\":\\"ooox\\",\\"freq\\":\\"500\\",\\"temp\\":\\"62\\",\\"chain_rate\\":\\"15.2\\"},'
          '{\\"index\\":\\"3\\",\\"chain_acn\\":\\"32\\",\\"hw\\":\\"2\\",\\"chain_acs\\":\\"oxoo\\",\\"freq\\":\\"500\\",\\"temp\\":\\"63\\",\\"chain_rate\\":\\"15.3\\"}'
          ']"}';

      final chains = parseVolcMinerChains(rawBody);

      expect(chains.map((chain) => chain.index), <int>[1, 2, 3]);
      expect(chains.map((chain) => chain.chainRate), <String>[
        '15.1',
        '15.2',
        '15.3',
      ]);
    },
  );
}
