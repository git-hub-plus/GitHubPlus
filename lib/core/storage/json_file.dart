import 'dart:convert';
import 'dart:io';

/// Reads JSON, returning null when the file is missing or invalid.
Future<Object?> readJsonFile(File file) async {
  try {
    return jsonDecode(await file.readAsString());
  } catch (_) {
    return null;
  }
}

/// Writes JSON atomically (temp file + rename) so a crash never leaves half a file.
Future<void> writeJsonFile(File file, Object? value) async {
  await file.parent.create(recursive: true);
  final temp = File('${file.path}.$pid.tmp');
  await temp.writeAsString(const JsonEncoder.withIndent('  ').convert(value), flush: true);
  await temp.rename(file.path);
}
