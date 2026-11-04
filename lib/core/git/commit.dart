// CONTRACT (owner: worker G1). Signatures are fixed; G1 implements the bodies.
// Port from GitHub+ v1 src/main/git/commit.ts + patch-formatter.ts + update-index.ts (GitHub Desktop, MIT).
import '../models/diff.dart';
import '../models/status.dart';
import 'git_runner.dart';

/// A working file and which of its lines go into the commit.
class CommitFileSelection {
  const CommitFileSelection({required this.file, required this.selection, this.diff});
  final WorkingFile file;
  final DiffSelection selection;

  /// Needed for partial selections (the patch is built from it).
  final TextDiff? diff;
}

/// Stages exactly [files] (whole files, or only the selected lines through a
/// generated patch applied with `git apply --cached`), then commits with
/// [message]. Files not listed stay unstaged; anything already in the index
/// that is not selected is reset first, so the commit contains only the
/// selection. With [amend], rewrites HEAD. Returns the new commit sha.
/// Throws [GitException] (e.g. identity missing, hooks failing).
Future<String> createCommit(
  GitRunner git,
  String repoPath, {
  required String message,
  required List<CommitFileSelection> files,
  bool amend = false,
}) => throw UnimplementedError('G1');
