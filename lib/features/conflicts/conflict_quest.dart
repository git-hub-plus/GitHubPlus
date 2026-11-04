import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/expeditions/expedition.dart';
import '../../core/git/git_runner.dart';
import '../../core/git/merge.dart';
import '../../core/git/stage.dart';
import '../../core/models/advanced.dart';
import '../../core/models/app_models.dart';
import '../../core/models/status.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/terms.dart';
import '../../state/app_state.dart';
import '../../state/changes_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/feedback.dart';
import '../../ui/widgets/hud.dart';

class ConflictQuest extends ConsumerStatefulWidget {
  const ConflictQuest({super.key, required this.repo, required this.status});
  final RepositoryInfo repo;
  final RepoStatus status;
  @override
  ConsumerState<ConflictQuest> createState() => _ConflictQuestState();
}

class _ConflictQuestState extends ConsumerState<ConflictQuest> {
  bool _busy = false;

  String _term(BuildContext context) {
    final t = Terms.of(context);
    return switch (widget.status.inProgress) {
      MergeInProgress() => t.merge,
      RebaseInProgress() => t.rebase,
      CherryPickInProgress() => t.cherryPick,
      _ => t.revert,
    };
  }

  Future<void> _run(bool abort) async {
    if (_busy) return;
    final l = L10n.of(context);
    final term = _term(context);
    final repo = widget.repo;
    final refresh = ref.read(changesProvider(repo.id).notifier).refreshStatus;
    final changesTerm = Terms.of(context).changes;
    final operation = widget.status.inProgress;
    setState(() => _busy = true);
    String? message;
    try {
      if (!abort && operation is MergeInProgress) {
        final git = ref.read(gitProvider);
        final path = await git.run(['rev-parse', '--git-path', 'MERGE_MSG'], cwd: repo.path);
        final file = File(
          p.isAbsolute(path.stdout.trim()) ? path.stdout.trim() : p.join(repo.path, path.stdout.trim()),
        );
        message = await file.readAsString();
      }
      if (!mounted) return;
      if (abort) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.conflictAbort(term)),
            content: Text(l.conflictAbortBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.changesCancel)),
              FilledButton(
                key: const Key('conflict-confirm'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.conflictAbort(term)),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      } else if (operation is MergeInProgress) {
        final initialMessage = message!;
        message = await showDialog<String>(
          context: context,
          builder: (_) => _MergeMessageDialog(initial: initialMessage, term: term),
        );
        if (message == null || !mounted) return;
      }
      final git = ref.read(gitProvider);
      final outcome = await ref
          .read(expeditionsProvider.notifier)
          .run<OperationOutcome>(
            kind: operation is RebaseInProgress ? ExpeditionKind.rebase : ExpeditionKind.checkout,
            title: abort ? l.conflictAbort(term) : l.conflictContinue(term),
            destination: repo.name,
            repoId: repo.id,
            task: (_) => withRepositoryOperation(repo.path, () async {
              try {
                if (abort) {
                  await abortOperation(git, repo.path);
                  return OperationOutcome.completed;
                }
                return await continueOperation(git, repo.path, message: operation is MergeInProgress ? message : null);
              } catch (error) {
                throw StateError(redactCredentials(error.toString()));
              }
            }),
            result: (result) =>
                result == OperationOutcome.conflicts ? l.mergeConflicts(changesTerm) : l.mergeCompleted(term),
          );
      if (mounted) {
        showGhpToast(
          context,
          outcome == null
              ? l.changesFailed
              : outcome == OperationOutcome.conflicts
              ? l.mergeConflicts(changesTerm)
              : l.mergeCompleted(term),
          tone: outcome == null
              ? ToastTone.error
              : outcome == OperationOutcome.conflicts
              ? ToastTone.info
              : ToastTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showGhpToast(context, l.changesFailed, tone: ToastTone.error, detail: redactCredentials(error.toString()));
      }
    } finally {
      refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final operation = status.inProgress;
    final l = L10n.of(context);
    final term = _term(context);
    final total = ref.watch(changesProvider(widget.repo.id)).conflictPaths.length;
    final resolved = (total - status.conflictCount).clamp(0, total);
    final progress = operation is RebaseInProgress
        ? (operation.totalSteps == 0 ? 0.0 : operation.step / operation.totalSteps)
        : (total == 0 ? 1.0 : resolved / total);
    return Container(
      key: const Key('conflict-quest'),
      padding: const EdgeInsets.all(Space.md),
      color: context.colors.accentSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            operation is RebaseInProgress
                ? l.conflictRebaseStep(term, operation.step, operation.totalSteps)
                : l.conflictQuestTitle(
                    term,
                    operation is MergeInProgress ? operation.theirBranch ?? widget.repo.name : widget.repo.name,
                  ),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Space.sm),
          Text(l.conflictSteps, style: TextStyle(color: context.colors.text, fontSize: 12)),
          const SizedBox(height: Space.sm),
          GaugeBar(fraction: progress, color: context.colors.accent),
          const SizedBox(height: Space.xs),
          Text(l.conflictProgress(resolved, total)),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              FilledButton(
                key: const Key('conflict-continue'),
                onPressed: _busy || status.conflictCount > 0 ? null : () => _run(false),
                child: Text(l.conflictContinue(term)),
              ),
              TextButton(
                key: const Key('conflict-abort'),
                onPressed: _busy ? null : () => _run(true),
                child: Text(l.conflictAbort(term)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MergeMessageDialog extends StatefulWidget {
  const _MergeMessageDialog({required this.initial, required this.term});
  final String initial;
  final String term;
  @override
  State<_MergeMessageDialog> createState() => _MergeMessageDialogState();
}

class _MergeMessageDialogState extends State<_MergeMessageDialog> {
  late final _message = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return AlertDialog(
      title: Text(l.mergeMessage(widget.term)),
      content: TextField(
        key: const Key('conflict-message'),
        controller: _message,
        maxLines: 4,
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.changesCancel)),
        FilledButton(
          key: const Key('conflict-confirm'),
          onPressed: _message.text.trim().isEmpty ? null : () => Navigator.pop(context, _message.text),
          child: Text(l.conflictContinue(widget.term)),
        ),
      ],
    );
  }
}
