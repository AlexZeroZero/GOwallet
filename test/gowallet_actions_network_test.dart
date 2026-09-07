import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:bitfinite/utilities/logger.dart';
import 'package:bitfinite/utilities/connection_check/electrum_connection_check.dart';
import 'package:bitfinite/widgets/wallet_navigation_bar/components/wallet_navigation_bar_item.dart';
import 'electrumx_test.dart' show MockPrefs;

void main() {
  setUpAll(() async {
    final logDir = await Directory.systemTemp.createTemp('go-node-test');
    await Logging.instance.initialize(logDir.path, level: Level.off);
  });
  test('translated wallet actions retain identity and callbacks', () {
    var tapped = '';
    final items = [
      WalletNavigationBarItemData(
        icon: const Icon(Icons.south),
        label: '收款',
        action: WalletAction.receive,
        onTap: () => tapped = 'receive',
      ),
      WalletNavigationBarItemData(
        icon: const Icon(Icons.north),
        label: '发送',
        action: WalletAction.send,
        onTap: () => tapped = 'send',
      ),
    ];
    items
        .singleWhere((e) => e.effectiveAction == WalletAction.receive)
        .onTap!();
    expect(tapped, 'receive');
    items.singleWhere((e) => e.effectiveAction == WalletAction.send).onTap!();
    expect(tapped, 'send');
    expect(
      items.where((e) => e.effectiveAction == WalletAction.other),
      isEmpty,
    );
  });
  for (final correct in [true, false]) {
    test(
      'node connection test ${correct ? 'accepts matching' : 'rejects wrong'} genesis and closes TCP',
      () async {
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final closed = Completer<void>();
        Socket? connection;
        server.listen((socket) {
          connection = socket;
          socket
              .cast<List<int>>()
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen(
                (line) {
                  final request = jsonDecode(line) as Map<String, dynamic>;
                  final result = request['method'] == 'server.features'
                      ? {
                          'genesis_hash': correct ? 'abc' : 'wrong',
                          'hash_function': 'sha256',
                        }
                      : ['GOwallet-test', '1.4'];
                  socket.write(
                    '${jsonEncode({'jsonrpc': '2.0', 'id': request['id'], 'result': result})}\n',
                  );
                },
                onDone: () {
                  if (!closed.isCompleted) closed.complete();
                },
              );
        });
        try {
          expect(
            await checkElectrumServer(
              host: '127.0.0.1',
              port: server.port,
              useSSL: false,
              expectedGenesis: 'abc',
              overridePrefs: MockPrefs(),
            ),
            correct,
          );
          await closed.future.timeout(const Duration(seconds: 3));
        } finally {
          connection?.destroy();
          await server.close();
        }
      },
    );
  }
}
