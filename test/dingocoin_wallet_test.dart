import 'package:bitfinite/app_config.dart';
import 'package:bitfinite/electrumx_rpc/verify_network.dart';
import 'package:bitfinite/utilities/enums/derive_path_type_enum.dart';
import 'package:bitfinite/wallets/crypto_currency/crypto_currency.dart';
import 'package:bitfinite/wallets/wallet/impl/public_electrum_wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final coin = Dingocoin(CryptoCurrencyNetwork.main);
  // Public block 1 from both independently operated nodes, matching Core's
  // checkpoint. Genesis alone cannot distinguish DINGO from Dogecoin.
  const header =
      '040062009156352c1818b32e90c9e792efd6a11a82fe7956a630f03bbee236cedae3911ad2071e2162c4805f039a457267166611af5b127891be4276e2e9810b9559c9b7a6936760f0ff0f1e909e0000';

  test(
    'native DINGO registration and recovery use the existing BIP44 convention',
    () {
      expect(AppConfig.getCryptoCurrencyFor('dingocoin'), coin);
      expect(
        coin.constructDerivePath(
          derivePathType: DerivePathType.bip44,
          chain: 0,
          index: 0,
        ),
        "m/44'/3'/0'/0/0",
      );
      expect(
        coin.constructDerivePath(
          derivePathType: DerivePathType.bip44,
          account: 1,
          chain: 1,
          index: 7,
        ),
        "m/44'/3'/1'/1/7",
      );
      expect(() => Dingocoin(CryptoCurrencyNetwork.test), throwsArgumentError);
      expect(
        () => coin.constructDerivePath(
          derivePathType: DerivePathType.bip84,
          chain: 0,
          index: 0,
        ),
        throwsArgumentError,
      );
      expect(coin.supportedDerivationPathTypes, [DerivePathType.bip44]);
      expect(coin.networkParams.p2pkhPrefix, 30);
      expect(coin.networkParams.p2shPrefix, 22);
      expect(coin.networkParams.wifPrefix, 158);
      expect(
        coin.networkParams.messagePrefix,
        '\x1aDingocoin Signed Message:\n',
      );
      expect(coin.minCoinbaseConfirms, 240);
      expect(
        coin.defaultBlockExplorer('abc').toString(),
        'https://explorer.dingocoin.com/tx/abc',
      );
    },
  );
  test(
    'default node is third-party TLS, fee fallback covers observed relay policy',
    () {
      final node = coin.defaultNode(isPrimary: true);
      expect(node.host, 'elecx1.dingocoin.com');
      expect(node.port, 3342);
      expect(node.useSSL, isTrue);
      expect(node.coinName, 'dingocoin');
      expect(coin.defaultFeeRate, BigInt.from(100000000));
      expect(coin.dustLimit.raw, BigInt.from(100000000));
      expect(
        PublicElectrumWallet(
          coin,
        ).estimateTxFee(vSize: 226, feeRatePerKB: coin.defaultFeeRate),
        22600000,
      );
    },
  );
  test(
    'DINGO checkpoint rejects shared-genesis wrong chains and malformed replies',
    () {
      expect(
        () => verifyElectrumCheckpoint(header, Dingocoin.blockOneHash),
        returnsNormally,
      );
      for (final bad in [
        null,
        <String, dynamic>{},
        '',
        '${header}00',
        '${header.substring(0, 158)}ff',
        'g' * 160,
      ]) {
        expect(
          () => verifyElectrumCheckpoint(bad, Dingocoin.blockOneHash),
          throwsStateError,
        );
      }
    },
  );
}
