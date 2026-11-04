// EXTENSION POINT (owner: worker U2). Replace the body; keep the function signature.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';

/// Opens the branch menu (list, search, create, switch, rename, delete) for
/// [repo], anchored below the banner's branch chip.
Future<void> showBranchMenu(BuildContext context, WidgetRef ref, RepositoryInfo repo) async {}
