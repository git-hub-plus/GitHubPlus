// EXTENSION POINT (owner: worker H3b). Replace the body; keep the function signature.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';

/// "허브에 처음 올리기": pick a discovered hub, name the repository and
/// publish. Opened by the banner's publish button when the repository has
/// no remote yet.
Future<void> showPublishToHubDialog(BuildContext context, WidgetRef ref, RepositoryInfo repo) async {}
