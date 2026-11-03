import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../git/git_runner.dart';

/// What a repository page shows: a folder listing and file contents.
///
/// The overview screen only talks to this interface, so the same page works
/// for a local working folder, a commit (HEAD or any branch) and, later, the
/// bare repositories a GitHub+ hub keeps.
abstract class RepoContentSource {
  /// Entries directly inside [dir] ('' for the root), folders first.
  Future<List<TreeEntry>> list(String dir);

  /// Contents of the file at [path], capped at [maxPreviewBytes].
  Future<BlobContent> read(String path);
}

const maxPreviewBytes = 2 * 1024 * 1024;

enum EntryKind { directory, file, submodule, symlink }

class TreeEntry {
  const TreeEntry({required this.path, required this.kind, this.size});

  /// Repository-relative, '/' separated.
  final String path;
  final EntryKind kind;
  final int? size;

  String get name => p.posix.basename(path);
  bool get isDirectory => kind == EntryKind.directory;
}

sealed class BlobContent {
  const BlobContent();
}

class TextBlob extends BlobContent {
  const TextBlob(this.text, this.size);
  final String text;
  final int size;
}

class ImageBlob extends BlobContent {
  const ImageBlob(this.bytes);
  final List<int> bytes;
}

class BinaryBlob extends BlobContent {
  const BinaryBlob(this.size);
  final int size;
}

class TooLargeBlob extends BlobContent {
  const TooLargeBlob(this.size);
  final int size;
}

class MissingBlob extends BlobContent {
  const MissingBlob();
}

/// The path is a link or reference that leaves the repository.
class BlockedBlob extends BlobContent {
  const BlockedBlob();
}

/// Normalizes a repository-relative path, or returns null when it is absolute
/// or climbs out of the repository ('..', drive letters, UNC paths).
String? normalizeRepoPath(String path) {
  final unified = path.replaceAll('\\', '/');
  if (unified.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(unified)) return null;
  final normalized = p.posix.normalize(unified);
  if (normalized == '.') return '';
  if (normalized == '..' || normalized.startsWith('../')) return null;
  return normalized;
}

/// Resolves a link found in a file inside [fromDir], GitHub style: a leading
/// '/' means the repository root. Returns null for anything outside it.
String? resolveRepoLink(String fromDir, String href) {
  final String target;
  try {
    target = Uri.decodeComponent(href.split('#').first.split('?').first);
  } on ArgumentError {
    return null;
  }
  if (target.isEmpty) return null;
  if (target.startsWith('/')) return normalizeRepoPath(target.substring(1));
  return normalizeRepoPath(fromDir.isEmpty ? target : '$fromDir/$target');
}

const _readmeNames = ['readme.md', 'readme.markdown', 'readme.txt', 'readme.rst', 'readme'];

/// The README GitHub would pick for a folder, if any.
TreeEntry? findReadme(List<TreeEntry> entries) {
  for (final name in _readmeNames) {
    final match = entries.where((e) => e.kind == EntryKind.file && e.name.toLowerCase() == name).firstOrNull;
    if (match != null) return match;
  }
  return null;
}

bool isMarkdownPath(String path) => const {'.md', '.markdown', '.mdown'}.contains(p.extension(path).toLowerCase());

const _imageExtensions = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.ico'};

/// Turns raw bytes into what the viewer can show.
BlobContent classifyBlob(String path, List<int> bytes) {
  if (_imageExtensions.contains(p.extension(path).toLowerCase())) return ImageBlob(bytes);
  final probe = bytes.length > 8000 ? bytes.sublist(0, 8000) : bytes;
  if (probe.contains(0)) return BinaryBlob(bytes.length);
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) text = text.substring(1);
  return TextBlob(text, bytes.length);
}

