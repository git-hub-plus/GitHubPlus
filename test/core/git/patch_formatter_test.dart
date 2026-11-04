// Ported from GitHub Desktop (MIT): app/test/unit/patch-formatter-test.ts (via GitHub+ v1 tests/main/git/patch-formatter.test.ts)
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/git/diff_parser.dart';
import 'package:github_plus/core/git/patch_formatter.dart';
import 'package:github_plus/core/models/diff.dart';
import 'package:github_plus/core/models/status.dart';

void main() {
  String patch(String raw, int line, [FileStatusKind kind = FileStatusKind.modified]) => formatPatch(
    WorkingFile(
      path: 'file.md',
      status: FileStatus(kind: kind),
    ),
    DiffParser().parse(raw) as TextDiff,
    DiffSelection.none().withLineSelection(line, true),
  );
  test('v1: unselected additions are omitted, not context', () {
    expect(
      patch('--- a/file.md\n+++ b/file.md\n@@ -10,2 +10,4 @@\n context\n+added line 1\n+added line 2\n context', 3),
      '--- a/file.md\n+++ b/file.md\n@@ -10,2 +10,3 @@\n context\n+added line 2\n context\n',
    );
  });
  test('v1: rewrites new file hunk header', () {
    final result = patch(
      '--- /dev/null\n+++ b/file.md\n@@ -0,2 +1,2 @@\n+added line 1\n+added line 2',
      2,
      FileStatusKind.added,
    );
    expect(result, contains('@@ -0,0 +1 @@'));
    expect(result, contains('+added line 2'));
  });
  test('v1: keeps empty context lines', () {
    final result = patch('--- a/file.md\n+++ b/file.md\n@@ -1 +1,2 @@\n \n+added line 2', 2);
    expect(result, contains('@@ -1 +1,2 @@\n \n+added line 2'));
  });
  test('v1: retains no newline marker for unselected deletion', () {
    final result = patch(
      '--- a/file.md\n+++ b/file.md\n@@ -23,5 +24,5 @@ and more stuff\n \n \n \n-\n-and fun stuff? I dnno\n\\ No newline at end of file\n+and fun stuff? I dnno\n+it could be,',
      7,
    );
    expect(result, contains(r'\ No newline at end of file'));
    expect(result, contains('+it could be'));
  });
  test('quotes paths and rejects empty selection', () {
    final diff = DiffParser().parse('--- a/x\n+++ b/x\n@@ -1 +1 @@\n-a\n+b') as TextDiff;
    const file = WorkingFile(
      path: 'a "b".txt',
      status: FileStatus(kind: FileStatusKind.modified),
    );
    expect(formatPatch(file, diff, DiffSelection.all()), contains('--- "a/a \\"b\\".txt"'.replaceAll('\\\\', '\\')));
    expect(() => formatPatch(file, diff, DiffSelection.none()), throwsStateError);
  });
}
