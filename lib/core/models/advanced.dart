// Shapes for merge, conflicts, stash, tags and history rewrites
// (from GitHub+ v1 src/shared/models/git.ts and src/main/git/*).

/// How a git operation that can stop on conflicts ended.
enum OperationOutcome {
  /// Finished; nothing left to do.
  completed,

  /// Stopped with conflicts; the repository is now in a merge/rebase/
  /// cherry-pick/revert state (see `RepoStatus.inProgress`).
  conflicts,

  /// There was nothing to do (already up to date, empty selection).
  nothingToDo,
}

enum ConflictSide { ours, theirs }

enum ConflictChoice { ours, theirs, both }

/// One conflict block (`<<<<<<<` … `=======` … `>>>>>>>`) in a text file.
class ConflictRegion {
  const ConflictRegion({
    required this.index,
    required this.startLine,
    required this.endLine,
    required this.ours,
    required this.theirs,
    this.base,
    this.oursLabel,
    this.theirsLabel,
  });

  /// 0-based order of the block in the file.
  final int index;

  /// 0-based line numbers of the opening and closing marker lines.
  final int startLine;
  final int endLine;
  final List<String> ours;
  final List<String> theirs;

  /// diff3 base section when present.
  final List<String>? base;
  final String? oursLabel;
  final String? theirsLabel;
}

class StashEntry {
  const StashEntry({
    required this.name,
    required this.sha,
    required this.message,
    required this.createdAt,
    this.branchName,
  });

  /// `stash@{0}`.
  final String name;
  final String sha;
  final String message;
  final DateTime createdAt;

  /// Branch the stash was made on, when git recorded it ("WIP on main: ...").
  final String? branchName;
}

class Tag {
  const Tag({required this.name, required this.targetSha, this.message});
  final String name;

  /// Commit the tag points at (annotated tags are peeled).
  final String targetSha;
  final String? message;
}
