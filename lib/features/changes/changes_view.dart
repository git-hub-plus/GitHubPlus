import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/git/commit.dart';
import '../../core/git/discard.dart';
import '../../core/git/git_runner.dart';
import '../../core/models/app_models.dart';
import '../../core/models/diff.dart';
import '../../core/models/status.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/terms.dart';
import '../../state/app_state.dart';
import '../../state/changes_state.dart';
import '../../state/repo_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/diff_view.dart';
import '../../ui/widgets/feedback.dart';
import '../../ui/widgets/hud.dart';

/// Changed files, line selection and a repository-specific commit draft.
class ChangesView extends ConsumerStatefulWidget {
  const ChangesView({super.key, required this.repo});
  final RepositoryInfo repo;

  @override
  ConsumerState<ChangesView> createState() => _ChangesViewState();
}

class _ChangesViewState extends ConsumerState<ChangesView> {
  double _panelWidth = 340;
  bool _busy = false;
  final _summary = TextEditingController();
  final _description = TextEditingController();
  ChangesNotifier get _controller => ref.read(changesProvider(widget.repo.id).notifier);

  @override
  void dispose() {
    _summary.dispose();
    _description.dispose();
    super.dispose();
  }

  void _syncText(TextEditingController controller, String text) {
    if (controller.text != text) {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _error(Object error) {
    if (!mounted) return;
    showGhpToast(
      context,
      L10n.of(context).changesFailed,
      tone: ToastTone.error,
      detail: redactCredentials(error.toString()),
    );
  }

  Future<void> _amend(bool enabled) async {
    if (_busy) return;
    if (!enabled) {
      _controller.draft(amend: false);
      return;
    }
    final repo = widget.repo;
    setState(() => _busy = true);
    try {
      final result = await ref.read(gitProvider).run(['log', '-1', '--format=%B', '--'], cwd: repo.path);
      if (!mounted || widget.repo.id != repo.id) return;
      final lines = result.stdout.trimRight().split('\n');
      _controller.draft(amend: true, summary: lines.first, description: lines.skip(1).join('\n').trim());
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _canCommit(ChangesState draft, RepoStatus status) =>
      !_busy && draft.summary.trim().isNotEmpty && draft.includedCount > 0 && status.conflictCount == 0;

  Future<void> _commit() async {
    final repo = widget.repo;
    final draft = ref.read(changesProvider(repo.id));
    final status = ref.read(repoStatusProvider(repo.id)).value;
    if (status == null || !_canCommit(draft, status)) return;
    setState(() => _busy = true);
    try {
      final files = <CommitFileSelection>[];
      for (final file in status.files) {
        final selection = draft.selections[file.path];
        if (selection == null || selection.selectionType == SelectionType.none) continue;
        TextDiff? text;
        if (selection.selectionType == SelectionType.partial) {
          final diff = await ref.read(workingDiffProvider((repoId: repo.id, path: file.path)).future);
          text = switch (diff) {
            TextDiff d => d,
            LargeDiff d => d.diff,
            _ => null,
          };
          if (text == null) throw StateError('Partial selection requires a text diff');
        }
        files.add(CommitFileSelection(file: file, selection: selection, diff: text));
      }
      final sha = await createCommit(
        ref.read(gitProvider),
        repo.path,
        message: '${draft.summary.trim()}${draft.description.trim().isEmpty ? '' : '\n\n${draft.description.trim()}'}',
        files: files,
        amend: draft.amend,
      );
      ref.read(changesProvider(repo.id).notifier).clearDraft();
      ref.invalidate(repoStatusProvider(repo.id));
      ref.invalidate(todayCommitsProvider(repo.id));
      if (mounted) {
        showGhpToast(
          context,
          L10n.of(context).changesCommitted(Terms.of(context).commit, sha.substring(0, 7)),
          tone: ToastTone.success,
        );
      }
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openBackup(String path) async {
    try {
      final systemRoot = Platform.environment['SystemRoot'];
      if (systemRoot == null || !p.isAbsolute(systemRoot)) throw StateError('SystemRoot is unavailable');
      await Process.start(p.join(systemRoot, 'explorer.exe'), [path]);
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _discard(List<WorkingFile> files) async {
    if (_busy) return;
    final repo = widget.repo;
    final l = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.changesDiscardTitle(files.length)),
        content: Text(l.changesDiscardBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.changesCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.changesDiscard)),
        ],
      ),
    );
    if (confirmed != true || !mounted || widget.repo.id != repo.id || _busy) return;
    setState(() => _busy = true);
    try {
      final backup = await discardChanges(
        ref.read(gitProvider),
        repo.path,
        files,
        backupDirectory: p.join(ref.read(bootstrapProvider).dataDirectory.path, 'discarded'),
      );
      ref.invalidate(repoStatusProvider(repo.id));
      if (!mounted) return;
      // The shared toast has no action slot; this backup toast keeps its path clickable.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: context.colors.raised,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.changesDiscarded, style: TextStyle(color: context.colors.success)),
              TextButton(onPressed: () => _openBackup(backup), child: Text(backup)),
            ],
          ),
        ),
      );
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _menu(WorkingFile file, Offset position) async {
    final l = L10n.of(context);
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(position & Size.zero, Offset.zero & overlay.size),
      items: [
        PopupMenuItem(value: 'discard', enabled: !_busy, child: Text(l.changesDiscard)),
        PopupMenuItem(value: 'copy', child: Text(l.changesCopyPath)),
      ],
    );
    if (!mounted) return;
    if (choice == 'discard') await _discard([file]);
    if (choice == 'copy') await Clipboard.setData(ClipboardData(text: file.path));
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(repoStatusProvider(widget.repo.id));
    final draft = ref.watch(changesProvider(widget.repo.id));
    _syncText(_summary, draft.summary);
    _syncText(_description, draft.description);
    final l = L10n.of(context);
    return status.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _failure(e, () => ref.invalidate(repoStatusProvider(widget.repo.id))),
      data: (status) => CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.enter, control: true): _commit},
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = _panelWidth.clamp(260.0, (constraints.maxWidth - 180).clamp(260.0, 700.0));
              return Row(
                children: [
                  SizedBox(
                    width: width,
                    child: ColoredBox(
                      color: context.colors.surface,
                      child: Column(
                        children: [
                          if (status.conflictCount > 0)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(Space.sm),
                              color: context.colors.warning.withValues(alpha: 0.15),
                              child: Text(
                                l.changesConflicts(status.conflictCount),
                                style: TextStyle(color: context.colors.warning),
                              ),
                            ),
                          _fileHeader(draft, status),
                          Expanded(
                            child: status.files.isEmpty
                                ? _empty(status)
                                : ListView.builder(
                                    itemCount: status.files.length,
                                    itemBuilder: (context, index) => _fileRow(status.files[index], draft),
                                  ),
                          ),
                          const Divider(height: 1),
                          _commitBox(draft, status),
                        ],
                      ),
                    ),
                  ),
                  Semantics(
                    label: l.changesResize,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                        key: const Key('changes-resize'),
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (details) => setState(
                          () => _panelWidth = (width + details.delta.dx).clamp(
                            260.0,
                            (constraints.maxWidth - 180).clamp(260.0, 700.0),
                          ),
                        ),
                        child: SizedBox(
                          width: Space.sm,
                          child: Center(child: Container(width: 1, color: context.colors.border)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _diff(draft, status)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _fileHeader(ChangesState draft, RepoStatus status) {
    final l = L10n.of(context);
    final types = draft.selections.values.map((s) => s.selectionType);
    final bool? checked = types.isEmpty || types.every((t) => t == SelectionType.none)
        ? false
        : types.every((t) => t == SelectionType.all)
        ? true
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
      child: Row(
        children: [
          Checkbox(
            key: const Key('changes-all'),
            tristate: true,
            value: checked,
            semanticLabel: l.changesSelectAll,
            onChanged: _busy || status.files.isEmpty ? null : (_) => _controller.selectAll(checked != true),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.changesSelectAll, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  l.changesIncluded(status.files.length, draft.includedCount),
                  style: TextStyle(color: context.colors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileRow(WorkingFile file, ChangesState draft) {
    final selection = draft.selections[file.path] ?? DiffSelection.all();
    final checked = switch (selection.selectionType) {
      SelectionType.all => true,
      SelectionType.none => false,
      SelectionType.partial => null,
    };
    return GestureDetector(
      onSecondaryTapDown: (details) => _menu(file, details.globalPosition),
      child: Material(
        color: draft.selectedPath == file.path ? context.colors.accentSoft : context.colors.surface,
        child: InkWell(
          onTap: () => _controller.selectFile(file.path),
          child: Padding(
            padding: const EdgeInsets.only(right: Space.sm),
            child: Row(
              children: [
                Checkbox(
                  key: ValueKey('include-${file.path}'),
                  tristate: true,
                  value: checked,
                  semanticLabel: file.path,
                  onChanged: _busy
                      ? null
                      : (_) => _controller.selectLines(
                          file.path,
                          checked == true ? selection.withSelectNone() : selection.withSelectAll(),
                        ),
                ),
                _badge(file),
                const SizedBox(width: Space.sm),
                Expanded(child: _path(file)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _path(WorkingFile file) {
    final path = file.path;
    final slash = path.lastIndexOf('/');
    return Tooltip(
      message: file.status.oldPath == null ? path : '${file.status.oldPath} → $path',
      child: Text.rich(
        TextSpan(
          children: [
            if (file.status.oldPath != null)
              TextSpan(
                text: '${file.status.oldPath} → ',
                style: TextStyle(color: context.colors.muted),
              ),
            if (slash >= 0)
              TextSpan(
                text: path.substring(0, slash + 1),
                style: TextStyle(color: context.colors.muted),
              ),
            TextSpan(
              text: path.substring(slash + 1),
              style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _badge(WorkingFile file) {
    final l = L10n.of(context);
    final c = context.colors;
    final (label, color) = switch (file.status.kind) {
      FileStatusKind.added || FileStatusKind.untracked || FileStatusKind.copied => (l.changesAdded, c.success),
      FileStatusKind.modified => (l.changesModified, c.warning),
      FileStatusKind.deleted => (l.changesDeleted, c.danger),
      FileStatusKind.renamed => (l.changesRenamed, c.accent),
      FileStatusKind.conflicted => (l.changesConflict(file.status.conflictMarkerCount?.toString() ?? '—'), c.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xs),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.sm)),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _commitBox(ChangesState draft, RepoStatus status) {
    final l = L10n.of(context);
    final t = Terms.of(context);
    final remaining = 72 - draft.summary.characters.length;
    final color = remaining < 0 ? context.colors.warning : context.colors.accent;
    return Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('changes-summary'),
            controller: _summary,
            enabled: !_busy,
            decoration: InputDecoration(labelText: l.changesSummary),
            style: TextStyle(color: remaining < 0 ? context.colors.warning : context.colors.text),
            onChanged: (value) => _controller.draft(summary: value),
          ),
          const SizedBox(height: Space.xs),
          GaugeBar(fraction: remaining / 72, color: color),
          Text(l.changesRemaining(remaining), style: TextStyle(color: color, fontSize: 11)),
          const SizedBox(height: Space.sm),
          TextField(
            key: const Key('changes-description'),
            controller: _description,
            enabled: !_busy,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(labelText: l.changesDescription),
            onChanged: (value) => _controller.draft(description: value),
          ),
          Row(
            children: [
              Checkbox(
                key: const Key('changes-amend'),
                value: draft.amend,
                onChanged: _busy || status.headSha == null ? null : (v) => _amend(v ?? false),
              ),
              Expanded(child: Text(l.changesAmend(t.commitUnit), style: const TextStyle(fontSize: 12))),
            ],
          ),
          FilledButton.icon(
            key: const Key('changes-commit'),
            onPressed: _canCommit(draft, status) ? _commit : null,
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(Space.md)),
            icon: Icon(_busy ? Icons.hourglass_top_rounded : Icons.check_circle_outline_rounded),
            label: Text(
              _busy ? l.changesBusy : l.changesCommit(status.currentBranch ?? l.changesDetached, t.commit),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(RepoStatus status) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 32, color: context.colors.success),
          const SizedBox(height: Space.sm),
          Text(L10n.of(context).changesSaved),
          const SizedBox(height: Space.sm),
          Text(
            L10n.of(context).changesEmptyHint(Terms.of(context).push, status.toPush),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget _failure(Object e, VoidCallback retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(L10n.of(context).changesFailed),
          Text(
            redactCredentials(e.toString()),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.colors.muted),
          ),
          TextButton(onPressed: retry, child: Text(L10n.of(context).changesRetry)),
        ],
      ),
    ),
  );

  Widget _diff(ChangesState draft, RepoStatus status) {
    final file = status.files.where((f) => f.path == draft.selectedPath).firstOrNull;
    if (file == null) {
      return Center(
        child: Text(L10n.of(context).changesPickFile, style: TextStyle(color: context.colors.muted)),
      );
    }
    final key = (repoId: widget.repo.id, path: file.path);
    final diff = ref.watch(workingDiffProvider(key));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: Row(
            children: [
              Expanded(child: _path(file)),
              const SizedBox(width: Space.sm),
              TextButton.icon(
                onPressed: _busy ? null : () => _discard([file]),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(L10n.of(context).changesDiscardFile),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: diff.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _failure(e, () => ref.invalidate(workingDiffProvider(key))),
            data: (value) => FileDiffView(
              key: ValueKey(file.path),
              diff: value,
              selection: draft.selections[file.path],
              onSelectionChanged: _busy ? null : (selection) => _controller.selectLines(file.path, selection),
            ),
          ),
        ),
      ],
    );
  }
}
