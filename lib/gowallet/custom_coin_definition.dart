import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Data only. Never downloads code or accepts key material from a server.
class CustomCoinDefinition {
  final Map<String, dynamic> _data;
  CustomCoinDefinition._(Map<String, dynamic> data)
    : _data = Map.unmodifiable(data);

  factory CustomCoinDefinition.fromJson(Map<String, dynamic> input) {
    const keys = {
      'schema',
      'name',
      'ticker',
      'genesis',
      'decimals',
      'slip44',
      'p2pkh',
      'p2sh',
      'wif',
      'bip32Public',
      'bip32Private',
      'segwit',
      'hrp',
      'txVersion',
      'blockTime',
      'confirmations',
      'coinbaseMaturity',
      'dust',
      'feePerKb',
      'explorer',
      'host',
      'port',
      'tls',
    };
    if (input.keys.any((k) => !keys.contains(k)) ||
        input.length != keys.length) {
      throw const FormatException('Invalid coin profile fields');
    }
    final data = Map<String, dynamic>.from(input);
    String text(String key, int max, {bool empty = false}) {
      final value = data[key];
      if (value is! String ||
          value.length > max ||
          (!empty && value.trim().isEmpty) ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
        throw FormatException('Invalid $key');
      }
      return data[key] = value.trim();
    }

    void number(String key, int min, int max) {
      final value = data[key];
      if (value is! int || value < min || value > max) {
        throw FormatException('Invalid $key');
      }
    }

    number('schema', 1, 1);
    text('name', 40);
    final ticker = text('ticker', 12).toUpperCase();
    if (!RegExp(r'^[A-Z][A-Z0-9]{0,11}$').hasMatch(ticker) ||
        const {'SCASH', 'SHIC', 'PEP'}.contains(ticker)) {
      throw const FormatException('Invalid or reserved ticker');
    }
    data['ticker'] = ticker;
    data['genesis'] = text('genesis', 64).toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(data['genesis'] as String) ||
        data['genesis'] == '0' * 64 ||
        const {
          'e3bf1597a568216022dbda6a0945f09b005d19f041e7158c3cbca9d4029ee82d',
          'ff271edcc83f7d71e7a4e4b0a43b386a188e1470a28671cdbdc47e900118ac7f',
          '37981c0c48b8d48965376c8a42ece9a0838daadb93ff975cb091f57f8c2a5faa',
        }.contains(data['genesis'])) {
      throw const FormatException('Invalid or built-in genesis');
    }
    number('decimals', 0, 12);
    number('slip44', 0, 0x7fffffff);
    for (final k in ['p2pkh', 'p2sh', 'wif']) {
      number(k, 0, 255);
    }
    if (data['p2pkh'] == data['p2sh'])
      throw const FormatException('Address prefixes must differ');
    for (final k in ['bip32Public', 'bip32Private']) {
      number(k, 1, 0xffffffff);
    }
    if (data['bip32Public'] == data['bip32Private'])
      throw const FormatException('HD prefixes must differ');
    if (data['segwit'] is! bool || data['tls'] is! bool)
      throw const FormatException('Invalid flags');
    final hrp = text('hrp', 30, empty: true);
    if ((data['segwit'] == true || hrp.isNotEmpty) &&
        !RegExp(r'^[a-z][a-z0-9]{0,29}$').hasMatch(hrp)) {
      throw const FormatException('Invalid bech32 HRP');
    }
    number('txVersion', 1, 2);
    number('blockTime', 1, 86400);
    number('confirmations', 1, 1000);
    number('coinbaseMaturity', 1, 100000);
    number('dust', 0, 1000000000000);
    number('feePerKb', 1, 1000000000000);
    final explorer = text('explorer', 250, empty: true);
    if (explorer.isNotEmpty) {
      final uri = Uri.tryParse(explorer);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw const FormatException(
          'Explorer requires an HTTPS transaction URL prefix',
        );
      }
    }
    data['host'] = validateElectrumHost(text('host', 253));
    number('port', 1, 65535);
    return CustomCoinDefinition._(data);
  }

  String get name => _data['name'] as String;
  String get ticker => _data['ticker'] as String;
  String string(String key) => _data[key] as String;
  int integer(String key) => _data[key] as int;
  bool flag(String key) => _data[key] as bool;
  Map<String, dynamic> toJson() => Map.of(_data);

  /// Names and endpoints cannot change key derivation or chain identity.
  String get identifier {
    final identity = Map<String, dynamic>.from(_data)
      ..removeWhere(
        (k, _) => const {
          'name',
          'ticker',
          'explorer',
          'host',
          'port',
          'tls',
        }.contains(k),
      );
    final sorted = Map.fromEntries(
      identity.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return 'custom_${sha256.convert(utf8.encode(jsonEncode(sorted)))}';
  }

  static List<CustomCoinDefinition> decodeProfiles(Object? value) {
    if (value == null) return [];
    if (value is! List ||
        value.length > 32 ||
        utf8.encode(jsonEncode(value)).length > 65536) {
      throw const FormatException('Too many or oversized custom profiles');
    }
    return value
        .map(
          (e) => CustomCoinDefinition.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }
}

String validateElectrumHost(String raw) {
  final host = raw.trim().toLowerCase();
  // DNS names / IPv4. No URLs, userinfo, shell syntax or paths.
  if (host.isEmpty ||
      host.length > 253 ||
      !RegExp(r'^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$').hasMatch(host) ||
      host
          .split('.')
          .any(
            (p) =>
                p.isEmpty ||
                p.length > 63 ||
                p.startsWith('-') ||
                p.endsWith('-'),
          )) {
    throw const FormatException(
      'Use a hostname or IPv4 address without protocol or path',
    );
  }
  return host;
}
