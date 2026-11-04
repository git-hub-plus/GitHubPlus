import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/git/stash.dart';
import '../core/models/advanced.dart';
import '../core/models/app_models.dart';
import '../core/models/commit.dart';
import '../core/models/diff.dart';
import 'app_state.dart';
import 'repo_state.dart';

final stashListProvider = FutureProvider.autoDispose.family<List<StashEntry>, RepositoryInfo>((ref, repo) {
  ref.watch(repoStatusProvider(repo.id));
  return stashList(ref.watch(gitProvider), repo.path);
});

// Use immutable object IDs: dropping an entry renumbers stash@{n}.
typedef StashLocation = ({String path, String sha});
final stashFilesProvider = FutureProvider.autoDispose.family<List<CommittedFile>, StashLocation>(
  (ref, key) => stashFiles(ref.watch(gitProvider), key.path, key.sha),
);
typedef StashDiffLocation = ({String path, String sha, CommittedFile file});
final stashDiffProvider = FutureProvider.autoDispose.family<FileDiff, StashDiffLocation>(
  (ref, key) => stashDiff(ref.watch(gitProvider), key.path, key.sha, key.file),
);
