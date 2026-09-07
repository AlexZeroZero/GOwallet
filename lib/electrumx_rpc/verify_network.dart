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
