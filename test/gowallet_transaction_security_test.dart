import 'dart:typed_data';

import 'package:bitfinite/electrumx_rpc/electrumx_client.dart';
import 'package:bitfinite/gowallet/bounded_fee.dart';
import 'package:bitfinite/gowallet/verified_prevouts.dart';
import 'package:bitfinite/models/input.dart';
import 'package:bitfinite/models/isar/models/blockchain_data/address.dart';
import 'package:bitfinite/models/isar/models/blockchain_data/utxo.dart';
import 'package:bitfinite/utilities/enums/derive_path_type_enum.dart';
import 'package:bitfinite/wallets/crypto_currency/crypto_currency.dart';
import 'package:bitfinite/wallets/crypto_currency/interfaces/electrumx_currency_interface.dart';
import 'package:bitfinite/wallets/isar/models/wallet_info.dart';
import 'package:bitfinite/wallets/models/tx_data.dart';
import 'package:bitfinite/wallets/wallet/impl/pepecoin_wallet.dart';
import 'package:bitfinite/wallets/wallet/impl/public_electrum_wallet.dart';
import 'package:coinlib_flutter/coinlib_flutter.dart' as cl;
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

// A deterministic adversarial RPC stub. No chain funds, secrets or broadcasts.
class NodeStub implements ElectrumXClient {
  NodeStub(this.raw);
  String raw;
  String reported = 'bad-txid';
  Decimal rate = Decimal.one;
  int requests = 0;
  @override
  Future<Map<String, dynamic>> getTransaction({
    required String txHash,
    bool verbose = true,
    String? requestID,
  }) async {
    expect(verbose, false);
    requests++;
    return {'rawtx': raw};
  }

  @override
  Future<String> broadcastTransaction({
    required String rawTx,
    String? requestID,
  }) async => reported;
  @override
  Future<Decimal> estimateFee({String? requestID, required int blocks}) async =>
      rate;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FeeWallet extends PepecoinWallet {
  FeeWallet() : super(CryptoCurrencyNetwork.main);
  @override
  WalletInfo get info => WalletInfo(
    walletId: 'audit',
    name: 'audit',
    mainAddressType: AddressType.p2pkh,
    coinName: cryptoCurrency.identifier,
  );
}

void main() {
  setUpAll(cl.loadCoinlib);
  late cl.HDPrivateKey key;
  late ElectrumXCurrencyInterface coin;
  late cl.Address address;
  late cl.Transaction funding;
  setUp(() {
    key = cl.HDPrivateKey.fromSeed(Uint8List.fromList(List.filled(32, 1)));
    coin = Pepecoin(CryptoCurrencyNetwork.main);
    address = coin
        .getAddressForPublicKey(
          publicKey: key.publicKey,
          derivePathType: DerivePathType.bip44,
        )
        .address;
    funding = cl.Transaction(
      inputs: [
        cl.RawInput(
          prevOut: cl.OutPoint.fromHex('11' * 32, 0),
          scriptSig: Uint8List(0),
        ),
      ],
      outputs: [cl.Output.fromAddress(BigInt.from(1000000000), address)],
    );
  });
  StandardInput input({
    int value = 1000000000,
    int vout = 0,
    String? txid,
    String? owner,
    DerivePathType path = DerivePathType.bip44,
  }) => StandardInput(
    UTXO(
      walletId: 'audit',
      txid: txid ?? funding.txid,
      vout: vout,
      value: value,
      name: '',
      isBlocked: false,
      blockedReason: null,
      isCoinbase: false,
      blockHash: null,
      blockHeight: 10,
      blockTime: null,
      address: owner ?? address.toString(),
    ),
    key: key,
    derivePathType: path,
  );

  test(
    'reproduce legacy amount lie: valid signature but 9 extra coins in fee',
    () {
      const claimed = 100000000, displayedFee = 1000;
      final unsigned = cl.Transaction(
        inputs: [
          cl.P2PKHInput(
            prevOut: cl.OutPoint.fromHex(funding.txid, 0),
            publicKey: key.publicKey,
          ),
        ],
        outputs: [
          cl.Output.fromAddress(BigInt.from(claimed - displayedFee), address),
        ],
      );
      final signed = unsigned.signLegacy(inputN: 0, key: key.privateKey);
      final signedInput = signed.inputs.single as cl.P2PKHInput;
      final digest = cl.LegacySignatureHasher(
        cl.LegacySignDetails(
          tx: signed,
          inputN: 0,
        ).addScript(address.program.script),
      ).hash;
      expect(signedInput.insig!.signature.verify(key.publicKey, digest), true);
      expect(
        funding.outputs.single.value - signed.outputs.single.value,
        BigInt.from(900001000),
      );
    },
  );

  test(
    'actual PEP and public wallet signing entry points reject amount lie',
    () async {
      for (final wallet in <PepecoinWallet>[
        PepecoinWallet(CryptoCurrencyNetwork.main),
        PublicElectrumWallet(coin),
      ]) {
        final node = NodeStub(funding.toHex());
        wallet.electrumXClient = node;
        // No DB/secure storage exists: rejection must happen before signing/DB use.
        await expectLater(
          wallet.buildTransaction(
            txData: TxData(),
            inputsWithKeys: [input(value: 100000000)],
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'cause',
              contains('incorrect input amount'),
            ),
          ),
        );
        expect(node.requests, 1);
      }
    },
  );

