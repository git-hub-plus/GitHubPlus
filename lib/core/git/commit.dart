// Ported from GitHub Desktop (MIT): app/src/lib/git/commit.ts (via GitHub+ v1 src/main/git/commit.ts)
// CONTRACT (owner: worker G1). Signatures are fixed; G1 implements the bodies.
// Port from GitHub+ v1 src/main/git/commit.ts + patch-formatter.ts + update-index.ts (GitHub Desktop, MIT).
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/diff.dart';
import '../models/status.dart';
import 'git_runner.dart';
import 'stage.dart';

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
}) async {
  for (final selected in files) {
    validateDiffPath(selected.file.path);
    validateDiffPath(selected.file.status.oldPath ?? selected.file.path);
  }
  return withRepositoryOperation(repoPath, () async {
    final head = await headOrNull(git, repoPath);
    final indexPath = (await git.run(['rev-parse', '--git-path', 'index'], cwd: repoPath)).stdout.trim();
    final index = File(p.isAbsolute(indexPath) ? indexPath : p.join(repoPath, indexPath));
    final original = await index.exists() ? await index.readAsBytes() : null;
    var committed = false;
    try {
      await git.run(['read-tree', if (head == null) '--empty' else head], cwd: repoPath);
      final paths = <String>{};
      for (final selected in files) {
        if (selected.selection.selectionType == SelectionType.none) continue;
        paths.add(selected.file.path);
        if (selected.file.status.oldPath != null) paths.add(selected.file.status.oldPath!);
        await stageSelection(git, repoPath, selected.file, selected.selection, selected.diff);
      }
      final staged = (await git.run([
        'diff',
        '--cached',
        '--no-ext-diff',
        '--no-textconv',
        '--no-renames',
        '--name-only',
        '-z',
      ], cwd: repoPath)).stdout.split('\u0000').where((s) => s.isNotEmpty);
      if (staged.any((path) => !paths.contains(path))) throw ArgumentError('Selection would change an unlisted file');
      if (await headOrNull(git, repoPath) != head) throw StateError('HEAD changed while preparing the commit; retry');
      await git.run(['commit', '-F', '-', if (amend) '--amend'], cwd: repoPath, stdin: message);
      committed = true;
      return (await git.run(['rev-parse', '--verify', 'HEAD'], cwd: repoPath)).stdout.trim();
    } finally {
      if (!committed) {
        if (original != null) {
          await index.writeAsBytes(original, flush: true);
        } else if (await index.exists()) {
          await index.delete();
        }
      }
    }
  });
}
