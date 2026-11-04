// CONTRACT (owner: worker G2). Signatures are fixed; G2 implements the bodies.
// Port from GitHub+ v1 src/main/git/{for-each-ref,branch,checkout}.ts (GitHub Desktop, MIT).
import '../models/commit.dart';
import 'git_runner.dart';

/// Local and remote branches (remote `HEAD` symrefs excluded), with upstream,
/// ahead/behind and tip date. The checked-out branch has `isCurrent`.
Future<List<Branch>> getBranches(GitRunner git, String repoPath) => throw UnimplementedError('G2');

/// Creates [name] at [startPoint] (default HEAD) and optionally switches to it.
/// Throws [GitException] with [GitError.branchAlreadyExists] when taken.
Future<void> createBranch(GitRunner git, String repoPath, String name, {String? startPoint, bool checkout = true}) =>
    throw UnimplementedError('G2');

/// Switches to [branch]. A remote branch with no local counterpart creates a
/// tracking local branch (`git checkout -b feature --track origin/feature`).
/// Reports progress lines through [onProgress].
Future<void> checkoutBranch(
  GitRunner git,
  String repoPath,
  Branch branch, {
  void Function(double value, String? stage)? onProgress,
}) => throw UnimplementedError('G2');

Future<void> renameBranch(GitRunner git, String repoPath, String oldName, String newName) =>
    throw UnimplementedError('G2');

/// Deletes a local branch (`-d`, or `-D` with [force]); with [includeRemote]
/// also deletes its upstream on the remote (`git push <remote> --delete`).
Future<void> deleteBranch(GitRunner git, String repoPath, Branch branch, {bool force = false, bool includeRemote = false}) =>
    throw UnimplementedError('G2');
