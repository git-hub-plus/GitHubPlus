// Ported from GitHub Desktop (MIT): app/src/lib/status-parser.ts, app/src/lib/git/status.ts
// (via GitHub+ v1 src/main/git/status-parser.ts and status.ts)
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/status.dart';
import 'git_runner.dart';
import 'in_progress.dart';

sealed class StatusItem {
  const StatusItem();
}

class StatusHeader extends StatusItem {
  const StatusHeader(this.value);
  final String value;
}

class StatusEntry extends StatusItem {
  const StatusEntry({
    required this.path,
    required this.statusCode,
    required this.submoduleStatusCode,
    this.oldPath,
    this.renameOrCopyScore,
  });

  final String path;
  final String statusCode;
  final String submoduleStatusCode;
  final String? oldPath;
  final int? renameOrCopyScore;
}

/// Parses `git status --porcelain=2 -z`. Only metadata fields are split so
/// paths keep their spaces and Unicode.
List<StatusItem> parsePorcelainStatus(String output) {
  final tokens = output.split('\x00');
  final items = <StatusItem>[];
  for (var i = 0; i < tokens.length; i++) {
    final field = tokens[i];
    if (field.startsWith('# ')) {
      items.add(StatusHeader(field.substring(2)));
      continue;
    }
    if (field.startsWith('? ')) {
      items.add(StatusEntry(path: field.substring(2), statusCode: '??', submoduleStatusCode: '????'));
      continue;
    }
    if (field.isEmpty || !'12u'.contains(field[0])) continue;
    final type = field[0];
    final count = type == '1' ? 8 : (type == '2' ? 9 : 10);
    var offset = 0;
    final parts = <String>[];
    for (var n = 0; n < count; n++) {
      final end = field.indexOf(' ', offset);
      if (end < 0) throw const FormatException('Malformed porcelain status record');
      parts.add(field.substring(offset, end));
      offset = end + 1;
    }
    String? oldPath;
    if (type == '2') {
      oldPath = ++i < tokens.length ? tokens[i] : null;
      if (oldPath == null || oldPath.isEmpty) throw const FormatException('Missing rename source path');
    }
    items.add(
      StatusEntry(
        path: field.substring(offset),
        statusCode: parts[1],
        submoduleStatusCode: parts[2],
        oldPath: oldPath,
        renameOrCopyScore: type == '2' ? int.tryParse(parts[8].substring(1)) : null,
      ),
    );
  }
  return items;
}

const _conflicts = {
  'DD': ConflictAction.bothDeleted,
  'AU': ConflictAction.addedByUs,
  'UD': ConflictAction.deletedByThem,
  'UA': ConflictAction.addedByThem,
  'DU': ConflictAction.deletedByUs,
  'AA': ConflictAction.bothAdded,
  'UU': ConflictAction.bothModified,
};

FileStatus mapStatus(String statusCode, {String submoduleStatusCode = 'N...', int? renameOrCopyScore, String? oldPath}) {
  final submodule = submoduleStatusCode.startsWith('S')
      ? SubmoduleStatus(
          commitChanged: submoduleStatusCode[1] == 'C',
          modifiedChanges: submoduleStatusCode[2] == 'M',
          untrackedChanges: submoduleStatusCode[3] == 'U',
        )
      : null;
  final conflict = _conflicts[statusCode];
  if (conflict != null) {
    return FileStatus(kind: FileStatusKind.conflicted, conflictAction: conflict, submodule: submodule);
  }
  if (statusCode == '??') return FileStatus(kind: FileStatusKind.untracked, submodule: submodule);
  if (oldPath != null && RegExp('[RC]').hasMatch(statusCode)) {
    return FileStatus(
      kind: statusCode.contains('R') ? FileStatusKind.renamed : FileStatusKind.copied,
      oldPath: oldPath,
      renameIncludesModifications: statusCode.contains('M') || (renameOrCopyScore != null && renameOrCopyScore < 100),
      submodule: submodule,
    );
  }
  final kind = statusCode.contains('A')
      ? FileStatusKind.added
      : (statusCode == 'D.' || statusCode == '.D')
      ? FileStatusKind.deleted
      : FileStatusKind.modified;
  return FileStatus(kind: kind, submodule: submodule);
}

