import 'dart:io';
import 'package:bitfinite/gowallet/go_backup_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'selected backup preserves text and rejects oversized or invalid UTF8 input',
    () async {
      final dir = await Directory.systemTemp.createTemp('go-backup-input-');
      try {
        final file = File('${dir.path}/input.swb');
        await file.writeAsString('opaque encrypted backup\n');
        expect(await readGoBackupFile(file.path), 'opaque encrypted backup\n');
        await file.writeAsBytes([0xff, 0xfe]);
        await expectLater(readGoBackupFile(file.path), throwsFormatException);
        expect(await tryReadGoBackupFile(file.path), isNull);
        final handle = await file.open(mode: FileMode.write);
        await handle.truncate(goMaxBackupBytes + 1);
        await handle.close();
        await expectLater(readGoBackupFile(file.path), throwsFormatException);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
