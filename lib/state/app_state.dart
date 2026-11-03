import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/expeditions/expedition.dart';
import '../core/git/git_runner.dart';
import '../core/models/app_models.dart';
import '../core/storage/json_file.dart';
import '../core/storage/repository_store.dart';

/// Everything loaded before the first frame (see main.dart).
class Bootstrap {
  const Bootstrap({
    required this.dataDirectory,
    required this.git,
    required this.repositoryStore,
    required this.settings,
    required this.repositories,
  });

  final Directory dataDirectory;
  final GitRunner git;
  final RepositoryStore repositoryStore;
  final AppSettings settings;
  final List<RepositoryInfo> repositories;

  File get settingsFile => File(p.join(dataDirectory.path, 'settings.json'));
}

final bootstrapProvider = Provider<Bootstrap>((ref) => throw StateError('bootstrapProvider must be overridden'));

final gitProvider = Provider<GitRunner>((ref) => ref.watch(bootstrapProvider).git);

// --- Settings -----------------------------------------------------------------

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(bootstrapProvider).settings;

  Future<void> update(AppSettings Function(AppSettings current) change) async {
    state = change(state);
    await writeJsonFile(ref.read(bootstrapProvider).settingsFile, state.toJson());
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// --- Library ------------------------------------------------------------------

class LibraryState {
  const LibraryState({required this.repositories, this.selectedId});

  final List<RepositoryInfo> repositories;
  final String? selectedId;

  RepositoryInfo? get selected =>
      selectedId == null ? null : repositories.where((r) => r.id == selectedId).firstOrNull;

  LibraryState copyWith({List<RepositoryInfo>? repositories, String? selectedId}) =>
      LibraryState(repositories: repositories ?? this.repositories, selectedId: selectedId ?? this.selectedId);
}

class LibraryNotifier extends Notifier<LibraryState> {
  RepositoryStore get _store => ref.read(bootstrapProvider).repositoryStore;

  @override
  LibraryState build() {
    final repositories = ref.read(bootstrapProvider).repositories;
    final recent = [...repositories]
      ..sort((a, b) => (b.lastOpenedAt ?? b.addedAt).compareTo(a.lastOpenedAt ?? a.addedAt));
    return LibraryState(repositories: repositories, selectedId: recent.firstOrNull?.id);
  }

  Future<void> _replace(List<RepositoryInfo> repositories, {String? selectedId}) async {
    state = LibraryState(repositories: repositories, selectedId: selectedId ?? state.selectedId);
    await _store.save(repositories);
  }

  /// Adds an existing repository folder; throws [NotARepositoryException].
  Future<RepositoryInfo> add(String path) async {
    final info = await _store.describe(path);
    final existing = state.repositories.where((r) => r.id == info.id).firstOrNull;
    if (existing != null) {
      await select(existing.id);
      return existing;
    }
    await _replace([...state.repositories, info], selectedId: info.id);
    return info;
  }

  Future<void> select(String id) async {
    final now = DateTime.now();
    await _replace(
      [for (final r in state.repositories) r.id == id ? r.copyWith(lastOpenedAt: now) : r],
      selectedId: id,
    );
  }

  Future<void> remove(String id) async {
    final remaining = state.repositories.where((r) => r.id != id).toList();
    state = LibraryState(
      repositories: remaining,
      selectedId: state.selectedId == id ? remaining.firstOrNull?.id : state.selectedId,
    );
    await _store.save(remaining);
  }

  Future<void> update(String id, RepositoryInfo Function(RepositoryInfo r) change) =>
      _replace([for (final r in state.repositories) r.id == id ? change(r) : r]);
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(LibraryNotifier.new);

// --- Expeditions --------------------------------------------------------------

class ExpeditionsNotifier extends Notifier<List<Expedition>> {
  var _counter = 0;

  @override
  List<Expedition> build() => const [];

  /// Starts an expedition and returns its id for [progress]/[finish].
  String start({
    required ExpeditionKind kind,
    required String title,
    required String destination,
    String? repoId,
  }) {
    final id = 'exp-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
    state = [
      Expedition(id: id, kind: kind, title: title, destination: destination, repoId: repoId, startedAt: DateTime.now()),
      ...state,
    ];
    return id;
  }

  void _edit(String id, Expedition Function(Expedition e) change) =>
      state = [for (final e in state) e.id == id ? change(e) : e];

  void progress(String id, double value, {String? stage}) =>
      _edit(id, (e) => e.isRunning ? e.copyWith(progress: value.clamp(0, 1), stage: stage) : e);

  void succeed(String id, {String? result}) => _edit(
    id,
    (e) => e.copyWith(status: ExpeditionStatus.succeeded, progress: 1, finishedAt: DateTime.now(), result: result),
  );

  void fail(String id, String error) =>
      _edit(id, (e) => e.copyWith(status: ExpeditionStatus.failed, finishedAt: DateTime.now(), error: error));

  /// "보상 수령": marks a finished expedition as seen.
  void collect(String id) => _edit(id, (e) => e.copyWith(seen: true));

  void dismiss(String id) => state = state.where((e) => e.id != id).toList();

  /// Runs [task] as an expedition, reporting failures on the card.
  Future<T?> run<T>({
    required ExpeditionKind kind,
    required String title,
    required String destination,
    String? repoId,
    required Future<T> Function(void Function(double value, String? stage) report) task,
    String? Function(T value)? result,
  }) async {
    final id = start(kind: kind, title: title, destination: destination, repoId: repoId);
    try {
      final value = await task((v, stage) => progress(id, v, stage: stage));
      succeed(id, result: result?.call(value));
      return value;
    } catch (error) {
      fail(id, error.toString());
      return null;
    }
  }
}

final expeditionsProvider = NotifierProvider<ExpeditionsNotifier, List<Expedition>>(ExpeditionsNotifier.new);

/// Number of finished expeditions whose result has not been viewed (badge).
final unseenExpeditionsProvider = Provider<int>(
  (ref) => ref.watch(expeditionsProvider).where((e) => !e.isRunning && !e.seen).length,
);
