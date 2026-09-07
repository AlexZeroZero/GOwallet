import 'dart:convert';
import 'dart:io';

/// Bounds memory before decoding/decrypting a manually selected backup.
const goMaxBackupBytes = 8 * 1024 * 1024;

/// Restore screens use their existing invalid-backup UI for read failures too.
Future<String?> tryReadGoBackupFile(String path) async {
  try {
    return await readGoBackupFile(path);
  } catch (_) {
    return null;
  }
}

Future<String> readGoBackupFile(String path) async {
  final file = File(path);
  if (await file.length() > goMaxBackupBytes) {
    throw const FormatException('Backup exceeds 8 MiB');
  }
  // Bound the stream as well: a file can grow after length() is checked.
  final bytes = <int>[];
  await for (final chunk in file.openRead().timeout(
    const Duration(seconds: 15),
  )) {
    if (bytes.length + chunk.length > goMaxBackupBytes) {
      throw const FormatException('Backup exceeds 8 MiB');
    }
    bytes.addAll(chunk);
  }
  return utf8.decode(bytes);
}
