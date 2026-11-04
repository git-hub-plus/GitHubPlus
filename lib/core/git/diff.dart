// Ported from GitHub Desktop (MIT): app/src/lib/git/diff.ts (via GitHub+ v1 src/main/git/diff.ts)
// CONTRACT (owner: worker G1). Signatures are fixed; G1 implements the bodies.
// Port from GitHub+ v1 src/main/git/diff.ts + diff-parser.ts (GitHub Desktop, MIT).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../models/commit.dart';
import '../models/diff.dart';
import '../models/status.dart';
import 'git_runner.dart';
import 'diff_parser.dart';
import 'stage.dart';

/// Diff text above this many bytes comes back as [LargeDiff].
const maxDiffBytes = 3 * 1024 * 1024;

/// Diff of a working-tree file against HEAD (index ignored, like GitHub Desktop):
/// untracked/new files diff against nothing, renames show the rename, binary
/// files give [BinaryDiff], images give [ImageDiff] with both versions.
Future<FileDiff> getWorkingDiff(GitRunner git, String repoPath, WorkingFile file) async {
  validateDiffPath(file.path);
  validateDiffPath(file.status.oldPath ?? file.path);
  final head = await headOrNull(git, repoPath);
  final List<String> args;
  var exits = const {0};
  if (file.status.submodule == null && (file.status.isNew || head == null)) {
    await safeWorkingPath(repoPath, file.path);
    args = ['diff', ..._options, '--no-index', '--', '/dev/null', file.path];
    exits = const {0, 1};
  } else if (file.status.oldPath != null && head != null) {
    final before = (await git.run([
      'rev-parse',
      '--verify',
      '--end-of-options',
      '$head:${file.status.oldPath}',
    ], cwd: repoPath)).stdout.trim();
    final path = await safeWorkingPath(repoPath, file.path);
    final after = (await git.run(
      ['hash-object', '-w', '--path=${file.path}', '--stdin'],
      cwd: repoPath,
      stdinBytes: await _readWorking(path, repoPath),
    )).stdout.trim();
    args = ['diff', ..._options, before, after, '--'];
  } else {
    final base = head ?? (await git.run(['mktree'], cwd: repoPath, stdin: '')).stdout.trim();
    args = ['--literal-pathspecs', 'diff', ..._options, base, '--', file.path];
  }
  final result = await git.run(args, cwd: repoPath, successExitCodes: exits);
  return _buildDiff(git, repoPath, file.path, file.status, result, head, null);
}

/// Diff of [file] as changed by commit [sha] (against its first parent, or the
/// empty tree for a root commit).
Future<FileDiff> getCommitDiff(GitRunner git, String repoPath, String sha, CommittedFile file) async {
  validateDiffPath(file.path);
  validateDiffPath(file.status.oldPath ?? file.path);
  if (sha.startsWith('-')) throw ArgumentError.value(sha, 'sha');
  final commit = (await git.run([
    'rev-parse',
    '--verify',
    '--end-of-options',
    '$sha^{commit}',
  ], cwd: repoPath)).stdout.trim();
  final parents = (await git.run([
    'rev-list',
    '--parents',
    '-n',
    '1',
    commit,
    '--',
  ], cwd: repoPath)).stdout.trim().split(' ');
  final parent = parents.length > 1 ? parents[1] : (await git.run(['mktree'], cwd: repoPath, stdin: '')).stdout.trim();
  final result = await git.run([
    '--literal-pathspecs',
    'diff',
    ..._options,
    '-M',
    parent,
    commit,
    '--',
    file.path,
    if (file.status.oldPath != null) file.status.oldPath!,
  ], cwd: repoPath);
  return _buildDiff(git, repoPath, file.path, file.status, result, parent, commit);
}

const _options = [
  '--no-ext-diff',
  '--no-textconv',
  '--no-color',
  '--no-renames',
  '--src-prefix=a/',
  '--dst-prefix=b/',
  '--unified=3',
  '--submodule=short',
];
const _images = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.bmp': 'image/bmp',
  '.ico': 'image/x-icon',
};
const _maxImageBytes = 10 * 1024 * 1024;

