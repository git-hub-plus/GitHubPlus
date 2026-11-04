// CONTRACT (owner: worker G2). Signatures are fixed; G2 implements the bodies.
// Port from GitHub+ v1 src/main/git/log.ts (GitHub Desktop, MIT).
import '../models/commit.dart';
import 'git_runner.dart';

/// Commits reachable from [revision], newest first (`--topo-order` so the
/// graph lays out cleanly), with parents and ref decorations. Empty list for
/// an unborn branch. [path] limits to commits touching that path.
Future<List<Commit>> getCommits(
  GitRunner git,
  String repoPath, {
  String revision = 'HEAD',
  int limit = 200,
  int skip = 0,
  String? path,
}) => throw UnimplementedError('G2');

/// Files changed by [sha] (against its first parent; root commit: everything).
Future<List<CommittedFile>> getCommitFiles(GitRunner git, String repoPath, String sha) =>
    throw UnimplementedError('G2');
