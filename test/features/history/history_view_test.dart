import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/features/history/history_view.dart';
import 'package:github_plus/state/history_state.dart';
import 'package:github_plus/state/repo_state.dart';
import 'package:github_plus/ui/theme.dart';
import 'package:github_plus/ui/widgets/diff_view.dart';

import 'history_test_support.dart';
import '../../core/git/helpers.dart';

void main() {
  late HistoryFixture fixture;
  setUp(() async {
    fixture = await HistoryFixture.create();
  });
  tearDown(() async {
    await fixture.repos.dispose();
  });

  testWidgets('merge graph, selection, file diff, keyboard, parents and filtering', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = fixture.repo;
    final git = fixture.repos;
    late String root, feature, main;
    await tester.runAsync(() async {
      root = await git.commit(repo.path, 'root', files: {'base.txt': 'base\n'});
      await git.run(repo.path, ['switch', '-c', 'feature']);
      feature = await git.commit(repo.path, 'feature change', files: {'feature.txt': 'feature content\n'});
      await git.run(repo.path, ['switch', 'main']);
      main = await git.commit(repo.path, 'main change', files: {'main.txt': 'main content\n'});
      await git.run(repo.path, ['merge', '--no-ff', 'feature', '-m', 'merge feature']);
      await git.run(repo.path, ['tag', 'v1']);
      await git.run(repo.path, ['update-ref', 'refs/remotes/origin/main', 'HEAD']);
    });
    drainGitOnTearDown(tester, fixture);
    await tester.pumpWidget(fixture.app(HistoryView(repo: repo)));
    final container = ProviderScope.containerOf(tester.element(find.byType(HistoryView)));
    await pumpUntil(tester, () => container.read(historyProvider(repo)).commits.length == 4);
    await pumpUntil(tester, () => find.byKey(const ValueKey('history-file-feature.txt')).evaluate().isNotEmpty);
    final state = container.read(historyProvider(repo));
    expect(state.graph.any((r) => r.laneCount > 1), isTrue);
    expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is CommitGraphPainter), findsNWidgets(4));
    expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    expect(find.byIcon(Icons.sell_outlined), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history-file-feature.txt')));
    await tester.pump();
    final selection = container.read(historyProvider(repo));
    expect(selection.file, isNotNull);
    final diffProvider = historyDiffProvider((path: repo.path, sha: selection.selected!.sha, file: selection.file!));
    await pumpUntil(
      tester,
      () => find.byType(FileDiffView).evaluate().isNotEmpty || container.read(diffProvider).hasError,
    );
    expect(container.read(diffProvider).error, isNull);
    expect(tester.widget<FileDiffView>(find.byType(FileDiffView)).selection, isNull);
    expect(find.textContaining('feature content'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('commit-$main')));
    await pumpUntil(tester, () => find.byKey(const ValueKey('history-file-main.txt')).evaluate().isNotEmpty);
    final ordered = container.read(historyProvider(repo)).commits;
    final mainIndex = ordered.indexWhere((c) => c.sha == main);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(container.read(historyProvider(repo)).selected?.sha, ordered[mainIndex + 1].sha);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(container.read(historyProvider(repo)).selected?.sha, main);
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('parent-$root')));
    await pumpUntil(tester, () => container.read(historyProvider(repo)).selected?.sha == root);
    await tester.enterText(find.byKey(const Key('history-search')), 'feature change');
    await tester.pump();
    expect(container.read(historyProvider(repo)).visibleIndices.length, 1);
    expect(find.byKey(ValueKey('commit-$feature')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('history-search')), 'Test');
    await tester.pump();
    expect(container.read(historyProvider(repo)).visibleIndices.length, 4);
    final before = tester.getSize(find.byKey(const Key('history-list'))).width;
    await tester.drag(find.byKey(const Key('history-divider')), const Offset(-80, 0));
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('history-list'))).width, lessThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('200-item paging, all branches, status invalidation resets first page', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = fixture.repo;
    await tester.runAsync(() async {
      final stream = StringBuffer();
      for (var i = 0; i < 205; i++) {
        final message = 'entry-$i';
        stream.write(
          'commit refs/heads/main\ncommitter Test <test@example.com> ${1700000000 + i} +0000\ndata ${message.length}\n$message\n\n',
        );
      }
      stream.write('done\n');
      await fixture.repos.git.run(
        [...TestRepos.identity, 'fast-import', '--quiet'],
        cwd: repo.path,
        stdin: stream.toString(),
      );
      await fixture.repos.run(repo.path, ['switch', '-c', 'side']);
      await fixture.repos.commit(repo.path, 'side-only version');
      await fixture.repos.run(repo.path, ['switch', 'main']);
    });
    drainGitOnTearDown(tester, fixture);
    await tester.pumpWidget(fixture.app(HistoryView(repo: repo)));
    final container = ProviderScope.containerOf(tester.element(find.byType(HistoryView)));
    await pumpUntil(tester, () => container.read(historyProvider(repo)).commits.length == 200);
    final scroll = tester.widget<ListView>(find.byKey(const Key('history-list'))).controller!;
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await pumpUntil(tester, () => container.read(historyProvider(repo)).commits.length == 205);
    expect(container.read(historyProvider(repo)).hasMore, isFalse);
    expect(container.read(historyProvider(repo)).commits.map((c) => c.sha).toSet().length, 205);
    await pumpUntil(tester, () => container.read(repoStatusProvider(repo.id)).hasValue);
    scroll.jumpTo(0);
    await tester.runAsync(() => fixture.repos.commit(repo.path, 'new version'));
    container.invalidate(repoStatusProvider(repo.id));
    await pumpUntil(tester, () {
      final s = container.read(historyProvider(repo));
      return !s.loading && s.commits.length == 200 && s.commits.first.summary == 'new version';
    });
    await tester.tap(find.text('All Branches'));
    await pumpUntil(
      tester,
      () => !container.read(historyProvider(repo)).loading && container.read(historyProvider(repo)).all,
    );
    await pumpUntil(tester, () => find.text('No changed files').evaluate().isNotEmpty);
    expect(container.read(historyProvider(repo)).commits.any((c) => c.summary == 'side-only version'), isTrue);
    await settleGit(tester, fixture);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unborn history and compact light layout have empty state', (tester) async {
    drainGitOnTearDown(tester, fixture);
    await tester.pumpWidget(fixture.app(HistoryView(repo: fixture.repo), brightness: Brightness.light));
    await pumpUntil(tester, () => find.text('No versions yet').evaluate().isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  test('graph palette contrasts with light and dark surfaces', () {
    for (final c in [GhpColors.light, GhpColors.dark]) {
      expect(graphPalette(c).length, 8);
      for (final color in graphPalette(c)) {
        final a = color.computeLuminance(), b = c.surface.computeLuminance();
        final contrast = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
        expect(contrast, greaterThanOrEqualTo(3));
      }
    }
  });
}
