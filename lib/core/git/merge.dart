// CONTRACT (owner: worker A1). Signatures are fixed; A1 implements the bodies.
// Port from GitHub+ v1 src/main/git/{merge,conflicts,cherry-pick,revert}.ts (GitHub Desktop, MIT).
import '../models/advanced.dart';
import 'git_runner.dart';

/// Merges [branch] into the current branch (`--no-edit`; [squash] stages the
/// result without committing). Conflicts return [OperationOutcome.conflicts]
/// instead of throwing; "Already up to date" returns nothingToDo.
Future<OperationOutcome> merge(GitRunner git, String repoPath, String branch, {bool squash = false}) =>
    throw UnimplementedError('A1');

/// Applies [shas] (oldest first) onto the current branch.
Future<OperationOutcome> cherryPick(GitRunner git, String repoPath, List<String> shas) =>
    throw UnimplementedError('A1');

/// Creates a commit that undoes [sha] (merge commits use the first parent).
Future<OperationOutcome> revert(GitRunner git, String repoPath, String sha) => throw UnimplementedError('A1');

/// Resolves a whole conflicted file by taking one side (deleted-by-one-side
/// conflicts keep or remove the file accordingly), then marks it resolved.
Future<void> resolveConflictWithSide(GitRunner git, String repoPath, String path, ConflictSide side) =>
    throw UnimplementedError('A1');

/// Stages [paths] as resolved (`git add`, or `git rm` for deleted files).
Future<void> markResolved(GitRunner git, String repoPath, List<String> paths) => throw UnimplementedError('A1');

/// Continues the merge/rebase/cherry-pick/revert in progress. Fails with
/// [StateError] while conflicted files remain. [message] overrides the merge
/// commit message. Returns conflicts again if the next rebase step stops.
Future<OperationOutcome> continueOperation(GitRunner git, String repoPath, {String? message}) =>
    throw UnimplementedError('A1');

/// Aborts the operation in progress (no-op when there is none).
Future<void> abortOperation(GitRunner git, String repoPath) => throw UnimplementedError('A1');
