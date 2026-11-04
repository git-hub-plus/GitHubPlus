import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/git/diff.dart';
import '../core/git/git_runner.dart';
import '../core/git/log.dart';
import '../core/expeditions/expedition.dart';
import '../core/history/graph.dart';
import '../core/models/app_models.dart';
import '../core/models/commit.dart';
import '../core/models/diff.dart';
import 'app_state.dart';
import 'repo_state.dart';

class HistoryState {
  const HistoryState({
    this.commits = const [],
    this.graph = const [],
    this.selected,
    this.file,
    this.query = '',
    this.all = false,
    this.loading = true,
    this.hasMore = true,
    this.error,
  });
  final List<Commit> commits;
  final List<GraphRow> graph;
  final Commit? selected;
  final CommittedFile? file;
  final String query;
  final bool all;
  final bool loading;
  final bool hasMore;
  final String? error;

  List<int> get visibleIndices {
    final q = query.trim().toLowerCase();
    return [
      for (var i = 0; i < commits.length; i++)
        if (q.isEmpty ||
            commits[i].summary.toLowerCase().contains(q) ||
            commits[i].author.name.toLowerCase().contains(q))
          i,
    ];
  }

  HistoryState copy({
    List<Commit>? commits,
    List<GraphRow>? graph,
    Commit? selected,
    CommittedFile? file,
    bool clearFile = false,
    String? query,
    bool? all,
    bool? loading,
    bool? hasMore,
    String? error,
    bool clearSelection = false,
  }) => HistoryState(
    commits: commits ?? this.commits,
    graph: graph ?? this.graph,
    selected: clearSelection ? null : selected ?? this.selected,
    file: clearFile || clearSelection ? null : file ?? this.file,
    query: query ?? this.query,
    all: all ?? this.all,
    loading: loading ?? this.loading,
    hasMore: hasMore ?? this.hasMore,
    error: error,
  );
}

/// Per-repository history. Request generations keep obsolete pages out after a refresh.
class HistoryNotifier extends Notifier<HistoryState> {
  HistoryNotifier(this.repo);
  final RepositoryInfo repo;
  int _generation = 0;

  @override
  HistoryState build() {
    var statusSeen = ref.read(repoStatusProvider(repo.id)).hasValue;
    ref.listen(repoStatusProvider(repo.id), (previous, next) {
      if (next.hasValue && !next.isLoading) {
        // The initial status and first page load together. Do not discard a
        // user's selection when that initial status request completes later.
        if (statusSeen || (!state.loading && !state.all && next.value?.headSha != state.commits.firstOrNull?.sha)) {
          unawaited(refresh());
        }
        statusSeen = true;
      }
    });
    scheduleMicrotask(refresh);
    return const HistoryState();
  }

  Future<void> refresh({bool? all}) async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    final mode = all ?? state.all;
    state = HistoryState(query: state.query, all: mode);
    await _load(generation, first: true);
  }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    state = state.copy(loading: true);
    await _load(_generation, first: false);
  }

  Future<void> _load(int generation, {required bool first}) async {
    try {
      final page = await getCommits(
        ref.read(gitProvider),
        repo.path,
        skip: first ? 0 : state.commits.length,
        all: state.all,
      );
      if (!ref.mounted || generation != _generation) return;
      final commits = [if (!first) ...state.commits, ...page];
      state = state.copy(
        commits: commits,
        graph: layoutGraph(commits),
        loading: false,
        hasMore: page.length == 200,
        selected: first ? commits.firstOrNull : null,
        clearSelection: commits.isEmpty,
        clearFile: first,
      );
    } catch (error) {
      if (ref.mounted && generation == _generation) {
        state = state.copy(loading: false, error: redactCredentials(error.toString()));
      }
    }
  }

  void filter(String query) => state = state.copy(query: query);
  void select(Commit commit) => state = state.copy(selected: commit, clearFile: true);
  void selectFile(CommittedFile file) => state = state.copy(file: file);

  Future<void> selectSha(String sha) async {
    final generation = _generation;
    state = state.copy(query: '');
    while (ref.mounted && generation == _generation) {
      final commit = state.commits.where((c) => c.sha == sha).firstOrNull;
      if (commit != null) {
        select(commit);
        return;
      }
      if (!state.hasMore || state.loading || state.error != null) return;
      await loadMore();
    }
  }
}

