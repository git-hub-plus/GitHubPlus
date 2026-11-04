// Ported from GitHub Desktop (MIT): app/test/unit/diff-parser-test.ts (via GitHub+ v1 tests/main/git/diff-parser.test.ts)
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/git/diff_parser.dart';
import 'package:github_plus/core/models/diff.dart';

void main() {
  test('parses changed files', () {
    final diffText = '''diff --git a/app/src/lib/diff-parser.ts b/app/src/lib/diff-parser.ts
index e1d4871..3bd3ee0 100644
--- a/app/src/lib/diff-parser.ts
+++ b/app/src/lib/diff-parser.ts
@@ -18,6 +18,7 @@ export function parseRawDiff(lines: ReadonlyArray<string>): Diff {

     let numberOfUnifiedDiffLines = 0

+
     while (prefixFound) {

       // trim any preceding text
@@ -71,12 +72,9 @@ export function parseRawDiff(lines: ReadonlyArray<string>): Diff {
         diffSections.push(new DiffSection(range, diffLines, startDiffSection, endDiffSection))
       } else {
         const diffBody = diffTextBuffer
-
         let startDiffSection: number = 0
         let endDiffSection: number = 0
-
         const diffLines = diffBody.split('\\n')
-
         if (diffSections.length === 0) {
           startDiffSection = 0
           endDiffSection = diffLines.length
@@ -84,10 +82,8 @@ export function parseRawDiff(lines: ReadonlyArray<string>): Diff {
           startDiffSection = numberOfUnifiedDiffLines
           endDiffSection = startDiffSection + diffLines.length
         }
-
         diffSections.push(new DiffSection(range, diffLines, startDiffSection, endDiffSection))
       }
     }
-
     return new Diff(diffSections)
 }
    ''';

    final parser = DiffParser();
    final diff = parser.parse(diffText.replaceAll('\n\n', '\n \n')) as TextDiff;
    expect(diff.hunks.length, 3);

    var hunk = diff.hunks[0];
    expect(hunk.unifiedDiffStart, 0);
    expect(hunk.unifiedDiffEnd, 7);

    var lines = hunk.lines;
    expect(lines.length, 8);

    var i = 0;
    expect(lines[i].text, '@@ -18,6 +18,7 @@ export function parseRawDiff(lines: ReadonlyArray<string>): Diff {');
    expect(lines[i].type, DiffLineType.hunk);
    expect(lines[i].oldLineNumber == null, isTrue);
    expect(lines[i].newLineNumber == null, isTrue);
    i++;

    expect(lines[i].text, ' ');
    expect(lines[i].type, DiffLineType.context);
    expect(lines[i].oldLineNumber, 18);
    expect(lines[i].newLineNumber, 18);
    i++;

    expect(lines[i].text, '     let numberOfUnifiedDiffLines = 0');
    expect(lines[i].type, DiffLineType.context);
    expect(lines[i].oldLineNumber, 19);
    expect(lines[i].newLineNumber, 19);
    i++;

    expect(lines[i].text, ' ');
    expect(lines[i].type, DiffLineType.context);
    expect(lines[i].oldLineNumber, 20);
    expect(lines[i].newLineNumber, 20);
    i++;

    expect(lines[i].text, '+');
    expect(lines[i].type, DiffLineType.add);
    expect(lines[i].oldLineNumber == null, isTrue);
    expect(lines[i].newLineNumber, 21);
    i++;

    expect(lines[i].text, '     while (prefixFound) {');
    expect(lines[i].type, DiffLineType.context);
    expect(lines[i].oldLineNumber, 21);
    expect(lines[i].newLineNumber, 22);

    hunk = diff.hunks[1];
    expect(hunk.unifiedDiffStart, 8);
    expect(hunk.unifiedDiffEnd, 20);

    lines = hunk.lines;
    expect(lines.length, 13);
  });

  test('parses new files', () {
    final diffText = '''diff --git a/testste b/testste
new file mode 100644
index 0000000..f13588b
--- /dev/null
+++ b/testste
@@ -0,0 +1 @@
+asdfasdf
''';

    final parser = DiffParser();
    final diff = parser.parse(diffText) as TextDiff;
    expect(diff.hunks.length, 1);

    final hunk = diff.hunks[0];
    expect(hunk.unifiedDiffStart, 0);
    expect(hunk.unifiedDiffEnd, 1);

    final lines = hunk.lines;
    expect(lines.length, 2);

    var i = 0;
    expect(lines[i].text, '@@ -0,0 +1 @@');
    expect(lines[i].type, DiffLineType.hunk);
    expect(lines[i].oldLineNumber == null, isTrue);
    expect(lines[i].newLineNumber == null, isTrue);
    i++;

    expect(lines[i].text, '+asdfasdf');
    expect(lines[i].type, DiffLineType.add);
    expect(lines[i].oldLineNumber == null, isTrue);
    expect(lines[i].newLineNumber, 1);
  });

  test('parses files containing @@', () {
    final diffText = '''diff --git a/test.txt b/test.txt
index 24219cc..bf711a5 100644
--- a/test.txt
+++ b/test.txt
@@ -1 +1 @@
-foo @@
+@@ foo
''';

    final parser = DiffParser();
    final diff = parser.parse(diffText) as TextDiff;
    expect(diff.hunks.length, 1);

    final hunk = diff.hunks[0];
    expect(hunk.unifiedDiffStart, 0);
    expect(hunk.unifiedDiffEnd, 2);

    final lines = hunk.lines;
    expect(lines.length, 3);

    var i = 0;
    expect(lines[i].text, '@@ -1 +1 @@');
    expect(lines[i].type, DiffLineType.hunk);
    expect(lines[i].oldLineNumber == null, isTrue);
    expect(lines[i].newLineNumber == null, isTrue);
    i++;

    expect(lines[i].text, '-foo @@');
    expect(lines[i].type, DiffLineType.delete);
    expect(lines[i].oldLineNumber, 1);
    expect(lines[i].newLineNumber == null, isTrue);
    i++;

    expect(lines[i].text, '+@@ foo');
    expect(lines[i].type, DiffLineType.add);
    expect(lines[i].oldLineNumber == null, isTrue);
    expect(lines[i].newLineNumber, 1);
  });

  test('parses new files without a newline at end of file', () {
    final diffText = '''diff --git a/test2.txt b/test2.txt
new file mode 100644
index 0000000..faf7da1
--- /dev/null
+++ b/test2.txt
@@ -0,0 +1 @@
+asdasdasd
\\ No newline at end of file
''';

    final parser = DiffParser();
    final diff = parser.parse(diffText) as TextDiff;
    expect(diff.hunks.length, 1);

    final hunk = diff.hunks[0];
    expect(hunk.unifiedDiffStart, 0);
    expect(hunk.unifiedDiffEnd, 1);

    final lines = hunk.lines;
    expect(lines.length, 2);

    var i = 0;
    expect(lines[i].text, '@@ -0,0 +1 @@');
    expect(lines[i].type, DiffLineType.hunk);
    expect(lines[i].oldLineNumber == null, isTrue);
    expect(lines[i].newLineNumber == null, isTrue);
    expect(lines[i].noTrailingNewLine, false);
    i++;

    expect(lines[i].text, '+asdasdasd');
    expect(lines[i].type, DiffLineType.add);
    expect(lines[i].oldLineNumber == null, isTrue);
    expect(lines[i].newLineNumber, 1);
    expect(lines[i].noTrailingNewLine, true);
  });

  test('parses diffs that adds newline to end of file', () {
    final diffText = '''diff --git a/test2.txt b/test2.txt
index 1910281..257cc56 100644
--- a/test2.txt
+++ b/test2.txt
@@ -1 +1 @@
-foo
\\ No newline at end of file
+foo
''';
    final parser = DiffParser();
    final diff = parser.parse(diffText) as TextDiff;
    expect(diff.hunks.length, 1);

    final hunk = diff.hunks[0];
    expect(hunk.unifiedDiffStart, 0);
    expect(hunk.unifiedDiffEnd, 2);

    final lines = hunk.lines;
    expect(lines.length, 3);

    var i = 0;
    expect(lines[i].text, '@@ -1 +1 @@');
    expect(lines[i].type, DiffLineType.hunk);
    expect(lines[i].oldLineNumber == null, isTrue);
    expect(lines[i].newLineNumber == null, isTrue);
    expect(lines[i].noTrailingNewLine, false);
    i++;

    expect(lines[i].text, '-foo');
    expect(lines[i].type, DiffLineType.delete);
    expect(lines[i].oldLineNumber, 1);
    expect(lines[i].newLineNumber == null, isTrue);
    expect(lines[i].originalLineNumber, 1);
    expect(lines[i].noTrailingNewLine, true);
    i++;

    expect(lines[i].text, '+foo');
    expect(lines[i].type, DiffLineType.add);
    expect(lines[i].oldLineNumber == null, isTrue);
    expect(lines[i].newLineNumber, 1);
    expect(lines[i].originalLineNumber, 2);
    expect(lines[i].noTrailingNewLine, false);
  });

  test('parses diffs where neither file version has a trailing newline', () {
    // echo -n 'foo' >  test
    // git add -A && git commit -m foo
    // echo -n 'bar' > test
    // git diff test
    final diffText = '''diff --git a/test b/test
index 1910281..ba0e162 100644
--- a/test
+++ b/test
@@ -1 +1 @@
-foo
\\ No newline at end of file
+bar
\\ No newline at end of file
''';
    final parser = DiffParser();
    final diff = parser.parse(diffText) as TextDiff;
    expect(diff.hunks.length, 1);

    final hunk = diff.hunks[0];
    expect(hunk.unifiedDiffStart, 0);
    expect(hunk.unifiedDiffEnd, 2);

    final lines = hunk.lines;
    expect(lines.length, 3);

    var i = 0;
    expect(lines[i].text, '@@ -1 +1 @@');
    expect(lines[i].type, DiffLineType.hunk);
    expect(lines[i].oldLineNumber == null, isTrue);
    expect(lines[i].newLineNumber == null, isTrue);
    expect(lines[i].noTrailingNewLine, false);
    i++;

    expect(lines[i].text, '-foo');
    expect(lines[i].type, DiffLineType.delete);
    expect(lines[i].oldLineNumber, 1);
    expect(lines[i].newLineNumber == null, isTrue);
    expect(lines[i].originalLineNumber, 1);
    expect(lines[i].noTrailingNewLine, true);
    i++;

    expect(lines[i].text, '+bar');
    expect(lines[i].type, DiffLineType.add);
    expect(lines[i].oldLineNumber == null, isTrue);
    expect(lines[i].newLineNumber, 1);
    expect(lines[i].originalLineNumber, 2);
    expect(lines[i].noTrailingNewLine, true);
  });

  test('parses binary diffs', () {
    final diffText = '''diff --git a/IMG_2306.CR2 b/IMG_2306.CR2
new file mode 100644
index 0000000..4bf3a64
Binary files /dev/null and b/IMG_2306.CR2 differ
''';
    final parser = DiffParser();
    final diff = parser.parse(diffText);
    expect(diff, isA<BinaryDiff>());
  });

  test('parses diff of empty file', () {
    // To produce this output, do
    // touch foo
    // git diff --no-index --patch-with-raw -z -- /dev/null foo
    final diffText = '''new file mode 100644
index 0000000..e69de29
''';

    final parser = DiffParser();
    final diff = parser.parse(diffText) as TextDiff;
    expect(diff.hunks.length, 0);
  });

  test('parses hunk headers with omitted line counts from new file', () {
    final diffText = '''diff --git a/testste b/testste
new file mode 100644
index 0000000..f13588b
--- /dev/null
+++ b/testste
@@ -0,0 +1 @@
+asdfasdf
''';

    final parser = DiffParser();
    final diff = parser.parse(diffText) as TextDiff;
    expect(diff.hunks.length, 1);

    final hunk = diff.hunks[0];
    expect(hunk.header.oldStartLine, 0);
    expect(hunk.header.oldLineCount, 0);
    expect(hunk.header.newStartLine, 1);
    expect(hunk.header.newLineCount, 1);
  });

  test('parses hunk headers with omitted line counts from old file', () {
    final diffText = '''diff --git a/testste b/testste
new file mode 100644
index 0000000..f13588b
--- /dev/null
+++ b/testste
@@ -1 +0,0 @@
-asdfasdf
''';

    final parser = DiffParser();
    final diff = parser.parse(diffText) as TextDiff;
    expect(diff.hunks.length, 1);

    final hunk = diff.hunks[0];
    expect(hunk.header.oldStartLine, 1);
    expect(hunk.header.oldLineCount, 1);
    expect(hunk.header.newStartLine, 0);
    expect(hunk.header.newLineCount, 0);
  });
}
