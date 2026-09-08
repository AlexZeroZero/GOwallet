import 'package:crypto/crypto.dart';

/// Validate before registering a connection or sending any wallet addresses.
void verifyElectrumNetwork(Object? features, String expectedGenesis) {
  if (features is! Map || features['genesis_hash'] != expectedGenesis) {
    throw StateError(
      'The Electrum server is serving a different blockchain. Check the coin and port.',
    );
  }
  if (features['hash_function'] != 'sha256') {
    throw StateError('Unsupported Electrum script hash function');
  }
}

/// Some forks share a genesis block. Check an independently pinned early block
/// as well, before sending wallet addresses. This is not full SPV validation.
void verifyElectrumCheckpoint(Object? header, String expectedHash) {
  if (header is! String ||
      header.length != 160 ||
      !RegExp(r'^[0-9a-fA-F]{160}$').hasMatch(header)) {
    throw StateError('Invalid Electrum checkpoint header');
  }
  final bytes = [
    for (var i = 0; i < header.length; i += 2)
      int.parse(header.substring(i, i + 2), radix: 16),
  ];
  final hash = sha256
      .convert(sha256.convert(bytes).bytes)
      .bytes
      .reversed
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  if (hash != expectedHash) {
    throw StateError('The Electrum server is serving a different blockchain');
  }
}
