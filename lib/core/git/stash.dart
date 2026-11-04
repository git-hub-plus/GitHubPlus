// Ported from GitHub Desktop (MIT): app/src/lib/git/stash.ts (via GitHub+ v1 src/main/git/stash.ts)
// CONTRACT (owner: worker A2). Signatures are fixed; A2 implements the bodies.
// Port from GitHub+ v1 src/main/git/stash.ts (GitHub Desktop, MIT).
import '../models/advanced.dart';
import '../models/commit.dart';
import '../models/diff.dart';
import '../models/status.dart';
import 'git_runner.dart';
import 'operation.dart';
import 'diff.dart';
import 'log.dart';
import 'status.dart';
import 'stage.dart';

Future<List<StashEntry>> stashList(GitRunner git, String repoPath) async {
  final result = await git.run(['stash', 'list', '--format=%gd%x00%H%x00%gs%x00%ct'], cwd: repoPath);
  return result.stdout.split('\n').where((line) => line.isNotEmpty).map((line) {
    final fields = line.trimRight().split('\x00');
    return StashEntry(
      name: fields[0],
      sha: fields[1],
      message: fields[2],
      createdAt: DateTime.fromMillisecondsSinceEpoch(int.parse(fields[3]) * 1000, isUtc: true),
      branchName: RegExp(r'^(?:WIP on|On) (.*?): ').firstMatch(fields[2])?.group(1),
    );
  }).toList();
}

/// Stashes working changes ([includeUntracked]: new files too). Returns
/// nothingToDo when there is nothing to stash.
Future<OperationOutcome> stashCreate(
  GitRunner git,
  String repoPath, {
  String? message,
  bool includeUntracked = true,
}) async {
  final status = await getStatus(git, repoPath);
  if (!status.files.any((f) => includeUntracked || f.status.kind != FileStatusKind.untracked)) {
    return OperationOutcome.nothingToDo;
  }
  return runOperation(git, repoPath, [
    'stash',
    'push',
    if (includeUntracked) '--include-untracked',
    if (message != null) ...['--message', message],
    '--',
  ]);
}

/// Applies (or pops) [name] (`stash@{n}`); conflicts return conflicts.
Future<OperationOutcome> stashApply(GitRunner git, String repoPath, String name, {bool pop = false}) async {
  final entry = await _entry(git, repoPath, name);
  return runOperation(git, repoPath, ['stash', pop ? 'pop' : 'apply', '--', entry.name]);
}

Future<void> stashDrop(GitRunner git, String repoPath, String name) async {
  final entry = await _entry(git, repoPath, name);
  await git.run(['stash', 'drop', '--', entry.name], cwd: repoPath);
}

/// Files in a stash, untracked ones included.
Future<List<CommittedFile>> stashFiles(GitRunner git, String repoPath, String name) async {
  final parts = await _parts(git, repoPath, name);
  return [
    ...await getCommitFiles(git, repoPath, parts.sha),
    if (parts.untracked != null) ...await getCommitFiles(git, repoPath, parts.untracked!),
  ];
}

Future<FileDiff> stashDiff(GitRunner git, String repoPath, String name, CommittedFile file) async {
  validateDiffPath(file.path);
  final parts = await _parts(git, repoPath, name);
  for (final sha in [parts.sha, if (parts.untracked != null) parts.untracked!]) {
    for (final actual in await getCommitFiles(git, repoPath, sha)) {
      if (actual.path == file.path) return getCommitDiff(git, repoPath, sha, actual);
    }
  }
  throw ArgumentError('File is not in stash');
}

Future<StashEntry> _entry(GitRunner git, String repo, String name) async {
  if (name.isEmpty || name.startsWith('-') || name.contains('\x00')) throw ArgumentError.value(name, 'name');
  for (final entry in await stashList(git, repo)) {
    if (entry.name == name || entry.sha == name) return entry;
  }
  throw ArgumentError('Unknown stash');
}

Future<({String sha, String? untracked})> _parts(GitRunner git, String repo, String name) async {
  final entry = await _entry(git, repo, name);
  final third = await git.run(
    ['rev-parse', '--verify', '--quiet', '--end-of-options', '${entry.sha}^3^{commit}'],
    cwd: repo,
    successExitCodes: {0, 1},
  );
  return (sha: entry.sha, untracked: third.exitCode == 0 ? third.stdout.trim() : null);
}
