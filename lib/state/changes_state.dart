import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/git/diff.dart';
import '../core/models/diff.dart';
import '../core/models/status.dart';
import 'app_state.dart';
import 'repo_state.dart';

class ChangesState {
  const ChangesState({
    this.selections = const {},
    this.selectedPath,
    this.summary = '',
    this.description = '',
    this.amend = false,
  });

  final Map<String, DiffSelection> selections;
  final String? selectedPath;
  final String summary;
  final String description;
  final bool amend;

  int get includedCount => selections.values.where((s) => s.selectionType != SelectionType.none).length;

  ChangesState copyWith({
    Map<String, DiffSelection>? selections,
    String? selectedPath,
    bool clearPath = false,
    String? summary,
    String? description,
    bool? amend,
  }) => ChangesState(
    selections: selections ?? this.selections,
    selectedPath: clearPath ? null : selectedPath ?? this.selectedPath,
    summary: summary ?? this.summary,
    description: description ?? this.description,
    amend: amend ?? this.amend,
  );
}

class ChangesNotifier extends Notifier<ChangesState> {
  ChangesNotifier(this.repoId);
  final String repoId;

  @override
  ChangesState build() {
    ref.listen(repoStatusProvider(repoId), (_, next) {
      final status = next.value;
      if (status != null) reconcile(status.files);
    });
    final files = ref.read(repoStatusProvider(repoId)).value?.files ?? const <WorkingFile>[];
    return ChangesState(
      selections: {for (final f in files) f.path: DiffSelection.all()},
      selectedPath: files.firstOrNull?.path,
    );
  }

  void reconcile(List<WorkingFile> files) {
    final selections = {for (final f in files) f.path: state.selections[f.path] ?? DiffSelection.all()};
    final path = selections.containsKey(state.selectedPath) ? state.selectedPath : files.firstOrNull?.path;
    state = state.copyWith(selections: selections, selectedPath: path, clearPath: path == null);
  }

  void selectFile(String path) => state = state.copyWith(selectedPath: path);
  void selectLines(String path, DiffSelection selection) {
    if (!state.selections.containsKey(path)) return;
    state = state.copyWith(selections: {...state.selections, path: selection});
  }

  void alignDiff(String path, FileDiff diff) {
    final text = switch (diff) {
      TextDiff d => d,
      LargeDiff d => d.diff,
      _ => null,
    };
    final current = state.selections[path];
    if (text != null && current != null) selectLines(path, current.withSelectableLines(text.selectableLines));
  }

  void selectAll(bool selected) => state = state.copyWith(
    selections: {
      for (final e in state.selections.entries) e.key: selected ? e.value.withSelectAll() : e.value.withSelectNone(),
    },
  );
  void draft({String? summary, String? description, bool? amend}) =>
      state = state.copyWith(summary: summary, description: description, amend: amend);
  void clearDraft() => draft(summary: '', description: '', amend: false);
}

final changesProvider = NotifierProvider.family<ChangesNotifier, ChangesState, String>(ChangesNotifier.new);

/// Status refreshes also reload the diff; only surviving line indices are retained.
final workingDiffProvider = FutureProvider.autoDispose.family<FileDiff, ({String repoId, String path})>((
  ref,
  key,
) async {
  final status = await ref.watch(repoStatusProvider(key.repoId).future);
  final repo = ref.watch(libraryProvider).repositories.firstWhere((r) => r.id == key.repoId);
  final file = status.files.firstWhere((f) => f.path == key.path);
  final diff = await getWorkingDiff(ref.watch(gitProvider), repo.path, file);
  if (ref.mounted) ref.read(changesProvider(key.repoId).notifier).alignDiff(key.path, diff);
  return diff;
});
