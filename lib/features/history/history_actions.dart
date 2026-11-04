import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/expeditions/expedition.dart';
import '../../core/git/git_runner.dart';
import '../../core/git/merge.dart';
import '../../core/git/rewrite.dart';
import '../../core/models/advanced.dart';
import '../../core/models/app_models.dart';
import '../../core/models/commit.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/terms.dart';
import '../../state/app_state.dart';
import '../../state/history_state.dart';
import '../../state/repo_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/feedback.dart';
import 'action_dialogs.dart';

enum _Action { revert, pick, tag, copy, undo, squash, up, down }

Future<({String text, String description})?> _input(
  BuildContext context,
  String title,
  String label, {
  String initial = '',
  String? secondLabel,
}) async {
  final text = TextEditingController(text: initial), description = TextEditingController();
  final l = L10n.of(context);
  final result = await showDialog<({String text, String description})>(
    context: context,
    animationStyle: AnimationStyle(
      duration: context.motion(Motion.normal),
      reverseDuration: context.motion(Motion.normal),
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('history-action-input'),
                controller: text,
                autofocus: true,
                minLines: 1,
                maxLines: secondLabel == null ? 6 : 1,
                decoration: InputDecoration(labelText: label),
                onChanged: (_) => update(() {}),
              ),
              if (secondLabel != null) ...[
                const SizedBox(height: Space.md),
                TextField(
                  key: const Key('tag-description'),
                  controller: description,
                  decoration: InputDecoration(labelText: secondLabel),
                  maxLines: 3,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.historyActionCancel)),
          FilledButton(
            onPressed: text.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, (text: text.text.trim(), description: description.text.trim())),
            child: Text(l.historyActionConfirm),
          ),
        ],
      ),
    ),
  );
  // Route exit animations still reference the controllers.
  await Future<void>.delayed(const Duration(milliseconds: 350));
  text.dispose();
  description.dispose();
  return result;
}

Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  RepositoryInfo repo,
  String title,
  Future<OperationOutcome> Function() task, {
  ExpeditionKind kind = ExpeditionKind.rebase,
}) async {
  final l = L10n.of(context);
  final success = l.historyActionDone,
      nothing = l.historyActionNothing,
      conflicts = l.historyActionConflicts(Terms.of(context).changes);
  try {
    final outcome = await ref
        .read(repositoryActionProvider(repo).notifier)
        .run(
          title: title,
          task: task,
          kind: kind,
          describe: (o) => switch (o) {
            OperationOutcome.completed => success,
            OperationOutcome.nothingToDo => nothing,
            OperationOutcome.conflicts => conflicts,
          },
        );
    if (context.mounted) showOutcome(context, outcome);
  } catch (error) {
    if (context.mounted) {
      showGhpToast(context, l.historyActionFailed, tone: ToastTone.error, detail: redactCredentials(error.toString()));
    }
  }
}

