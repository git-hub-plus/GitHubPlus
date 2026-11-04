// Ported from GitHub Desktop (MIT): app/src/lib/git/update-index.ts and apply.ts (via GitHub+ v1 src/main/git/update-index.ts and apply.ts)
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;
import '../content/repo_content.dart';
import '../models/diff.dart';
import '../models/status.dart';
import 'diff.dart';
import 'git_runner.dart';
import 'patch_formatter.dart';

final _operations = <String, Future<void>>{};

Future<T> withRepositoryOperation<T>(String repo, Future<T> Function() operation) async {
  final key = p.normalize(p.absolute(repo)).toLowerCase();
  final previous = _operations[key];
  final done = Completer<void>();
  _operations[key] = done.future;
  try {
    if (previous != null) await previous;
    return await operation();
  } finally {
    done.complete();
    if (identical(_operations[key], done.future)) _operations.remove(key);
  }
}

String validateDiffPath(String path) {
  final normalized = normalizeRepoPath(path);
  if (normalized == null ||
      normalized.isEmpty ||
      path.contains('\u0000') ||
      path.replaceAll('\\', '/').split('/').contains('..')) {
    throw ArgumentError.value(path, 'path', 'Invalid repository path');
  }
  return normalized;
}

/// Reject parent links escaping the repository before any filesystem access.
Future<String> safeWorkingPath(String repo, String path) async {
  final safe = validateDiffPath(path);
  final root = await Directory(repo).resolveSymbolicLinks();
  var parent = Directory(p.dirname(p.join(root, safe)));
  while (!await parent.exists()) {
    final next = parent.parent;
    if (next.path == parent.path) throw ArgumentError('Invalid repository parent');
    parent = next;
  }
  final resolved = await parent.resolveSymbolicLinks();
  if (!p.equals(root, resolved) && !p.isWithin(root, resolved)) throw ArgumentError('Path escapes repository');
  return p.join(root, safe);
}

Future<String?> headOrNull(GitRunner git, String repo) async {
  final result = await git.run(['rev-parse', '--verify', '--quiet', 'HEAD'], cwd: repo, successExitCodes: {0, 1});
  return result.exitCode == 0 ? result.stdout.trim() : null;
}

Future<void> updateIndex(GitRunner git, String repo, List<String> paths, {bool remove = false}) async {
  if (paths.isEmpty) return;
  await git.run(
    ['update-index', '--add', '--remove', '--replace', if (remove) '--force-remove', '-z', '--stdin'],
    cwd: repo,
    stdin: '${paths.join('\u0000')}\u0000',
  );
}

Future<void> stageSelection(
  GitRunner git,
  String repo,
  WorkingFile file,
  DiffSelection selection,
  TextDiff? supplied,
) async {
  if (selection.selectionType == SelectionType.none) return;
  if (selection.selectionType == SelectionType.all) {
    if (file.status.kind == FileStatusKind.renamed) await updateIndex(git, repo, [file.status.oldPath!], remove: true);
    await updateIndex(git, repo, [file.path], remove: file.status.kind == FileStatusKind.deleted);
    return;
  }
  final loaded = supplied ?? await getWorkingDiff(git, repo, file);
  final TextDiff diff;
  if (loaded is TextDiff) {
    diff = loaded;
  } else if (loaded is LargeDiff) {
    diff = loaded.diff;
  } else {
    throw ArgumentError('Cannot select lines in a non-text diff');
  }
  if (file.status.oldPath != null) {
    final entry = (await git.run([
      '--literal-pathspecs',
      'ls-tree',
      '-z',
      'HEAD',
      '--',
      file.status.oldPath!,
    ], cwd: repo)).stdout;
    final fields = entry.substring(0, entry.indexOf('\t')).split(' ');
    if (file.status.kind == FileStatusKind.renamed) await updateIndex(git, repo, [file.status.oldPath!], remove: true);
    await git.run(
      ['update-index', '-z', '--index-info'],
      cwd: repo,
      stdin: '${fields[0]} ${fields[2]}\t${file.path}\u0000',
    );
  }
  await git.run(
    ['apply', '--cached', '--unidiff-zero', '--whitespace=nowarn', '-'],
    cwd: repo,
    stdin: formatPatch(file, diff, selection),
  );
}
