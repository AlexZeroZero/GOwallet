import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/pages/settings_views/global_settings_view/stack_backup_views/helpers/restore_create_backup.dart'
    as app;
import 'package:stack_wallet_backup/stack_wallet_backup.dart' as swb;

class UnmountedContext extends Fake implements BuildContext {
  @override
  bool get mounted => false;
}

void main() {
  test('backup creation rejects short/blank passphrases and mismatches', () {
    final context = UnmountedContext();
    for (final password in ['', '123456', '           ', 'short       ']) {
      expect(
        app.validateFail(context, 'content://audit', password, password),
        true,
      );
    }
    expect(
      app.validateFail(
        context,
        'content://audit',
        'audit-long-password',
        'audit-long-password',
      ),
      false,
    );
    expect(
      app.validateFail(
        context,
        'content://audit',
        'audit-long-password',
        'different-password',
      ),
      true,
    );
  });
  test(
    'backup v2 round trip, wrong password, tamper with recomputed checksum',
    () async {
      const password = 'audit-only-long-backup-passphrase';
      final plain = Uint8List.fromList(
        utf8.encode('{"wallets":[],"goCustomCoins":[]}'),
      );
      final encrypted = await swb.encryptRawWithPassphrase(password, plain);
      final data = encrypted.item1;
      final encoded = data.encode(encrypted.item2);
      expect(data.parameters.version, 2);
      expect(await swb.decryptWithPassphrase(password, encoded), plain);
      await expectLater(
        swb.decryptWithPassphrase('wrong-password', encoded),
        throwsA(anything),
      );
      // An attacker can recompute the unkeyed checksum, but cannot forge AEAD.
      data.ciphertext[0] ^= 1;
      final forged = data.encode(await data.parameters.checksum(data));
      await expectLater(
        swb.decryptWithPassphrase(password, forged),
        throwsA(anything),
      );
      await expectLater(
        swb.decryptWithPassphrase(
          password,
          Uint8List.fromList([255, ...encoded.skip(1)]),
        ),
        throwsA(isA<swb.BadProtocolVersion>()),
      );
    },
  );
}
