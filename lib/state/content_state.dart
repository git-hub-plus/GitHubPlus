import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content/repo_content.dart';
import 'app_state.dart';
import 'repo_state.dart';

/// Which copy of the repository the overview page shows.
enum ContentView { workingTree, head }

typedef ContentKey = ({String repoId, ContentView view});

/// Rebuilt whenever the repository status refreshes, so listings follow
/// new files, commits and branch switches. Disposed with the page, so a big
/// working-folder index does not stay in memory.
final contentSourceProvider = Provider.autoDispose.family<RepoContentSource?, ContentKey>((ref, key) {
  final repo = ref.watch(libraryProvider).repositories.where((r) => r.id == key.repoId).firstOrNull;
  if (repo == null) return null;
  ref.watch(repoStatusProvider(key.repoId).select((s) => s.value));
  final git = ref.watch(gitProvider);
  return switch (key.view) {
    ContentView.workingTree => WorkingTreeSource(git, repo.path),
    ContentView.head => GitTreeSource(git, repo.path),
  };
});

/// Keyed by the source instance: a refreshed source is a new key, so
/// listings reload; hub sources work the same way as local ones.
final treeProvider = FutureProvider.autoDispose.family<List<TreeEntry>, ({RepoContentSource source, String dir})>(
  (ref, args) => args.source.list(args.dir),
);

final blobProvider = FutureProvider.autoDispose.family<BlobContent, ({RepoContentSource source, String path})>(
  (ref, args) => args.source.read(args.path),
);
