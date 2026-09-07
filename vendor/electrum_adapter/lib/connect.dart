import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io' as io;
import 'dart:io';

import 'package:electrum_adapter/client/json_newline_transformer.dart';
import 'package:socks_socket/socks_socket.dart';
import 'package:stream_channel/stream_channel.dart';

const connectionTimeout = Duration(seconds: 5);
const aliveTimerDuration = Duration(seconds: 2);

Future<StreamChannel> connect(
  String host, {
  int port = 50002,
  Duration connectionTimeout = connectionTimeout,
  Duration aliveTimerDuration = aliveTimerDuration,
  bool acceptUnverified = false,
  bool useSSL = true,
  ({InternetAddress host, int port})? proxyInfo,
}) async {
  var socket;
  if (proxyInfo == null) {
    if (useSSL) {
      socket = await io.SecureSocket.connect(host, port,
          timeout: connectionTimeout,
          onBadCertificate: acceptUnverified ? (_) => true : null);
      // TODO do not automatically accept unverified certificates.
    } else {
      socket = await io.Socket.connect(host, port, timeout: connectionTimeout);
    }
    var channel =
        StreamChannel(socket.cast<List<int>>() as Stream, socket as StreamSink);
    var channelUtf8 =
        channel.transform(StreamChannelTransformer.fromCodec(convert.utf8));
    var channelJson = jsonNewlineDocument.bind(channelUtf8).transformStream(
      StreamTransformer<Object?, Object?>.fromHandlers(handleError: (error, trace, sink) {
        // Terminate malformed input before forwarding it into json_rpc_2.
        // Its peer closes all pending requests when this stream ends.
        socket.destroy();
        sink.close();
      }),
    );
    return channelJson;
  } else {
    // Proxy info is provided, so we should use it.
    //
    // First, connect to Tor proxy.
    socket = await SOCKSSocket.create(
      proxyHost: proxyInfo.host.address,
      proxyPort: proxyInfo.port,
      sslEnabled: useSSL,
    );
    await socket.connect();

    // Then connect to destination host.
    await socket.connectTo(host, port);

    var channel = StreamChannel(socket.inputStream as Stream<dynamic>,
        socket.outputStream as StreamSink<dynamic>);
    var channelUtf8 =
        channel.transform(StreamChannelTransformer.fromCodec(convert.utf8));
    var channelJson = jsonNewlineDocument.bind(channelUtf8).transformStream(
      StreamTransformer<Object?, Object?>.fromHandlers(handleError: (error, trace, sink) {
        channel.sink.close();
        sink.close();
      }),
    );
    return channelJson;
  }
}
