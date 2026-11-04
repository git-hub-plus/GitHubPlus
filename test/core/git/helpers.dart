import 'dart:io';

import 'package:github_plus/core/git/git_runner.dart';
import 'package:path/path.dart' as p;

/// Temporary repositories for tests. Identity is passed per command so the
/// user's global git config is never touched.
class TestRepos {
  TestRepos._(this.root, this.git);

  final Directory root;
  final GitRunner git;

  static Future<TestRepos> create() async =>
      TestRepos._(await Directory.systemTemp.createTemp('ghp-test-'), GitRunner(executable: GitRunner.locateExecutable()));

  /// Windows can keep a just-exited git's files locked for a moment; retry
  /// instead of failing the test on cleanup.
  Future<void> dispose() async {
    for (var attempt = 0; ; attempt++) {
      try {
        if (await root.exists()) await root.delete(recursive: true);
        return;
      } on FileSystemException {
        if (attempt >= 20) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  }

  static const identity = ['-c', 'user.name=Test', '-c', 'user.email=test@example.com'];

  Future<String> init(String name, {bool bare = false}) async {
    final dir = Directory(p.join(root.path, name));
    await dir.create(recursive: true);
    await git.run(['init', '-b', 'main', if (bare) '--bare'], cwd: dir.path);
    if (!bare) {
      await git.run(['config', 'user.name', 'Test'], cwd: dir.path);
      await git.run(['config', 'user.email', 'test@example.com'], cwd: dir.path);
      await git.run(['config', 'core.autocrlf', 'false'], cwd: dir.path);
    }
    return dir.path;
  }

  Future<GitResult> run(String repo, List<String> args) => git.run([...identity, ...args], cwd: repo);

  Future<void> write(String repo, String path, String content) async {
    final file = File(p.join(repo, path));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  Future<String> commit(String repo, String message, {Map<String, String> files = const {}}) async {
    for (final entry in files.entries) {
      await write(repo, entry.key, entry.value);
    }
    await run(repo, ['add', '-A']);
    await run(repo, ['commit', '--allow-empty', '-m', message]);
    return (await run(repo, ['rev-parse', 'HEAD'])).stdout.trim();
  }

  /// Clone of [source] (path or bare repo) with identity configured.
  Future<String> clone(String source, String name) async {
    final target = p.join(root.path, name);
    await git.run(['clone', source, target], cwd: root.path);
    await git.run(['config', 'user.name', 'Test'], cwd: target);
    await git.run(['config', 'user.email', 'test@example.com'], cwd: target);
    await git.run(['config', 'core.autocrlf', 'false'], cwd: target);
    return target;
  }
}
