import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/expeditions/expedition.dart';
import '../core/git/status.dart';
import '../core/git/sync.dart';
import '../core/models/app_models.dart';
import '../core/models/status.dart';
import 'app_state.dart';

RepositoryInfo? _repository(Ref ref, String repoId) =>
    ref.watch(libraryProvider).repositories.where((r) => r.id == repoId).firstOrNull;

/// Working tree status of a repository. Invalidate to refresh.
final repoStatusProvider = FutureProvider.family<RepoStatus, String>((ref, repoId) async {
  final repo = _repository(ref, repoId);
  if (repo == null) throw StateError('unknown repository $repoId');
  return getStatus(ref.watch(gitProvider), repo.path);
});

/// Today's commits by the configured user, for the daily goal bar.
final todayCommitsProvider = FutureProvider.family<int, String>((ref, repoId) async {
  final repo = _repository(ref, repoId);
  if (repo == null) return 0;
  final git = ref.watch(gitProvider);
  final email = await git.run(['config', 'user.email'], cwd: repo.path, successExitCodes: {0, 1});
  final value = email.stdout.trim();
  return countCommitsToday(git, repo.path, email: value.isEmpty ? null : value);
});

/// When each repository was last fetched in this session.
class LastFetchNotifier extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() => const {};
  void mark(String repoId) => state = {...state, repoId: DateTime.now()};
}

final lastFetchProvider = NotifierProvider<LastFetchNotifier, Map<String, DateTime>>(LastFetchNotifier.new);

/// The main button's action, chosen from the repository state.
enum PrimaryAction { resolve, commit, publish, pull, push, fetch }

PrimaryAction primaryActionFor(RepoStatus status) {
  if (status.conflictCount > 0) return PrimaryAction.resolve;
  if (status.files.isNotEmpty) return PrimaryAction.commit;
  if (status.upstream == null && status.currentBranch != null) return PrimaryAction.publish;
  if (status.behind > 0) return PrimaryAction.pull;
  if (status.ahead > 0) return PrimaryAction.push;
  return PrimaryAction.fetch;
}

/// Runs fetch/pull/push/publish as expeditions and refreshes status afterwards.
class SyncController {
  SyncController(this.ref);
  final Ref ref;

  Future<bool> run(RepositoryInfo repo, PrimaryAction action, {required String Function(SyncOutcome) describe, required String title}) async {
    final git = ref.read(gitProvider);
    final status = ref.read(repoStatusProvider(repo.id)).value;
    final remote = status?.upstream?.split('/').first ?? 'origin';
    final kind = switch (action) {
      PrimaryAction.pull => ExpeditionKind.pull,
      PrimaryAction.push => ExpeditionKind.push,
      PrimaryAction.publish => ExpeditionKind.publish,
      _ => ExpeditionKind.fetch,
    };
    final outcome = await ref.read(expeditionsProvider.notifier).run<SyncOutcome>(
      kind: kind,
      title: title,
      destination: remote,
      repoId: repo.id,
      task: (report) => switch (action) {
        PrimaryAction.pull => pull(git, repo.path, remote: remote, onProgress: report),
        PrimaryAction.push => push(git, repo.path, remote: remote, onProgress: report),
        PrimaryAction.publish => push(
          git,
          repo.path,
          remote: remote,
          branch: status?.currentBranch,
          setUpstream: true,
          onProgress: report,
        ),
        _ => fetch(git, repo.path, remote: remote, onProgress: report),
      },
      result: describe,
    );
    if (action != PrimaryAction.push) ref.read(lastFetchProvider.notifier).mark(repo.id);
    ref.invalidate(repoStatusProvider(repo.id));
    ref.invalidate(todayCommitsProvider(repo.id));
    return outcome != null;
  }
}

final syncControllerProvider = Provider<SyncController>(SyncController.new);
