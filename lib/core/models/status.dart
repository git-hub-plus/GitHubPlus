// File status types ported from GitHub Desktop (MIT): app/src/models/status.ts

enum FileStatusKind { added, modified, deleted, copied, renamed, conflicted, untracked }

enum ConflictAction { addedByUs, deletedByUs, addedByThem, deletedByThem, bothDeleted, bothAdded, bothModified }

class SubmoduleStatus {
  const SubmoduleStatus({required this.commitChanged, required this.modifiedChanges, required this.untrackedChanges});
  final bool commitChanged;
  final bool modifiedChanges;
  final bool untrackedChanges;
}

class FileStatus {
  const FileStatus({
    required this.kind,
    this.oldPath,
    this.renameIncludesModifications = false,
    this.conflictAction,
    this.conflictMarkerCount,
    this.submodule,
  });

  final FileStatusKind kind;

  /// Source path for renames and copies.
  final String? oldPath;
  final bool renameIncludesModifications;
  final ConflictAction? conflictAction;

  /// Remaining conflict markers for text conflicts; null when a side must be picked.
  final int? conflictMarkerCount;
  final SubmoduleStatus? submodule;

  bool get isConflicted => kind == FileStatusKind.conflicted;
  bool get isNew => kind == FileStatusKind.added || kind == FileStatusKind.untracked;

  FileStatus withConflictMarkers(int count) => FileStatus(
    kind: kind,
    oldPath: oldPath,
    renameIncludesModifications: renameIncludesModifications,
    conflictAction: conflictAction,
    conflictMarkerCount: count,
    submodule: submodule,
  );
}

/// A changed file in the working directory (path relative to the root, `/` separated).
class WorkingFile {
  const WorkingFile({required this.path, required this.status});
  final String path;
  final FileStatus status;
}

sealed class InProgressOperation {
  const InProgressOperation();
}

class MergeInProgress extends InProgressOperation {
  const MergeInProgress({this.theirBranch});

  /// Branch being merged, from MERGE_MSG; null when unknown.
  final String? theirBranch;
}

class RebaseInProgress extends InProgressOperation {
  const RebaseInProgress({required this.targetBranch, this.baseBranch, required this.step, required this.totalSteps});
  final String targetBranch;
  final String? baseBranch;
  final int step;
  final int totalSteps;
}

class CherryPickInProgress extends InProgressOperation {
  const CherryPickInProgress({required this.step, required this.totalSteps});
  final int step;
  final int totalSteps;
}

class RevertInProgress extends InProgressOperation {
  const RevertInProgress();
}

class RepoStatus {
  const RepoStatus({
    required this.files,
    this.currentBranch,
    this.headSha,
    this.upstream,
    this.ahead = 0,
    this.behind = 0,
    this.unpublished = 0,
    this.inProgress,
    this.stashCount = 0,
  });

  final List<WorkingFile> files;

  /// Null when HEAD is detached or the branch is unborn.
  final String? currentBranch;
  final String? headSha;

  /// e.g. `origin/main`.
  final String? upstream;
  final int ahead;
  final int behind;

  /// Without an upstream: commits on HEAD that no remote has yet.
  final int unpublished;
  final InProgressOperation? inProgress;
  final int stashCount;

  int get conflictCount => files.where((f) => f.status.isConflicted).length;

  /// Commits waiting to go to a remote (ahead of upstream, or unpublished).
  int get toPush => upstream != null ? ahead : unpublished;
}
