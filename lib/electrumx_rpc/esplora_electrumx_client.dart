import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:socks5_proxy/socks_client.dart';

import '../app_config.dart';
import '../services/event_bus/events/global/tor_connection_status_changed_event.dart';
import '../services/tor_service.dart';
import '../utilities/logger.dart';
import '../utilities/prefs.dart';
import '../utilities/tor_plain_net_option_enum.dart';
import '../wallets/crypto_currency/crypto_currency.dart';
import 'electrumx_client.dart';

/// An [ElectrumXClient] whose backend is an esplora-style HTTP API instead of
/// an Electrum server.
///
/// Bellscoin has no public Electrum server anywhere — the chain is ~365 GB
/// (inscription eras average 0.7–1.6 MB per 1-minute block), which is also why
/// nobody runs one. What exists is Nintondo's esplora fork at
/// https://electrs.nintondo.io. This adapter translates the Electrum protocol
/// subset the wallet actually uses into esplora HTTP calls, so all of
/// ElectrumXInterface (coin selection, signing, gap scanning, refresh) runs
/// unchanged. The seam is deliberate: `request()`/`batchRequest()` are the
/// funnel every inherited method goes through, except `getTransaction()`,
/// which talks to the socket adapter directly and is overridden separately.
///
/// Two protocol impedance mismatches worth knowing:
/// - Electrum scripthashes are sha256(scriptPubKey) BYTE-REVERSED; esplora
///   wants the forward order. Verified against the live server: forward
///   returns history, reversed returns []. Every scripthash is re-reversed
///   here before it goes on the wire.
/// - Nintondo's `/scripthash/:sh/utxo` is flattened (`confirmed: true`, no
///   block height, unlike stock esplora's `status` object), so confirmed
///   UTXO heights are backfilled with one `/tx/:txid/status` per unique txid.
class EsploraElectrumXClient extends ElectrumXClient {
  // Not super parameters despite the lint's suggestion: both are also needed
  // in this class's own initializer list (the base keeps its copies private
  // to its library), and a super parameter is not referenceable there.
  // ignore: use_super_parameters
  EsploraElectrumXClient({
    required super.host,
    required super.port,
    required super.useSSL,
    required Prefs prefs,
    required super.netType,
    required super.failovers,
    required super.cryptoCurrency,
    TorService? torService,
    super.globalEventBusForTesting,
  }) : _esploraPrefs = prefs,
       _esploraTorService = torService ?? TorService.sharedInstance,
       super(prefs: prefs, torService: torService);

  factory EsploraElectrumXClient.from({
    required ElectrumXNode node,
    required Prefs prefs,
    required List<ElectrumXNode> failovers,
    required CryptoCurrency cryptoCurrency,
    TorService? torService,
  }) {
    return EsploraElectrumXClient(
      host: node.address,
      port: node.port,
      useSSL: node.useSSL,
      prefs: prefs,
      torService: torService,
      failovers: failovers,
      cryptoCurrency: cryptoCurrency,
      netType: TorPlainNetworkOption.fromNodeData(
        node.torEnabled,
        node.clearnetEnabled,
      ),
    );
  }

  // The base class keeps its own copies private to its library, so this
  // subclass carries its own references for the tor policy check.
  final Prefs _esploraPrefs;
  final TorService _esploraTorService;

  // Cloudflare fronts the API and rejects clients with a bare library
  // User-Agent (verified: default curl/urllib get blocked, a browser UA
  // passes), so every request must carry one.
  static const Map<String, String> _headers = {
    "User-Agent": "BitFinite Wallet",
    "Accept": "*/*",
  };

  /// One persistent HttpClient, reused across requests so TLS sessions and
  /// TCP connections are kept alive. The first cut created a client per
  /// request (via the HTTP wrapper): a full handshake for every one of the
  /// hundreds of calls a large-wallet sync makes, and a phone full of
  /// TIME_WAIT sockets. Rebuilt only when the tor proxy decision changes.
  HttpClient? _httpClient;
  ({InternetAddress host, int port})? _httpClientProxy;

