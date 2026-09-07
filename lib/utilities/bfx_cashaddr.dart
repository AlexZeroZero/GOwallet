// BitFinite (BFX) cashaddr codec.
//
// BFX is a BCHN fork whose cashaddr encoding is STANDARD in every respect
// (same "bfx"/"bfxtest" prefix scheme, same version-byte layout — P2PKH is
// still type 0 / version byte 0x00, same BCH polymod checksum) EXCEPT it uses
// a custom base32 alphabet with `q` and `f` swapped:
//
//   standard : qpzry9x8gf2tvdw0s3jn54khce6mua7l
//   BFX      : fpzry9x8gq2tvdw0s3jn54khce6mua7l   (index 0 and 9 swapped)
//
// Ground truth: bitfinite-core/src/cashaddr.cpp `CHARSET`, and the web wallet's
// @bitauth/libauth patch (`bech32CharacterSet`). Because of the swap, a P2PKH
// address has version byte 0 → first symbol charset[0] = 'f' (hence "bfx:f...").
//
// The checksum polymod operates on 5-bit VALUES, not characters, so it is
// unchanged — only the char<->value mapping differs. This codec therefore is
// the ordinary cashaddr algorithm parameterised on the BFX alphabet.
//
// Do NOT route BFX addresses through the stock `bitbox`/`coinlib` cashaddr code:
// those use the standard alphabet and will fail the checksum on `bfx:` strings.

import 'dart:typed_data';

class BfxCashAddr {
  static const String charset = "fpzry9x8gq2tvdw0s3jn54khce6mua7l";
  static const String mainnetPrefix = "bfx";
  static const String testnetPrefix = "bfxtest";

  // cashaddr content types (standard).
  static const int typeP2PKH = 0;
  static const int typeP2SH = 1;

  /// Encode a 20-byte hash160 to a BFX cashaddr (e.g. "bfx:f...").
  static String encode({
    required Uint8List hash160,
    int type = typeP2PKH,
    String prefix = mainnetPrefix,
  }) {
    assert(hash160.length == 20, "only 160-bit hashes supported here");
    final versionByte = (type << 3) | _sizeCode(hash160.length);
    final payload = Uint8List.fromList([versionByte, ...hash160]);
    final payload5 = _convertBits(payload, 8, 5, pad: true);
    final checksum = _createChecksum(prefix, payload5);
    final combined = [...payload5, ...checksum];
    final sb = StringBuffer("$prefix:");
    for (final v in combined) {
      sb.write(charset[v]);
    }
    return sb.toString();
  }

  /// Decode a BFX cashaddr into (type, hash160). Throws on bad checksum/format.
  static ({int type, Uint8List hash160}) decode(String address) {
    final lower = address.toLowerCase();
    final idx = lower.indexOf(":");
    final prefix = idx >= 0 ? lower.substring(0, idx) : mainnetPrefix;
    final body = idx >= 0 ? lower.substring(idx + 1) : lower;

    final values = <int>[];
    for (final c in body.split("")) {
      final v = charset.indexOf(c);
      if (v == -1) throw FormatException("invalid cashaddr char '$c'");
      values.add(v);
    }
    if (!_verifyChecksum(prefix, values)) {
      throw FormatException("bad cashaddr checksum for '$address'");
    }
    final payload5 = values.sublist(0, values.length - 8);
    final payload = _convertBits(
      Uint8List.fromList(payload5),
      5,
      8,
      pad: false,
    );
    final versionByte = payload[0];
    final type = (versionByte >> 3) & 0x1f;
    final hash160 = Uint8List.fromList(payload.sublist(1));
    return (type: type, hash160: hash160);
  }

  static bool isValid(String address) {
    try {
      decode(address);
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- internals (standard cashaddr) ---

  static int _sizeCode(int len) {
    switch (len) {
      case 20:
        return 0;
      case 24:
        return 1;
      case 28:
        return 2;
      case 32:
        return 3;
      case 40:
        return 4;
      case 48:
        return 5;
      case 56:
        return 6;
      case 64:
        return 7;
      default:
        throw ArgumentError("unsupported hash length: $len");
    }
  }

  static List<int> _convertBits(
    Uint8List data,
    int from,
    int to, {
    required bool pad,
  }) {
    var acc = 0;
    var bits = 0;
    final out = <int>[];
    final maxv = (1 << to) - 1;
    for (final value in data) {
      acc = (acc << from) | value;
      bits += from;
      while (bits >= to) {
        bits -= to;
        out.add((acc >> bits) & maxv);
      }
    }
    if (pad && bits > 0) {
      out.add((acc << (to - bits)) & maxv);
    }
    return out;
  }

  static List<int> _prefixExpand(String prefix) =>
      [...prefix.codeUnits.map((c) => c & 0x1f), 0];

  static int _polyMod(List<int> data) {
    var c = 1;
    for (final d in data) {
      final c0 = c >> 35;
      c = ((c & 0x07ffffffff) << 5) ^ d;
      if (c0 & 0x01 != 0) c ^= 0x98f2bc8e61;
      if (c0 & 0x02 != 0) c ^= 0x79b76d99e2;
      if (c0 & 0x04 != 0) c ^= 0xf33e5fb3c4;
      if (c0 & 0x08 != 0) c ^= 0xae2eabe2a8;
      if (c0 & 0x10 != 0) c ^= 0x1e4f43e470;
    }
    return c ^ 1;
  }

  static List<int> _createChecksum(String prefix, List<int> payload5) {
    final data = [..._prefixExpand(prefix), ...payload5, 0, 0, 0, 0, 0, 0, 0, 0];
    final mod = _polyMod(data);
    return List<int>.generate(8, (i) => (mod >> (5 * (7 - i))) & 0x1f);
  }

  static bool _verifyChecksum(String prefix, List<int> values) =>
      _polyMod([..._prefixExpand(prefix), ...values]) == 0;
}
