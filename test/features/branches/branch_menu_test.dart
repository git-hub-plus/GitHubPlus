import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/expeditions/expedition.dart';
import 'package:github_plus/core/git/branches.dart';
import 'package:github_plus/core/models/commit.dart';
import 'package:github_plus/features/branches/branch_menu.dart';
import 'package:github_plus/state/app_state.dart';
import 'package:github_plus/state/repo_state.dart';

import '../history/history_test_support.dart';

class _OpenMenu extends ConsumerWidget {
  const _OpenMenu(this.fixture);
  final HistoryFixture fixture;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      TextButton(onPressed: () => showBranchMenu(context, ref, fixture.repo), child: const Text('Open branches'));
}

void main() {
  late HistoryFixture fixture;
  setUp(() async {
    fixture = await HistoryFixture.create();
    await fixture.repos.commit(fixture.repo.path, 'initial', files: {'file.txt': 'base\n'});
  });
  tearDown(() async {
    await fixture.repos.dispose();
  });

  Future<ProviderContainer> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    drainGitOnTearDown(tester, fixture);
    await tester.pumpWidget(fixture.app(_OpenMenu(fixture)));
    final container = ProviderScope.containerOf(tester.element(find.byType(_OpenMenu)));
    await tester.tap(find.text('Open branches'));
    await pumpUntil(tester, () => find.byKey(const ValueKey('branch-local-main')).evaluate().isNotEmpty);
    await settleGit(tester, fixture);
    return container;
  }

  for (final mode in ['clean merge', 'conflicted merge', 'rebase', 'already current']) {
    testWidgets('menu runs $mode with real providers', (tester) async {
      await tester.runAsync(() async {
        await fixture.repos.run(fixture.repo.path, ['switch', '-c', 'feature']);
        if (mode != 'already current') {
          await fixture.repos.commit(fixture.repo.path, 'feature version', files: {'file.txt': 'incoming\n'});
        }
        await fixture.repos.run(fixture.repo.path, ['switch', 'main']);
        if (mode == 'conflicted merge') {
          await fixture.repos.commit(fixture.repo.path, 'main version', files: {'file.txt': 'mine\n'});
        }
        if (mode == 'rebase') {
          await fixture.repos.commit(fixture.repo.path, 'main version', files: {'other.txt': 'mine\n'});
        }
      });
      final container = await open(tester);
      await tester.tap(find.byKey(const ValueKey('branch-menu-feature')));
      await settleGit(tester, fixture);
      await tester.tap(find.text(mode == 'rebase' ? 'Move base onto this Branch' : 'Combine into current Branch'));
      if (mode == 'rebase') {
        await pumpUntil(tester, () => find.byKey(const Key('rebase-confirm')).evaluate().isNotEmpty);
        await settleGit(tester, fixture);
        expect(find.textContaining('rewrite versions already uploaded'), findsOneWidget);
        await tester.tap(find.byKey(const Key('rebase-confirm')));
      }
      await pumpUntil(
        tester,
        () => container.read(expeditionsProvider).firstOrNull?.status == ExpeditionStatus.succeeded,
      );
      await settleGit(tester, fixture);
      await pumpUntil(
        tester,
        () =>
            !container.read(repoStatusProvider(fixture.repo.id)).isLoading &&
            (mode != 'conflicted merge' ||
                container.read(repoStatusProvider(fixture.repo.id)).value?.conflictCount == 1),
      );
      final status = container.read(repoStatusProvider(fixture.repo.id)).value!;
      if (mode == 'conflicted merge') {
        expect(status.conflictCount, 1);
        expect(find.text('Conflicts found. Resolve them in Changed files.'), findsOneWidget);
      } else {
        expect(status.inProgress, isNull);
        expect(status.currentBranch, 'main');
        final content = await tester.runAsync(() => fixture.repos.run(fixture.repo.path, ['show', 'HEAD:file.txt']));
        expect(content!.stdout, mode == 'already current' ? 'base\n' : 'incoming\n');
      }
      if (mode == 'already current') expect(find.text('Already up to date'), findsOneWidget);
      await pumpUntil(tester, () => !container.read(branchListProvider(fixture.repo)).isLoading);
      await settleGit(tester, fixture);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('create normalizes spaces, duplicate error, rename, switch and delete', (tester) async {
    final container = await open(tester);
    await tester.tap(find.byKey(const Key('branch-create')));
    await settleGit(tester, fixture);
    await tester.enterText(find.byKey(const Key('branch-name')), 'new work');
    expect(tester.widget<TextField>(find.byKey(const Key('branch-name'))).controller!.text, 'new-work');
    await tester.tap(find.byKey(const Key('branch-save')));
    await pumpUntil(
      tester,
      () =>
          find.byKey(const ValueKey('branch-local-new-work')).evaluate().isNotEmpty &&
          find.byKey(const Key('branch-name')).evaluate().isEmpty,
    );
    expect(container.read(expeditionsProvider).first.status, ExpeditionStatus.succeeded);
    expect(container.read(expeditionsProvider).first.progress, 1);
    await tester.tap(find.byKey(const Key('branch-create')));
    await settleGit(tester, fixture);
    await tester.enterText(find.byKey(const Key('branch-name')), 'main');
    await tester.tap(find.byKey(const Key('branch-save')));
    await pumpUntil(tester, () => find.textContaining('This name already exists').evaluate().isNotEmpty);
    await tester.tap(find.text('Cancel'));
    await settleGit(tester, fixture);

    await tester.tap(find.byKey(const ValueKey('branch-menu-new-work')));
    await settleGit(tester, fixture);
    final delete = tester.widget<PopupMenuItem<String>>(find.widgetWithText(PopupMenuItem<String>, 'Delete'));
    expect(delete.enabled, isFalse);
    await tester.tap(find.text('Rename'));
    await settleGit(tester, fixture);
    await tester.enterText(find.byKey(const Key('branch-name')), 'renamed');
    await tester.tap(find.byKey(const Key('branch-save')));
    await pumpUntil(
      tester,
      () =>
          find.byKey(const ValueKey('branch-local-renamed')).evaluate().isNotEmpty &&
          find.byKey(const Key('branch-name')).evaluate().isEmpty,
    );
    await tester.tap(find.byKey(const ValueKey('branch-local-main')));
    await pumpUntil(tester, () => find.byKey(const Key('branch-search')).evaluate().isEmpty);
    await tester.tap(find.text('Open branches'));
    await pumpUntil(tester, () => find.byKey(const ValueKey('branch-local-renamed')).evaluate().isNotEmpty);
    await settleGit(tester, fixture);
    await tester.tap(find.byKey(const ValueKey('branch-menu-renamed')));
    await settleGit(tester, fixture);
    await tester.tap(find.text('Delete'));
    await pumpUntil(tester, () => find.byKey(const Key('branch-confirm-delete')).evaluate().isNotEmpty);
    await settleGit(tester, fixture);
    await tester.tap(find.byKey(const Key('branch-confirm-delete')));
    await pumpUntil(
      tester,
      () =>
          !container.read(branchListProvider(fixture.repo)).isLoading &&
          container.read(branchListProvider(fixture.repo)).value?.any((b) => b.name == 'renamed') == false,
    );
    final branches = await tester.runAsync(() => getBranches(fixture.repos.git, fixture.repo.path));
    expect(branches!.map((b) => b.name), ['main']);
    expect(container.read(repoStatusProvider(fixture.repo.id)).value?.currentBranch, 'main');
    expect(tester.takeException(), isNull);
  });

  testWidgets('dirty checkout warns; Git refusal stays on current branch and shows error', (tester) async {
    await tester.runAsync(() async {
      await fixture.repos.run(fixture.repo.path, ['switch', '-c', 'other']);
      await fixture.repos.commit(fixture.repo.path, 'other version', files: {'file.txt': 'other\n'});
      await fixture.repos.run(fixture.repo.path, ['switch', 'main']);
      await fixture.repos.write(fixture.repo.path, 'file.txt', 'local changes\n');
    });
    final container = await open(tester);
    await tester.tap(find.byKey(const ValueKey('branch-local-other')));
    await pumpUntil(tester, () => find.byKey(const Key('branch-confirm-switch')).evaluate().isNotEmpty);
    await pumpUntil(tester, () => !container.read(branchListProvider(fixture.repo)).isLoading);
    await settleGit(tester, fixture);
    await tester.tap(find.byKey(const Key('branch-confirm-switch')));
    await pumpUntil(tester, () => container.read(expeditionsProvider).firstOrNull?.status == ExpeditionStatus.failed);
    await pumpUntil(tester, () => !container.read(branchListProvider(fixture.repo)).isLoading);
    await settleGit(tester, fixture);
    expect(find.text('Could not complete the operation'), findsOneWidget);
    await pumpUntil(tester, () => container.read(repoStatusProvider(fixture.repo.id)).value?.currentBranch == 'main');
    expect(tester.takeException(), isNull);
  });

  testWidgets('checked remote deletion removes the branch on the real remote', (tester) async {
    await tester.runAsync(() async {
      final remote = await fixture.repos.init('remote', bare: true);
      await fixture.repos.run(fixture.repo.path, ['remote', 'add', 'origin', remote]);
      await fixture.repos.run(fixture.repo.path, ['push', 'origin', 'main:refs/heads/remove-me']);
      await fixture.repos.run(fixture.repo.path, ['fetch', 'origin']);
    });
    final container = await open(tester);
    await tester.tap(find.byKey(const ValueKey('branch-menu-origin/remove-me')));
    await settleGit(tester, fixture);
    await tester.tap(find.text('Delete'));
    await pumpUntil(tester, () => find.byKey(const Key('branch-confirm-delete')).evaluate().isNotEmpty);
    await settleGit(tester, fixture);
    await tester.tap(find.byKey(const Key('branch-delete-remote')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('branch-confirm-delete')));
    await settleGit(tester, fixture);
    expect(container.read(expeditionsProvider).first.status, ExpeditionStatus.succeeded);
    final remoteRefs = await tester.runAsync(
      () => fixture.repos.run(fixture.repo.path, ['ls-remote', '--heads', 'origin', 'refs/heads/remove-me']),
    );
    expect(remoteRefs!.stdout.trim(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmerged delete requires force; remote tracking deletion is opt-in', (tester) async {
    await tester.runAsync(() async {
      await fixture.repos.run(fixture.repo.path, ['switch', '-c', 'unmerged']);
      await fixture.repos.commit(fixture.repo.path, 'unmerged work');
      await fixture.repos.run(fixture.repo.path, ['switch', 'main']);
      await fixture.repos.run(fixture.repo.path, ['remote', 'add', 'origin', fixture.repo.path]);
      await fixture.repos.run(fixture.repo.path, ['update-ref', 'refs/remotes/origin/sample', 'HEAD']);
    });
    final container = await open(tester);
    await tester.tap(find.byKey(const ValueKey('branch-menu-unmerged')));
    await settleGit(tester, fixture);
    await tester.tap(find.text('Delete'));
    await pumpUntil(tester, () => find.byKey(const Key('branch-confirm-delete')).evaluate().isNotEmpty);
    await settleGit(tester, fixture);
    await tester.tap(find.byKey(const Key('branch-confirm-delete')));
    await pumpUntil(tester, () => container.read(expeditionsProvider).firstOrNull?.status == ExpeditionStatus.failed);
    await settleGit(tester, fixture);
    await tester.tap(find.byKey(const ValueKey('branch-menu-unmerged')));
    await settleGit(tester, fixture);
    await tester.tap(find.text('Delete'));
    await pumpUntil(tester, () => find.byKey(const Key('branch-confirm-delete')).evaluate().isNotEmpty);
    await settleGit(tester, fixture);
    await tester.tap(find.byKey(const Key('branch-force')));
    await tester.tap(find.byKey(const Key('branch-confirm-delete')));
    await pumpUntil(
      tester,
      () => container.read(branchListProvider(fixture.repo)).value?.any((b) => b.name == 'unmerged') == false,
    );
    await settleGit(tester, fixture);
    await tester.tap(find.byKey(const ValueKey('branch-menu-origin/sample')));
    await settleGit(tester, fixture);
    await tester.tap(find.text('Delete'));
    await pumpUntil(tester, () => find.byKey(const Key('branch-confirm-delete')).evaluate().isNotEmpty);
    await settleGit(tester, fixture);
    final checkbox = tester.widget<CheckboxListTile>(find.byKey(const Key('branch-delete-remote')));
    expect(checkbox.value, isFalse);
    await tester.tap(find.byKey(const Key('branch-confirm-delete')));
    await pumpUntil(
      tester,
      () => container.read(branchListProvider(fixture.repo)).value?.any((b) => b.type == BranchType.remote) == false,
    );
    expect(tester.takeException(), isNull);
  });
}
