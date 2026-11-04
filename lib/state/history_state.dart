import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/git/diff.dart';
import '../core/git/git_runner.dart';
import '../core/git/log.dart';
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
