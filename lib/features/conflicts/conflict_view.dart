import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/git/conflict_markers.dart';
import '../../core/git/merge.dart';
import '../../core/git/stage.dart';
import '../../core/git/git_runner.dart';
import '../../core/models/advanced.dart';
import '../../core/models/app_models.dart';
import '../../core/models/status.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../state/changes_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/feedback.dart';

class ConflictView extends ConsumerStatefulWidget {
  const ConflictView({super.key, required this.repo, required this.file});
  final RepositoryInfo repo;
  final WorkingFile file;
  @override
  ConsumerState<ConflictView> createState() => _ConflictViewState();
}

class _ConflictViewState extends ConsumerState<ConflictView> {
  late Future<String?> _source = _load();
  final _choices = <int, ConflictChoice>{};
  bool _busy = false;

  Future<String?> _load() async {
    final full = await safeWorkingPath(widget.repo.path, widget.file.path);
    // A leaf symlink must never be followed when reading or replacing a file.
    if (await FileSystemEntity.type(full, followLinks: false) != FileSystemEntityType.file) return null;
    final file = File(full);
    if (await file.length() > 2 * 1024 * 1024) return null;
    final bytes = await file.readAsBytes();
    if (bytes.contains(0)) return null;
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return null;
    }
  }

  Future<void> _resolve({ConflictSide? side, String? source}) async {
    if (_busy) return;
    final l = L10n.of(context);
    final refresh = ref.read(changesProvider(widget.repo.id).notifier).refreshStatus;
    setState(() => _busy = true);
    try {
      final git = ref.read(gitProvider);
      await withRepositoryOperation(widget.repo.path, () async {
        if (side != null) {
          await resolveConflictWithSide(git, widget.repo.path, widget.file.path, side);
        } else {
          if (source == null || await _load() != source) throw StateError(l.conflictStale);
          final full = await safeWorkingPath(widget.repo.path, widget.file.path);
          await File(full).writeAsString(applyConflictChoices(source, _choices), flush: true);
          await markResolved(git, widget.repo.path, [widget.file.path]);
        }
      });
    } catch (error) {
      if (mounted) {
        showGhpToast(context, l.changesFailed, tone: ToastTone.error, detail: redactCredentials(error.toString()));
      }
    } finally {
      refresh();
      if (mounted) {
        setState(() {
          _busy = false;
          _choices.clear();
          _source = _load();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.file.path, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              OutlinedButton(
                key: const Key('conflict-all-ours'),
                onPressed: _busy ? null : () => _resolve(side: ConflictSide.ours),
                child: Text(l.conflictAllOurs),
              ),
              OutlinedButton(
                key: const Key('conflict-all-theirs'),
                onPressed: _busy ? null : () => _resolve(side: ConflictSide.theirs),
                child: Text(l.conflictAllTheirs),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: Space.md),
          Expanded(
            child: FutureBuilder<String?>(
              future: _source,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return Center(child: Text(redactCredentials(snapshot.error.toString())));
                final source = snapshot.data;
                final regions = source == null ? <ConflictRegion>[] : parseConflictMarkers(source);
                if (regions.isEmpty) return Center(child: Text(l.conflictSideOnly));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          for (final region in regions)
                            Padding(
                              padding: const EdgeInsets.only(bottom: Space.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Wrap(
                                    spacing: Space.sm,
                                    runSpacing: Space.xs,
                                    children: [
                                      for (final choice in ConflictChoice.values)
                                        ChoiceChip(
                                          key: ValueKey('conflict-${region.index}-${choice.name}'),
                                          label: Text(switch (choice) {
                                            ConflictChoice.ours => l.conflictOurs,
                                            ConflictChoice.theirs => l.conflictTheirs,
                                            ConflictChoice.both => l.conflictBoth,
                                          }),
                                          selected: _choices[region.index] == choice,
                                          onSelected: _busy
                                              ? null
                                              : (_) => setState(() => _choices[region.index] = choice),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: Space.sm),
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(child: _side(region.oursLabel ?? l.conflictOurs, region.ours)),
                                        const SizedBox(width: Space.sm),
                                        Expanded(child: _side(region.theirsLabel ?? l.conflictTheirs, region.theirs)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    FilledButton(
                      key: const Key('conflict-save'),
                      onPressed: !_busy && _choices.length == regions.length ? () => _resolve(source: source) : null,
                      child: Text(l.conflictSave),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _side(String label, List<String> lines) => Container(
    padding: const EdgeInsets.all(Space.sm),
    decoration: BoxDecoration(
      color: context.colors.surface,
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(Radii.sm),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.colors.accent, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: Space.sm),
        SelectableText(
          lines.join('\n'),
          style: TextStyle(fontFamily: 'monospace', color: context.colors.text),
        ),
      ],
    ),
  );
}
