// Ported from GitHub Desktop (MIT): app/src/lib/diff-parser.ts (via GitHub+ v1 src/main/git/diff-parser.ts)
import '../models/diff.dart';

final hiddenBidiCharsRegex = RegExp(r'[\u202a-\u202e\u2066-\u2069]');
final _header = RegExp(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@');

/// GNU unified diff parser. Marker lines do not occupy selection coordinates.
class DiffParser {
  FileDiff parse(String raw) {
    if (RegExp(r'^Binary files .* differ$', multiLine: true).hasMatch(raw)) return const BinaryDiff();
    final lines = raw.split('\n');
    final start = lines.indexWhere((line) => line.startsWith('+++'));
    if (start < 0) return const TextDiff(text: '', hunks: [], maxLineNumber: 0);
    final hunks = <DiffHunk>[];
    final body = <String>[];
    var consumed = 0;
    var maxLine = 0;
    var i = start + 1;
    while (i < lines.length && lines[i].isNotEmpty) {
      final heading = lines[i++];
      final match = _header.firstMatch(heading);
      if (match == null) throw const FormatException('Invalid hunk header format');
      final header = DiffHunkHeader(
        oldStartLine: int.parse(match[1]!),
        oldLineCount: int.parse(match[2] ?? '1'),
        newStartLine: int.parse(match[3]!),
        newLineCount: int.parse(match[4] ?? '1'),
      );
      var oldLine = header.oldStartLine;
      var newLine = header.newStartLine;
      final parsed = <DiffLine>[DiffLine(text: heading, type: DiffLineType.hunk, originalLineNumber: 1)];
      body.add(heading);
      while (i < lines.length && lines[i].isNotEmpty && !lines[i].startsWith('@@')) {
        final line = lines[i];
        final prefix = line[0];
        if (![' ', '+', '-', '\\'].contains(prefix)) break;
        i++;
        if (prefix == '\\') {
          if (line.length < 12 || parsed.length == 1) throw const FormatException('Invalid no newline marker');
          final previous = parsed.removeLast();
          parsed.add(
            DiffLine(
              text: previous.text,
              type: previous.type,
              originalLineNumber: previous.originalLineNumber,
              oldLineNumber: previous.oldLineNumber,
              newLineNumber: previous.newLineNumber,
              noTrailingNewLine: true,
            ),
          );
          continue;
        }
        final old = prefix == '+' ? null : oldLine++;
        final current = prefix == '-' ? null : newLine++;
        if ((old ?? 0) > maxLine) maxLine = old!;
        if ((current ?? 0) > maxLine) maxLine = current!;
        parsed.add(
          DiffLine(
            text: line,
            type: prefix == '+'
                ? DiffLineType.add
                : prefix == '-'
                ? DiffLineType.delete
                : DiffLineType.context,
            originalLineNumber: consumed + parsed.length,
            oldLineNumber: old,
            newLineNumber: current,
          ),
        );
        body.add(line);
      }
      if (parsed.length == 1) throw const FormatException('Malformed diff, empty hunk');
      hunks.add(
        DiffHunk(
          header: header,
          lines: parsed,
          unifiedDiffStart: consumed,
          unifiedDiffEnd: consumed + parsed.length - 1,
        ),
      );
      consumed += parsed.length;
    }
    return TextDiff(
      text: body.join('\n'),
      hunks: hunks,
      maxLineNumber: maxLine,
      hasHiddenBidiChars: hiddenBidiCharsRegex.hasMatch(raw),
    );
  }
}
