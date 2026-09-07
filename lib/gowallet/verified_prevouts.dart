import 'package:coinlib_flutter/coinlib_flutter.dart' as cl;
import 'package:flutter/foundation.dart';

import '../models/input.dart';
import '../wallets/crypto_currency/interfaces/electrumx_currency_interface.dart';

/// Authenticates amounts before legacy signatures (which do not commit to the
/// input amount). This is not a proof of inclusion, maturity or unspentness.
class VerifiedPrevouts {
  final _cache = <String, cl.Transaction>{};
  int _cachedBytes = 0;
  static const _maxCacheBytes = 4 * 1024 * 1024;

  Future<void> verify({
    required List<BaseInput> inputs,
    required ElectrumXCurrencyInterface currency,
    required Future<String> Function(String txid) fetchRaw,
  }) async {
    final seen = <String>{};
    for (final input in inputs) {
      if (input is! StandardInput ||
          input.key == null ||
          input.derivePathType == null) {
        throw StateError('Cannot verify transaction input');
      }
      final u = input.utxo;
      if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(u.txid) ||
          u.vout < 0 ||
          u.value < 0 ||
          !seen.add('${u.txid.toLowerCase()}:${u.vout}')) {
        throw StateError('Invalid or duplicate transaction input');
      }
      final localAddress = currency
          .getAddressForPublicKey(
            publicKey: input.key!.publicKey,
            derivePathType: input.derivePathType!,
          )
          .address;
      if (localAddress.toString() != u.address) {
        throw StateError('Transaction input does not match wallet key');
      }
      final id = u.txid.toLowerCase();
      var previous = _cache.remove(id);
      if (previous != null) {
        _cache[id] = previous;
      } else {
        final raw = await fetchRaw(id);
        if (raw.isEmpty ||
            raw.length > cl.Transaction.maxSize * 2 ||
            raw.length.isOdd ||
            !RegExp(r'^[a-fA-F0-9]+$').hasMatch(raw)) {
          throw StateError('Invalid previous transaction encoding');
        }
        previous = cl.Transaction.fromHex(raw);
        // Reject trailing bytes, noncanonical and unsupported encodings.
        if (previous.toHex() != raw.toLowerCase() || previous.txid != id) {
          throw StateError('Previous transaction hash or encoding mismatch');
        }
        while (_cache.isNotEmpty &&
            (_cache.length >= 128 ||
                _cachedBytes + previous.size > _maxCacheBytes)) {
          _cachedBytes -= _cache.remove(_cache.keys.first)!.size;
        }
        _cache[id] = previous;
        _cachedBytes += previous.size;
      }
      if (u.vout >= previous.outputs.length) {
        throw StateError('Previous transaction output is missing');
      }
      final output = previous.outputs[u.vout];
      if (output.value != BigInt.from(u.value) ||
          !listEquals(
            output.scriptPubKey,
            localAddress.program.script.compiled,
          )) {
        throw StateError(
          'Node supplied an incorrect input amount or script; '
          'switch node and refresh wallet before sending',
        );
      }
    }
  }

  static void checkBroadcast(String raw, String reportedTxid) {
    final expected = cl.Transaction.fromHex(raw).txid;
    if (reportedTxid.toLowerCase() != expected) {
      throw StateError(
        'Node returned a different transaction ID; '
        'broadcast status is unknown, refresh wallet before retrying',
      );
    }
  }
}
