// Ported from GitHub Desktop (MIT): app/test/unit/git/{merge,cherry-pick,revert}-test.ts (via GitHub+ v1 tests/main/git/advanced/advanced.test.ts)
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/git/git_runner.dart';
import 'package:github_plus/core/git/merge.dart';
import 'package:github_plus/core/git/operation.dart';
import 'package:github_plus/core/git/in_progress.dart';
import 'package:github_plus/core/git/status.dart';
import 'package:github_plus/core/models/advanced.dart';
import 'helpers.dart';

void main() {
  late TestRepos repos;
  late String repo;
  setUp(() async {
    repos = await TestRepos.create();
    repo = await repos.init('repo');
    repos.git.registerAuthProvider(
      (_, _) => const GitAuthExtras(configArgs: [...TestRepos.identity, '-c', 'commit.gpgsign=false']),
    );
  });
  tearDown(() => repos.dispose());

  Future<String> head() async => (await repos.run(repo, ['rev-parse', 'HEAD'])).stdout.trim();
  Future<String> read(String path) => File('$repo/$path').readAsString();
  Future<void> switchBranch(String name, {bool create = false}) async {
    await repos.run(repo, ['switch', if (create) '-c', name]);
  }

  Future<String> conflictRepo({bool deleteOurs = false, bool deleteTheirs = false}) async {
    await repos.commit(repo, 'base', files: {'text': 'base\n', 'binary': 'base\x00bytes'});
    await switchBranch('topic', create: true);
    if (deleteTheirs) await repos.run(repo, ['rm', '--', 'text']);
    await repos.commit(repo, 'theirs', files: {if (!deleteTheirs) 'text': 'theirs\n', 'binary': 'theirs\x00bytes'});
    await switchBranch('main');
    if (deleteOurs) await repos.run(repo, ['rm', '--', 'text']);
    return repos.commit(repo, 'ours', files: {if (!deleteOurs) 'text': 'ours\n', 'binary': 'ours\x00bytes'});
  }

  test('fast-forward, already current, and squash without a commit', () async {
    final base = await repos.commit(repo, 'base');
    await switchBranch('topic', create: true);
    final tip = await repos.commit(repo, 'topic', files: {'new': 'topic\n'});
    await switchBranch('main');
    expect(await merge(repos.git, repo, 'topic', squash: true), OperationOutcome.completed);
    expect(await head(), base);
    await repos.run(repo, ['restore', '--staged', '--worktree', '--', 'new']);
    expect(await merge(repos.git, repo, 'topic'), OperationOutcome.completed);
    expect(await head(), tip);
    expect(await merge(repos.git, repo, 'topic'), OperationOutcome.nothingToDo);
  });

  test('ordinary diverged merge creates a two-parent commit without an editor', () async {
    await repos.commit(repo, 'base');
    await switchBranch('topic', create: true);
    await repos.commit(repo, 'topic', files: {'topic': 'x'});
    await switchBranch('main');
    await repos.commit(repo, 'main', files: {'main': 'x'});
    expect(await merge(repos.git, repo, 'topic'), OperationOutcome.completed);
    expect(
      (await repos.run(repo, ['rev-list', '--parents', '-n', '1', 'HEAD'])).stdout.trim().split(' '),
      hasLength(3),
    );
  });

  for (final custom in [false, true]) {
    test('text and binary sides resolve and continue merge (custom message: $custom)', () async {
      await conflictRepo();
      expect(await merge(repos.git, repo, 'topic'), OperationOutcome.conflicts);
      await expectLater(continueOperation(repos.git, repo), throwsStateError);
      await resolveConflictWithSide(repos.git, repo, 'text', ConflictSide.theirs);
      await resolveConflictWithSide(repos.git, repo, 'binary', ConflictSide.ours);
      expect(await read('text'), 'theirs\n');
      expect(await read('binary'), 'ours\x00bytes');
      const message = 'resolved merge\n\nbody with --options';
      expect(await continueOperation(repos.git, repo, message: custom ? message : null), OperationOutcome.completed);
      expect(await getInProgress(repos.git, repo), isNull);
      final actual = (await repos.run(repo, ['log', '-1', '--format=%B'])).stdout.trim();
      expect(actual, custom ? message : contains('Merge'));
    });
  }

  for (final deleteOurs in [false, true]) {
    for (final side in ConflictSide.values) {
      test('modify/delete resolves deleted ours=$deleteOurs, side=${side.name}, then aborts', () async {
        final original = await conflictRepo(deleteOurs: deleteOurs, deleteTheirs: !deleteOurs);
        expect(await merge(repos.git, repo, 'topic'), OperationOutcome.conflicts);
        await resolveConflictWithSide(repos.git, repo, 'text', side);
        final deleted = deleteOurs == (side == ConflictSide.ours);
        expect(await File('$repo/text').exists(), !deleted);
        if (!deleted) expect(await read('text'), side == ConflictSide.ours ? 'ours\n' : 'theirs\n');
        await abortOperation(repos.git, repo);
        expect(await head(), original);
        expect((await getStatus(repos.git, repo)).files, isEmpty);
        expect(await continueOperation(repos.git, repo), OperationOutcome.nothingToDo);
        await abortOperation(repos.git, repo);
      });
    }
  }

  test('markResolved stages manual edits, retained markers, literal and deleted paths', () async {
    await repos.commit(repo, 'base', files: {'text': 'base\n', '[a]': 'literal', 'a': 'other'});
    await switchBranch('topic', create: true);
    await repos.commit(repo, 'topic', files: {'text': 'theirs\n'});
    await switchBranch('main');
    await repos.commit(repo, 'ours', files: {'text': 'ours\n'});
    await merge(repos.git, repo, 'topic');
    await repos.write(repo, '[a]', 'changed');
    await repos.write(repo, 'a', 'unstaged');
    await markResolved(repos.git, repo, ['text', '[a]']);
    expect(await read('text'), contains('<<<<<<<'));
    expect((await repos.run(repo, ['diff', '--cached', '--name-only'])).stdout.trim().split('\n'), ['[a]', 'text']);
    await File('$repo/text').delete();
    await markResolved(repos.git, repo, ['text']);
    expect(await continueOperation(repos.git, repo), OperationOutcome.completed);
  });

  test('multiple cherry-picks stop in the middle and continue through remaining commits', () async {
    await repos.commit(repo, 'base', files: {'text': 'base\n'});
    await switchBranch('topic', create: true);
    final first = await repos.commit(repo, 'first', files: {'first': '1'});
    final second = await repos.commit(repo, 'second', files: {'text': 'theirs\n'});
    final third = await repos.commit(repo, 'third', files: {'third': '3'});
    await switchBranch('main');
    await repos.commit(repo, 'ours', files: {'text': 'ours\n'});
    expect(await cherryPick(repos.git, repo, [first, second, third]), OperationOutcome.conflicts);
    expect(await read('first'), '1');
    await resolveConflictWithSide(repos.git, repo, 'text', ConflictSide.theirs);
    expect(await continueOperation(repos.git, repo), OperationOutcome.completed);
    expect(await read('third'), '3');
    expect(await getInProgress(repos.git, repo), isNull);
    expect(await cherryPick(repos.git, repo, []), OperationOutcome.nothingToDo);
  });

  test('revert normal and merge commits using first parent; rejects cherry-pick merges', () async {
    await repos.commit(repo, 'base');
    final normal = await repos.commit(repo, 'normal', files: {'normal': 'n'});
    expect(await revert(repos.git, repo, normal), OperationOutcome.completed);
    expect(await File('$repo/normal').exists(), isFalse);
    await switchBranch('topic', create: true);
    await repos.commit(repo, 'topic', files: {'topic': 't'});
    await switchBranch('main');
    await repos.run(repo, ['merge', '--no-ff', '--no-edit', '--', 'topic']);
    await expectLater(cherryPick(repos.git, repo, ['HEAD']), throwsArgumentError);
    expect(await revert(repos.git, repo, 'HEAD'), OperationOutcome.completed);
    expect(await File('$repo/topic').exists(), isFalse);
  });

  test('conflicting revert aborts, then resolves and continues', () async {
    await repos.commit(repo, 'base', files: {'text': 'base\n'});
    final change = await repos.commit(repo, 'change', files: {'text': 'changed\n'});
    final original = await repos.commit(repo, 'later', files: {'text': 'later\n'});
    expect(await revert(repos.git, repo, change), OperationOutcome.conflicts);
    await abortOperation(repos.git, repo);
    expect(await head(), original);
    expect(await revert(repos.git, repo, change), OperationOutcome.conflicts);
    await resolveConflictWithSide(repos.git, repo, 'text', ConflictSide.theirs);
    expect(await continueOperation(repos.git, repo), OperationOutcome.completed);
    expect(await read('text'), 'base\n');
  });

  test('rebase continuation can stop again, then complete; abort restores branch', () async {
    await repos.commit(repo, 'base', files: {'one': 'base\n', 'two': 'base\n'});
    await switchBranch('topic', create: true);
    await repos.commit(repo, 'topic', files: {'one': 'topic\n', 'two': 'topic\n'});
    await switchBranch('main');
    await repos.commit(repo, 'one', files: {'one': 'main\n'});
    final original = await repos.commit(repo, 'two', files: {'two': 'main\n'});
    expect(await runOperation(repos.git, repo, ['rebase', '--', 'topic']), OperationOutcome.conflicts);
    await abortOperation(repos.git, repo);
    expect(await head(), original);
    expect(await runOperation(repos.git, repo, ['rebase', '--', 'topic']), OperationOutcome.conflicts);
    await resolveConflictWithSide(repos.git, repo, 'one', ConflictSide.theirs);
    expect(await continueOperation(repos.git, repo), OperationOutcome.conflicts);
    await resolveConflictWithSide(repos.git, repo, 'two', ConflictSide.theirs);
    expect(await continueOperation(repos.git, repo), OperationOutcome.completed);
    expect(await getInProgress(repos.git, repo), isNull);
  });

  test('rejects unsafe refs and paths before changing repository', () async {
    await repos.commit(repo, 'base', files: {'text': 'base'});
    for (final ref in ['', '--abort', '-m', 'HEAD\x00']) {
      await expectLater(merge(repos.git, repo, ref), throwsArgumentError);
      await expectLater(cherryPick(repos.git, repo, [ref]), throwsArgumentError);
      await expectLater(revert(repos.git, repo, ref), throwsArgumentError);
    }
    for (final path in ['../outside', '.git/config', 'C:/outside', 'text\x00']) {
      await expectLater(markResolved(repos.git, repo, [path]), throwsArgumentError);
      await expectLater(resolveConflictWithSide(repos.git, repo, path, ConflictSide.ours), throwsArgumentError);
    }
    await expectLater(resolveConflictWithSide(repos.git, repo, 'text', ConflictSide.ours), throwsStateError);
    await expectLater(merge(repos.git, repo, 'missing'), throwsA(isA<GitException>()));
    await markResolved(repos.git, repo, []);
  });
}
