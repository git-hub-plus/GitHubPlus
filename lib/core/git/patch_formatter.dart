// Ported from GitHub Desktop (MIT): app/src/lib/patch-formatter.ts (via GitHub+ v1 src/main/git/patch-formatter.ts)
import 'dart:convert';

import '../models/diff.dart';
import '../models/status.dart';

String _quote(String path) => RegExp(r'[\s"\\]').hasMatch(path) ? jsonEncode(path) : path;
String _range(int start, int count) => count == 1 ? '$start' : '$start,$count';

/// Formats selected changes for application to an index initialized from HEAD.
String formatPatch(WorkingFile file, TextDiff diff, DiffSelection selection) {
  final patch = StringBuffer();
  for (final hunk in diff.hunks) {
    final body = StringBuffer();
    var oldCount = 0;
    var newCount = 0;
    var changed = false;
    for (final line in hunk.lines) {
      if (line.type == DiffLineType.hunk) continue;
      if (line.type == DiffLineType.context) {
        body.writeln(line.text);
        oldCount++;
        newCount++;
      } else if (selection.isSelectable(line.originalLineNumber) && selection.isSelected(line.originalLineNumber)) {
        body.writeln(line.text);
        if (line.type == DiffLineType.add) newCount++;
        if (line.type == DiffLineType.delete) oldCount++;
        changed = true;
      } else if (line.type == DiffLineType.add || file.status.isNew) {
        continue;
      } else {
        body.writeln(' ${line.content}');
        oldCount++;
        newCount++;
      }
      if (line.noTrailingNewLine) body.writeln(r'\ No newline at end of file');
    }
    if (!changed) continue;
    patch.writeln(
      '@@ -${_range(hunk.header.oldStartLine, oldCount)} +${_range(hunk.header.newStartLine, newCount)} @@',
    );
    patch.write(body);
  }
  if (patch.isEmpty) throw StateError('Could not generate a patch, no changes');
  final from = file.status.isNew ? '/dev/null' : 'a/${file.path}';
  return '--- ${_quote(from)}\n+++ ${_quote('b/${file.path}')}\n$patch';
}
