// Shared confirmations and outcome messages for repository actions.
import 'package:flutter/material.dart';
import '../../core/models/advanced.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/terms.dart';
import '../../ui/widgets/feedback.dart';
import '../../ui/theme.dart';

String outcomeMessage(BuildContext context, OperationOutcome outcome) {
  final l = L10n.of(context);
  return switch (outcome) {
    OperationOutcome.completed => l.historyActionDone,
    OperationOutcome.conflicts => l.historyActionConflicts(Terms.of(context).changes),
    OperationOutcome.nothingToDo => l.historyActionNothing,
  };
}

void showOutcome(BuildContext context, OperationOutcome outcome) => showGhpToast(
  context,
  outcomeMessage(context, outcome),
  tone: outcome == OperationOutcome.conflicts
      ? ToastTone.error
      : outcome == OperationOutcome.completed
      ? ToastTone.success
      : ToastTone.info,
);
Future<bool> confirmHistoryAction(BuildContext context, String title, String message) async {
  final l = L10n.of(context);
  return await showDialog<bool>(
        context: context,
        animationStyle: AnimationStyle(
          duration: context.motion(Motion.normal),
          reverseDuration: context.motion(Motion.normal),
        ),
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.historyActionCancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.historyActionConfirm)),
          ],
        ),
      ) ??
      false;
}
