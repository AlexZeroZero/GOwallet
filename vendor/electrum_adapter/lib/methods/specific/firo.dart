import 'package:electrum_adapter/electrum_adapter.dart';

extension SparkMethods on FiroElectrumClient {
  /// Takes [startNumber], if it is 0, we get the full set,
  /// otherwise the used tags after that number
  Future<Map<String, dynamic>> getUsedCoinsTags({
    required int startNumber,
  }) async {
    return await request(
      'spark.getusedcoinstags',
      [
        "$startNumber",
      ],
    ) as Map<String, dynamic>;
  }

  /// Returns the whole Spark anonymity set for denomination in the groupId.
  ///
  /// Takes [coinGroupId] and [startBlockHash], if the last is empty it returns
  /// the full set, otherwise returns mint after that block, we need to call this
  /// to keep our anonymity set data up to date.
  ///
  /// Returns blockHash (last block hash),
  /// setHash (hash of current set)
  /// and coins (the list of pairs serialized coin and tx hash)
  Future<Map<String, dynamic>> getSparkAnonymitySet({
    String coinGroupId = "1",
    String startBlockHash = "",
  }) async {
    return await request(
      'spark.getsparkanonymityset',
      [
        coinGroupId,
        startBlockHash,
      ],
    ) as Map<String, dynamic>;
  }

  /// Takes a list of [sparkCoinHashes] and returns the set id and block height
  /// for each coin.
  ///
  /// arg:
  /// {
  ///   "coinHashes": [
  ///       "b476ed2b374bb081ea51d111f68f0136252521214e213d119b8dc67b92f5a390",
  ///       "b476ed2b374bb081ea51d111f68f0136252521214e213d119b8dc67b92f5a390",
  ///   ]
  /// }
  Future<List<dynamic>> getSparkMintMetaData({
    required List<String> sparkCoinHashes,
  }) async {
    return await request(
      'spark.getsparkmintmetadata',
      [
        {
          "coinHashes": sparkCoinHashes,
        },
      ],
    ) as List<dynamic>;
  }

  /// Returns the latest Spark set id
  ///
  /// ex: 1
  Future<int> getSparkLatestCoinId() async {
    return await request(
      'spark.getsparklatestcoinid',
    ) as int;
  }
}

extension LelantusMethods on FiroElectrumClient {
  /// Returns the whole Lelantus anonymity set for denomination in the groupId.
  ///
  /// ex:
  ///  {
  ///     "blockHash": "37effb57352693f4efcb1710bf68e3a0d79ff6b8f1605529de3e0706d9ca21da",
  ///     "setHash": "aae1a64f19f5ccce1c242dfe331d8db2883a9508d998efa3def8a64844170fe4",
  ///     "coins": [
  ///               [dynamic list of length 4],
  ///               [dynamic list of length 4],
  ///               ....
  ///               [dynamic list of length 4],
  ///               [dynamic list of length 4],
  ///         ]
  ///   }
  Future<Map<String, dynamic>> getLelantusAnonymitySet({
    String groupId = "1",
    String blockHash = "",
  }) async {
    final response = await request(
      'lelantus.getanonymityset',
      [
        groupId,
        blockHash,
      ],
    );
    return Map<String, dynamic>.from(response as Map);
  }

  // TODO add example to docs
  /// Returns the block height and groupId of a Lelantus pubcoin.
  Future<dynamic> getLelantusMintData({
    dynamic mints,
  }) async {
    final response = await request(
      'lelantus.getmintmetadata',
      [
        mints,
      ],
    );
    return response;
  }

  //TODO add example to docs
  /// Returns the whole set of the used Lelantus coin serials.
  Future<Map<String, dynamic>> getLelantusUsedCoinSerials({
    required int startNumber,
  }) async {
    final response = await request(
      'lelantus.getusedcoinserials',
      [
        "$startNumber",
      ],
      // requestTimeout: const Duration(minutes: 2),
      // TODO alter request to accept a timeout param.
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Returns the latest Lelantus set id
  ///
  /// ex: 1
  Future<int> getLatestCoinId() async {
    final response = await request(
      'lelantus.getlatestcoinid',
    );
    return response as int;
  }
}
