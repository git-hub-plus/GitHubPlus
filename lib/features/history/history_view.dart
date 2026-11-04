// EXTENSION POINT (owner: worker U2). Replace the body; keep the class name and constructor.
import 'package:flutter/material.dart';

import '../../core/models/app_models.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/terms.dart';
import '../../ui/theme.dart';

/// "버전 기록" tab: commit list with graph, commit details and diffs.
class HistoryView extends StatelessWidget {
  const HistoryView({super.key, required this.repo});
  final RepositoryInfo repo;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(L10n.of(context).tabHistory(Terms.of(context).history), style: TextStyle(color: context.colors.muted)),
  );
}
