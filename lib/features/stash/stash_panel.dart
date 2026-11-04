// EXTENSION POINT (owner: worker B2). Keep the public function signature.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/git/git_runner.dart';
import '../../core/git/stash.dart';
import '../../core/models/advanced.dart';
import '../../core/models/app_models.dart';
import '../../core/models/commit.dart';
import '../../core/models/status.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/terms.dart';
import '../../state/app_state.dart';
import '../../state/history_state.dart';
import '../../state/repo_state.dart';
import '../../state/stash_state.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/diff_view.dart';
import '../../ui/widgets/feedback.dart';
import '../history/action_dialogs.dart';

Future<void> showStashPanel(BuildContext context, WidgetRef ref, RepositoryInfo repo) => showDialog<void>(
  context: context,
  animationStyle: AnimationStyle(
    duration: context.motion(Motion.normal),
    reverseDuration: context.motion(Motion.normal),
  ),
  builder: (_) => _StashPanel(repo: repo),
);

class _StashPanel extends ConsumerStatefulWidget {
  const _StashPanel({required this.repo});
  final RepositoryInfo repo;
  @override
  ConsumerState<_StashPanel> createState() => _StashPanelState();
}

class _StashPanelState extends ConsumerState<_StashPanel> {
  final _message = TextEditingController();
  bool _untracked = true;
  String? _sha;
  CommittedFile? _file;
  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _run(String title, Future<OperationOutcome> Function() task, {bool creating = false}) async {
    final l = L10n.of(context);
    final done = l.historyActionDone,
        nothing = l.historyActionNothing,
        conflicts = l.historyActionConflicts(Terms.of(context).changes);
    try {
      final outcome = await ref
          .read(repositoryActionProvider(widget.repo).notifier)
          .run(
            title: title,
            task: task,
            describe: (value) => switch (value) {
              OperationOutcome.completed => done,
              OperationOutcome.nothingToDo => nothing,
              OperationOutcome.conflicts => conflicts,
            },
          );
      if (!mounted) return;
      if (creating && outcome == OperationOutcome.completed) _message.clear();
      setState(() {
        _sha = null;
        _file = null;
      });
      ref.invalidate(stashListProvider(widget.repo));
      showOutcome(context, outcome);
    } catch (error) {
      if (mounted) {
        showGhpToast(
          context,
          l.historyActionFailed,
          tone: ToastTone.error,
          detail: redactCredentials(error.toString()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    final l = L10n.of(context), t = Terms.of(context);
    final busy = ref.watch(repositoryActionProvider(repo));
    final status = ref.watch(repoStatusProvider(repo.id));
    final canCreate = status.value?.files.any((f) => _untracked || f.status.kind != FileStatusKind.untracked) ?? false;
    final entries = ref.watch(stashListProvider(repo));
    final git = ref.read(gitProvider);
    return Dialog(
      child: SizedBox(
        width: 1100,
        height: 760,
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l.stashTitle(t.stash), style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                    tooltip: l.historyActionClose,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              TextField(
                key: const Key('stash-message'),
                controller: _message,
                enabled: !busy,
                decoration: InputDecoration(labelText: l.stashMessage),
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Space.md,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(value: _untracked, onChanged: busy ? null : (v) => setState(() => _untracked = v!)),
                      Text(l.stashUntracked),
                    ],
                  ),
                  FilledButton(
                    key: const Key('stash-create'),
                    onPressed: busy || !canCreate || status.value?.inProgress != null
                        ? null
                        : () => _run(
                            l.stashCreate(t.stash),
                            () => stashCreate(
                              git,
                              repo.path,
                              message: _message.text.trim().isEmpty ? null : _message.text.trim(),
                              includeUntracked: _untracked,
                            ),
                            creating: true,
                          ),
                    child: Text(l.stashCreate(t.stash)),
                  ),
                ],
              ),
              if (busy || status.isLoading) const LinearProgressIndicator(),
              if (status.hasError)
                SelectableText(
                  redactCredentials(status.error.toString()),
                  style: TextStyle(color: context.colors.danger),
                ),
              const Divider(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final list = entries.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SelectableText(redactCredentials(e.toString())),
                            TextButton(
                              onPressed: () => ref.invalidate(stashListProvider(repo)),
                              child: Text(l.historyRetry),
                            ),
                          ],
                        ),
                      ),
                      data: (items) => items.isEmpty
                          ? Center(child: Text(l.stashEmpty))
                          : ListView(
                              children: [
                                for (final entry in items)
                                  ExpansionTile(
                                    key: ValueKey('stash-${entry.sha}'),
                                    title: Text(entry.message),
                                    subtitle: Text(
                                      [
                                        if (entry.branchName != null) entry.branchName!,
                                        formatAgo(context, entry.createdAt),
                                      ].join(' · '),
                                    ),
                                    children: [
                                      Wrap(
                                        spacing: Space.sm,
                                        children: [
                                          TextButton(
                                            onPressed: busy
                                                ? null
                                                : () => _run(
                                                    l.stashPop,
                                                    () => stashApply(git, repo.path, entry.sha, pop: true),
                                                  ),
                                            child: Text(l.stashPop),
                                          ),
                                          TextButton(
                                            onPressed: busy
                                                ? null
                                                : () => _run(l.stashApply, () => stashApply(git, repo.path, entry.sha)),
                                            child: Text(l.stashApply),
                                          ),
                                          TextButton(
                                            onPressed: busy
                                                ? null
                                                : () async {
                                                    if (!await confirmHistoryAction(
                                                          context,
                                                          l.stashDrop,
                                                          l.stashDropConfirm,
                                                        ) ||
                                                        !mounted) {
                                                      return;
                                                    }
                                                    await _run(l.stashDrop, () async {
                                                      await stashDrop(git, repo.path, entry.sha);
                                                      return OperationOutcome.completed;
                                                    });
                                                  },
                                            child: Text(l.stashDrop),
                                          ),
                                        ],
                                      ),
                                      _StashFiles(
                                        path: repo.path,
                                        sha: entry.sha,
                                        selected: _sha == entry.sha ? _file?.path : null,
                                        onSelect: (file) => setState(() {
                                          _sha = entry.sha;
                                          _file = file;
                                        }),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                    );
                    final diff = _sha == null || _file == null
                        ? Center(child: Text(l.stashSelect))
                        : ref
                              .watch(stashDiffProvider((path: repo.path, sha: _sha!, file: _file!)))
                              .when(
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (e, _) => Center(child: SelectableText(redactCredentials(e.toString()))),
                                data: (diff) => FileDiffView(diff: diff),
                              );
                    if (constraints.maxWidth < 700) {
                      return Column(
                        children: [
                          Expanded(child: list),
                          const Divider(),
                          Expanded(child: diff),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        SizedBox(width: constraints.maxWidth * .4, child: list),
                        const VerticalDivider(),
                        Expanded(child: diff),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StashFiles extends ConsumerWidget {
  const _StashFiles({required this.path, required this.sha, required this.onSelect, this.selected});
  final String path, sha;
  final String? selected;
  final ValueChanged<CommittedFile> onSelect;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(stashFilesProvider((path: path, sha: sha)))
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => SelectableText(redactCredentials(e.toString())),
        data: (files) => Column(
          children: [
            for (final file in files)
              ListTile(
                key: ValueKey('stash-file-${file.path}'),
                dense: true,
                selected: selected == file.path,
                leading: const Icon(Icons.description_outlined),
                title: Text(file.path),
                onTap: () => onSelect(file),
              ),
          ],
        ),
      );
}