List<TreeEntry> _sorted(Iterable<TreeEntry> entries) {
  int rank(TreeEntry e) => e.isDirectory || e.kind == EntryKind.submodule ? 0 : 1;
  return entries.toList()
    ..sort((a, b) {
      final byKind = rank(a) - rank(b);
      return byKind != 0 ? byKind : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
}

/// Contents of a commit-ish ([ref]) read straight from the object database.
/// Works on bare repositories too.
class GitTreeSource implements RepoContentSource {
  GitTreeSource(this.git, this.repoPath, {this.ref = 'HEAD'});

  final GitRunner git;
  final String repoPath;
  final String ref;

  @override
  Future<List<TreeEntry>> list(String dir) async {
    final safeDir = normalizeRepoPath(dir);
    if (safeDir == null) return const [];
    final result = await git.run([
      'ls-tree', '-z', '--long', ref, '--', if (safeDir.isNotEmpty) '$safeDir/',
    ], cwd: repoPath);
    return _sorted(parseLsTree(result.stdout));
  }

  @override
  Future<BlobContent> read(String path) async {
    final safePath = normalizeRepoPath(path);
    if (safePath == null || safePath.isEmpty) return const BlockedBlob();
    final spec = '$ref:$safePath';
    final type = await git.run(['cat-file', '-t', spec], cwd: repoPath, successExitCodes: {0, 128});
    if (type.exitCode != 0 || type.stdout.trim() != 'blob') return const MissingBlob();
    final size = int.parse((await git.run(['cat-file', '-s', spec], cwd: repoPath)).stdout.trim());
    if (size > maxPreviewBytes) return TooLargeBlob(size);
    return classifyBlob(safePath, await git.runBytes(['cat-file', 'blob', spec], cwd: repoPath));
  }
}

/// Parses `git ls-tree -z --long` records: `<mode> <type> <oid> <size>TAB<path>NUL`.
List<TreeEntry> parseLsTree(String output) {
  final entries = <TreeEntry>[];
  for (final record in output.split('\x00')) {
    final tab = record.indexOf('\t');
    if (tab < 0) continue;
    final fields = record.substring(0, tab).split(RegExp(r'\s+'));
    if (fields.length < 4) continue;
    final kind = switch ((fields[0], fields[1])) {
      (_, 'tree') => EntryKind.directory,
      (_, 'commit') => EntryKind.submodule,
      ('120000', _) => EntryKind.symlink,
      _ => EntryKind.file,
    };
    entries.add(TreeEntry(path: record.substring(tab + 1), kind: kind, size: int.tryParse(fields[3])));
  }
  return entries;
}

/// The working folder as the user sees it, minus files .gitignore hides.
/// Shows uncommitted edits, and works before the first commit.
class WorkingTreeSource implements RepoContentSource {
  WorkingTreeSource(this.git, this.root);

  final GitRunner git;
  final String root;
  Future<Map<String, Set<String>>>? _index;

  /// dir -> names directly inside it (files and folders), built once.
  Future<Map<String, Set<String>>> _buildIndex() async {
    final result = await git.run(['ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd: root);
    final index = <String, Set<String>>{};
    for (final path in result.stdout.split('\x00')) {
      if (path.isEmpty) continue;
      var child = path;
      while (true) {
        final parent = p.posix.dirname(child);
        final dir = parent == '.' ? '' : parent;
        index.putIfAbsent(dir, () => {}).add(p.posix.basename(child));
        if (dir.isEmpty) break;
        child = dir;
      }
    }
    return index;
  }

  @override
  Future<List<TreeEntry>> list(String dir) async {
    final safeDir = normalizeRepoPath(dir);
    if (safeDir == null) return const [];
    final index = await (_index ??= _buildIndex());
    final entries = <TreeEntry>[];
    for (final name in index[safeDir] ?? const <String>{}) {
      final path = safeDir.isEmpty ? name : '$safeDir/$name';
      final entry = _describe(path, hasChildren: index.containsKey(path));
      if (entry != null) entries.add(entry);
    }
    return _sorted(entries);
  }

  /// Null when a tracked file was deleted from disk.
  TreeEntry? _describe(String path, {required bool hasChildren}) {
    final full = p.join(root, path);
    final type = FileSystemEntity.typeSync(full, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type == FileSystemEntityType.link) return TreeEntry(path: path, kind: EntryKind.symlink);
    if (type == FileSystemEntityType.directory) {
      return TreeEntry(path: path, kind: hasChildren ? EntryKind.directory : EntryKind.submodule);
    }
    return TreeEntry(path: path, kind: EntryKind.file, size: File(full).lengthSync());
  }

  @override
  Future<BlobContent> read(String path) async {
    final safePath = normalizeRepoPath(path);
    if (safePath == null || safePath.isEmpty) return const BlockedBlob();
    final file = File(p.join(root, safePath));
    if (!file.existsSync()) return const MissingBlob();
    // Follow links only while they stay inside the repository.
    final realRoot = Directory(root).resolveSymbolicLinksSync();
    final real = file.resolveSymbolicLinksSync();
    if (!p.isWithin(realRoot, real)) return const BlockedBlob();
    if (FileSystemEntity.isDirectorySync(real)) return const MissingBlob();
    final size = file.lengthSync();
    if (size > maxPreviewBytes) return TooLargeBlob(size);
    return classifyBlob(safePath, await file.readAsBytes());
  }
}
