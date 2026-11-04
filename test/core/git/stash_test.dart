// Ported from GitHub Desktop (MIT): app/test/unit/git/stash-test.ts
// (via GitHub+ v1 tests/main/git/advanced/advanced.test.ts)
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/git/stash.dart';
import 'package:github_plus/core/git/status.dart';
import 'package:github_plus/core/models/advanced.dart';
import 'package:github_plus/core/models/commit.dart';
import 'package:github_plus/core/models/diff.dart';
import 'package:github_plus/core/models/status.dart';
import 'helpers.dart';

void main() {
  late TestRepos repos;
  late String repo;
  setUp(() async {
    repos = await TestRepos.create();
    repo = await repos.init('stash');
    await repos.commit(repo, 'base', files: {'tracked': 'base\n'});
  });
  tearDown(() => repos.dispose());

  test('lists metadata and reads tracked and third-parent untracked diffs, applies and drops', () async {
    expect(await stashList(repos.git, repo), isEmpty);
    expect(await stashCreate(repos.git, repo), OperationOutcome.nothingToDo);
    await repos.write(repo, 'tracked', 'stashed\n');
    await repos.write(repo, '새 파일 [1].txt', 'untracked stash\n');
    expect(await stashCreate(repos.git, repo, message: 'custom message'), OperationOutcome.completed);
    final entry = (await stashList(repos.git, repo)).single;
    expect(entry.name, 'stash@{0}');
    expect(entry.branchName, 'main');
    expect(entry.message, 'On main: custom message');
    expect(entry.createdAt.difference(DateTime.now()).inSeconds.abs(), lessThan(30));
    final files = await stashFiles(repos.git, repo, entry.sha);
    expect(files.map((f) => f.path), unorderedEquals(['tracked', '새 파일 [1].txt']));
    for (final file in files) {
      final diff = await stashDiff(repos.git, repo, entry.name, file) as TextDiff;
      expect(diff.text, contains(file.path == 'tracked' ? '+stashed' : '+untracked stash'));
    }
    await expectLater(
      stashDiff(
        repos.git,
        repo,
        entry.name,
        const CommittedFile(
          path: '../escape',
          status: FileStatus(kind: FileStatusKind.added),
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      stashDiff(
        repos.git,
        repo,
        entry.name,
        const CommittedFile(
          path: 'missing',
          status: FileStatus(kind: FileStatusKind.added),
        ),
      ),
      throwsArgumentError,
    );
    expect(await stashApply(repos.git, repo, entry.sha), OperationOutcome.completed);
    expect(await stashList(repos.git, repo), hasLength(1));
    await stashDrop(repos.git, repo, entry.sha);
    expect(await stashList(repos.git, repo), isEmpty);
    await repos.run(repo, ['stash', 'push', '-u', '-m', 'external']);
    expect((await stashList(repos.git, repo)).single.message, contains('external'));
    expect(await stashApply(repos.git, repo, 'stash@{0}', pop: true), OperationOutcome.completed);
    expect(await stashList(repos.git, repo), isEmpty);
  });

  test('excludes untracked files and does not create an empty stash', () async {
    await repos.write(repo, 'new', 'new\n');
    expect(await stashCreate(repos.git, repo, includeUntracked: false), OperationOutcome.nothingToDo);
    await repos.write(repo, 'tracked', 'changed\n');
    expect(await stashCreate(repos.git, repo, includeUntracked: false), OperationOutcome.completed);
    expect((await stashFiles(repos.git, repo, 'stash@{0}')).map((f) => f.path), ['tracked']);
    expect((await getStatus(repos.git, repo)).files.single.path, 'new');
  });

  for (final pop in [false, true]) {
    test('conflicting ${pop ? 'pop' : 'apply'} retains the stash', () async {
      await repos.write(repo, 'tracked', 'stash\n');
      await stashCreate(repos.git, repo);
      await repos.commit(repo, 'head', files: {'tracked': 'head\n'});
      expect(await stashApply(repos.git, repo, 'stash@{0}', pop: pop), OperationOutcome.conflicts);
      expect(await stashList(repos.git, repo), hasLength(1));
      expect((await getStatus(repos.git, repo)).files.single.status.isConflicted, isTrue);
    });
  }

  test('rejects option-like and unknown stash names', () async {
    for (final name in ['--all', '', 'missing']) {
      await expectLater(stashApply(repos.git, repo, name), throwsArgumentError);
      await expectLater(stashDrop(repos.git, repo, name), throwsArgumentError);
      await expectLater(stashFiles(repos.git, repo, name), throwsArgumentError);
    }
  });
}
