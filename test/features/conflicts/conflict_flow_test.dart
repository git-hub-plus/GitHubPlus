import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/git/merge.dart';
import 'package:github_plus/core/git/rewrite.dart';
import 'package:github_plus/core/git/stash.dart';
import 'package:github_plus/core/models/advanced.dart';
import 'package:github_plus/features/changes/changes_view.dart';
import 'package:github_plus/state/changes_state.dart';
import 'package:github_plus/core/models/diff.dart';
import 'package:github_plus/state/repo_state.dart';
import 'package:github_plus/ui/widgets/diff_view.dart';
import '../history/history_test_support.dart';

void main() {
  late HistoryFixture f;
  late String original;
  setUp(() async {
    f = await HistoryFixture.create();
    await f.repos.commit(f.repo.path, 'base', files: {'file.txt': 'base\n'});
    await f.repos.run(f.repo.path, ['switch', '-c', 'feature']);
    await f.repos.commit(f.repo.path, 'incoming', files: {'file.txt': 'incoming\n', 'z.txt': 'added\n'});
    await f.repos.run(f.repo.path, ['switch', 'main']);
    original = await f.repos.commit(f.repo.path, 'mine', files: {'file.txt': 'mine\n'});
  });
  tearDown(() => f.repos.dispose());
  Future<ProviderContainer> mount(WidgetTester tester, {bool quest = true}) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    drainGitOnTearDown(tester, f);
    await tester.pumpWidget(f.app(ChangesView(repo: f.repo)));
    final c = ProviderScope.containerOf(tester.element(find.byType(ChangesView)));
    await pumpUntil(
      tester,
      () => find.byKey(Key(quest ? 'conflict-quest' : 'conflict-all-ours')).evaluate().isNotEmpty,
    );
    c.read(changesProvider(f.repo.id).notifier).selectFile('file.txt');
    await pumpUntil(tester, () => find.byKey(const Key('conflict-all-ours')).evaluate().isNotEmpty);
    await settleGit(tester, f);
    return c;
  }

  testWidgets('merge quest locks selection, saves blocks and continues to a merge commit', (tester) async {
    expect(await tester.runAsync(() => merge(f.git, f.repo.path, 'feature')), OperationOutcome.conflicts);
    final c = await mount(tester);
    expect(tester.widget<Checkbox>(find.byKey(const Key('changes-all'))).onChanged, isNull);
    expect(tester.widget<Checkbox>(find.byKey(const Key('include-file.txt'))).onChanged, isNull);
    c.read(changesProvider(f.repo.id).notifier).selectLines('file.txt', DiffSelection.none());
    expect(c.read(changesProvider(f.repo.id)).selections['file.txt']!.selectionType, SelectionType.all);
    expect(find.byKey(const Key('changes-summary')), findsNothing);
    c.read(changesProvider(f.repo.id).notifier).selectFile('z.txt');
    await pumpUntil(tester, () => find.byType(FileDiffView).evaluate().isNotEmpty);
    expect(tester.widget<FileDiffView>(find.byType(FileDiffView)).selection, isNull);
    expect(tester.widget<FileDiffView>(find.byType(FileDiffView)).onSelectionChanged, isNull);
    c.read(changesProvider(f.repo.id).notifier).selectFile('file.txt');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('conflict-continue'))).onPressed, isNull);
    await pumpUntil(tester, () => find.byKey(const ValueKey('conflict-0-both')).evaluate().isNotEmpty);
    expect(tester.widget<FilledButton>(find.byKey(const Key('conflict-save'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('conflict-0-both')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('conflict-save')));
    await pumpUntil(tester, () => c.read(repoStatusProvider(f.repo.id)).value?.conflictCount == 0);
    await settleGit(tester, f);
    expect(find.text('Resolved 1/1 conflict files'), findsOneWidget);
    expect(await tester.runAsync(() => File('${f.repo.path}/file.txt').readAsString()), 'mine\nincoming\n');
    await tester.tap(find.byKey(const Key('conflict-continue')));
    await pumpUntil(tester, () => find.byKey(const Key('conflict-message')).evaluate().isNotEmpty);
    expect(tester.widget<TextField>(find.byKey(const Key('conflict-message'))).controller!.text, contains('Merge'));
    await tester.enterText(find.byKey(const Key('conflict-message')), '');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('conflict-confirm'))).onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await settleGit(tester, f);
    expect(c.read(repoStatusProvider(f.repo.id)).value?.inProgress, isNotNull);
    await tester.tap(find.byKey(const Key('conflict-continue')));
    await pumpUntil(tester, () => find.byKey(const Key('conflict-message')).evaluate().isNotEmpty);
    await tester.enterText(find.byKey(const Key('conflict-message')), 'Resolved merge');
    await tester.tap(find.byKey(const Key('conflict-confirm')));
    await pumpUntil(tester, () => find.byKey(const Key('conflict-quest')).evaluate().isEmpty);
    await settleGit(tester, f);
    final result = await tester.runAsync(() => f.repos.run(f.repo.path, ['log', '-1', '--format=%s%n%P']));
    expect(result!.stdout, startsWith('Resolved merge\n'));
    expect(result.stdout.trim().split('\n').last.split(' '), hasLength(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('abort confirms and restores the original branch and file', (tester) async {
    await tester.runAsync(() => merge(f.git, f.repo.path, 'feature'));
    final c = await mount(tester);
    await tester.tap(find.byKey(const Key('conflict-abort')));
    await settleGit(tester, f);
    await tester.tap(find.text('Cancel'));
    await settleGit(tester, f);
    expect(c.read(repoStatusProvider(f.repo.id)).value?.inProgress, isNotNull);
    await tester.tap(find.byKey(const Key('conflict-abort')));
    await settleGit(tester, f);
    await tester.tap(find.byKey(const Key('conflict-confirm')));
    await pumpUntil(tester, () => find.byKey(const Key('conflict-quest')).evaluate().isEmpty);
    await settleGit(tester, f);
    expect(c.read(repoStatusProvider(f.repo.id)).value?.headSha, original);
    expect(await tester.runAsync(() => File('${f.repo.path}/file.txt').readAsString()), 'mine\n');
    expect(tester.takeException(), isNull);
  });
  testWidgets('whole incoming side resolves a rebase and continues it', (tester) async {
    expect(await tester.runAsync(() => rebase(f.git, f.repo.path, 'feature')), OperationOutcome.conflicts);
    final c = await mount(tester);
    expect(find.textContaining('step 1/1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('conflict-all-theirs')));
    await pumpUntil(tester, () => c.read(repoStatusProvider(f.repo.id)).value?.conflictCount == 0);
    await settleGit(tester, f);
    await tester.tap(find.byKey(const Key('conflict-continue')));
    await pumpUntil(tester, () => find.byKey(const Key('conflict-quest')).evaluate().isEmpty);
    await settleGit(tester, f);
    expect(c.read(repoStatusProvider(f.repo.id)).value?.currentBranch, 'main');
    expect(tester.takeException(), isNull);
  });
  for (final kind in ['binary', 'deleted']) {
    testWidgets('$kind conflicts offer whole-file choices and refresh status', (tester) async {
      await tester.runAsync(() async {
        await f.repos.run(f.repo.path, ['switch', 'feature']);
        if (kind == 'deleted') {
          await f.repos.run(f.repo.path, ['rm', '--', 'file.txt']);
        } else {
          await File('${f.repo.path}/file.txt').writeAsBytes([0, 1, 2]);
        }
        await f.repos.commit(f.repo.path, 'incoming $kind');
        await f.repos.run(f.repo.path, ['switch', 'main']);
        if (kind == 'binary') {
          await File('${f.repo.path}/file.txt').writeAsBytes([0, 3, 4]);
          await f.repos.commit(f.repo.path, 'my binary');
        }
        expect(await merge(f.git, f.repo.path, 'feature'), OperationOutcome.conflicts);
      });
      final c = await mount(tester);
      await pumpUntil(tester, () => find.textContaining('Binary, deleted or unreadable').evaluate().isNotEmpty);
      expect(find.byKey(const Key('conflict-save')), findsNothing);
      await tester.tap(find.byKey(const Key('conflict-all-theirs')));
      await pumpUntil(tester, () => c.read(repoStatusProvider(f.repo.id)).value?.conflictCount == 0);
      await settleGit(tester, f);
      if (kind == 'deleted') {
        expect(await tester.runAsync(() => File('${f.repo.path}/file.txt').exists()), isFalse);
      } else {
        expect(await tester.runAsync(() => File('${f.repo.path}/file.txt').readAsBytes()), [0, 1, 2]);
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final kind in ['cherry-pick', 'revert']) {
    testWidgets('$kind conflicts finish through the quest', (tester) async {
      await tester.runAsync(() async {
        if (kind == 'revert') {
          await f.repos.commit(f.repo.path, 'later', files: {'file.txt': 'later\n'});
          expect(await revert(f.git, f.repo.path, original), OperationOutcome.conflicts);
        } else {
          expect(await cherryPick(f.git, f.repo.path, ['feature']), OperationOutcome.conflicts);
        }
      });
      final c = await mount(tester);
      await tester.tap(find.byKey(const Key('conflict-all-theirs')));
      await pumpUntil(tester, () => c.read(repoStatusProvider(f.repo.id)).value?.conflictCount == 0);
      await settleGit(tester, f);
      await tester.tap(find.byKey(const Key('conflict-continue')));
      await pumpUntil(tester, () => find.byKey(const Key('conflict-quest')).evaluate().isEmpty);
      await settleGit(tester, f);
      expect(
        await tester.runAsync(() => File('${f.repo.path}/file.txt').readAsString()),
        kind == 'revert' ? 'base\n' : 'incoming\n',
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('stash conflicts resolve without inventing a sequencer operation', (tester) async {
    await tester.runAsync(() async {
      await f.repos.write(f.repo.path, 'file.txt', 'stashed\n');
      await stashCreate(f.git, f.repo.path);
      await f.repos.commit(f.repo.path, 'after stash', files: {'file.txt': 'newer\n'});
      expect(await stashApply(f.git, f.repo.path, 'stash@{0}'), OperationOutcome.conflicts);
    });
    final c = await mount(tester, quest: false);
    expect(find.byKey(const Key('conflict-quest')), findsNothing);
    await tester.tap(find.byKey(const Key('conflict-all-theirs')));
    await pumpUntil(tester, () => c.read(repoStatusProvider(f.repo.id)).value?.conflictCount == 0);
    await settleGit(tester, f);
    expect(await tester.runAsync(() => File('${f.repo.path}/file.txt').readAsString()), 'stashed\n');
    expect(find.byKey(const Key('changes-summary')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
