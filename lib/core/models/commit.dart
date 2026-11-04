// Commit and branch shapes (from GitHub+ v1 src/shared/models/git.ts).
import 'status.dart';

class CommitIdentity {
  const CommitIdentity({required this.name, required this.email, required this.date, required this.tzOffsetMinutes});
  final String name;
  final String email;
  final DateTime date;

  /// Timezone offset recorded by git, in minutes (e.g. +540 for KST).
  final int tzOffsetMinutes;
}

class Commit {
  const Commit({
    required this.sha,
    required this.summary,
    required this.body,
    required this.author,
    required this.committer,
    required this.parentShas,
    this.refs = const [],
  });

  final String sha;
  final String summary;
  final String body;
  final CommitIdentity author;
  final CommitIdentity committer;
  final List<String> parentShas;

  /// Decorations pointing here: `HEAD`, `main`, `origin/main`, `tag: v1.0`.
  final List<String> refs;

  String get shortSha => sha.length > 7 ? sha.substring(0, 7) : sha;
  bool get isMerge => parentShas.length > 1;
}

/// A file a commit changed.
class CommittedFile {
  const CommittedFile({required this.path, required this.status});
  final String path;
  final FileStatus status;
}

enum BranchType { local, remote }

class Branch {
  const Branch({
    required this.name,
    required this.type,
    required this.tipSha,
    this.remoteName,
    this.upstream,
    this.tipDate,
    this.isCurrent = false,
    this.ahead = 0,
    this.behind = 0,
  });

  /// Short name: `main`, or `origin/main` for remote branches.
  final String name;
  final BranchType type;
  final String tipSha;

  /// Remote of a remote branch, e.g. `origin`.
  final String? remoteName;

  /// Upstream of a local branch, e.g. `origin/main`.
  final String? upstream;
  final DateTime? tipDate;
  final bool isCurrent;

  /// Commits ahead of / behind the upstream (local branches with an upstream).
  final int ahead;
  final int behind;

  /// Name without the remote prefix (`origin/feature/x` -> `feature/x`).
  String get nameWithoutRemote =>
      remoteName != null && name.startsWith('$remoteName/') ? name.substring(remoteName!.length + 1) : name;
}
