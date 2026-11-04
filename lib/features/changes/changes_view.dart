// EXTENSION POINT (owner: worker U1). Replace the body; keep the class name and constructor.
import 'package:flutter/material.dart';

import '../../core/models/app_models.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/terms.dart';
import '../../ui/theme.dart';

/// "바뀐 파일" tab: changed files, diff with line selection, commit box.
class ChangesView extends StatelessWidget {
  const ChangesView({super.key, required this.repo});
  final RepositoryInfo repo;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(L10n.of(context).tabChanges(Terms.of(context).changes), style: TextStyle(color: context.colors.muted)),
  );
}
