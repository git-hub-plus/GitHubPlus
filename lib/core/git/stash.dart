// CONTRACT (owner: worker A2). Signatures are fixed; A2 implements the bodies.
// Port from GitHub+ v1 src/main/git/stash.ts (GitHub Desktop, MIT).
import '../models/advanced.dart';
import '../models/commit.dart';
import '../models/diff.dart';
import 'git_runner.dart';

Future<List<StashEntry>> stashList(GitRunner git, String repoPath) => throw UnimplementedError('A2');

/// Stashes working changes ([includeUntracked]: new files too). Returns
/// nothingToDo when there is nothing to stash.
Future<OperationOutcome> stashCreate(GitRunner git, String repoPath, {String? message, bool includeUntracked = true}) =>
    throw UnimplementedError('A2');

/// Applies (or pops) [name] (`stash@{n}`); conflicts return conflicts.
Future<OperationOutcome> stashApply(GitRunner git, String repoPath, String name, {bool pop = false}) =>
    throw UnimplementedError('A2');

Future<void> stashDrop(GitRunner git, String repoPath, String name) => throw UnimplementedError('A2');

/// Files in a stash, untracked ones included.
Future<List<CommittedFile>> stashFiles(GitRunner git, String repoPath, String name) => throw UnimplementedError('A2');

Future<FileDiff> stashDiff(GitRunner git, String repoPath, String name, CommittedFile file) =>
    throw UnimplementedError('A2');
