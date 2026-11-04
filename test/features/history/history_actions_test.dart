import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/features/history/history_view.dart';
import 'package:github_plus/state/history_state.dart';
import 'package:github_plus/state/repo_state.dart';
import 'history_test_support.dart';

Future<void> openMenu(WidgetTester tester, String sha, String label) async {
  await pumpUntil(tester, () => find.byKey(ValueKey('history-actions-$sha')).evaluate().isNotEmpty);
  await tester.tap(find.byKey(ValueKey('history-actions-$sha')));
  await pumpUntil(
    tester,
    () => find.byType(PopupMenuItem<dynamic>).evaluate().isNotEmpty || find.text(label).evaluate().isNotEmpty,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text(label));
  if (label == 'Create Label…' || label == 'Combine versions…') {
    await pumpUntil(tester, () => find.byKey(const Key('history-action-input')).evaluate().isNotEmpty);
  } else if (label == 'Undo changes: versions' || label == 'Undo last versions' || label == 'Move down') {
    await pumpUntil(tester, () => find.widgetWithText(FilledButton, 'Continue').evaluate().isNotEmpty);
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> confirm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pump();
}

void main() {
  late HistoryFixture fixture;
  setUp(() async {
    fixture = await HistoryFixture.create();
  });
  tearDown(() async {
    await fixture.repos.dispose();
  });

  Future<ProviderContainer> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    drainGitOnTearDown(tester, fixture);
    await tester.pumpWidget(fixture.app(HistoryView(repo: fixture.repo)));
    final container = ProviderScope.containerOf(tester.element(find.byType(HistoryView)));
    await pumpUntil(
      tester,
      () =>
          !container.read(historyProvider(fixture.repo)).loading &&
          container.read(repoStatusProvider(fixture.repo.id)).hasValue,
    );
    return container;
  }

  testWidgets('tag create/delete, revert and undo with message copy action', (tester) async {
    final repo = fixture.repo;
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    late String sha;
    await tester.runAsync(() async {
      final remote = await fixture.repos.init('tag-remote', bare: true);
      await fixture.repos.run(repo.path, ['remote', 'add', 'origin', remote]);
      await fixture.repos.commit(repo.path, 'base', files: {'base.txt': 'base\n'});
      sha = await fixture.repos.commit(repo.path, 'add item', files: {'item.txt': 'item\n'});
    });
    final container = await mount(tester);
    await openMenu(tester, sha, 'Copy SHA');
    expect(copied, sha);
    await openMenu(tester, sha, 'Create Label…');
    await tester.enterText(find.byKey(const Key('history-action-input')), 'v-test');
    await tester.enterText(find.byKey(const Key('tag-description')), 'release notes');
    await confirm(tester);
    await pumpUntil(tester, () => find.text('v-test').evaluate().isNotEmpty);
    await settleGit(tester, fixture);
    final badge = find.text('v-test');
    final gesture = await tester.startGesture(
      tester.getCenter(badge),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await pumpUntil(tester, () => find.text('Delete Label').evaluate().isNotEmpty);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Upload Label to remote'));
    await pumpUntil(
      tester,
      () => !container.read(repositoryActionProvider(repo)) && find.text('Upload Label to remote').evaluate().isEmpty,
    );
    await settleGit(tester, fixture);
    final remoteTags = await tester.runAsync(
      () => fixture.repos.run('${fixture.repos.root.path}/tag-remote', ['tag', '--list']),
    );
    expect(remoteTags!.stdout, contains('v-test'));
    final deleteGesture = await tester.startGesture(
      tester.getCenter(find.text('v-test')),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await deleteGesture.up();
    await pumpUntil(tester, () => find.text('Delete Label').evaluate().isNotEmpty);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Delete Label'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await confirm(tester);
    await pumpUntil(
      tester,
      () => !container.read(repositoryActionProvider(repo)) && find.text('v-test').evaluate().isEmpty,
    );
    final tags = await tester.runAsync(() => fixture.repos.run(repo.path, ['tag', '--list']));
    expect(tags!.stdout.trim(), isEmpty);
    final deletedRemoteTags = await tester.runAsync(
      () => fixture.repos.run('${fixture.repos.root.path}/tag-remote', ['tag', '--list']),
    );
    expect(deletedRemoteTags!.stdout.trim(), isEmpty);
    await openMenu(tester, sha, 'Undo changes: versions');
    await confirm(tester);
    await pumpUntil(
      tester,
      () =>
          !container.read(repositoryActionProvider(repo)) && container.read(historyProvider(repo)).commits.length == 3,
    );
    final reverted = container.read(historyProvider(repo)).commits.first;
    expect(reverted.summary, contains('Revert'));
    await openMenu(tester, reverted.sha, 'Undo last versions');
    await confirm(tester);
    await pumpUntil(tester, () => find.text('Copy message').evaluate().isNotEmpty);
    await pumpUntil(
      tester,
      () => !container.read(historyProvider(repo)).loading && container.read(historyProvider(repo)).commits.length == 2,
    );
    expect(container.read(historyProvider(repo)).commits.length, 2);
    await pumpUntil(tester, () => !container.read(repoStatusProvider(repo.id)).isLoading);
    expect(container.read(repoStatusProvider(repo.id)).value?.files.isNotEmpty, isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Copy message'));
    expect(copied, contains(reverted.summary));
    await settleGit(tester, fixture);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only absent commits can be cherry-picked into current branch', (tester) async {
    final repo = fixture.repo;
    late String sha, base;
    await tester.runAsync(() async {
      base = await fixture.repos.commit(repo.path, 'base', files: {'base.txt': 'base\n'});
      await fixture.repos.run(repo.path, ['switch', '-c', 'side']);
      sha = await fixture.repos.commit(repo.path, 'side item', files: {'side.txt': 'side\n'});
      await fixture.repos.run(repo.path, ['switch', 'main']);
    });
    final container = await mount(tester);
    await tester.tap(find.text('All Branches'));
    await pumpUntil(tester, () => container.read(historyProvider(repo)).commits.length == 2);
    await tester.tap(find.byKey(ValueKey('history-actions-$base')));
    await pumpUntil(tester, () => find.text('Pick changes into the current Branch').evaluate().isNotEmpty);
    final disabled = tester.widget<PopupMenuItem<dynamic>>(
      find
          .ancestor(
            of: find.text('Pick changes into the current Branch'),
            matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
          )
          .first,
    );
    expect(disabled.enabled, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await openMenu(tester, sha, 'Pick changes into the current Branch');
    await pumpUntil(
      tester,
      () =>
          !container.read(repositoryActionProvider(repo)) &&
          container.read(repoStatusProvider(repo.id)).value?.headSha != base,
    );
    final file = await tester.runAsync(() => fixture.repos.run(repo.path, ['show', 'HEAD:side.txt']));
    expect(file!.stdout, contains('side'));
    await settleGit(tester, fixture);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl/Shift selection, squash and move with published history warning', (tester) async {
    final repo = fixture.repo;
    late String a, b, c;
    await tester.runAsync(() async {
      a = await fixture.repos.commit(repo.path, 'alpha', files: {'a.txt': 'a\n'});
      b = await fixture.repos.commit(repo.path, 'beta', files: {'b.txt': 'b\n'});
      c = await fixture.repos.commit(repo.path, 'gamma', files: {'c.txt': 'c\n'});
    });
    final container = await mount(tester);
    await tester.tap(find.byKey(ValueKey('commit-$b')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.byKey(ValueKey('commit-$c')));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(find.textContaining('2 selected'), findsOneWidget);
    await openMenu(tester, c, 'Combine versions…');
    expect(tester.widget<TextField>(find.byKey(const Key('history-action-input'))).controller!.text, 'beta\n\ngamma');
    await tester.enterText(find.byKey(const Key('history-action-input')), 'combined');
    await confirm(tester);
    await pumpUntil(
      tester,
      () =>
          !container.read(repositoryActionProvider(repo)) && container.read(historyProvider(repo)).commits.length == 2,
    );
    final combined = container.read(historyProvider(repo)).commits.first;
    expect(combined.summary, 'combined');
    await tester.runAsync(() => fixture.repos.run(repo.path, ['update-ref', 'refs/remotes/origin/main', combined.sha]));
    container.invalidate(repoStatusProvider(repo.id));
    await pumpUntil(
      tester,
      () => !container.read(historyProvider(repo)).loading && container.read(repoStatusProvider(repo.id)).hasValue,
    );
    await openMenu(tester, combined.sha, 'Move down');
    expect(find.textContaining('already uploaded'), findsOneWidget);
    await confirm(tester);
    await pumpUntil(
      tester,
      () =>
          !container.read(repositoryActionProvider(repo)) &&
          container.read(historyProvider(repo)).commits.firstOrNull?.summary == 'alpha',
    );
    final state = container.read(historyProvider(repo));
    expect(state.commits.map((c) => c.summary), ['alpha', 'combined']);
    expect(state.commits.any((c) => c.sha == a), isFalse);
    // Exercise Shift range selection after a refresh too.
    await tester.tap(find.byKey(ValueKey('commit-${state.commits.first.sha}')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byKey(ValueKey('commit-${state.commits.last.sha}')));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(find.textContaining('2 selected'), findsOneWidget);
    await settleGit(tester, fixture);
    expect(tester.takeException(), isNull);
  });
}
