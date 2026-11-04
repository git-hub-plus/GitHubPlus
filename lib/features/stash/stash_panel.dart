// EXTENSION POINT (owner: worker B2). Replace the body; keep the function signature.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';

/// Opens the stash panel ("임시 보관"): stash current changes, list stashes,
/// look at their files, apply/pop/drop. Called from the HUD stash stat.
Future<void> showStashPanel(BuildContext context, WidgetRef ref, RepositoryInfo repo) async {}
