// Ported from GitHub Desktop (MIT): app/src/lib/git/{for-each-ref,branch,checkout}.ts (via GitHub+ v1 src/main/git/{for-each-ref,branch,checkout}.ts)
// CONTRACT (owner: worker G2). Signatures are fixed; G2 implements the bodies.
// Port from GitHub+ v1 src/main/git/{for-each-ref,branch,checkout}.ts (GitHub Desktop, MIT).
import '../models/commit.dart';
import 'git_runner.dart';
import 'git_errors.dart';
import 'progress.dart';

/// Local and remote branches (remote `HEAD` symrefs excluded), with upstream,
/// ahead/behind and tip date. The checked-out branch has `isCurrent`.
Future<List<Branch>> getBranches(GitRunner git, String repoPath) async {
  final remotes =
      (await git.run([
          'remote',
        ], cwd: repoPath)).stdout.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  final result = await git.run([
    'for-each-ref',
    '--format=%(refname)%00%(upstream:short)%00%(objectname)%00%(committerdate:unix)%00%(HEAD)%00%(symref)%00%(upstream:track)',
    '--',
    'refs/heads',
    'refs/remotes',
  ], cwd: repoPath);
  final branches = <Branch>[];
  for (final line in result.stdout.split('\n').where((l) => l.isNotEmpty)) {
    final fields = line.trimRight().split('\x00');
    if (fields[5].isNotEmpty) continue;
    final local = fields[0].startsWith('refs/heads/');
    final name = fields[0].substring(local ? 11 : 13);
    if (!local && name.endsWith('/HEAD')) continue;
    final remote = remotes.where((r) => name.startsWith('$r/')).firstOrNull;
    final ahead = RegExp(r'ahead (\d+)').firstMatch(fields[6]);
    final behind = RegExp(r'behind (\d+)').firstMatch(fields[6]);
    branches.add(
      Branch(
        name: name,
        type: local ? BranchType.local : BranchType.remote,
        tipSha: fields[2],
        upstream: fields[1].isEmpty ? null : fields[1],
        remoteName: local ? null : remote,
        tipDate: fields[3].isEmpty
            ? null
            : DateTime.fromMillisecondsSinceEpoch(int.parse(fields[3]) * 1000, isUtc: true),
        isCurrent: fields[4] == '*',
        ahead: ahead == null ? 0 : int.parse(ahead[1]!),
        behind: behind == null ? 0 : int.parse(behind[1]!),
      ),
    );
  }
  return branches;
}

/// Creates [name] at [startPoint] (default HEAD) and optionally switches to it.
/// Throws [GitException] with [GitError.branchAlreadyExists] when taken.
Future<void> createBranch(GitRunner git, String repoPath, String name, {String? startPoint, bool checkout = true}) =>
    _createBranch(git, repoPath, name, startPoint: startPoint, checkout: checkout);

/// Switches to [branch]. A remote branch with no local counterpart creates a
/// tracking local branch (`git checkout -b feature --track origin/feature`).
/// Reports progress lines through [onProgress].
Future<void> checkoutBranch(
  GitRunner git,
  String repoPath,
  Branch branch, {
  void Function(double value, String? stage)? onProgress,
}) async {
  _validateName(branch.name);
  var name = branch.name;
  if (branch.type == BranchType.remote) {
    final remote = branch.remoteName;
    if (remote == null || !name.startsWith('$remote/')) throw ArgumentError('Unknown remote');
    _validateName(remote);
    name = name.substring(remote.length + 1);
    _validateName(name);
    final locals = await getBranches(git, repoPath);
    if (!locals.any((b) => b.type == BranchType.local && b.name == name)) {
      await git.run(['branch', '--track', '--', name, 'refs/remotes/${branch.name}'], cwd: repoPath);
    }
  }
  onProgress?.call(0, null);
  await git.run(
    ['switch', '--progress', '--', name],
    cwd: repoPath,
    onStderrLine: (line) {
      final progress = parseProgressLine(line);
      if (progress != null) onProgress?.call(progress.percent / 100, progress.title);
    },
  );
  onProgress?.call(1, null);
}

Future<void> renameBranch(GitRunner git, String repoPath, String oldName, String newName) async {
  _validateName(oldName);
  _validateName(newName);
  try {
    await git.run(['branch', '-m', '--', oldName, newName], cwd: repoPath);
  } on GitException catch (e) {
    if (e.result.error != GitError.branchAlreadyExists ||
        oldName.toLowerCase() != newName.toLowerCase() ||
        (await getBranches(git, repoPath)).any((b) => b.type == BranchType.local && b.name == newName)) {
      rethrow;
    }
    await git.run(['branch', '-M', '--', oldName, newName], cwd: repoPath);
  }
}

/// Deletes a local branch (`-d`, or `-D` with [force]); with [includeRemote]
/// also deletes its upstream on the remote (`git push <remote> --delete`).
Future<void> deleteBranch(
  GitRunner git,
  String repoPath,
  Branch branch, {
  bool force = false,
  bool includeRemote = false,
}) => _deleteBranch(git, repoPath, branch, force: force, includeRemote: includeRemote);

void _validateName(String value) {
  if (value.isEmpty || value.startsWith('-') || value.contains('\x00')) throw ArgumentError.value(value, 'branch');
}

Future<void> _createBranch(
  GitRunner git,
  String repoPath,
  String name, {
  String? startPoint,
  required bool checkout,
}) async {
  _validateName(name);
  if (startPoint != null) _validateName(startPoint);
  await git.run(['branch', '--no-track', '--', name, ?startPoint], cwd: repoPath);
  if (checkout) {
    final branch = (await getBranches(git, repoPath)).firstWhere((b) => b.type == BranchType.local && b.name == name);
    await checkoutBranch(git, repoPath, branch);
  }
}

Future<void> _deleteBranch(
  GitRunner git,
  String repoPath,
  Branch branch, {
  required bool force,
  required bool includeRemote,
}) async {
  _validateName(branch.name);
  if (includeRemote) {
    String? remote;
    String? merge;
    if (branch.type == BranchType.remote) {
      remote = branch.remoteName;
      if (remote != null && branch.name.startsWith('$remote/')) {
        merge = 'refs/heads/${branch.name.substring(remote.length + 1)}';
      }
    } else {
      final r = await git.run(
        ['config', '--get', '--', 'branch.${branch.name}.remote'],
        cwd: repoPath,
        successExitCodes: {0, 1},
      );
      final m = await git.run(
        ['config', '--get', '--', 'branch.${branch.name}.merge'],
        cwd: repoPath,
        successExitCodes: {0, 1},
      );
      remote = r.stdout.trim();
      merge = m.stdout.trim();
    }
    if (remote == null || remote.isEmpty || remote == '.' || merge == null || merge.isEmpty) {
      throw ArgumentError('No remote upstream');
    }
    _validateName(remote);
    _validateName(merge);
    await git.run(['push', '--delete', '--', remote, merge], cwd: repoPath);
    if (branch.type == BranchType.remote &&
        !(await getBranches(git, repoPath)).any((b) => b.type == BranchType.remote && b.name == branch.name)) {
      return;
    }
  }
  await git.run([
    'branch',
    if (branch.type == BranchType.remote) '-r',
    force ? '-D' : '-d',
    '--',
    branch.name,
  ], cwd: repoPath);
}
