// Fetch / pull / push with progress (ported from GitHub Desktop (MIT):
// app/src/lib/git/{fetch,pull,push}.ts via GitHub+ v1).
import 'git_runner.dart';
import 'progress.dart';

typedef ProgressReport = void Function(double value, String? stage);

/// What an expedition brought back.
class SyncOutcome {
  const SyncOutcome({this.received = 0, this.sent = 0});

  /// Commits that arrived from the remote.
  final int received;

  /// Commits that went to the remote.
  final int sent;
}

Future<String?> _revParse(GitRunner git, String repo, String ref) async {
  // Missing refs (no upstream, unborn HEAD) exit 1 or 128; both mean "none".
  final result = await git.run(['rev-parse', '--verify', '--quiet', ref], cwd: repo, successExitCodes: {0, 1, 128});
  final sha = result.stdout.trim();
  return result.exitCode == 0 && sha.isNotEmpty ? sha : null;
}

Future<int> _count(GitRunner git, String repo, List<String> revisions) async {
  final result = await git.run(['rev-list', '--count', ...revisions], cwd: repo, successExitCodes: {0, 128});
  return result.exitCode == 0 ? int.tryParse(result.stdout.trim()) ?? 0 : 0;
}

void Function(String) _progress(List<ProgressStep> steps, ProgressReport? report) {
  final parser = WeightedProgress(steps);
  return (line) {
    final update = parser.feed(line);
    if (update != null) report?.call(update.value, update.title);
  };
}

Future<SyncOutcome> fetch(GitRunner git, String repo, {String remote = 'origin', ProgressReport? onProgress}) async {
  final before = await _revParse(git, repo, '@{upstream}');
  await git.run(
    ['fetch', '--progress', '--prune', remote],
    cwd: repo,
    onStderrLine: _progress(WeightedProgress.fetch, onProgress),
  );
  final after = await _revParse(git, repo, '@{upstream}');
  final received = before != null && after != null && before != after ? await _count(git, repo, ['$before..$after']) : 0;
  return SyncOutcome(received: received);
}

/// Pulls with the user's `pull.rebase` preference, defaulting to merge.
Future<SyncOutcome> pull(GitRunner git, String repo, {String remote = 'origin', ProgressReport? onProgress}) async {
  final before = await _revParse(git, repo, 'HEAD');
  final rebase = await git.run(['config', '--get', 'pull.rebase'], cwd: repo, successExitCodes: {0, 1});
  await git.run(
    ['pull', '--progress', if (rebase.stdout.trim().isEmpty) '--no-rebase', remote],
    cwd: repo,
    onStderrLine: _progress(WeightedProgress.fetch, onProgress),
  );
  final after = await _revParse(git, repo, 'HEAD');
  final received = before != null && after != null && before != after ? await _count(git, repo, ['$before..$after']) : 0;
  return SyncOutcome(received: received);
}

Future<SyncOutcome> push(
  GitRunner git,
  String repo, {
  String remote = 'origin',
  String? branch,
  bool setUpstream = false,
  ProgressReport? onProgress,
}) async {
  final upstream = await _revParse(git, repo, '@{upstream}');
  final sent = upstream != null
      ? await _count(git, repo, ['$upstream..HEAD'])
      : await _count(git, repo, ['HEAD', '--not', '--remotes']);
  await git.run(
    ['push', '--progress', if (setUpstream) '-u', remote, if (branch != null) branch else 'HEAD'],
    cwd: repo,
    onStderrLine: _progress(WeightedProgress.push, onProgress),
  );
  return SyncOutcome(sent: sent);
}
