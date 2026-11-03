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

  test('a repository cannot run commands through core.fsmonitor', () async {
    await git.run(['init', '-q', dir.path], cwd: dir.path);
    await File('${dir.path}/a.txt').writeAsString('x');
    await git.run(['config', 'core.fsmonitor', 'echo pwned > fsm-marker.txt; false'], cwd: dir.path);
    await git.run(['status', '--porcelain'], cwd: dir.path);
    expect(File('${dir.path}/fsm-marker.txt').existsSync(), isFalse);
  });

  test('credentials in URLs are hidden from messages', () {
    expect(
      redactCredentials("fatal: unable to access 'https://me:ghp_secret@github.com/a/b.git/'"),
      "fatal: unable to access 'https://***@github.com/a/b.git/'",
    );
    expect(redactCredentials('ssh://git@host/repo and user@host:repo'), 'ssh://***@host/repo and user@host:repo');
    final error = GitException(
      ['clone', 'https://u:token@example.com/r.git'],
      const GitResult(exitCode: 128, stdout: '', stderr: 'https://u:token@example.com failed', error: null),
    );
    expect('$error', isNot(contains('token')));
  });

  test('output that is not valid UTF-8 does not throw', () async {
    await git.run(['init', '-q', dir.path], cwd: dir.path);
    final result = await git.run(['hash-object', '-w', '--stdin'], cwd: dir.path, stdinBytes: [0xff, 0xfe]);
    expect(result.exitCode, 0);
    final cat = await git.run(['cat-file', '-p', result.stdout.trim()], cwd: dir.path);
    expect(cat.stdout, isNotEmpty);
  });
}
