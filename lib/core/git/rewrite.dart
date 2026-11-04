// CONTRACT (owner: worker A2). Signatures are fixed; A2 implements the bodies.
// Port from GitHub+ v1 src/main/git/{reset,tag,rebase,squash,reorder}.ts (GitHub Desktop, MIT).
import '../models/advanced.dart';
import 'git_runner.dart';

/// `git reset --soft HEAD^` (root commit: back to unborn keeping changes).
/// Returns the undone commit's message so the commit box can be refilled.
/// Refuses ([StateError]) during an operation in progress.
Future<({String summary, String description})> undoLastCommit(GitRunner git, String repoPath) =>
    throw UnimplementedError('A2');

Future<List<Tag>> getTags(GitRunner git, String repoPath) => throw UnimplementedError('A2');

/// Lightweight tag, or annotated when [message] is given.
Future<void> createTag(GitRunner git, String repoPath, String name, String sha, {String? message}) =>
    throw UnimplementedError('A2');

/// Deletes locally and, with [remote], on that remote too.
Future<void> deleteTag(GitRunner git, String repoPath, String name, {String? remote}) =>
    throw UnimplementedError('A2');

Future<void> pushTag(GitRunner git, String repoPath, String name, {String remote = 'origin'}) =>
    throw UnimplementedError('A2');

/// Rebases the current branch onto [onto].
Future<OperationOutcome> rebase(GitRunner git, String repoPath, String onto) => throw UnimplementedError('A2');

/// Squashes [shas] (any order, all on the current branch's first-parent
/// history, no merges in between) into one commit with [message], via a
/// generated non-interactive rebase todo.
Future<OperationOutcome> squash(GitRunner git, String repoPath, List<String> shas, String message) =>
    throw UnimplementedError('A2');

/// Moves [sha] to sit right after [afterSha] (null: as the oldest of the
/// rewritten range) on the current branch's history.
Future<OperationOutcome> reorder(GitRunner git, String repoPath, String sha, {String? afterSha}) =>
    throw UnimplementedError('A2');
