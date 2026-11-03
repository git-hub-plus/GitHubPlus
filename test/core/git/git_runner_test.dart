import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/git/git_errors.dart';
import 'package:github_plus/core/git/git_runner.dart';

void main() {
  late Directory dir;
  late GitRunner git;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ghp-runner-');
    git = GitRunner(executable: GitRunner.locateExecutable());
  });
  tearDown(() => dir.delete(recursive: true));

  test('uses the vendored portable git during development', () {
    expect(git.executable, endsWith(r'cmd\git.exe'));
  });

  test('applies provider config but never exposes it in errors', () async {
    const secret = 'http.extraHeader=AUTHORIZATION: basic c2VjcmV0LXRva2Vu';
    git.registerAuthProvider((args, cwd) => const GitAuthExtras(configArgs: ['-c', secret]));

    final shown = await git.run(
      ['config', '--get', 'http.extraHeader'],
      cwd: dir.path,
      successExitCodes: {0, 1},
    );
    expect(shown.stdout.trim(), 'AUTHORIZATION: basic c2VjcmV0LXRva2Vu');

    final failure = await git
        .run(['rev-parse', 'no-such-ref'], cwd: dir.path)
        .then<Object?>((_) => null, onError: (Object e) => e);
    expect(failure, isA<GitException>());
    expect(failure.toString(), isNot(contains('c2VjcmV0')));
    expect((failure as GitException).args, isNot(contains(secret)));
  });

  test('classifies errors and honours expected errors', () async {
    final failure = await git
        .run(['status'], cwd: dir.path)
        .then<Object?>((_) => null, onError: (Object e) => e);
    expect((failure as GitException).kind, GitErrorKind.notARepository);

    final tolerated = await git.run(
      ['status'],
      cwd: dir.path,
      expectedErrors: {GitError.notAGitRepository},
    );
    expect(tolerated.error, GitError.notAGitRepository);
  });

  test('recognises GitHub+ specific errors before upstream patterns', () {
    expect(parseGitError('Author identity unknown\n*** Please tell me who you are.'),
        GitError.authorIdentityUnknown);
    expect(parseGitError(' ! [remote rejected] main (pre-receive hook declined)'),
        GitError.hubHistoryProtected);
    expect(classifyGitError(GitError.hubHistoryProtected), GitErrorKind.hubHistoryProtected);
  });

  test('keeps non-ASCII paths readable', () async {
    await git.run(['init', '-b', 'main'], cwd: dir.path);
    await File('${dir.path}/한글 파일.txt').writeAsString('x');
    final status = await git.run(['status', '--porcelain=v1'], cwd: dir.path);
    expect(status.stdout, contains('한글 파일.txt'));
  });
}