Future<List<int>> _readWorking(String path, String repo) async {
  final resolved = await File(path).resolveSymbolicLinks();
  final root = await Directory(repo).resolveSymbolicLinks();
  if (!p.isWithin(root, resolved)) throw ArgumentError('Path escapes repository');
  return File(path).readAsBytes();
}

Future<FileDiff> _buildDiff(
  GitRunner git,
  String repo,
  String path,
  FileStatus status,
  GitResult result,
  String? previousRef,
  String? currentRef,
) async {
  final raw = result.stdout;
  final size = utf8.encode(raw).length;
  if (size > 70000000) return const UnrenderableDiff();
  if (status.submodule != null ||
      RegExp(r'^(?:index .* 160000|(?:new|deleted) file mode 160000)$', multiLine: true).hasMatch(raw)) {
    final url = (await git.run(
      ['config', '--get', 'submodule.$path.url'],
      cwd: repo,
      successExitCodes: {0, 1},
    )).stdout.trim();
    return SubmoduleDiff(
      path: path,
      url: url.isEmpty ? null : redactCredentials(url),
      status: status.submodule,
      oldSha: RegExp(r'^-Subproject commit ([0-9a-f]+)', multiLine: true).firstMatch(raw)?[1],
      newSha: RegExp(r'^\+Subproject commit ([0-9a-f]+)', multiLine: true).firstMatch(raw)?[1],
    );
  }
  final parsed = DiffParser().parse(raw);
  if (parsed is BinaryDiff) {
    final media = _images[p.extension(path).toLowerCase()];
    if (media == null) return parsed;
    Future<DiffImage?> image(String? ref, String name) async {
      final List<int> bytes;
      if (ref != null) {
        final object = '$ref:$name';
        final length = int.parse((await git.run(['cat-file', '-s', object], cwd: repo)).stdout.trim());
        if (length > _maxImageBytes) return null;
        bytes = await git.runBytes(['cat-file', 'blob', object], cwd: repo);
      } else {
        final fullPath = await safeWorkingPath(repo, name);
        if (await File(fullPath).length() > _maxImageBytes) return null;
        bytes = await _readWorking(fullPath, repo);
      }
      if (bytes.length > _maxImageBytes) return null;
      return DiffImage(bytes: Uint8List.fromList(bytes), mediaType: _images[p.extension(name).toLowerCase()] ?? media);
    }

    final hasPrevious = previousRef != null && !status.isNew;
    final hasCurrent = status.kind != FileStatusKind.deleted;
    final previous = hasPrevious ? await image(previousRef, status.oldPath ?? path) : null;
    final current = hasCurrent ? await image(currentRef, path) : null;
    if ((hasPrevious && previous == null) || (hasCurrent && current == null)) return const BinaryDiff();
    return ImageDiff(previous: previous, current: current);
  }
  final text = parsed as TextDiff;
  LineEnding? ending(String prefix) {
    final lines = text.hunks.expand((h) => h.lines).where((l) => l.text.startsWith(prefix)).toList();
    if (lines.isEmpty) return null;
    return lines.every((l) => l.text.endsWith('\r')) ? LineEnding.crlf : LineEnding.lf;
  }

  final warning = RegExp(r'(CRLF|CR|LF) will be replaced by (CRLF|CR|LF)').firstMatch(result.stderr);
  final from = warning == null ? ending('-') : LineEnding.values.byName(warning[1]!.toLowerCase());
  final to = warning == null ? ending('+') : LineEnding.values.byName(warning[2]!.toLowerCase());
  final diff = TextDiff(
    text: text.text,
    hunks: text.hunks,
    maxLineNumber: text.maxLineNumber,
    hasHiddenBidiChars: text.hasHiddenBidiChars,
    lineEndingsChange: from != null && to != null && from != to ? (from: from, to: to) : null,
  );
  return size > maxDiffBytes || text.hunks.any((h) => h.lines.any((l) => l.text.length > 5000))
      ? LargeDiff(diff: diff, size: size)
      : diff;
}
