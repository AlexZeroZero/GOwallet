import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../providers/global/prefs_provider.dart';
import '../wallets/crypto_currency/crypto_currency.dart';
import '../wallets/isar/models/wallet_info.dart';
import '../wallets/isar/providers/all_wallets_info_provider.dart';

/// Fixed identities, never resolved by a possibly ambiguous ticker at runtime.
const goMarketIds = {
  'scash': 'satoshi-cash-network',
  'shibacoin': 'shibacoin',
  'pepecoin': 'pepecoin-network',
  'dingocoin': 'dingocoin',
};

class GoQuote {
  const GoQuote(this.price, this.updatedAt);
  final Decimal price;
  final DateTime updatedAt;
  bool freshAt(DateTime now) =>
      price > Decimal.zero &&
      now.difference(updatedAt) <= const Duration(minutes: 15) &&
      updatedAt.difference(now) <= const Duration(minutes: 2);
}

Map<String, GoQuote> parseGoQuotes(String body, String currency, DateTime now) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final result = <String, GoQuote>{};
  for (final entry in goMarketIds.entries) {
    final data = json[entry.value];
    if (data is! Map) continue;
    final value = Decimal.tryParse('${data[currency.toLowerCase()]}');
    final stamp = data['last_updated_at'];
    if (value == null ||
        stamp is! num ||
        !stamp.isFinite ||
        stamp <= 0 ||
        stamp > 8640000000000)
      continue;
    final quote = GoQuote(
      value,
      DateTime.fromMillisecondsSinceEpoch(stamp.toInt() * 1000, isUtc: true),
    );
    if (quote.freshAt(now)) result[entry.key] = quote;
  }
  return result;
}

final pGoQuoteEpoch = StateProvider<int>((ref) => 0);

final pGoQuotes = FutureProvider<Map<String, GoQuote>>((ref) async {
  final enabled = ref.watch(
    prefsChangeNotifierProvider.select((p) => p.externalCalls),
  );
  final currency = ref.watch(
    prefsChangeNotifierProvider.select((p) => p.currency),
  );
  if (!enabled) return {};
  // The request contains only the supported public coin IDs and fiat unit.
  // No address, balance, wallet ID, name or recovery material is transmitted.
  ref.watch(pGoQuoteEpoch);
  final client = http.Client();
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    client.close();
  });
  final timer = Timer(
    const Duration(minutes: 5),
    () => ref.read(pGoQuoteEpoch.state).state++,
  );
  ref.onDispose(timer.cancel);
  final result = await fetchGoQuotes(
    client,
    currency,
  ).whenComplete(client.close);
  if (disposed) return {};
  var next = const Duration(minutes: 5);
  for (final quote in result.values) {
    final remaining = quote.updatedAt
        .add(const Duration(minutes: 15, seconds: 1))
        .difference(DateTime.now().toUtc());
    if (remaining < next) next = remaining;
  }
  timer.cancel();
  final expiry = Timer(
    next.isNegative ? const Duration(seconds: 1) : next,
    () => ref.read(pGoQuoteEpoch.state).state++,
  );
  ref.onDispose(expiry.cancel);
  return result;
});

Future<Map<String, GoQuote>> fetchGoQuotes(
  http.Client client,
  String currency,
) async {
  final uri = Uri.https('api.coingecko.com', '/api/v3/simple/price', {
    'ids': goMarketIds.values.join(','),
    'vs_currencies': currency.toLowerCase(),
    'include_last_updated_at': 'true',
  });
  final response = await client.get(uri).timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) throw StateError('Market data unavailable');
  return parseGoQuotes(response.body, currency, DateTime.now().toUtc());
}

class GoHolding {
  const GoHolding({
    required this.coin,
    required this.walletCount,
    required this.balance,
    required this.pendingWallets,
    this.estimate,
  });
  final CryptoCurrency coin;
  final int walletCount;

  /// Null means at least one account has never computed its balance.
  final Decimal? balance;
  final int pendingWallets;
  final Decimal? estimate;
}

class GoPortfolio {
  const GoPortfolio(this.holdings);
  final List<GoHolding> holdings;
  int get missingCount => holdings.where((h) => h.estimate == null).length;
  bool get complete => missingCount == 0;
  Decimal? get estimate {
    if (holdings.isEmpty) return Decimal.zero;
    final values = holdings.where((h) => h.estimate != null);
    if (values.isEmpty) return null;
    return values.fold<Decimal>(Decimal.zero, (sum, h) => sum + h.estimate!);
  }
}

GoPortfolio computeGoPortfolio(
  List<WalletInfo> infos,
  Map<String, GoQuote> quotes,
  DateTime now,
) {
  final groups = <CryptoCurrency, List<WalletInfo>>{};
  for (final info in infos) {
    (groups[info.coin] ??= []).add(info);
  }
  return GoPortfolio(
    groups.entries.map((entry) {
      final pending = entry.value
          .where((w) => w.cachedBalanceString == null)
          .length;
      final balance = pending > 0
          ? null
          : entry.value.fold<Decimal>(
              Decimal.zero,
              (sum, w) => sum + w.cachedBalance.total.decimal,
            );
      final quote = quotes[entry.key.identifier];
      final estimate = balance == null
          ? null
          : balance == Decimal.zero
          ? Decimal.zero
          : quote != null && quote.freshAt(now)
          ? balance * quote.price
          : null;
      return GoHolding(
        coin: entry.key,
        walletCount: entry.value.length,
        balance: balance,
        pendingWallets: pending,
        estimate: estimate,
      );
    }).toList(),
  );
}

final pGoPortfolio = Provider.autoDispose((ref) {
  final infos = ref.watch(pAllWalletsInfo);
  final enabled = ref.watch(
    prefsChangeNotifierProvider.select((p) => p.externalCalls),
  );
  final quotes = ref.watch(pGoQuotes);
  // Never reuse a previous currency's async value during a provider refresh.
  return computeGoPortfolio(
    infos,
    enabled
        ? quotes.maybeWhen(
            data: (value) => value,
            orElse: () => <String, GoQuote>{},
          )
        : <String, GoQuote>{},
    DateTime.now().toUtc(),
  );
});
