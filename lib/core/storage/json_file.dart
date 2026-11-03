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

final _pendingWrites = <String, Future<void>>{};

/// Writes JSON atomically (temp file + rename) so a crash never leaves half a
/// file. Writes to the same file run one after another, so quick successive
/// saves (typing in a settings field) cannot race on the temp file.
Future<void> writeJsonFile(File file, Object? value) {
  final content = const JsonEncoder.withIndent('  ').convert(value);
  final previous = _pendingWrites[file.path] ?? Future<void>.value();
  final next = previous.catchError((_) {}).then((_) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.$pid.tmp');
    await temp.writeAsString(content, flush: true);
    await temp.rename(file.path);
  });
  _pendingWrites[file.path] = next;
  return next.whenComplete(() {
    if (identical(_pendingWrites[file.path], next)) _pendingWrites.remove(file.path);
  });
}
