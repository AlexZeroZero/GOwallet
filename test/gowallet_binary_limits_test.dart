import 'dart:typed_data';
import 'package:coinlib_flutter/coinlib_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'witness vector length checked before allocation and integer conversion',
    () {
      for (final bytes in [
        [0xfe, 0xff, 0xff, 0xff, 0x7f],
        [0xff, ...List.filled(8, 0xff)],
        [2, 0],
      ]) {
        expect(
          () => BytesReader(Uint8List.fromList(bytes)).readVector(),
          throwsA(isA<OutOfData>()),
        );
      }
      final vector = BytesReader(
        Uint8List.fromList([2, 0, 2, 42, 43]),
      ).readVector();
      expect(vector, <List<int>>[
        [],
        [42, 43],
      ]);
    },
  );
  test(
    'slice length checked against remaining bytes before narrowing uint64',
    () {
      expect(
        () => BytesReader(
          Uint8List.fromList([0xff, ...List.filled(8, 0xff)]),
        ).readVarSlice(),
        throwsA(isA<OutOfData>()),
      );
    },
  );
}
