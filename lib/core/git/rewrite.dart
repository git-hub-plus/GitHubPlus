// Ported from GitHub Desktop (MIT): app/src/lib/git/{reset,tag,rebase,squash,reorder}.ts
// (via GitHub+ v1 src/main/git/{reset,tag,rebase,squash,reorder}.ts)
// CONTRACT (owner: worker A2). Signatures are fixed; A2 implements the bodies.
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/advanced.dart';
import 'git_runner.dart';
import 'operation.dart';
import 'in_progress.dart';
import 'log.dart';

/// `git reset --soft HEAD^` (root commit: back to unborn keeping changes).
/// Returns the undone commit's message so the commit box can be refilled.
/// Refuses ([StateError]) during an operation in progress.
Future<({String summary, String description})> undoLastCommit(GitRunner git, String repoPath) async {
  await _idle(git, repoPath);
  final commits = await getCommits(git, repoPath, limit: 1);
  if (commits.isEmpty) throw StateError('There is no commit to undo');
  final commit = commits.single;
  final published = await git.run([
    'for-each-ref',
    '--contains=${commit.sha}',
    '--format=%(refname)',
    '--',
    'refs/remotes/',
  ], cwd: repoPath);
  if (published.stdout.trim().isNotEmpty) throw StateError('Cannot undo a pushed commit');
  if (commit.parentShas.isEmpty) {
    await git.run(['update-ref', '-d', 'HEAD', commit.sha], cwd: repoPath);
  } else {
    await git.run(['reset', '--soft', commit.parentShas.first, '--'], cwd: repoPath);
  }
  return (summary: commit.summary, description: commit.body.trimRight());
}

Future<List<Tag>> getTags(GitRunner git, String repoPath) async {
  final result = await git.run(['show-ref', '--tags', '-d'], cwd: repoPath, successExitCodes: {0, 1});
  final tags = <String, String>{};
  for (final line in result.stdout.split('\n').where((line) => line.trim().isNotEmpty)) {
    final fields = line.trim().split(' ');
    tags[fields[1].replaceFirst('refs/tags/', '').replaceFirst(RegExp(r'\^\{\}$'), '')] = fields[0];
  }
  return tags.entries.map((entry) => Tag(name: entry.key, targetSha: entry.value)).toList();
}

/// Lightweight tag, or annotated when [message] is given.
Future<void> createTag(GitRunner git, String repoPath, String name, String sha, {String? message}) async {
  await _tagRef(git, repoPath, name);
  final target = await _resolve(git, repoPath, sha);
  await git.run([
    '-c',
    'tag.gpgsign=false',
    'tag',
    if (message != null) ...['-a', '-m', message] else '--no-sign',
    '--',
    name,
    target,
  ], cwd: repoPath);
}

/// Deletes locally and, with [remote], on that remote too.
Future<void> deleteTag(GitRunner git, String repoPath, String name, {String? remote}) async {
  final ref = await _tagRef(git, repoPath, name);
  if (remote != null) {
    _validate(remote);
    await git.run(['push', '--', remote, ':$ref'], cwd: repoPath);
  }
  await git.run(['tag', '-d', '--', name], cwd: repoPath);
}

Future<void> pushTag(GitRunner git, String repoPath, String name, {String remote = 'origin'}) async {
  final ref = await _tagRef(git, repoPath, name);
  _validate(remote);
  await git.run(['push', '--', remote, '$ref:$ref'], cwd: repoPath);
}

/// Rebases the current branch onto [onto].
Future<OperationOutcome> rebase(GitRunner git, String repoPath, String onto) async {
  await _idle(git, repoPath);
  final base = await _resolve(git, repoPath, onto);
  await _noMerges(git, repoPath, '$base..HEAD');
  final ancestor = await git.run(
    ['merge-base', '--is-ancestor', base, 'HEAD'],
    cwd: repoPath,
    successExitCodes: {0, 1},
  );
  if (ancestor.exitCode == 0) return OperationOutcome.nothingToDo;
  return runOperation(git, repoPath, ['-c', 'rebase.updateRefs=false', 'rebase', '--', base]);
}

/// Squashes [shas] (any order, all on the current branch's first-parent
/// history, no merges in between) into one commit with [message], via a
/// generated non-interactive rebase todo.
Future<OperationOutcome> squash(GitRunner git, String repoPath, List<String> shas, String message) async {
  if (message.trim().isEmpty) throw ArgumentError('A squash message is required');
  await _idle(git, repoPath);
  final history = await _history(git, repoPath);
  final selected = <String>{};
  for (final sha in shas) {
    final resolved = await _resolve(git, repoPath, sha);
    if (!history.contains(resolved) || !selected.add(resolved)) throw ArgumentError('Invalid squash selection');
  }
  if (selected.length < 2) throw ArgumentError('Select at least two commits');
  final start = history.indexWhere(selected.contains);
  final retained = start == 0 ? null : history[start - 1];
  await _noMerges(git, repoPath, retained == null ? 'HEAD' : '$retained..HEAD');
  final range = history.sublist(start);
  final picked = range.where(selected.contains).toList();
  // Give the last fixup the requested message without invoking an editor.
  // The replacement has exactly the same tree/parents, so its patch is identical.
  // Its object remains available when a conflicted rebase is continued later.
  final last = picked.last;
  final metadata = (await git.run([
    'show',
    '-s',
    '--format=%T%n%P',
    '--end-of-options',
    last,
    '--',
  ], cwd: repoPath)).stdout.trim().split('\n');
  final replacement = (await git.run(
    [
      '-c',
      'commit.gpgsign=false',
      'commit-tree',
      metadata[0],
      if (metadata.length > 1)
        for (final parent in metadata[1].split(' ')) ...['-p', parent],
    ],
    cwd: repoPath,
    stdin: message,
  )).stdout.trim();
  final todo = <String>[
    'pick ${picked.first}',
    for (final sha in picked.skip(1)) sha == last ? 'fixup -C $replacement' : 'fixup $sha',
    for (final sha in range.where((sha) => !selected.contains(sha))) 'pick $sha',
  ];
  return _interactive(git, repoPath, todo, retained);
}

