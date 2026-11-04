// Ported from GitHub Desktop (MIT): app/src/lib/git/log.ts (via GitHub+ v1 src/main/git/log.ts)
// CONTRACT (owner: worker G2). Signatures are fixed; G2 implements the bodies.
// Port from GitHub+ v1 src/main/git/log.ts (GitHub Desktop, MIT).
import '../models/commit.dart';
import 'git_runner.dart';
import '../content/repo_content.dart';
import 'delimiter_parser.dart';
import 'status.dart';

/// Commits reachable from [revision], newest first (`--topo-order` so the
/// graph lays out cleanly), with parents and ref decorations. Empty list for
/// an unborn branch. [path] limits to commits touching that path. With
/// [all], every branch, remote branch and tag is included (`--all`) and
/// [revision] is ignored.
Future<List<Commit>> getCommits(
  GitRunner git,
  String repoPath, {
  String revision = 'HEAD',
  int limit = 200,
  int skip = 0,
  String? path,
  bool all = false,
}) async {
  _validateRevision(revision);
  if (limit < 0 || skip < 0) throw ArgumentError('Invalid history pagination');
  final safePath = path == null ? null : normalizeRepoPath(path);
  if (path != null && safePath == null) throw ArgumentError.value(path, 'path');
  if (limit == 0) return [];
  if (revision == 'HEAD' && !all) {
    final head = await git.run(
      ['rev-parse', '--verify', '--quiet', '--end-of-options', 'HEAD^{commit}'],
      cwd: repoPath,
      successExitCodes: {0, 1},
    );
    if (head.exitCode == 1) {
      // Only an unborn symbolic HEAD is empty; detached/broken revisions still fail.
      await git.run(['symbolic-ref', '--quiet', 'HEAD'], cwd: repoPath);
      final refs = await git.run(
        [
          'show-ref',
          '--verify',
          '--quiet',
          '--',
          (await git.run(['symbolic-ref', 'HEAD'], cwd: repoPath)).stdout.trim(),
        ],
        cwd: repoPath,
        successExitCodes: {0, 1},
      );
      if (refs.exitCode == 1) return [];
    }
  }
  final parser = LogParser({
    'sha': '%H',
    'summary': '%s',
    'body': '%b',
    'an': '%an',
    'ae': '%ae',
    'ad': '%ad',
    'cn': '%cn',
    'ce': '%ce',
    'cd': '%cd',
    'parents': '%P',
    'refs': '%D',
  });
  final result = await git.run([
    'log',
    '--date=raw',
    '--no-color',
    '--no-show-signature',
    '--decorate=short',
    '--topo-order',
    '--max-count=$limit',
    '--skip=$skip',
    ...parser.formatArgs,
    if (safePath != null) '--full-history',
    if (all) '--all',
    '--end-of-options',
    if (!all) revision,
    '--',
    if (safePath != null) ':(literal)$safePath',
  ], cwd: repoPath);
  return parser
      .parse(result.stdout)
      .map(
        (e) => Commit(
          sha: e['sha']!,
          summary: e['summary']!,
          body: e['body']!,
          author: _identity(e['an']!, e['ae']!, e['ad']!),
          committer: _identity(e['cn']!, e['ce']!, e['cd']!),
          parentShas: e['parents']!.isEmpty ? [] : e['parents']!.split(' '),
          refs: e['refs']!.isEmpty ? [] : e['refs']!.split(', ').expand((ref) => ref.split(' -> ')).toList(),
        ),
      )
      .toList();
}

/// Files changed by [sha] (against its first parent; root commit: everything).
Future<List<CommittedFile>> getCommitFiles(GitRunner git, String repoPath, String sha) async {
  _validateRevision(sha);
  final resolved = (await git.run([
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
    '--end-of-options',
    resolved,
    '--',
  ], cwd: repoPath)).stdout.trim().split(' ');
  final result = await git.run([
    if (parents.length > 1) 'diff' else 'diff-tree',
    '-r',
    '-z',
    '--name-status',
    '-M',
    '--no-ext-diff',
    '--no-textconv',
    if (parents.length == 1) ...['--root', '--no-commit-id'],
    '--end-of-options',
    if (parents.length > 1) parents[1],
    resolved,
    '--',
  ], cwd: repoPath);
  final tokens = result.stdout.split('\x00');
  final files = <CommittedFile>[];
  for (var i = 0; i < tokens.length && tokens[i].isNotEmpty;) {
    final code = tokens[i++];
    final source = tokens[i++];
    final renamed = code.startsWith('R') || code.startsWith('C');
    final path = renamed ? tokens[i++] : source;
    files.add(
      CommittedFile(
        path: path,
        status: mapStatus(
          '${code[0]}.',
          oldPath: renamed ? source : null,
          renameOrCopyScore: renamed ? int.tryParse(code.substring(1)) : null,
        ),
      ),
    );
  }
  return files;
}

void _validateRevision(String value) {
  if (value.isEmpty || value.startsWith('-') || value.contains('\x00')) throw ArgumentError.value(value, 'revision');
}

CommitIdentity _identity(String name, String email, String raw) {
  final match = RegExp(r'^(-?\d+) ([+-])(\d{2})(\d{2})$').firstMatch(raw);
  if (match == null) throw const FormatException('Malformed commit date');
  return CommitIdentity(
    name: name,
    email: email,
    date: DateTime.fromMillisecondsSinceEpoch(int.parse(match[1]!) * 1000, isUtc: true),
    tzOffsetMinutes: (match[2] == '-' ? -1 : 1) * (int.parse(match[3]!) * 60 + int.parse(match[4]!)),
  );
}
