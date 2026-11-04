import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/git/git_runner.dart';
import 'package:github_plus/core/git/operation.dart';
import 'package:github_plus/core/git/in_progress.dart';
import 'package:github_plus/core/models/advanced.dart';
import 'helpers.dart';
import 'package:github_plus/core/git/git_errors.dart';

class FailingGit extends GitRunner {
  FailingGit(this.failure) : super(executable: 'unused');
  final GitException failure;
  @override
  Future<GitResult> run(
    List<String> args, {
    required String cwd,
    Set<int> successExitCodes = const {0},
    Set<GitError> expectedErrors = const {},
    String? stdin,
    List<int>? stdinBytes,
    Map<String, String> environment = const {},
    void Function(String)? onStderrLine,
  }) async => throw failure;
}

void main() {
  test('failure with unmerged index entries and no in-progress marker is conflicts', () async {
    final repos = await TestRepos.create();
    addTearDown(repos.dispose);
    final repo = await repos.init('repo');
    await repos.commit(repo, 'base');
    final blob = (await repos.git.run(['hash-object', '-w', '--stdin'], cwd: repo, stdin: 'content')).stdout.trim();
    await repos.git.run(
      ['update-index', '--index-info'],
      cwd: repo,
      stdin: '100644 $blob 2\tconflict\n100644 $blob 3\tconflict\n',
    );
    expect(await getInProgress(repos.git, repo), isNull);
    expect(await runOperation(repos.git, repo, ['not-a-command']), OperationOutcome.conflicts);
  });

  test('failure with an in-progress operation and a resolved index is conflicts', () async {
    final repos = await TestRepos.create();
    addTearDown(repos.dispose);
    final repo = await repos.init('repo');
    await repos.commit(repo, 'base');
    await repos.run(repo, ['switch', '-c', 'topic']);
    await repos.commit(repo, 'topic', files: {'topic': 't'});
    await repos.run(repo, ['switch', 'main']);
    await repos.run(repo, ['merge', '--no-ff', '--no-commit', '--', 'topic']);
    expect(await getInProgress(repos.git, repo), isNotNull);
    expect(await runOperation(repos.git, repo, ['not-a-command']), OperationOutcome.conflicts);
  });

  test('failed diagnostics retain the original GitException instance', () async {
    final failure = GitException([
      'merge',
    ], const GitResult(exitCode: 128, stdout: '', stderr: 'original', error: null));
    await expectLater(runOperation(FailingGit(failure), '.', ['merge']), throwsA(same(failure)));
  });
  test('empty commit is nothingToDo and unrelated failure remains GitException', () async {
    final repos = await TestRepos.create();
    addTearDown(repos.dispose);
    final repo = await repos.init('repo');
    await repos.commit(repo, 'base');
    expect(await runOperation(repos.git, repo, ['commit', '--no-edit']), OperationOutcome.nothingToDo);
    await expectLater(runOperation(repos.git, repo, ['not-a-command']), throwsA(isA<GitException>()));
  });
}
