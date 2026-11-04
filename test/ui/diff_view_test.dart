import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/models/diff.dart';
import 'package:github_plus/l10n/app_localizations.dart';
import 'package:github_plus/ui/theme.dart';
import 'package:github_plus/ui/widgets/diff_view.dart';

TextDiff _diff() {
  const lines = [
    DiffLine(text: '@@ -1,3 +1,3 @@', type: DiffLineType.hunk, originalLineNumber: 0),
    DiffLine(text: ' keep', type: DiffLineType.context, originalLineNumber: 1, oldLineNumber: 1, newLineNumber: 1),
    DiffLine(text: '-old a', type: DiffLineType.delete, originalLineNumber: 2, oldLineNumber: 2),
    DiffLine(text: '-old b', type: DiffLineType.delete, originalLineNumber: 3, oldLineNumber: 3),
    DiffLine(text: '+new a', type: DiffLineType.add, originalLineNumber: 4, newLineNumber: 2),
  ];
  return const TextDiff(
    text: '',
    maxLineNumber: 3,
    hunks: [
      DiffHunk(
        header: DiffHunkHeader(oldStartLine: 1, oldLineCount: 3, newStartLine: 1, newLineCount: 2),
        lines: lines,
        unifiedDiffStart: 0,
        unifiedDiffEnd: 4,
      ),
    ],
  );
}

class _Harness extends StatefulWidget {
  const _Harness({required this.onChanged});
  final ValueChanged<DiffSelection> onChanged;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final diff = _diff();
  late var selection = DiffSelection.all(diff.selectableLines);

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildTheme(Brightness.dark),
    localizationsDelegates: L10n.localizationsDelegates,
    supportedLocales: L10n.supportedLocales,
    home: Scaffold(
      body: FileDiffView(
        diff: diff,
        selection: selection,
        onSelectionChanged: (next) {
          setState(() => selection = next);
          widget.onChanged(next);
        },
      ),
    ),
  );
}

Finder _gutterOf(String text) => find.descendant(
  of: find.ancestor(of: find.text(text), matching: find.byType(Row)).first,
  matching: find.byType(GestureDetector),
);

void main() {
  testWidgets('click toggles a line, shift-click selects a range, header toggles the hunk', (tester) async {
    DiffSelection? last;
    await tester.pumpWidget(_Harness(onChanged: (s) => last = s));
    expect(find.text('+new a'), findsOneWidget);

    await tester.tap(_gutterOf('-old a'));
    await tester.pump();
    expect(last!.isSelected(2), isFalse);
    expect(last!.selectionType, SelectionType.partial);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(_gutterOf('+new a'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect([2, 3, 4].map(last!.isSelected), [false, false, false]);
    expect(last!.selectionType, SelectionType.none);

    await tester.tap(_gutterOf('@@ -1,3 +1,3 @@'));
    await tester.pump();
    expect(last!.selectionType, SelectionType.all);
  });

  testWidgets('read-only diffs have no clickable gutter', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(body: FileDiffView(diff: _diff())),
      ),
    );
    expect(find.byType(GestureDetector).evaluate().where((e) => (e.widget as GestureDetector).onTap != null), isEmpty);
  });

  test('selection ignores context lines and collapses to all/none', () {
    final diff = _diff();
    var s = DiffSelection.none(diff.selectableLines);
    s = s.withRangeSelection(0, 10, true);
    expect(s.selectionType, SelectionType.all);
    expect(s.divergingLines, isEmpty);
    expect(s.withLineSelection(1, false).selectionType, SelectionType.all);
  });
}
