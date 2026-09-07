import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/hive/db.dart';
import '../wallets/crypto_currency/coins/custom_electrum.dart';
import 'custom_coin_definition.dart';

final pCustomCoins = ChangeNotifierProvider<GoCoinUpdates>(
  (ref) => GoCoinUpdates(),
);

/// A provider owns this subscription, never the process-wide persisted registry.
class GoCoinUpdates extends ChangeNotifier {
  GoCoinUpdates() {
    CustomCoinRegistry.instance.addListener(notifyListeners);
  }
  @override
  void dispose() {
    CustomCoinRegistry.instance.removeListener(notifyListeners);
    super.dispose();
  }
}

class CustomCoinRegistry extends ChangeNotifier {
  static final instance = CustomCoinRegistry();
  static const storageKey = 'gowallet.customCoins.v1';
  List<CustomElectrumCurrency> _coins = [];
  List<CustomElectrumCurrency> get coins => List.unmodifiable(_coins);
  List<Map<String, dynamic>> exportProfiles() =>
      _coins.map((c) => c.definition.toJson()).toList();

  void load() {
    final raw = DB.instance.hive.box<dynamic>(DB.boxNameDBInfo).get(storageKey);
    if (raw != null && (raw is! String || raw.length > 65536))
      throw const FormatException('Invalid custom coin storage');
    _coins = mergeProfiles(
      [],
      CustomCoinDefinition.decodeProfiles(
        raw == null ? null : jsonDecode(raw as String),
      ),
    ).map(CustomElectrumCurrency.new).toList();
  }

  static List<CustomCoinDefinition> mergeProfiles(
    List<CustomCoinDefinition> current,
    List<CustomCoinDefinition> incoming,
  ) {
    final result = [...current];
    for (final p in incoming) {
      final same = result.where((v) => v.identifier == p.identifier);
      if (same.isNotEmpty)
        continue; // An import never rewrites an existing profile.
      if (result.any(
        (v) =>
            v.ticker == p.ticker || v.string('genesis') == p.string('genesis'),
      )) {
        throw const FormatException('Conflicting custom coin identity');
      }
      result.add(p);
    }
    if (result.length > 32)
      throw const FormatException('Maximum 32 custom coins');
    return result;
  }

  Future<void> importProfiles(Object? data) async {
    final next = mergeProfiles(
      _coins.map((c) => c.definition).toList(),
      CustomCoinDefinition.decodeProfiles(data),
    );
    final encoded = jsonEncode(next.map((p) => p.toJson()).toList());
    if (utf8.encode(encoded).length > 65536) {
      throw const FormatException('Custom profiles exceed storage limit');
    }
    // Persist before exposing the currency to wallet creation.
    await DB.instance.hive
        .box<dynamic>(DB.boxNameDBInfo)
        .put(storageKey, encoded);
    _coins = next.map(CustomElectrumCurrency.new).toList();
    notifyListeners();
  }
}