/// Moves [sha] to sit right after [afterSha] (null: as the oldest of the
/// rewritten range) on the current branch's history.
Future<OperationOutcome> reorder(GitRunner git, String repoPath, String sha, {String? afterSha}) async {
  await _idle(git, repoPath);
  final history = await _history(git, repoPath);
  final selected = await _resolve(git, repoPath, sha);
  final after = afterSha == null ? null : await _resolve(git, repoPath, afterSha);
  if (!history.contains(selected) || (after != null && (!history.contains(after) || after == selected))) {
    throw ArgumentError('Invalid reorder selection or destination');
  }
  final ordered = history.where((entry) => entry != selected).toList();
  ordered.insert(after == null ? 0 : ordered.indexOf(after) + 1, selected);
  var start = 0;
  while (start < history.length && history[start] == ordered[start]) {
    start++;
  }
  if (start == history.length) return OperationOutcome.nothingToDo;
  final retained = start == 0 ? null : history[start - 1];
  return _interactive(git, repoPath, ordered.sublist(start).map((sha) => 'pick $sha').toList(), retained);
}

void _validate(String value) {
  if (value.isEmpty || value.startsWith('-') || value.contains('\x00')) throw ArgumentError.value(value);
}

Future<String> _resolve(GitRunner git, String repo, String value) async {
  _validate(value);
  final result = await git.run(
    ['rev-parse', '--verify', '--quiet', '--end-of-options', '$value^{commit}'],
    cwd: repo,
    successExitCodes: {0, 1},
  );
  if (result.exitCode != 0) throw ArgumentError('Unknown commit');
  return result.stdout.trim();
}

Future<String> _tagRef(GitRunner git, String repo, String name) async {
  _validate(name);
  final ref = 'refs/tags/$name';
  // check-ref-format has no option delimiter; this argument always starts refs/.
  final result = await git.run(['check-ref-format', ref], cwd: repo, successExitCodes: {0, 1});
  if (result.exitCode != 0) throw ArgumentError('Invalid tag name');
  return ref;
}

Future<void> _idle(GitRunner git, String repo) async {
  if (await getInProgress(git, repo) != null) throw StateError('An operation is in progress');
}

Future<List<String>> _history(GitRunner git, String repo) async {
  final head = await git.run(
    ['rev-parse', '--verify', '--quiet', '--end-of-options', 'HEAD^{commit}'],
    cwd: repo,
    successExitCodes: {0, 1},
  );
  if (head.exitCode != 0) return [];
  return (await git.run([
    'rev-list',
    '--reverse',
    '--first-parent',
    head.stdout.trim(),
    '--',
  ], cwd: repo)).stdout.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

Future<void> _noMerges(GitRunner git, String repo, String range) async {
  final result = await git.run(['rev-list', '--min-parents=2', '--end-of-options', range, '--'], cwd: repo);
  if (result.stdout.trim().isNotEmpty) throw StateError('History editing cannot include merge commits');
}

String _quote(String value) => "'${value.replaceAll('\\', '/').replaceAll("'", "'\"'\"'")}'";

Future<OperationOutcome> _interactive(GitRunner git, String repo, List<String> todo, String? retained) async {
  await _idle(git, repo);
  await _noMerges(git, repo, retained == null ? 'HEAD' : '$retained..HEAD');
  final directory = await Directory.systemTemp.createTemp('ghp-rebase-');
  try {
    final todoFile = File(p.join(directory.path, 'todo'));
    await todoFile.writeAsString('${todo.join('\n')}\n');
    final script = File(p.join(directory.path, 'sequence.sh'));
    // Git uses its POSIX shell on Windows too. Only generated paths enter source.
    // Source the script using shell builtins only; no executable is looked up
    // in the working repository. Git appends the quoted destination to `>`.
    await script.writeAsString(
      'while IFS= read -r line; do printf \'%s\\n\' "\$line"; done < ${_quote(todoFile.path)}\n',
    );
    return await runOperation(
      git,
      repo,
      [
        '-c',
        'rebase.abbreviateCommands=false',
        '-c',
        'rebase.updateRefs=false',
        'rebase',
        '--interactive',
        '--force-rebase',
        '--keep-empty',
        if (retained == null) '--root' else ...['--', retained],
      ],
      environment: {'GIT_SEQUENCE_EDITOR': '. ${_quote(script.path)} >'},
    );
  } finally {
    await directory.delete(recursive: true);
  }
}
