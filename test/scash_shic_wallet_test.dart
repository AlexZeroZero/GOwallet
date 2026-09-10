import 'package:bitfinite/app_config.dart';
import 'package:bitfinite/electrumx_rpc/verify_network.dart';
import 'package:bitfinite/utilities/enums/derive_path_type_enum.dart';
import 'package:bitfinite/wallets/crypto_currency/crypto_currency.dart';
import 'package:bitfinite/wallets/wallet/impl/public_electrum_wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final scash = Scash(CryptoCurrencyNetwork.main);
  final shic = Shibacoin(CryptoCurrencyNetwork.main);

  test('flavor registers both distinct mainnet wallets', () {
    expect(AppConfig.coins.map((c) => c.ticker), [
      'SCASH',
      'SHIC',
      'PEP',
      'DINGO',
      'BFX',
    ]);
    expect(scash, isNot(shic));
    expect(() => Scash(CryptoCurrencyNetwork.test), throwsArgumentError);
    expect(() => Shibacoin(CryptoCurrencyNetwork.test), throwsArgumentError);
  });

  test('SLIP-44 recovery paths are chain specific', () {
    expect(
      scash.constructDerivePath(
        derivePathType: DerivePathType.bip84,
        chain: 0,
        index: 0,
      ),
      "m/84'/805'/0'/0/0",
    );
    expect(
      scash.constructDerivePath(
        derivePathType: DerivePathType.bip44,
        account: 2,
        chain: 1,
        index: 9,
      ),
      "m/44'/805'/2'/1/9",
    );
    expect(
      shic.constructDerivePath(
        derivePathType: DerivePathType.bip44,
        chain: 0,
        index: 0,
      ),
      "m/44'/4474'/0'/0/0",
    );
    expect(
      () => shic.constructDerivePath(
        derivePathType: DerivePathType.bip84,
        chain: 0,
        index: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => scash.constructDerivePath(
        derivePathType: DerivePathType.bip84,
        chain: 0,
        index: 0x80000000,
      ),
      throwsArgumentError,
    );
  });

  test('node defaults select TLS and keep per-coin identifiers', () {
    final a = scash.defaultNode(isPrimary: true);
    final b = shic.defaultNode(isPrimary: true);
    expect(a.host, 'scash.gozero.trade');
    expect(b.host, 'shic.gozero.trade');
    expect(a.port, 50002);
    expect(b.port, 50012);
    expect(a.useSSL, true);
    expect(b.useSSL, true);
    expect(a.coinName, 'scash');
    expect(b.coinName, 'shibacoin');
    expect(a.id, isNot(b.id));
  });

  test('address and maturity parameters agree with the full node sources', () {
    expect(scash.networkParams.bech32Hrp, 'scash');
    expect(scash.networkParams.p2pkhPrefix, 0);
    expect(scash.minCoinbaseConfirms, 100);
    expect(shic.networkParams.p2pkhPrefix, 63);
    expect(shic.networkParams.p2shPrefix, 22);
    expect(shic.networkParams.privHDPrefix, 0x02fac495);
    expect(shic.networkParams.pubHDPrefix, 0x02fadafe);
    expect(shic.minCoinbaseConfirms, 240);
    expect(shic.dustLimit.raw, BigInt.from(1000000));
  });

  test(
    'wrong-chain, missing-genesis and unsupported hash servers are rejected',
    () {
      final valid = {
        'genesis_hash': scash.genesisHash,
        'hash_function': 'sha256',
      };
      expect(
        () => verifyElectrumNetwork(valid, scash.genesisHash),
        returnsNormally,
      );
      expect(
        () => verifyElectrumNetwork(valid, shic.genesisHash),
        throwsStateError,
      );
      expect(
        () => verifyElectrumNetwork(null, scash.genesisHash),
        throwsStateError,
      );
      expect(
        () => verifyElectrumNetwork({
          'genesis_hash': scash.genesisHash,
        }, scash.genesisHash),
        throwsStateError,
      );
    },
  );

  test('fees round up without losing fractional satoshis', () {
    final wallet = PublicElectrumWallet(scash);
    expect(
      wallet.estimateTxFee(vSize: 141, feeRatePerKB: BigInt.from(1001)),
      142,
    );
    expect(
      wallet.estimateTxFee(vSize: 141, feeRatePerKB: BigInt.from(1000)),
      141,
    );
    expect(
      () => wallet.estimateTxFee(vSize: -1, feeRatePerKB: BigInt.one),
      throwsArgumentError,
    );
    final legacy = PublicElectrumWallet(shic);
    expect(
      legacy.estimateTxFee(vSize: 226, feeRatePerKB: shic.defaultFeeRate),
      226000,
    );
  });
}
