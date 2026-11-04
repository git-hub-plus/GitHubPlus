// CONTRACT (owner: worker G1). Signatures are fixed; G1 implements the bodies.
// Port from GitHub+ v1 src/main/git/diff.ts + diff-parser.ts (GitHub Desktop, MIT).
import '../models/commit.dart';
import '../models/diff.dart';
import '../models/status.dart';
import 'git_runner.dart';

/// Diff text above this many bytes comes back as [LargeDiff].
const maxDiffBytes = 3 * 1024 * 1024;

/// Diff of a working-tree file against HEAD (index ignored, like GitHub Desktop):
/// untracked/new files diff against nothing, renames show the rename, binary
/// files give [BinaryDiff], images give [ImageDiff] with both versions.
Future<FileDiff> getWorkingDiff(GitRunner git, String repoPath, WorkingFile file) =>
    throw UnimplementedError('G1');

/// Diff of [file] as changed by commit [sha] (against its first parent, or the
/// empty tree for a root commit).
Future<FileDiff> getCommitDiff(GitRunner git, String repoPath, String sha, CommittedFile file) =>
    throw UnimplementedError('G1');
