// Ported from GitHub Desktop (MIT): app/src/lib/git/{merge,rebase,cherry-pick}.ts
// (via GitHub+ v1 src/main/git/in-progress.ts). Adds the merged branch name.
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/status.dart';
import 'git_runner.dart';

Future<String?> _read(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return (await file.readAsString()).trim();
}

/// `.git` directory (resolving worktrees and `--separate-git-dir`).
Future<String> gitDirectory(GitRunner git, String repoPath) async {
  final result = await git.run(['rev-parse', '--git-dir'], cwd: repoPath);
  final dir = result.stdout.trim();
  return p.isAbsolute(dir) ? dir : p.join(repoPath, dir);
}

/// Branch name from the first line of MERGE_MSG, e.g. `Merge branch 'feature'`.
String? mergedBranchFromMessage(String? message) {
  if (message == null) return null;
  final first = message.split('\n').first;
  final match = RegExp(r"^Merge (?:remote-tracking )?branch(?:es)? '([^']+)'").firstMatch(first);
  return match?.group(1);
}

Future<InProgressOperation?> getInProgress(GitRunner git, String repoPath) async {
  final gitDir = await gitDirectory(git, repoPath);
  for (final directory in ['rebase-merge', 'rebase-apply']) {
    final root = p.join(gitDir, directory);
    final head = await _read(p.join(root, 'head-name'));
    if (head != null) {
      final merge = directory == 'rebase-merge';
      return RebaseInProgress(
        targetBranch: head.replaceFirst(RegExp('^refs/heads/'), ''),
        baseBranch: await _read(p.join(root, 'onto')),
        step: int.tryParse(await _read(p.join(root, merge ? 'msgnum' : 'next')) ?? '') ?? 0,
        totalSteps: int.tryParse(await _read(p.join(root, merge ? 'end' : 'last')) ?? '') ?? 0,
      );
    }
  }
  if (await _read(p.join(gitDir, 'MERGE_HEAD')) != null) {
    return MergeInProgress(theirBranch: mergedBranchFromMessage(await _read(p.join(gitDir, 'MERGE_MSG'))));
  }
  final todo = await _read(p.join(gitDir, 'sequencer', 'todo'));
  final commands = (todo ?? '').split('\n').where((line) => RegExp('^(pick|revert) ').hasMatch(line)).toList();
  if (await _read(p.join(gitDir, 'CHERRY_PICK_HEAD')) != null || commands.any((l) => l.startsWith('pick '))) {
    final head = await _read(p.join(gitDir, 'sequencer', 'head'));
    final safety = await _read(p.join(gitDir, 'sequencer', 'abort-safety'));
    var completed = 0;
    if (head != null && safety != null && head != safety) {
      final count = await git.run(['rev-list', '--count', '--end-of-options', '$head..$safety', '--'], cwd: repoPath);
      completed = int.tryParse(count.stdout.trim()) ?? 0;
    }
    final remaining = commands.isEmpty ? 1 : commands.length;
    return CherryPickInProgress(step: completed + 1, totalSteps: completed + remaining);
  }
  if (await _read(p.join(gitDir, 'REVERT_HEAD')) != null || commands.any((l) => l.startsWith('revert '))) {
    return const RevertInProgress();
  }
  return null;
}