  HttpClient _getHttpClient(({InternetAddress host, int port})? proxyInfo) {
    if (_httpClient == null ||
        _httpClientProxy?.host != proxyInfo?.host ||
        _httpClientProxy?.port != proxyInfo?.port) {
      _httpClient?.close(force: true);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);
      client.idleTimeout = const Duration(seconds: 45);
      if (proxyInfo != null) {
        SocksTCPClient.assignToHttpClient(client, [
          ProxySettings(proxyInfo.host, proxyInfo.port),
        ]);
      }
      _httpClient = client;
      _httpClientProxy = proxyInfo;
    }
    return _httpClient!;
  }

  String? _cachedGenesisHash;
  int? _cachedTipHeight;
  DateTime _tipFetchedAt = DateTime.fromMillisecondsSinceEpoch(0);

  String get _baseUrl {
    String h = host.trim();
    while (h.endsWith("/")) {
      h = h.substring(0, h.length - 1);
    }
    if (!h.startsWith("http://") && !h.startsWith("https://")) {
      h = useSSL ? "https://$h" : "http://$h";
    }
    final uri = Uri.parse(h);
    // Only append the port when the host string didn't already carry one and
    // it isn't the scheme default; "https://host:443" works but reads worse
    // in logs than it needs to.
    if (uri.hasPort ||
        (useSSL && port == 443) ||
        (!useSSL && port == 80)) {
      return h;
    }
    return "$h:$port";
  }

  /// Tor policy for HTTP calls — the same decisions
  /// [ElectrumXClient.checkElectrumAdapter] makes at the socket layer.
  ({InternetAddress host, int port})? get _proxyInfo {
    if (!AppConfig.hasFeature(AppFeature.tor)) {
      return null;
    }
    if (_esploraPrefs.useTor) {
      if (_esploraTorService.status != TorConnectionStatus.connected) {
        if (_esploraPrefs.torKillSwitch) {
          throw Exception(
            "Tor preference and killswitch set but Tor is not enabled, "
            "not sending esplora request",
          );
        }
        Logging.instance.w(
          "Tor preference set but Tor is not enabled, killswitch not set, "
          "sending esplora request over clearnet",
        );
        return null;
      }
      return _esploraTorService.getProxyInfo();
    }
    return null;
  }

  Future<bool> _esploraAllow() async {
    if (_esploraPrefs.wifiOnly) {
      return (await Connectivity().checkConnectivity()) ==
          ConnectivityResult.wifi;
    }
    return true;
  }

  // ===========================================================================
  // raw http helpers

  /// The .timeout() wraps the WHOLE request, not just the connection: a
  /// stall while reading the response body must throw so the caller's retry
  /// logic runs, instead of parking the sync forever behind a dead await —
  /// exactly the hang the first on-device test produced.
  Future<String> _getString(
    String path, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final client = _getHttpClient(_proxyInfo);
    return await () async {
      final request = await client.getUrl(Uri.parse("$_baseUrl$path"));
      _headers.forEach(request.headers.add);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception(
          "Esplora GET $path failed (${response.statusCode}): $body",
        );
      }
      return body;
    }()
        .timeout(timeout);
  }

  Future<dynamic> _getJson(String path) async => jsonDecode(
    await _getString(path),
  );

  // ===========================================================================
  // command implementations

  Future<Map<String, dynamic>> _serverFeatures() async {
    // Fetched from the server rather than echoed from cryptoCurrency so the
    // genesis check in ElectrumXInterface actually guards — Pepecoin's
    // carried Dogecoin's hash for months because the guard was fed the
    // expected value back. See pepecoin.dart's genesisHash doc comment.
    _cachedGenesisHash ??= (await _getString("/block-height/0")).trim();

    return {
      "genesis_hash": _cachedGenesisHash,
      "hash_function": "sha256",
      "hosts": <String, dynamic>{},
      "protocol_min": "1.4",
      "protocol_max": "1.4",
      "pruning": null,
      // Parsed by ElectrumXInterface._parseServerVersion into [1, 4], which
      // is below the [1, 6] batching cutoff — serverCanBatch stays false and
      // the interface takes its linear (non-batched) code paths.
      "server_version": "esplora 1.4",
    };
  }

  Future<int> getChainHeight() async {
    final now = DateTime.now();
    if (_cachedTipHeight == null ||
        now.difference(_tipFetchedAt) > const Duration(seconds: 20)) {
      _cachedTipHeight = int.parse(
        (await _getString("/blocks/tip/height")).trim(),
      );
      _tipFetchedAt = now;
    }
    return _cachedTipHeight!;
  }

  Future<Map<String, dynamic>> _headersSubscribe() async {
    final height = await getChainHeight();
    final hash = (await _getString("/blocks/tip/hash")).trim();
    final hex = (await _getString("/block/$hash/header")).trim();
    return {"height": height, "hex": hex};
  }

  /// blockchain.estimatefee returns coins per kB, esplora sat/vB per target.
  ///
  /// Nintondo's `/fee-estimates` currently returns `{}` (empty — the chain's
  /// mempool idles at zero), in which case this returns -1 and the inherited
  /// [estimateFee] falls back to the coin's defaultFeeRate, exactly like the
  /// electr-bfx "Method not found" path it already handles.
  Future<dynamic> _estimateFee(int blocks) async {
    final map = await _getJson("/fee-estimates") as Map;
    if (map.isEmpty) {
      return -1;
    }
    final targets = map.keys.map((e) => int.parse(e as String)).toList()
      ..sort();
    // Largest target that is <= the requested confirmation target, falling
    // back to the fastest the server quotes.
    final target = targets.lastWhere(
      (t) => t <= blocks,
      orElse: () => targets.first,
    );
    final satPerVb = (map["$target"] as num).toDouble();
    final satsPerKb = (satPerVb * 1000).ceil();
    return _satsToCoinString(BigInt.from(satsPerKb));
  }

  Future<String> _broadcast(String rawTx) async {
    final client = _getHttpClient(_proxyInfo);
    return await () async {
      final request = await client.postUrl(Uri.parse("$_baseUrl/tx"));
      _headers.forEach(request.headers.add);
      request.headers.add("Content-Type", "text/plain");
      request.write(rawTx);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception(
          "Esplora broadcast failed (${response.statusCode}): $body",
        );
      }
      return body.trim();
    }()
        .timeout(const Duration(seconds: 60));
  }

  /// Electrum scripthash (reversed) -> esplora scripthash (forward).
  String _reverseHex(String hex) {
    final bytes = <String>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(hex.substring(i, i + 2));
    }
    return bytes.reversed.join();
  }

  static const int _esploraPageSize = 25;
  // 25 txs per page; 400 pages = 10k txs. An address bigger than that (the
  // mining pool's payout address has 358k txs) would loop for hours over a
  // Cloudflare-fronted API — a wallet that large needs an Electrum server,
  // not this adapter. Truncating history is loud in the log, not silent.
  static const int _maxHistoryPages = 400;

  Future<List<Map<String, dynamic>>> _getHistory(
    String electrumScriptHash,
  ) async {
    final sh = _reverseHex(electrumScriptHash);

    final List<Map<String, dynamic>> confirmed = [];
    final List<Map<String, dynamic>> mempool = [];

    List<dynamic> page = await _getJson("/scripthash/$sh/txs") as List;
    int pageCount = 1;

    while (true) {
      String? lastConfirmedTxid;
      int confirmedInPage = 0;

      for (final e in page) {
        final tx = Map<String, dynamic>.from(e as Map);
        final status = Map<String, dynamic>.from(tx["status"] as Map? ?? {});
        final txid = tx["txid"] as String;

        if (status["confirmed"] == true) {
          confirmedInPage++;
          lastConfirmedTxid = txid;
          confirmed.add({
            "height": status["block_height"] as int,
            "tx_hash": txid,
          });
        } else {
          mempool.add({"height": 0, "tx_hash": txid});
        }
      }

      // The first page mixes mempool + up to 25 confirmed txs; chained pages
      // are confirmed-only. A page with fewer than 25 confirmed entries is
      // the last one.
      if (confirmedInPage < _esploraPageSize || lastConfirmedTxid == null) {
        break;
      }
      if (pageCount >= _maxHistoryPages) {
        Logging.instance.w(
          "Esplora history truncated at $_maxHistoryPages pages "
          "(${confirmed.length} txs) for scripthash $sh",
        );
        break;
      }
      page = await _getJson(
        "/scripthash/$sh/txs/chain/$lastConfirmedTxid",
      ) as List;
      pageCount++;
    }

    // Electrum returns confirmed txs in blockchain order with mempool last.
    confirmed.sort(
      (a, b) => (a["height"] as int).compareTo(b["height"] as int),
    );
    return [...confirmed, ...mempool];
  }

  Future<List<Map<String, dynamic>>> _getUtxos(
    String electrumScriptHash,
  ) async {
    final sh = _reverseHex(electrumScriptHash);
    final utxos = await _getJson("/scripthash/$sh/utxo") as List;

    final List<Map<String, dynamic>> result = [];
    final Map<String, int> heightCache = {};

    for (final e in utxos) {
      final utxo = Map<String, dynamic>.from(e as Map);
      final txid = utxo["txid"] as String;

      int height = 0;
      final status = utxo["status"];
      if (status is Map) {
        // Stock esplora shape.
        if (status["confirmed"] == true) {
          height = status["block_height"] as int? ?? 0;
        }
      } else if (utxo["confirmed"] == true) {
        // Nintondo's flattened shape carries no height at all.
        height = heightCache[txid] ??= await _fetchTxHeight(txid);
      }

      result.add({
        "tx_hash": txid,
        "tx_pos": utxo["vout"] as int,
        "value": utxo["value"] as int,
        "height": height,
      });
    }
    return result;
  }

  Future<int> _fetchTxHeight(String txid) async {
    final status = await _getJson("/tx/$txid/status") as Map;
    return status["confirmed"] == true
        ? status["block_height"] as int? ?? 0
        : 0;
  }

  /// Exact sats -> decimal coin string ("200000000" -> "2.00000000").
  /// String all the way: a double loses precision above 2^53 raw sats.
  String _satsToCoinString(BigInt sats) {
    final s = BigInt.from(100000000);
    return "${sats ~/ s}.${(sats % s).toString().padLeft(8, '0')}";
  }

  // ===========================================================================
  // ElectrumXClient overrides

  /// No socket adapter to manage; HTTP tor policy is applied per request in
  /// [_proxyInfo]. Deliberately does not call super — the base implementation
  /// would open an Electrum TCP connection to the esplora host.
  @override
  Future<void> checkElectrumAdapter() async {}

  @override
  Future<void> closeAdapter() async {
    _httpClient?.close(force: true);
    _httpClient = null;
    _httpClientProxy = null;
  }

  /// Transient-failure test shared by the retry paths. A timeout, reset or
  /// stale keep-alive connection is retryable; an HTTP status error (4xx)
  /// is not — esplora uses those to mean "no such tx" and similar.
  bool _isTransient(Object e) =>
      e is TimeoutException || e is SocketException || e is HttpException;

  @override
  Future<dynamic> request({
    required String command,
    List<dynamic> args = const [],
    String? requestID,
    int retries = 2,
    Duration requestTimeout = const Duration(seconds: 60),
  }) async {
    if (!(await _esploraAllow())) {
      throw WifiOnlyException();
    }

    try {
      switch (command) {
        case 'server.ping':
          await getChainHeight();
          return true;

        case 'server.features':
          return await _serverFeatures();

        case 'blockchain.headers.subscribe':
          return await _headersSubscribe();

        case 'blockchain.estimatefee':
          return await _estimateFee(args.first as int);

        case 'blockchain.relayfee':
          // DEFAULT_MIN_RELAY_TX_FEE is 1000 sat/kvB in bellscoinV3.
          return "0.00001";

        case 'blockchain.transaction.broadcast':
          return await _broadcast(args.first as String);

        case 'blockchain.scripthash.get_history':
          return await _getHistory(args.first as String);

        case 'blockchain.scripthash.listunspent':
          return await _getUtxos(args.first as String);

        default:
          throw Exception(
            "EsploraElectrumXClient does not support command: $command",
          );
      }
    } on WifiOnlyException {
      rethrow;
    } catch (e) {
      if (_isTransient(e) && retries > 0) {
        // A dead keep-alive connection surfaces as exactly these; a fresh
        // client on the retry avoids reusing the corpse.
        await closeAdapter();
        return request(
          command: command,
          args: args,
          requestID: requestID,
          retries: retries - 1,
          requestTimeout: requestTimeout,
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> batchRequest({
    required String command,
    required List<dynamic> args,
    Duration requestTimeout = const Duration(seconds: 60),
    int retries = 2,
  }) async {
    // serverCanBatch is false for this client (see _serverFeatures), so the
    // interface shouldn't get here — but if it does, sequential is correct,
    // just slower.
    final List<dynamic> results = [];
    for (final arg in args) {
      results.add(
        await request(
          command: command,
          args: arg as List,
          requestTimeout: requestTimeout,
          retries: retries,
        ),
      );
    }
    return results;
  }

  /// Builds the bitcoind-verbose shape ElectrumXInterface and the wallet
  /// impls consume ([parseUTXO], updateTransactions) from esplora's tx JSON.
  @override
  Future<Map<String, dynamic>> getTransaction({
    required String txHash,
    bool verbose = true,
    String? requestID,
  }) async {
    // The base class routes this through the socket adapter rather than
    // request(), so it needs its own retry-on-transient wrapper: it is the
    // hottest call in a large-wallet sync (one per tx + one per prevout).
    for (int attempt = 0; ; attempt++) {
      try {
        return await _getTransactionOnce(txHash: txHash, verbose: verbose);
      } catch (e) {
        if (_isTransient(e) && attempt < 2) {
          await closeAdapter();
          continue;
        }
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> _getTransactionOnce({
    required String txHash,
    required bool verbose,
  }) async {
    if (!(await _esploraAllow())) {
      throw WifiOnlyException();
    }

    if (!verbose) {
      return {"rawtx": (await _getString("/tx/$txHash/hex")).trim()};
    }

    final tx = Map<String, dynamic>.from(await _getJson("/tx/$txHash") as Map);
    final status = Map<String, dynamic>.from(tx["status"] as Map? ?? {});

    final bool confirmed = status["confirmed"] == true;
    final int? blockHeight = status["block_height"] as int?;
    int confirmations = 0;
    if (confirmed && blockHeight != null) {
      final tip = await getChainHeight();
      confirmations = tip - blockHeight + 1;
      if (confirmations < 1) confirmations = 1;
    }

    final List<Map<String, dynamic>> vin = [];
    for (final e in (tx["vin"] as List? ?? [])) {
      final input = Map<String, dynamic>.from(e as Map);
      const allZeroTxid =
          "00000000000000000000000000000000"
          "00000000000000000000000000000000";
      final bool isCoinbase =
          input["is_coinbase"] == true || input["txid"] == allZeroTxid;

      if (isCoinbase) {
        vin.add({
          "coinbase": input["scriptsig"] as String? ?? "",
          "sequence": input["sequence"] as int?,
        });
      } else {
        // Esplora inlines each input's prevout (value + address), which
        // bitcoind-verbose does not have. Passed through under a private
        // key so BellscoinWallet.updateTransactions can price inputs
        // without fetching every referenced transaction — a pool payout
        // here consolidates hundreds of 2-BELLS coinbases, so the fetch-
        // per-input pattern the other coins use costs thousands of round
        // trips per sync on exactly the wallets worth watching.
        final prevout = input["prevout"];
        vin.add({
          "txid": input["txid"] as String,
          "vout": input["vout"] as int,
          "scriptSig": {
            "hex": input["scriptsig"] as String?,
            "asm": input["scriptsig_asm"] as String?,
          },
          "sequence": input["sequence"] as int?,
          if (prevout is Map)
            "_prevout": {
              "value": _satsToCoinString(BigInt.from(prevout["value"] as int)),
              "addresses": [
                if (prevout["scriptpubkey_address"] is String)
                  prevout["scriptpubkey_address"] as String,
              ],
            },
        });
      }
    }

    final List<Map<String, dynamic>> vout = [];
    int n = 0;
    for (final e in (tx["vout"] as List? ?? [])) {
      final output = Map<String, dynamic>.from(e as Map);
      final address = output["scriptpubkey_address"] as String?;
      vout.add({
        "n": n++,
        // Decimal-coin STRING: consumed via Decimal.parse(value.toString())
        // with isFullAmountNotSats: true in OutputV2.fromElectrumXJson.
        "value": _satsToCoinString(BigInt.from(output["value"] as int)),
        "scriptPubKey": {
          "hex": output["scriptpubkey"] as String,
          "asm": output["scriptpubkey_asm"] as String?,
          "type": output["scriptpubkey_type"] as String?,
          if (address != null) "address": address,
          if (address != null) "addresses": [address],
        },
      });
    }

    final int? weight = tx["weight"] as int?;

    return {
      "txid": tx["txid"] as String,
      "hash": tx["txid"] as String,
      "version": tx["version"] as int? ?? 1,
      "size": tx["size"] as int?,
      if (weight != null) "vsize": (weight + 3) ~/ 4,
      if (weight != null) "weight": weight,
      "locktime": tx["locktime"] as int? ?? 0,
      "vin": vin,
      "vout": vout,
      "confirmations": confirmations,
      if (confirmed) "blockhash": status["block_hash"] as String?,
      if (confirmed) "blocktime": status["block_time"] as int?,
      if (confirmed) "time": status["block_time"] as int?,
      if (confirmed) "height": blockHeight,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getBatchTransactions({
    required List<String> txHashes,
    String? requestID,
  }) async {
    final List<Map<String, dynamic>> results = [];
    for (final txHash in txHashes) {
      results.add(await getTransaction(txHash: txHash));
    }
    return results;
  }
}
