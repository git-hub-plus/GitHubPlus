// Ported from GitHub Desktop (MIT): app/test/unit/git/{reset,tag,rebase,squash,reorder}-test.ts
// (via GitHub+ v1 tests/main/git/advanced/advanced.test.ts)
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/git/git_runner.dart';
import 'package:github_plus/core/git/in_progress.dart';
import 'package:github_plus/core/git/rewrite.dart';
import 'package:github_plus/core/git/status.dart';
import 'package:github_plus/core/models/advanced.dart';
import 'helpers.dart';

void main() {
  late TestRepos repos;
  late String repo;
  setUp(() async {
    repos = await TestRepos.create();
    repo = await repos.init('rewrite');
  });
  tearDown(() => repos.dispose());
  Future<String> run(List<String> args) async => (await repos.run(repo, args)).stdout.trim();
  Future<List<String>> history(int count) async {
    final shas = <String>[];
    for (var i = 0; i < count; i++) {
      shas.add(await repos.commit(repo, '$i', files: {'file$i': '$i\n'}));
    }
    return shas;
  }

  Future<void> divergent({bool conflict = false}) async {
    await repos.commit(repo, 'base', files: {'text': 'base\n'});
    await repos.run(repo, ['switch', '-c', 'topic']);
    await repos.commit(repo, 'topic', files: {conflict ? 'text' : 'topic': 'topic\n'});
    await repos.run(repo, ['switch', 'main']);
    await repos.commit(repo, 'main', files: {conflict ? 'text' : 'main': 'main\n'});
  }

  test('rejects history selections on an unborn branch', () async {
    await expectLater(squash(repos.git, repo, [], 'message'), throwsArgumentError);
    await expectLater(squash(repos.git, repo, ['--all', 'HEAD'], 'message'), throwsArgumentError);
    await expectLater(reorder(repos.git, repo, '--all'), throwsArgumentError);
    await expectLater(reorder(repos.git, repo, 'HEAD'), throwsArgumentError);
  });

  test('undoes root and regular commits, keeps staged changes and returns summary/body', () async {
    await expectLater(undoLastCommit(repos.git, repo), throwsStateError);
    await repos.commit(repo, 'first\n\nbody', files: {'first': 'first'});
    expect(await undoLastCommit(repos.git, repo), (summary: 'first', description: 'body'));
    expect((await getStatus(repos.git, repo)).headSha, isNull);
    expect(await run(['diff', '--cached', '--name-only']), 'first');
    final first = await repos.commit(repo, 'first');
    await repos.commit(repo, 'second\n\nsecond body', files: {'second': 'second'});
    expect(await undoLastCommit(repos.git, repo), (summary: 'second', description: 'second body'));
    expect(await run(['rev-parse', 'HEAD']), first);
    expect(await run(['diff', '--cached', '--name-only']), 'second');
    await repos.run(repo, ['update-ref', 'refs/remotes/origin/main', first]);
    await expectLater(undoLastCommit(repos.git, repo), throwsStateError);
  });

  test('tags lightweight/annotated objects, peels targets, pushes and deletes on bare remote', () async {
    final sha = (await history(1)).single;
    expect(await getTags(repos.git, repo), isEmpty);
    await createTag(repos.git, repo, 'light', sha);
    await createTag(repos.git, repo, 'annotated', sha, message: 'release body');
    expect(await run(['cat-file', '-t', 'light']), 'commit');
    expect(await run(['cat-file', '-t', 'annotated']), 'tag');
    final tags = await getTags(repos.git, repo);
    expect(tags.map((t) => t.name), ['annotated', 'light']);
    expect(tags.map((t) => t.targetSha), [sha, sha]);
    final remote = await repos.init('remote.git', bare: true);
    await repos.run(repo, ['remote', 'add', 'origin', remote]);
    await pushTag(repos.git, repo, 'annotated');
    expect((await repos.run(remote, ['rev-parse', 'refs/tags/annotated^{}'])).stdout.trim(), sha);
    await deleteTag(repos.git, repo, 'annotated', remote: 'origin');
    expect((await repos.git.run(['show-ref', '--tags'], cwd: remote, successExitCodes: {0, 1})).stdout, isEmpty);
    await deleteTag(repos.git, repo, 'light');
    expect(await getTags(repos.git, repo), isEmpty);
    for (final name in ['--force', '', 'bad name', 'x..y', 'x@{y']) {
      await expectLater(createTag(repos.git, repo, name, sha), throwsArgumentError);
      await expectLater(deleteTag(repos.git, repo, name), throwsArgumentError);
      await expectLater(pushTag(repos.git, repo, name), throwsArgumentError);
    }
    await expectLater(createTag(repos.git, repo, 'safe', '--all'), throwsArgumentError);
  });

  test('rejected remote deletion preserves local tag and unexpected errors propagate', () async {
    final sha = (await history(1)).single;
    await createTag(repos.git, repo, 'keep', sha);
    await expectLater(deleteTag(repos.git, repo, 'keep', remote: 'missing'), throwsA(isA<GitException>()));
    expect((await getTags(repos.git, repo)).single.name, 'keep');
  });

  test('rebases diverged history and reports no-op and fast-forward', () async {
    await divergent();
    final onto = await run(['rev-parse', 'topic']);
    expect(await rebase(repos.git, repo, 'topic'), OperationOutcome.completed);
    expect(await run(['rev-parse', 'HEAD^']), onto);
    expect(await rebase(repos.git, repo, 'topic'), OperationOutcome.nothingToDo);
    await repos.run(repo, ['switch', 'topic']);
    expect(await rebase(repos.git, repo, 'main'), OperationOutcome.completed);
    expect(await run(['rev-parse', 'HEAD']), await run(['rev-parse', 'main']));
    await expectLater(rebase(repos.git, repo, '--all'), throwsArgumentError);
  });

  test('rebase conflicts expose operation state and block undo and rewrites', () async {
    await divergent(conflict: true);
    expect(await rebase(repos.git, repo, 'topic'), OperationOutcome.conflicts);
    expect(await getInProgress(repos.git, repo), isNotNull);
    await expectLater(undoLastCommit(repos.git, repo), throwsStateError);
    await expectLater(rebase(repos.git, repo, 'topic'), throwsStateError);
    await expectLater(squash(repos.git, repo, ['HEAD', 'HEAD^'], 'message'), throwsStateError);
    await expectLater(reorder(repos.git, repo, 'HEAD'), throwsStateError);
  });

  for (final noncontiguous in [false, true]) {
    test('squashes ${noncontiguous ? 'noncontiguous' : 'contiguous root'} three commits with message', () async {
      final shas = await history(noncontiguous ? 5 : 3);
      final selected = noncontiguous ? [shas[4], shas[0], shas[2]] : shas.reversed.toList();
      final beforeTree = await run(['rev-parse', 'HEAD^{tree}']);
      expect(await squash(repos.git, repo, selected, 'combined\n\ncombined body'), OperationOutcome.completed);
      expect(await run(['rev-list', '--count', 'HEAD']), noncontiguous ? '3' : '1');
      expect(await run(['log', '--reverse', '--format=%s']), noncontiguous ? 'combined\n1\n3' : 'combined');
      expect(await run(['log', '-1', '--format=%B', noncontiguous ? 'HEAD~2' : 'HEAD']), 'combined\n\ncombined body');
      expect(await run(['rev-parse', 'HEAD^{tree}']), beforeTree);
      expect((await getStatus(repos.git, repo)).files, isEmpty);
    });
  }

  test('squash message survives fixup and later pick conflicts after temporary editor cleanup', () async {
    await repos.commit(repo, 'base', files: {'text': 'base\n'});
    final a = await repos.commit(repo, 'a', files: {'a': 'a'});
    await repos.commit(repo, 'b', files: {'text': 'b\n'});
    final c = await repos.commit(repo, 'c', files: {'text': 'c\n'});
    expect(await squash(repos.git, repo, [a, c], 'combined\n\nbody'), OperationOutcome.conflicts);
    for (var attempt = 0; attempt < 2; attempt++) {
      await repos.write(repo, 'text', 'resolved $attempt\n');
      await repos.run(repo, ['add', '--', 'text']);
      final result = await repos.git.run(
        ['rebase', '--continue'],
        cwd: repo,
        environment: {'GIT_EDITOR': 'true'},
        successExitCodes: {0, 1},
      );
      expect(result.exitCode, attempt == 0 ? 1 : 0);
    }
    expect(await run(['log', '--reverse', '--format=%s']), 'base\ncombined\nb');
    expect(await run(['log', '-1', '--format=%B', 'HEAD^']), 'combined\n\nbody');
  });

  test('reorders forwards, backwards to root and detects unchanged order', () async {
    final shas = await history(4);
    expect(await reorder(repos.git, repo, shas[1], afterSha: shas[3]), OperationOutcome.completed);
    expect(await run(['log', '--reverse', '--format=%s']), '0\n2\n3\n1');
    expect(await reorder(repos.git, repo, 'HEAD'), OperationOutcome.completed);
    expect(await run(['log', '--reverse', '--format=%s']), '1\n0\n2\n3');
    expect(await reorder(repos.git, repo, 'HEAD', afterSha: 'HEAD^'), OperationOutcome.nothingToDo);
    await expectLater(reorder(repos.git, repo, 'HEAD', afterSha: 'HEAD'), throwsArgumentError);
  });

  test('rejects invalid, duplicate and non-HEAD selections and merge ranges', () async {
    final shas = await history(3);
    await repos.run(repo, ['switch', '-c', 'other']);
    final outside = await repos.commit(repo, 'outside', files: {'other': 'other'});
    await repos.run(repo, ['switch', 'main']);
    for (final selected in [
      <String>[],
      [shas[0]],
      [shas[0], shas[0]],
      [shas[0], outside],
      ['-bad', shas[0]],
    ]) {
      await expectLater(squash(repos.git, repo, selected, 'message'), throwsArgumentError);
    }
    await expectLater(squash(repos.git, repo, shas, ' '), throwsArgumentError);
    await expectLater(reorder(repos.git, repo, outside), throwsArgumentError);
    await expectLater(reorder(repos.git, repo, shas[0], afterSha: outside), throwsArgumentError);
    await repos.run(repo, ['merge', '--no-ff', '-m', 'merge', 'other']);
    await expectLater(squash(repos.git, repo, ['HEAD', 'HEAD^'], 'message'), throwsStateError);
    await expectLater(reorder(repos.git, repo, 'HEAD'), throwsStateError);
    await expectLater(rebase(repos.git, repo, shas[0]), throwsStateError);
    expect(await Directory('${await gitDirectory(repos.git, repo)}/rebase-merge').exists(), isFalse);
  });
}