  test(
    'honest input accepted; cached raw still checks new amount claims',
    () async {
      final guard = VerifiedPrevouts();
      var requests = 0;
      Future<String> fetch(String id) async {
        requests++;
        return funding.toHex();
      }

      await guard.verify(inputs: [input()], currency: coin, fetchRaw: fetch);
      await expectLater(
        guard.verify(
          inputs: [input(value: 1)],
          currency: coin,
          fetchRaw: fetch,
        ),
        throwsStateError,
      );
      expect(requests, 1);
    },
  );

  for (final scenario in [
    'hash',
    'index',
    'amount',
    'script',
    'key',
    'trailing',
    'malformed',
    'duplicate',
    'oversize',
    'unavailable',
  ]) {
    test('reject malicious prevout: $scenario', () async {
      var raw = funding.toHex();
      var inputs = [input()];
      switch (scenario) {
        case 'hash':
          inputs = [input(txid: '22' * 32)];
        case 'index':
          inputs = [input(vout: 1)];
        case 'amount':
          inputs = [input(value: 1)];
        case 'script':
          funding = cl.Transaction(
            inputs: funding.inputs,
            outputs: [
              cl.Output.fromScriptBytes(
                BigInt.from(1000000000),
                Uint8List.fromList([0x51]),
              ),
            ],
          );
          raw = funding.toHex();
          inputs = [input()];
        case 'key':
          inputs = [input(owner: 'incorrect-owner')];
        case 'trailing':
          raw += '00';
        case 'malformed':
          raw = '00';
        case 'duplicate':
          inputs = [input(), input()];
        case 'oversize':
          raw = '00' * (cl.Transaction.maxSize + 1);
      }
      await expectLater(
        VerifiedPrevouts().verify(
          inputs: inputs,
          currency: coin,
          fetchRaw: (_) async {
            if (scenario == 'unavailable') throw StateError('RPC unavailable');
            return raw;
          },
        ),
        throwsA(anything),
      );
    });
  }

  test('SCASH witness funding uses txid, not wtxid', () async {
    coin = Scash(CryptoCurrencyNetwork.main);
    address = coin
        .getAddressForPublicKey(
          publicKey: key.publicKey,
          derivePathType: DerivePathType.bip84,
        )
        .address;
    funding =
        cl.Transaction(
          inputs: [
            cl.P2WPKHInput(
              prevOut: cl.OutPoint.fromHex('11' * 32, 0),
              publicKey: key.publicKey,
            ),
          ],
          outputs: [cl.Output.fromAddress(BigInt.from(1000000000), address)],
        ).signLegacyWitness(
          inputN: 0,
          key: key.privateKey,
          value: BigInt.from(1000001000),
        );
    expect(funding.txid, isNot(funding.hashHex));
    await VerifiedPrevouts().verify(
      inputs: [input(path: DerivePathType.bip84)],
      currency: coin,
      fetchRaw: (_) async => funding.toHex(),
    );
  });

  test(
    'broadcast mismatch rejected before local UTXOs or history writes',
    () async {
      final wallet = PepecoinWallet(CryptoCurrencyNetwork.main);
      wallet.electrumXClient = NodeStub(funding.toHex());
      await expectLater(
        wallet.confirmSend(txData: TxData(raw: funding.toHex())),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'cause',
            contains('different transaction ID'),
          ),
        ),
      );
      expect(
        () => VerifiedPrevouts.checkBroadcast(funding.toHex(), funding.txid),
        returnsNormally,
      );
    },
  );

  test(
    'fee cap rejects server rate and retains only previously safe cache',
    () async {
      final wallet = FeeWallet();
      final node = NodeStub('');
      wallet.electrumXClient = node;
      await expectLater(wallet.fees, throwsStateError);
      node.rate = Decimal.parse('0.000025');
      final safe = await wallet.fees;
      node.rate = Decimal.one;
      expect(await wallet.fees, same(safe));
    },
  );

  test('normal decimal/exponent fee estimates parse', () {
    expect(parseBoundedElectrumFee(0.00001), Decimal.parse('0.00001'));
    expect(parseBoundedElectrumFee('1e-8'), Decimal.parse('0.00000001'));
    expect(parseBoundedElectrumFee(-1), Decimal.fromInt(-1));
  });
  test('reject fee allocation bombs and malformed numeric values', () {
    for (final value in [
      '1e999999999',
      '1e-999999999',
      '9' * 1000,
      double.infinity,
      double.nan,
      <Object>[],
      <String, Object>{},
      '1e19',
    ]) {
      expect(() => parseBoundedElectrumFee(value), throwsFormatException);
    }
  });
}
