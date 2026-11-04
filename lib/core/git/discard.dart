// Ported from GitHub Desktop (MIT): app/src/lib/git/checkout.ts and reset.ts (via GitHub+ v1 src/main/git/discard.ts)
// CONTRACT (owner: worker G1). Signatures are fixed; G1 implements the bodies.
// Port from GitHub+ v1 src/main/git/discard.ts (GitHub Desktop, MIT).
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/status.dart';
import 'git_runner.dart';
import 'stage.dart';

/// Throws away working-tree changes to [files] (tracked: back to HEAD,
/// untracked/new: deleted, renames: both paths restored). Before touching
/// anything, copies the current contents of every affected file into a new
/// timestamped folder under [backupDirectory] and returns that folder, so the
/// user can recover what was discarded.
Future<String> discardChanges(
  GitRunner git,
  String repoPath,
  List<WorkingFile> files, {
  required String backupDirectory,
}) async {
  return withRepositoryOperation(repoPath, () async {
    final paths = <String>{};
    for (final file in files) {
      paths.add(validateDiffPath(file.path));
      if (file.status.kind == FileStatusKind.renamed) paths.add(validateDiffPath(file.status.oldPath!));
    }
    final fullPaths = <String, String>{};
    for (final path in paths) {
      final full = await safeWorkingPath(repoPath, path);
      final type = await FileSystemEntity.type(full, followLinks: false);
      if (type == FileSystemEntityType.directory) throw ArgumentError('Cannot discard a directory');
      fullPaths[path] = full;
    }
    final now = DateTime.now();
    String pad(int n) => '$n'.padLeft(2, '0');
    final stamp = '${now.year}${pad(now.month)}${pad(now.day)}-${pad(now.hour)}${pad(now.minute)}${pad(now.second)}';
    var backup = Directory(p.join(backupDirectory, stamp));
    var suffix = 0;
    while (await backup.exists()) {
      backup = Directory(p.join(backupDirectory, '$stamp-${++suffix}'));
    }
    await backup.create(recursive: true);
    // Complete every backup before touching the worktree or index.
    for (final entry in fullPaths.entries) {
      final type = await FileSystemEntity.type(entry.value, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      final target = p.join(backup.path, entry.key);
      await Directory(p.dirname(target)).create(recursive: true);
      if (type == FileSystemEntityType.link) {
        await Link(target).create(await Link(entry.value).target());
      } else {
        await File(entry.value).copy(target);
      }
    }
    if (paths.isEmpty) return backup.path;
    final head = await headOrNull(git, repoPath);
    final tracked = head == null
        ? <String>{}
        : (await git.run([
            '--literal-pathspecs',
            'ls-tree',
            '-r',
            '-z',
            '--name-only',
            head,
            '--',
            ...paths,
          ], cwd: repoPath)).stdout.split('\u0000').where((s) => s.isNotEmpty).toSet();
    final remove = paths.difference(tracked);
    for (final path in remove) {
      final full = fullPaths[path]!;
      final type = await FileSystemEntity.type(full, followLinks: false);
      if (type == FileSystemEntityType.link) {
        await Link(full).delete();
      } else if (type != FileSystemEntityType.notFound) {
        await File(full).delete();
      }
    }
    if (remove.isNotEmpty) {
      await git.run([
        '--literal-pathspecs',
        'rm',
        '--cached',
        '-f',
        '--ignore-unmatch',
        '--',
        ...remove,
      ], cwd: repoPath);
    }
    if (tracked.isNotEmpty) {
      await git.run([
        '--literal-pathspecs',
        'restore',
        '--source=HEAD',
        '--staged',
        '--worktree',
        '--',
        ...tracked,
      ], cwd: repoPath);
    }
    return backup.path;
  });
}
