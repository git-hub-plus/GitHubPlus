import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/features/stash/stash_panel.dart';
import 'package:github_plus/core/models/app_models.dart';
import 'package:github_plus/state/history_state.dart';
import 'package:github_plus/state/repo_state.dart';
import 'package:github_plus/state/stash_state.dart';
import 'package:github_plus/ui/widgets/diff_view.dart';
import '../history/history_test_support.dart';

void main() {
  late HistoryFixture fixture;
  setUp(() async {
    fixture = await HistoryFixture.create();
  });
  tearDown(() async {
    await fixture.repos.dispose();
  });
  testWidgets('create, list files and diff, apply, pop, and confirmed drop with real providers', (tester) async {
    drainGitOnTearDown(tester, fixture);
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = fixture.repo;
    await tester.runAsync(() async {
      await fixture.repos.commit(repo.path, 'base', files: {'base.txt': 'base\n'});
      await fixture.repos.write(repo.path, 'new.txt', 'saved content\n');
    });
    await tester.pumpWidget(
      fixture.app(
        Consumer(
          builder: (context, ref, _) =>
              TextButton(onPressed: () => showStashPanel(context, ref, repo), child: const Text('Open')),
        ),
      ),
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(TextButton)));
    await tester.tap(find.text('Open'));
    await pumpUntil(tester, () => tester.widget<FilledButton>(find.byKey(const Key('stash-create'))).onPressed != null);
    await tester.enterText(find.byKey(const Key('stash-message')), 'saved work');
    await tester.tap(find.byKey(const Key('stash-create')));
    await pumpUntil(
      tester,
      () => find.textContaining('saved work').evaluate().isNotEmpty && !container.read(repositoryActionProvider(repo)),
    );
    await pumpUntil(tester, () => container.read(stashListProvider(repo)).value?.length == 1);
    await pumpUntil(tester, () => !container.read(repoStatusProvider(repo.id)).isLoading);
    expect(container.read(repoStatusProvider(repo.id)).value?.files, isEmpty);
    final entry = container.read(stashListProvider(repo)).value!.single;
    await pumpUntil(tester, () => find.byKey(ValueKey('stash-${entry.sha}')).evaluate().isNotEmpty);
    await tester.tap(find.byKey(ValueKey('stash-${entry.sha}')));
    await pumpUntil(tester, () => find.byKey(const ValueKey('stash-file-new.txt')).evaluate().isNotEmpty);
    await tester.tap(find.byKey(const ValueKey('stash-file-new.txt')));
    await pumpUntil(tester, () => find.byType(FileDiffView).evaluate().isNotEmpty);
    expect(find.textContaining('saved content'), findsOneWidget);
    expect(tester.widget<FileDiffView>(find.byType(FileDiffView)).selection, isNull);
    await tester.tap(find.text('Apply only'));
    await pumpUntil(
      tester,
      () =>
          !container.read(repositoryActionProvider(repo)) &&
          container.read(repoStatusProvider(repo.id)).value?.files.isNotEmpty == true,
    );
    expect(container.read(stashListProvider(repo)).value?.length, 1);
    // Commit the applied content while keeping its saved entry.
    await tester.runAsync(() async {
      await fixture.repos.commit(repo.path, 'keep applied work');
      await fixture.repos.write(repo.path, 'base.txt', 'second change\n');
    });
    container.invalidate(repoStatusProvider(repo.id));
    await pumpUntil(tester, () => tester.widget<FilledButton>(find.byKey(const Key('stash-create'))).onPressed != null);
    await tester.enterText(find.byKey(const Key('stash-message')), 'second work');
    await tester.tap(find.byKey(const Key('stash-create')));
    await pumpUntil(
      tester,
      () =>
          !container.read(repositoryActionProvider(repo)) && container.read(stashListProvider(repo)).value?.length == 2,
    );
    final second = container.read(stashListProvider(repo)).value!.first;
    await pumpUntil(tester, () => find.byKey(ValueKey('stash-${second.sha}')).evaluate().isNotEmpty);
    await tester.tap(find.byKey(ValueKey('stash-${second.sha}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Pop').first);
    await pumpUntil(
      tester,
      () =>
          !container.read(repositoryActionProvider(repo)) && container.read(stashListProvider(repo)).value?.length == 1,
    );
    final restored = await tester.runAsync(
      () => fixture.repos.run(repo.path, ['diff', '--no-ext-diff', '--no-textconv', '--', 'base.txt']),
    );
    expect(restored!.stdout, contains('second change'));
    await pumpUntil(tester, () => find.byKey(ValueKey('stash-${entry.sha}')).evaluate().isNotEmpty);
    await tester.tap(find.byKey(ValueKey('stash-${entry.sha}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Drop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(stashListProvider(repo)).value?.length, 1);
    await tester.tap(find.text('Drop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Continue'));
    await pumpUntil(tester, () => find.text('Nothing set aside yet.').evaluate().isNotEmpty);
    expect(tester.takeException(), isNull);
    await settleGit(tester, fixture);
  });

  testWidgets('pop conflicts guide to changes and retain the stash', (tester) async {
    final repo = fixture.repo;
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await fixture.repos.commit(repo.path, 'base', files: {'base.txt': 'base\n'});
      await fixture.repos.write(repo.path, 'base.txt', 'set aside\n');
    });
    drainGitOnTearDown(tester, fixture);
    await tester.pumpWidget(
      fixture.app(
        Consumer(
          builder: (context, ref, _) =>
              TextButton(onPressed: () => showStashPanel(context, ref, repo), child: const Text('Open')),
        ),
      ),
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(TextButton)));
    await tester.tap(find.text('Open'));
    await pumpUntil(tester, () => tester.widget<FilledButton>(find.byKey(const Key('stash-create'))).onPressed != null);
    await tester.tap(find.byKey(const Key('stash-create')));
    await pumpUntil(
      tester,
      () =>
          !container.read(repositoryActionProvider(repo)) && container.read(stashListProvider(repo)).value?.length == 1,
    );
    await tester.runAsync(() => fixture.repos.commit(repo.path, 'competing', files: {'base.txt': 'competing\n'}));
    container.invalidate(repoStatusProvider(repo.id));
    await settleGit(tester, fixture);
    final entry = container.read(stashListProvider(repo)).value!.single;
    await tester.tap(find.byKey(ValueKey('stash-${entry.sha}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Pop'));
    await pumpUntil(tester, () => container.read(repoStatusProvider(repo.id)).value?.conflictCount == 1);
    await pumpUntil(
      tester,
      () => find.text('Conflicts found. Resolve them in the Changed files tab.').evaluate().isNotEmpty,
    );
    expect(container.read(stashListProvider(repo)).value?.length, 1);
    await settleGit(tester, fixture);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty compact panel uses Korean terms in both modes and disables creation', (tester) async {
    drainGitOnTearDown(tester, fixture);
    for (final style in TermStyle.values) {
      await tester.pumpWidget(
        fixture.app(
          Consumer(
            builder: (context, ref, _) =>
                TextButton(onPressed: () => showStashPanel(context, ref, fixture.repo), child: const Text('Open')),
          ),
          language: AppLanguage.ko,
          terms: style,
          brightness: Brightness.light,
        ),
      );
      await tester.tap(find.text('Open'));
      await pumpUntil(tester, () => find.text('보관한 항목이 없습니다.').evaluate().isNotEmpty);
      expect(tester.widget<FilledButton>(find.byKey(const Key('stash-create'))).onPressed, isNull);
      expect(find.text(style == TermStyle.plain ? '지금 바뀐 파일 임시 보관' : '지금 바뀐 파일 스태시'), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await settleGit(tester, fixture);
    }
    expect(tester.takeException(), isNull);
  });
}