final historyProvider = NotifierProvider.autoDispose.family<HistoryNotifier, HistoryState, RepositoryInfo>(
  HistoryNotifier.new,
);

typedef CommitLocation = ({String path, String sha});
final historyFilesProvider = FutureProvider.autoDispose.family<List<CommittedFile>, CommitLocation>(
  (ref, key) => getCommitFiles(ref.watch(gitProvider), key.path, key.sha),
);
typedef HistoryDiffLocation = ({String path, String sha, CommittedFile file});
final historyDiffProvider = FutureProvider.autoDispose.family<FileDiff, HistoryDiffLocation>(
  (ref, key) => getCommitDiff(ref.watch(gitProvider), key.path, key.sha, key.file),
);

/// Complete first-parent order, independent of history paging and filtering.
final historyOrderProvider = FutureProvider.family<List<String>, RepositoryInfo>((ref, repo) async {
  ref.watch(repoStatusProvider(repo.id));
  final result = await ref.watch(gitProvider).run(['rev-list', '--first-parent', 'HEAD', '--'], cwd: repo.path);
  return result.stdout.trim().split('\n').where((s) => s.isNotEmpty).toList();
});

typedef HistoryMembership = ({RepositoryInfo repo, String sha});
final historyMembershipProvider = FutureProvider.family<({bool current, bool published}), HistoryMembership>((
  ref,
  key,
) async {
  ref.watch(repoStatusProvider(key.repo.id));
  if (!RegExp(r'^[0-9a-fA-F]{40,64}$').hasMatch(key.sha)) throw ArgumentError('Invalid SHA');
  final git = ref.watch(gitProvider);
  final current = await git.run(
    ['merge-base', '--is-ancestor', key.sha, 'HEAD'],
    cwd: key.repo.path,
    successExitCodes: {0, 1},
  );
  final published = await git.run([
    'for-each-ref',
    '--contains=${key.sha}',
    '--format=%(refname)',
    '--',
    'refs/remotes/',
  ], cwd: key.repo.path);
  return (current: current.exitCode == 0, published: published.stdout.trim().isNotEmpty);
});

/// Serializes mutations from both panels and keeps the expedition alive when a panel closes.
class RepositoryActionNotifier extends Notifier<bool> {
  RepositoryActionNotifier(this.repo);
  final RepositoryInfo repo;
  @override
  bool build() => false;

  Future<T> run<T>({
    required String title,
    required Future<T> Function() task,
    ExpeditionKind kind = ExpeditionKind.rebase,
    String Function(T)? describe,
  }) async {
    if (state) throw StateError('An operation is already running');
    state = true;
    Object? failure;
    try {
      final result = await ref
          .read(expeditionsProvider.notifier)
          .run<T>(
            kind: kind,
            title: title,
            destination: repo.name,
            repoId: repo.id,
            task: (_) async {
              try {
                return await task();
              } catch (error) {
                failure = StateError(redactCredentials(error.toString()));
                throw failure!;
              }
            },
            result: describe,
          );
      if (failure != null) throw failure!;
      return result as T;
    } finally {
      if (ref.mounted) {
        try {
          ref.invalidate(repoStatusProvider(repo.id));
          await ref.read(repoStatusProvider(repo.id).future);
          if (ref.mounted) {
            ref.invalidate(historyOrderProvider(repo));
            ref.invalidate(historyMembershipProvider);
            await ref.read(historyProvider(repo).notifier).refresh();
          }
        } finally {
          if (ref.mounted) state = false;
        }
      }
    }
  }
}

final repositoryActionProvider = NotifierProvider.family<RepositoryActionNotifier, bool, RepositoryInfo>(
  RepositoryActionNotifier.new,
);
