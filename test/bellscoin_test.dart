import 'dart:io';

import 'package:bitfinite/models/isar/models/blockchain_data/address.dart';
import 'package:bitfinite/utilities/amount/amount.dart';
import 'package:bitfinite/utilities/enums/derive_path_type_enum.dart';
import 'package:bitfinite/wallets/crypto_currency/crypto_currency.dart';
import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("Bellscoin coin class (pure Dart)", () {
    final bells = Bellscoin(CryptoCurrencyNetwork.main);

    test("identity", () {
      expect(bells.identifier, "bellscoin");
      expect(bells.ticker, "BELLS");
      expect(bells.uriScheme, "bellscoin");
    });

    test("no testnet is constructible", () {
      expect(
        () => Bellscoin(CryptoCurrencyNetwork.test),
        throwsA(isA<Exception>()),
      );
    });

    test("derivation path uses SLIP-44 coin type 762", () {
      // Deliberately NOT the Nintondo extension's m/44'/0' — see the
      // constructDerivePath doc comment in bellscoin.dart.
      expect(
        bells.constructDerivePath(
          derivePathType: DerivePathType.bip44,
          chain: 0,
          index: 0,
        ),
        "m/44'/762'/0'/0/0",
      );
    });

    test("genesis hash matches bellscoinV3 kernel/chainparams.cpp", () {
      expect(
        bells.genesisHash,
        "e5be24df57c43a82d15c2f06bda961296948f8f8eb48501bed1efb929afe0698",
      );
    });

    test("policy constants match the node source", () {
      // DUST_RELAY_TX_FEE 3000 sat/kvB => 546 sat P2PKH dust (Bitcoin's).
      expect(bells.dustLimit.raw, BigInt.from(546));
      // 10x DEFAULT_TRANSACTION_MINFEE (10000 sat/kvB).
      expect(bells.defaultFeeRate, BigInt.from(100000));
      expect(bells.targetBlockTimeSeconds, 60);
      expect(bells.fractionDigits, 8);
      expect(
        bells.dustLimit,
        Amount(rawValue: BigInt.from(546), fractionDigits: 8),
      );
    });

    test("block explorer links to the Nintondo explorer", () {
      expect(
        bells.defaultBlockExplorer("abc123").toString(),
        "https://nintondo.io/bells/explorer/tx/abc123",
      );
    });
  });

  group(
    "Bellscoin coin class (requires coinlib)",
    () {
      final bells = Bellscoin(CryptoCurrencyNetwork.main);

      setUpAll(() => coinlib.loadCoinlib());

      test("validateAddress accepts a live mainnet P2PKH address", () {
        // Coinbase payout address read from block 1210962 via the esplora
        // API.
        expect(
          bells.validateAddress("B5bLTaCj9m1QtTDLV8rrRgQTUEs4dSiboa"),
          true,
        );
      });

      test("Dogecoin addresses collide with Bells P2SH — documented hazard", () {
        // bellscoinV3 chose P2SH version byte 30, which is Dogecoin's P2PKH
        // byte, so every Doge address is ALSO a checksum-valid Bells P2SH
        // address (and real Bells P2SH addresses start with 'D'). A user
        // pasting a Doge address into the Bells send field passes
        // validation and burns the coins. This test pins the collision so
        // nobody "fixes" a send-flow bug by loosening validateAddress —
        // any guard has to live above it (e.g. warn on 'D' addresses).
        expect(
          bells.validateAddress("DDogepartyxxxxxxxxxxxxxxxxxxw1dfzr"),
          true,
        );
      });

      test("validateAddress rejects other chains' addresses", () {
        // Pepecoin (prefix 56 = 'P').
        expect(
          bells.validateAddress("PfM3mHVGkroaJxqfXNiJHbCAWuq14U8kAV"),
          false,
        );
        // BFX cashaddr.
        expect(
          bells.validateAddress(
            "bfx:frazyrzg50rpdcmc2rn5f553f2tyvtk3kgjszd0v33",
          ),
          false,
        );
        // Bitcoin P2PKH (prefix 0 = '1').
        expect(
          bells.validateAddress("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"),
          false,
        );
      });

      test("derived P2PKH addresses start with B and round-trip validate", () {
        // Any valid pubkey works; what matters is the version byte routing.
        final key = coinlib.ECPrivateKey.fromHex(
          "0000000000000000000000000000000000000000000000000000000000000001",
        );
        final result = bells.getAddressForPublicKey(
          publicKey: key.pubkey,
          derivePathType: DerivePathType.bip44,
        );
        expect(result.addressType, AddressType.p2pkh);
        expect(result.address.toString().startsWith("B"), true);
        expect(bells.validateAddress(result.address.toString()), true);
      });
    },
    // Runs when the native lib is present (`dart run coinlib:build_linux`);
    // skips cleanly where it isn't, like the electrum_seed_utils tests.
    skip: File("build/libsecp256k1.so").existsSync()
        ? false
        : "Requires build/libsecp256k1.so for coinlib-backed address checks "
              "on Ubuntu; pure-Dart Bellscoin coverage remains active.",
  );
}