Future<void> showHistoryActions(
  BuildContext context,
  WidgetRef ref,
  RepositoryInfo repo,
  Commit commit,
  List<Commit> selection,
  Offset position,
) async {
  if (ref.read(repositoryActionProvider(repo))) return;
  final l = L10n.of(context), t = Terms.of(context);
  final git = ref.read(gitProvider);
  try {
    final membership = await ref.read(historyMembershipProvider((repo: repo, sha: commit.sha)).future);
    final order = await ref.read(historyOrderProvider(repo).future);
    final status = await ref.read(repoStatusProvider(repo.id).future);
    if (!context.mounted) return;
    final index = order.indexOf(commit.sha);
    final idle = status.inProgress == null;
    final clean = status.files.isEmpty && idle && status.currentBranch != null;
    final selected = selection.length > 1 ? selection : [commit];
    final squashable = selected.length > 1 && selected.every((c) => order.contains(c.sha) && c.parentShas.length <= 1);
    final action = await showMenu<_Action>(
      context: context,
      popUpAnimationStyle: AnimationStyle(
        duration: context.motion(Motion.normal),
        reverseDuration: context.motion(Motion.normal),
      ),
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          value: _Action.revert,
          enabled: clean,
          child: Text(l.historyActionRevert(t.commitUnit, t.revert)),
        ),
        PopupMenuItem(
          value: _Action.pick,
          enabled: clean && !membership.current && commit.parentShas.length <= 1,
          child: Text(l.historyActionPick(t.branch, t.cherryPick)),
        ),
        PopupMenuItem(value: _Action.tag, enabled: idle, child: Text(l.tagCreate(t.tag))),
        PopupMenuItem(value: _Action.copy, child: Text(l.historyCopySha)),
        if (status.headSha == commit.sha && status.currentBranch != null)
          PopupMenuItem(value: _Action.undo, enabled: idle, child: Text(l.historyActionUndo(t.commitUnit))),
        PopupMenuItem(
          value: _Action.squash,
          enabled: clean && squashable,
          child: Text(l.historyActionSquash(t.squash)),
        ),
        PopupMenuItem(
          value: _Action.up,
          enabled: clean && index > 0 && commit.parentShas.length <= 1,
          child: Text(l.historyActionUp),
        ),
        PopupMenuItem(
          value: _Action.down,
          enabled: clean && index >= 0 && index < order.length - 1 && commit.parentShas.length <= 1,
          child: Text(l.historyActionDown),
        ),
      ],
    );
    if (action == null || !context.mounted || ref.read(repositoryActionProvider(repo))) return;
    if (action == _Action.copy) {
      await Clipboard.setData(ClipboardData(text: commit.sha));
      if (context.mounted) showGhpToast(context, l.historyCopied);
      return;
    }
    if (action == _Action.tag) {
      final value = await _input(context, l.tagCreate(t.tag), l.tagName, secondLabel: l.tagDescription);
      if (value == null || !context.mounted) return;
      await _run(context, ref, repo, l.tagCreate(t.tag), () async {
        await createTag(
          git,
          repo.path,
          value.text,
          commit.sha,
          message: value.description.isEmpty ? null : value.description,
        );
        return OperationOutcome.completed;
      });
      return;
    }
    if (action == _Action.revert) {
      if (!await confirmHistoryAction(
            context,
            l.historyActionRevert(t.commitUnit, t.revert),
            l.historyActionRevertConfirm(t.commitUnit),
          ) ||
          !context.mounted) {
        return;
      }
      await _run(
        context,
        ref,
        repo,
        l.historyActionRevert(t.commitUnit, t.revert),
        () => revert(git, repo.path, commit.sha),
      );
      return;
    }
    if (action == _Action.pick) {
      await _run(
        context,
        ref,
        repo,
        l.historyActionPick(t.branch, t.cherryPick),
        () => cherryPick(git, repo.path, [commit.sha]),
      );
      return;
    }
    // Rewrites can replace every descendant of the earliest affected commit.
    final affectedIndex = action == _Action.squash
        ? selected.map((c) => order.indexOf(c.sha)).reduce((a, b) => a > b ? a : b)
        : action == _Action.down
        ? index + 1
        : index;
    if (affectedIndex >= 0) {
      var published = false;
      for (final sha in order.take(affectedIndex + 1)) {
        if ((await ref.read(historyMembershipProvider((repo: repo, sha: sha)).future)).published) {
          published = true;
          break;
        }
      }
      if (!context.mounted) return;
      if (published &&
          (!await confirmHistoryAction(context, l.historyActionMenu, l.historyActionPublished) || !context.mounted)) {
        return;
      }
    }
    if (action == _Action.undo) {
      if (!await confirmHistoryAction(
            context,
            l.historyActionUndo(t.commitUnit),
            l.historyActionUndoConfirm(t.commitUnit),
          ) ||
          !context.mounted) {
        return;
      }
      String? message;
      await _run(context, ref, repo, l.historyActionUndo(t.commitUnit), () async {
        final value = await undoLastCommit(git, repo.path);
        message = [value.summary, if (value.description.isNotEmpty) value.description].join('\n\n');
        return OperationOutcome.completed;
      });
      if (context.mounted && message != null) {
        // The shared toast has no action slot; use the same messenger for the copy action.
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.historyActionUndoMessage(redactCredentials(message!))),
            duration: const Duration(seconds: 15),
            showCloseIcon: true,
            action: SnackBarAction(
              label: l.historyActionCopyMessage,
              onPressed: () => Clipboard.setData(ClipboardData(text: message!)),
            ),
          ),
        );
      }
      return;
    }
    if (action == _Action.squash) {
      final ordered = selected.toList()..sort((a, b) => order.indexOf(b.sha).compareTo(order.indexOf(a.sha)));
      final value = await _input(
        context,
        l.historyActionSquash(t.squash),
        l.historyActionMessage,
        initial: ordered.map((c) => c.summary).join('\n\n'),
      );
      if (value == null || !context.mounted) return;
      await _run(
        context,
        ref,
        repo,
        l.historyActionSquash(t.squash),
        () => squash(git, repo.path, ordered.map((c) => c.sha).toList(), value.text),
      );
    } else {
      final after = action == _Action.up ? order[index - 1] : (index + 2 < order.length ? order[index + 2] : null);
      await _run(
        context,
        ref,
        repo,
        action == _Action.up ? l.historyActionUp : l.historyActionDown,
        () => reorder(git, repo.path, commit.sha, afterSha: after),
      );
    }
  } catch (error) {
    if (context.mounted) {
      showGhpToast(context, l.historyActionFailed, tone: ToastTone.error, detail: redactCredentials(error.toString()));
    }
  }
}

Future<void> showTagActions(
  BuildContext context,
  WidgetRef ref,
  RepositoryInfo repo,
  String name,
  Offset position,
) async {
  if (ref.read(repositoryActionProvider(repo))) return;
  final l = L10n.of(context), t = Terms.of(context);
  final git = ref.read(gitProvider);
  final action = await showMenu<bool>(
    context: context,
    popUpAnimationStyle: AnimationStyle(
      duration: context.motion(Motion.normal),
      reverseDuration: context.motion(Motion.normal),
    ),
    position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
    items: [
      PopupMenuItem(value: true, child: Text(l.tagPush(t.tag))),
      PopupMenuItem(value: false, child: Text(l.tagDelete(t.tag))),
    ],
  );
  if (action == null || !context.mounted) return;
  final remote = ref.read(repoStatusProvider(repo.id)).value?.upstream?.split('/').first ?? 'origin';
  var deleteRemote = false;
  if (!action) {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AnimationStyle(
        duration: context.motion(Motion.normal),
        reverseDuration: context.motion(Motion.normal),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(l.tagDelete(t.tag)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.tagDeleteConfirm(name)),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.tagRemote),
                value: deleteRemote,
                onChanged: (v) => update(() => deleteRemote = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.historyActionCancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.historyActionConfirm)),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }
  await _run(
    context,
    ref,
    repo,
    action ? l.tagPush(t.tag) : l.tagDelete(t.tag),
    () async {
      if (action) {
        await pushTag(git, repo.path, name, remote: remote);
      } else {
        await deleteTag(git, repo.path, name, remote: deleteRemote ? remote : null);
      }
      return OperationOutcome.completed;
    },
    kind: action || deleteRemote ? ExpeditionKind.push : ExpeditionKind.rebase,
  );
}
