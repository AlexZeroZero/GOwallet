/*
 * This file is part of BitFinite Wallet.
 *
 * Recognising mining payouts, and summarising them for the wallet view.
 */

import '../models/isar/models/blockchain_data/transaction.dart';
import '../models/isar/models/blockchain_data/v2/transaction_v2.dart';
import '../utilities/amount/amount.dart';
import '../wallets/crypto_currency/crypto_currency.dart';

/// Payouts come in two shapes that look nothing alike on chain.
///
///   Solo    the block reward pays the miner's address directly, so the
///           transaction carries a coinbase input. This needs no
///           configuration, works on any chain, and keeps working if a pool
///           ever moves its wallet.
///   Shared  the pool pays everyone from its own wallet in one sendmany, so
///           the only signal is the sending address.
///
/// Coinbase detection is the one that carries most of the weight here: our
/// miners are mostly solo and Bitaxe sized.
///
/// The shared-pool list is the same pair the aggregator uses (current hot
/// address plus the legacy one), kept here rather than fetched so that
/// labelling a transaction never depends on the network being reachable.
const _bitfinitePoolPayoutAddresses = <String>{
  "frq8k96fr9j004hpyz9xaa5ema0hvm2gccnn5lxw0s",
  "frkq2xkaqv3694rzc8ahreef78kpljd38gp6n2d5ch",
};

/// Addresses known to pay out shared-pool rewards for [coin], prefix stripped.
///
/// Empty for every coin but ours. That is deliberate: guessing at another
/// chain's pool addresses would mislabel ordinary payments, and a wrong label
/// on someone's money is worse than no label.
Set<String> poolPayoutAddresses(CryptoCurrency coin) {
  if (coin is Bitfinite) return _bitfinitePoolPayoutAddresses;
  return const {};
}

/// Strips any `scheme:` prefix and lowercases.
///
/// BitFinite addresses are cashaddr and turn up both as `bfx:f...` and bare
/// `f...` depending on which side produced them, so comparing raw strings
/// silently fails to match about half the time.
String _normalise(String address) {
  final i = address.indexOf(":");
  final bare = i >= 0 ? address.substring(i + 1) : address;
  return bare.toLowerCase();
}

/// Whether [tx] is money arriving from mining rather than from a person.
bool isMiningPayout(TransactionV2 tx, CryptoCurrency coin) {
  if (tx.type != TransactionType.incoming) return false;

  // Solo: a coinbase input means this is a block reward, and since it is
  // incoming, the reward is ours.
  //
  // Presence of the field is the test, not its contents. Every parser leaves
  // it null for an ordinary input and only sets it for a coinbase, and the
  // esplora path sets it to "" when the scriptsig is absent, so checking for
  // a non-empty string would silently miss Bellscoin block rewards.
  for (final input in tx.inputs) {
    if (input.coinbase != null) return true;
  }

  final pools = poolPayoutAddresses(coin);
  if (pools.isEmpty) return false;

  for (final input in tx.inputs) {
    for (final address in input.addresses) {
      if (pools.contains(_normalise(address))) return true;
    }
  }
  return false;
}

/// What the wallet view shows above the transaction list.
class MiningPayoutSummary {
  const MiningPayoutSummary({
    required this.count,
    required this.total,
    required this.last,
    required this.first,
  });

  /// How many payouts are in the transactions we hold.
  final int count;

  /// Their sum, as received by this wallet.
  final Amount total;

  /// When the most recent one landed, or null if there are none.
  final DateTime? last;

  /// When the oldest one we hold landed, or null if there are none.
  ///
  /// "Since" rather than "first ever": on a wallet whose history was truncated
  /// this is the oldest payout still in the database, which is exactly what
  /// the count beside it is counting.
  final DateTime? first;

  bool get isEmpty => count == 0;
}

/// Totals the payouts in [transactions].
///
/// Counts only what the wallet actually holds. On an address whose history was
/// truncated during sync that is a floor rather than a lifetime total, which
/// is why the card built on this says "recent" rather than claiming to be
/// complete.
MiningPayoutSummary summariseMiningPayouts(
  List<TransactionV2> transactions,
  CryptoCurrency coin,
) {
  final fractionDigits = coin.fractionDigits;
  var count = 0;
  var totalSats = BigInt.zero;
  int? newest;
  int? oldest;

  for (final tx in transactions) {
    if (!isMiningPayout(tx, coin)) continue;
    count++;
    totalSats += tx
        .getAmountReceivedInThisWallet(fractionDigits: fractionDigits)
        .raw;
    if (newest == null || tx.timestamp > newest) {
      newest = tx.timestamp;
    }
    if (oldest == null || tx.timestamp < oldest) {
      oldest = tx.timestamp;
    }
  }

  return MiningPayoutSummary(
    count: count,
    total: Amount(rawValue: totalSats, fractionDigits: fractionDigits),
    last: newest == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(newest * 1000),
    first: oldest == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(oldest * 1000),
  );
}

/// "now", "14m ago", "2h ago", "42d ago".
///
/// The card this feeds is one line beside a total, so the long form pushed
/// the freshness off the end into an ellipsis. Freshness is the whole
/// question a miner opens the wallet to answer, so it gets the short form and
/// goes first, and the payout count truncates instead.
String describeAgeShort(DateTime when, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(when);
  if (diff.inSeconds < 90) return "now";
  if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
  if (diff.inHours < 24) return "${diff.inHours}h ago";
  return "${diff.inDays}d ago";
}

/// "just now", "14 minutes ago", "3 hours ago", "42 days ago".
///
/// The long form, for the payout card's headline. That line is the card's
/// title and has the width to itself, so it says the thing in words instead of
/// the compressed "14m ago" the old single-row layout had to use.
String describeAge(DateTime when, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(when);
  String plural(int n, String unit) => "$n $unit${n == 1 ? "" : "s"} ago";
  if (diff.inSeconds < 90) return "just now";
  if (diff.inMinutes < 60) return plural(diff.inMinutes, "minute");
  if (diff.inHours < 24) return plural(diff.inHours, "hour");
  return plural(diff.inDays, "day");
}

/// "3 Jun", or "3 Jun 2025" once the date is in an earlier year.
///
/// Dropping the year inside the current year keeps the subtitle short, which
/// is where it usually sits; showing it otherwise stops "since 3 Jun" quietly
/// meaning eighteen months ago.
String describeShortDate(DateTime when, {DateTime? now}) {
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  final today = now ?? DateTime.now();
  final stem = "${when.day} ${months[when.month - 1]}";
  return when.year == today.year ? stem : "$stem ${when.year}";
}