/// Counts conflict markers the way git does (honouring `conflict-marker-size`).
Future<FileStatus> _withConflictMarkers(GitRunner git, String repoPath, String path, FileStatus status) async {
  final action = status.conflictAction;
  if (action != ConflictAction.bothAdded && action != ConflictAction.bothModified) return status;
  final file = File(p.join(repoPath, path));
  if (!await file.exists()) return status;
  final bytes = await file.readAsBytes();
  if (bytes.contains(0)) return status; // binary: a side must be picked
  final attr = await git.run(['check-attr', '-z', 'conflict-marker-size', 'diff', '--', path], cwd: repoPath);
  final attrs = attr.stdout.split('\x00');
  final size = attrs.length > 2 && RegExp(r'^\d+$').hasMatch(attrs[2]) ? int.parse(attrs[2]).clamp(1, 1000) : 7;
  if (attrs.length > 5 && attrs[5] == 'unset') return status;
  final text = String.fromCharCodes(bytes);
  final count = RegExp('^<{$size}(?: |\$)', multiLine: true).allMatches(text).length;
  return status.withConflictMarkers(count);
}

Future<RepoStatus> getStatus(GitRunner git, String repoPath) async {
  final results = await Future.wait([
    git.run(['--no-optional-locks', 'status', '--porcelain=2', '--branch', '--untracked-files=all', '-z'], cwd: repoPath),
    git.run(['stash', 'list', '--format=%H'], cwd: repoPath),
  ]);
  final inProgress = await getInProgress(git, repoPath);
  final items = parsePorcelainStatus(results[0].stdout);
  final headers = <String, String>{};
  for (final header in items.whereType<StatusHeader>()) {
    final space = header.value.indexOf(' ');
    if (space > 0) headers[header.value.substring(0, space)] = header.value.substring(space + 1);
  }
  final head = headers['branch.oid'];
  final branch = headers['branch.head'];
  final upstream = headers['branch.upstream'];
  final ab = RegExp(r'^\+(\d+) -(\d+)$').firstMatch(headers['branch.ab'] ?? '');
  final headSha = head != null && head != '(initial)' ? head : null;

  final files = await Future.wait(
    items.whereType<StatusEntry>().map((entry) async {
      var status = mapStatus(
        entry.statusCode,
        submoduleStatusCode: entry.submoduleStatusCode,
        renameOrCopyScore: entry.renameOrCopyScore,
        oldPath: entry.oldPath,
      );
      if (status.isConflicted) status = await _withConflictMarkers(git, repoPath, entry.path, status);
      return WorkingFile(path: entry.path, status: status);
    }),
  );

  // Without an upstream, "to push" means commits no remote has seen yet.
  var unpublished = 0;
  if (upstream == null && headSha != null) {
    final count = await git.run(['rev-list', '--count', 'HEAD', '--not', '--remotes'], cwd: repoPath);
    unpublished = int.tryParse(count.stdout.trim()) ?? 0;
  }

  return RepoStatus(
    files: files,
    currentBranch: branch != null && !branch.startsWith('(') ? branch : null,
    headSha: headSha,
    upstream: upstream,
    ahead: ab != null ? int.parse(ab.group(1)!) : 0,
    behind: ab != null ? int.parse(ab.group(2)!) : 0,
    unpublished: unpublished,
    inProgress: inProgress,
    stashCount: results[1].stdout.split('\n').where((l) => l.trim().isNotEmpty).length,
  );
}

/// Commits made today on HEAD by [email] (or by anyone when null), for the goal bar.
Future<int> countCommitsToday(GitRunner git, String repoPath, {String? email}) async {
  final result = await git.run(
    ['rev-list', '--count', '--since=midnight', if (email != null) '--author=<$email>', 'HEAD'],
    cwd: repoPath,
    successExitCodes: {0, 128},
  );
  return result.exitCode == 0 ? int.tryParse(result.stdout.trim()) ?? 0 : 0;
}
