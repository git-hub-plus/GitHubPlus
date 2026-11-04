// Ported from GitHub Desktop (MIT): app/test/unit/git/checkout-test.ts and reset-test.ts (via GitHub+ v1 tests/main/git/discard.test.ts)
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:github_plus/core/git/discard.dart';
import 'package:github_plus/core/models/status.dart';
import 'helpers.dart';

WorkingFile file(String path, FileStatusKind kind) => WorkingFile(
  path: path,
  status: FileStatus(kind: kind),
);
void main() {
  late TestRepos repos;
  late String repo;
  late String backups;
  setUp(() async {
    repos = await TestRepos.create();
    repo = await repos.init('repo');
    backups = p.join(repos.root.path, 'backups');
  });
  tearDown(() async => repos.dispose());
  test('v1: tracked/staged/deleted/new files restored with recoverable backups', () async {
    await repos.commit(repo, 'base', files: {'tracked': 'original\n', 'deleted': 'original\n'});
    await repos.write(repo, 'tracked', 'staged\n');
    await repos.run(repo, ['add', '--', 'tracked']);
    await repos.write(repo, 'tracked', 'unstaged\n');
    await File(p.join(repo, 'deleted')).delete();
    await repos.write(repo, 'untracked', 'original\n');
    await repos.write(repo, 'added', 'original\n');
    await repos.run(repo, ['add', '--', 'added']);
    final backup = await discardChanges(repos.git, repo, [
      file('tracked', FileStatusKind.modified),
      file('deleted', FileStatusKind.deleted),
      file('untracked', FileStatusKind.untracked),
      file('added', FileStatusKind.added),
    ], backupDirectory: backups);
    expect(p.basename(backup), matches(r'^\d{8}-\d{6}$'));
    expect(await File(p.join(repo, 'tracked')).readAsString(), 'original\n');
    expect(await File(p.join(repo, 'deleted')).readAsString(), 'original\n');
    expect(await File(p.join(backup, 'tracked')).readAsString(), 'unstaged\n');
    expect(await File(p.join(backup, 'untracked')).readAsString(), 'original\n');
    expect(await File(p.join(backup, 'added')).readAsString(), 'original\n');
    expect(await File(p.join(repo, 'untracked')).exists(), isFalse);
    expect((await repos.run(repo, ['status', '--porcelain'])).stdout, isEmpty);
  });
  test('v1: rename source restored, destination backed up, unselected file retained', () async {
    await repos.commit(repo, 'base', files: {'old': 'original\n', 'keep': 'original\n'});
    await File(p.join(repo, 'old')).rename(p.join(repo, 'new'));
    await repos.run(repo, ['add', '-A']);
    await repos.write(repo, 'new', 'renamed content\n');
    await repos.write(repo, 'old', 'recreated source\n');
    await repos.write(repo, 'keep', 'keep this\n');
    final backup = await discardChanges(repos.git, repo, [
      const WorkingFile(
        path: 'new',
        status: FileStatus(kind: FileStatusKind.renamed, oldPath: 'old'),
      ),
    ], backupDirectory: backups);
    expect(await File(p.join(repo, 'old')).readAsString(), 'original\n');
    expect(await File(p.join(repo, 'new')).exists(), isFalse);
    expect(await File(p.join(backup, 'new')).readAsString(), 'renamed content\n');
    expect(await File(p.join(backup, 'old')).readAsString(), 'recreated source\n');
    expect(await File(p.join(repo, 'keep')).readAsString(), 'keep this\n');
    expect((await repos.run(repo, ['status', '--porcelain'])).stdout.trim(), 'M keep');
  });
  test('v1: backup failure changes neither files nor index', () async {
    await repos.write(repo, 'added', 'original\n');
    await repos.run(repo, ['add', '--', 'added']);
    final blocked = p.join(repos.root.path, 'blocked');
    await File(blocked).writeAsString('not a directory');
    await expectLater(
      discardChanges(repos.git, repo, [file('added', FileStatusKind.added)], backupDirectory: blocked),
      throwsA(isA<FileSystemException>()),
    );
    expect(await File(p.join(repo, 'added')).readAsString(), 'original\n');
    expect((await repos.run(repo, ['diff', '--cached', '--name-only'])).stdout.trim(), 'added');
  });
  test('v1: unborn repository, invalid paths and directory refusal', () async {
    await repos.write(repo, 'new', 'original\n');
    await repos.run(repo, ['add', '--', 'new']);
    for (final path in ['../outside', '.', '.git/HEAD', 'C:/outside', '/outside']) {
      await expectLater(
        discardChanges(repos.git, repo, [file(path, FileStatusKind.untracked)], backupDirectory: backups),
        throwsArgumentError,
      );
    }
    await Directory(p.join(repo, 'dir')).create();
    await expectLater(
      discardChanges(repos.git, repo, [file('dir', FileStatusKind.untracked)], backupDirectory: backups),
      throwsArgumentError,
    );
    final backup = await discardChanges(repos.git, repo, [file('new', FileStatusKind.added)], backupDirectory: backups);
    expect(await File(p.join(backup, 'new')).readAsString(), 'original\n');
    expect((await repos.run(repo, ['status', '--porcelain'])).stdout, isEmpty);
  });
  test('v1: removed directory restoration and literal wildcard paths', () async {
    await repos.commit(
      repo,
      'base',
      files: {'nested/deleted': 'original\n', '[abc].txt': 'original\n', 'a.txt': 'original\n'},
    );
    await File(p.join(repo, 'nested', 'deleted')).delete();
    await Directory(p.join(repo, 'nested')).delete();
    await repos.write(repo, '[abc].txt', 'changed');
    await repos.write(repo, 'a.txt', 'keep');
    final backup = await discardChanges(repos.git, repo, [
      file('nested/deleted', FileStatusKind.deleted),
      file('[abc].txt', FileStatusKind.modified),
    ], backupDirectory: backups);
    expect(await File(p.join(repo, 'nested', 'deleted')).readAsString(), 'original\n');
    expect(await File(p.join(repo, '[abc].txt')).readAsString(), 'original\n');
    expect(await File(p.join(backup, '[abc].txt')).readAsString(), 'changed');
    expect(await File(p.join(repo, 'a.txt')).readAsString(), 'keep');
  });
  test('conflicted paths are restored according to HEAD membership', () async {
    final base = await repos.commit(repo, 'base', files: {'tracked': 'ours\n'});
    final theirs = (await repos.run(repo, ['hash-object', '-w', '--stdin'])).stdout.trim();
    // Build unmerged entries directly; no branch switching is needed.
    final ours = (await repos.run(repo, ['rev-parse', '$base:tracked'])).stdout.trim();
    await repos.git.run(
      ['update-index', '--index-info'],
      cwd: repo,
      stdin:
          '0 ${'0' * 40}\ttracked\n100644 $ours 1\ttracked\n100644 $ours 2\ttracked\n100644 $theirs 3\ttracked\n100644 $ours 1\tremoved\n100644 $theirs 3\tremoved\n',
    );
    await repos.write(repo, 'tracked', 'conflict\n');
    await repos.write(repo, 'removed', 'theirs\n');
    final backup = await discardChanges(repos.git, repo, [
      file('tracked', FileStatusKind.conflicted),
      file('removed', FileStatusKind.conflicted),
    ], backupDirectory: backups);
    expect(await File(p.join(repo, 'tracked')).readAsString(), 'ours\n');
    expect(await File(p.join(repo, 'removed')).exists(), isFalse);
    expect(await File(p.join(backup, 'tracked')).readAsString(), 'conflict\n');
    expect((await repos.run(repo, ['status', '--porcelain'])).stdout, isEmpty);
  });
  test('successive calls retain separate backup folders', () async {
    await repos.commit(repo, 'base', files: {'tracked': 'original'});
    await repos.write(repo, 'tracked', 'first');
    final one = await discardChanges(repos.git, repo, [
      file('tracked', FileStatusKind.modified),
    ], backupDirectory: backups);
    await repos.write(repo, 'tracked', 'second');
    final two = await discardChanges(repos.git, repo, [
      file('tracked', FileStatusKind.modified),
    ], backupDirectory: backups);
    expect(one, isNot(two));
    expect(await File(p.join(one, 'tracked')).readAsString(), 'first');
    expect(await File(p.join(two, 'tracked')).readAsString(), 'second');
  });
}
