import 'dart:async';
import 'dart:convert';

/// Electrum messages are newline-delimited JSON. Bound input before decoding.
class BoundedJsonDecoder extends StreamTransformerBase<String, Object?> {
  final int maxBytes;
  final int maxDepth;
  const BoundedJsonDecoder(
      {this.maxBytes = 8 * 1024 * 1024, this.maxDepth = 64});

  @override
  Stream<Object?> bind(Stream<String> stream) async* {
    var pending = StringBuffer();
    var bytes = 0;
    await for (final chunk in stream) {
      var start = 0;
      while (start < chunk.length) {
        final newline = chunk.indexOf('\n', start);
        final end = newline < 0 ? chunk.length : newline;
        final piece = chunk.substring(start, end);
        bytes += utf8.encode(piece).length;
        if (bytes > maxBytes)
          throw const FormatException('Electrum message exceeds size limit');
        pending.write(piece);
        if (newline < 0) break;
        final text = pending.toString();
        pending = StringBuffer();
        bytes = 0;
        if (text.trim().isNotEmpty) {
          _checkDepth(text);
          final value = jsonDecode(text);
          if (value is! Map && value is! List)
            throw const FormatException('Invalid RPC envelope');
          yield value;
        }
        start = newline + 1;
      }
    }
    if (bytes != 0) throw const FormatException('Incomplete Electrum message');
  }

  void _checkDepth(String text) {
    var quoted = false, escaped = false;
    var depth = 0;
    for (final c in text.codeUnits) {
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (c == 92) {
          escaped = true;
        } else if (c == 34) {
          quoted = false;
        }
      } else if (c == 34) {
        quoted = true;
      } else if (c == 123 || c == 91) {
        if (++depth > maxDepth)
          throw const FormatException('Electrum nesting exceeds limit');
      } else if (c == 125 || c == 93) {
        depth--;
      }
    }
  }
}
