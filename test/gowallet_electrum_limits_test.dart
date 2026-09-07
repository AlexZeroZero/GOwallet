import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:electrum_adapter/electrum_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:electrum_adapter/client/bounded_json_decoder.dart';

void main() {
  test(
    'malicious server nesting closes transport and rejects pending request',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final closed = Completer<void>();
      Socket? peer;
      server.listen((socket) {
        peer = socket;
        socket.listen(
          (_) => socket.write('${'[' * 70}${']' * 70}\n'),
          onDone: () {
            if (!closed.isCompleted) closed.complete();
          },
        );
      });
      final client = await ElectrumClient.connect(
        host: '127.0.0.1',
        port: server.port,
        useSSL: false,
      );
      try {
        await expectLater(
          client
              .request('server.version', ['GOwallet-test', '1.4'])
              .timeout(const Duration(seconds: 3)),
          throwsA(isA<StateError>()),
        );
        await closed.future.timeout(const Duration(seconds: 3));
      } finally {
        await client.close();
        peer?.destroy();
        await server.close();
      }
    },
  );
  test(
    'fragmented/coalesced RPC and Unicode quoted brackets decode correctly',
    () async {
      final line = jsonEncode({'result': '中文 [ ] " \\', 'id': 1});
      final rows = await Stream.fromIterable([
        line.substring(0, 8),
        '${line.substring(8)}\n{"id":2,"result":[]}\n',
      ]).transform(const BoundedJsonDecoder()).toList();
      expect(rows.length, 2);
      expect((rows.first as Map)['id'], 1);
    },
  );
  for (final pieces in [
    ['x' * 30],
    ['x' * 8, 'x' * 8, 'x' * 8],
    ['{"id":1}'],
    ['[[[[[[]]]]]]\n'],
    ['false\n'],
    ['{bad}\n'],
  ]) {
    test(
      'bounded RPC rejects malformed/large/unfinished input ${pieces.length}',
      () async {
        await expectLater(
          Stream.fromIterable(pieces)
              .transform(const BoundedJsonDecoder(maxBytes: 20, maxDepth: 4))
              .toList(),
          throwsFormatException,
        );
      },
    );
  }
  test('frame byte budget resets for each newline', () async {
    final rows = await Stream.fromIterable(
      List.filled(100, '{"id":1}\n'),
    ).transform(const BoundedJsonDecoder(maxBytes: 12)).toList();
    expect(rows.length, 100);
  });
}
