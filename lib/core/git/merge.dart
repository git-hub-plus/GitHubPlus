// Ported from GitHub Desktop (MIT): app/src/lib/git/{merge,checkout,cherry-pick,revert}.ts, app/src/models/manual-conflict-resolution.ts (via GitHub+ v1 src/main/git/{merge,conflicts,cherry-pick,revert}.ts)
// CONTRACT (owner: worker A1). Signatures are fixed; A1 implements the bodies.
import '../models/advanced.dart';
import '../models/status.dart';
import 'git_runner.dart';
import 'in_progress.dart';
import 'operation.dart';
import 'stage.dart';
import 'status.dart';

Future<String> _resolveCommit(GitRunner git, String repo, String ref) async {
  if (ref.isEmpty || ref.startsWith('-') || ref.contains('\x00')) {
    throw ArgumentError.value(ref, 'ref', 'Invalid commit reference');
  }
  final result = await git.run(['rev-parse', '--verify', '--end-of-options', '$ref^{commit}'], cwd: repo);
  return result.stdout.trim();
}

Future<List<String>> _parents(GitRunner git, String repo, String sha) async {
  final result = await git.run(['rev-list', '--parents', '-n', '1', '--end-of-options', sha, '--'], cwd: repo);
  return result.stdout.trim().split(' ').skip(1).toList();
}

/// Merges [branch] into the current branch (`--no-edit`; [squash] stages the
/// result without committing). Conflicts return [OperationOutcome.conflicts]
/// instead of throwing; "Already up to date" returns nothingToDo.
Future<OperationOutcome> merge(GitRunner git, String repoPath, String branch, {bool squash = false}) async {
  final sha = await _resolveCommit(git, repoPath, branch);
  return runOperation(git, repoPath, ['merge', '--no-edit', if (squash) '--squash', '--', sha]);
}

/// Applies [shas] (oldest first) onto the current branch.
Future<OperationOutcome> cherryPick(GitRunner git, String repoPath, List<String> shas) async {
  if (shas.isEmpty) return OperationOutcome.nothingToDo;
  final commits = <String>[];
  for (final ref in shas) {
    final sha = await _resolveCommit(git, repoPath, ref);
    if ((await _parents(git, repoPath, sha)).length > 1) {
      throw ArgumentError.value(ref, 'shas', 'Cherry-pick cannot include merge commits');
    }
    commits.add(sha);
  }
  return runOperation(git, repoPath, ['cherry-pick', '--', ...commits]);
}

/// Creates a commit that undoes [sha] (merge commits use the first parent).
Future<OperationOutcome> revert(GitRunner git, String repoPath, String sha) async {
  final commit = await _resolveCommit(git, repoPath, sha);
  final parents = await _parents(git, repoPath, commit);
  return runOperation(git, repoPath, [
    'revert',
    '--no-edit',
    if (parents.length > 1) ...['-m', '1'],
    '--',
    commit,
  ]);
}

/// Resolves a whole conflicted file by taking one side (deleted-by-one-side
/// conflicts keep or remove the file accordingly), then marks it resolved.
Future<void> resolveConflictWithSide(GitRunner git, String repoPath, String path, ConflictSide side) async {
  final safe = validateDiffPath(path);
  await safeWorkingPath(repoPath, safe);
  final result = await git.run(['--literal-pathspecs', 'ls-files', '-u', '-z', '--', safe], cwd: repoPath);
  final entries = result.stdout.split('\x00').where((entry) => entry.isNotEmpty).toList();
  if (entries.isEmpty) throw StateError('File is not conflicted');
  final stage = side == ConflictSide.ours ? '2' : '3';
  if (entries.any((entry) => entry.split('\t').first.endsWith(' $stage'))) {
    await git.run(['--literal-pathspecs', 'checkout', '--${side.name}', '--', safe], cwd: repoPath);
    await markResolved(git, repoPath, [safe]);
  } else {
    await git.run(['--literal-pathspecs', 'rm', '-f', '--', safe], cwd: repoPath);
  }
}

/// Stages [paths] as resolved (`git add`, or `git rm` for deleted files).
Future<void> markResolved(GitRunner git, String repoPath, List<String> paths) async {
  final safe = paths.map(validateDiffPath).toList();
  for (final path in safe) {
    await safeWorkingPath(repoPath, path);
  }
  if (safe.isEmpty) return;
  await git.run(['--literal-pathspecs', 'add', '-A', '--', ...safe], cwd: repoPath);
}

String _kind(InProgressOperation operation) => switch (operation) {
  MergeInProgress() => 'merge',
  RebaseInProgress() => 'rebase',
  CherryPickInProgress() => 'cherry-pick',
  RevertInProgress() => 'revert',
};

/// Continues the merge/rebase/cherry-pick/revert in progress. Fails with
/// [StateError] while conflicted files remain. [message] overrides the merge
/// commit message. Returns conflicts again if the next rebase step stops.
Future<OperationOutcome> continueOperation(GitRunner git, String repoPath, {String? message}) async {
  final status = await getStatus(git, repoPath);
  if (status.conflictCount > 0) throw StateError('Resolve all conflicted files before continuing');
  final operation = status.inProgress;
  if (operation == null) return OperationOutcome.nothingToDo;
  if (operation is MergeInProgress) {
    return runOperation(git, repoPath, [
      'commit',
      if (message == null) '--no-edit' else ...['-F', '-'],
    ], stdin: message);
  }
  return runOperation(git, repoPath, [_kind(operation), '--continue']);
}

/// Aborts the operation in progress (no-op when there is none).
Future<void> abortOperation(GitRunner git, String repoPath) async {
  final operation = await getInProgress(git, repoPath);
  if (operation == null) return;
  await git.run([_kind(operation), '--abort'], cwd: repoPath, environment: const {'GIT_EDITOR': 'true'});
}
