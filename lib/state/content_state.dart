import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/content/repo_content.dart';
import 'app_state.dart';
import 'repo_state.dart';

/// Which copy of the repository the overview page shows.
enum ContentView { workingTree, head }

typedef ContentKey = ({String repoId, ContentView view});

/// Rebuilt whenever the repository status refreshes, so listings follow
/// new files, commits and branch switches.
final contentSourceProvider = Provider.family<RepoContentSource?, ContentKey>((ref, key) {
  final repo = ref.watch(libraryProvider).repositories.where((r) => r.id == key.repoId).firstOrNull;
  if (repo == null) return null;
  ref.watch(repoStatusProvider(key.repoId).select((s) => s.value));
  final git = ref.watch(gitProvider);
  return switch (key.view) {
    ContentView.workingTree => WorkingTreeSource(git, repo.path),
    ContentView.head => GitTreeSource(git, repo.path),
  };
});

final treeProvider = FutureProvider.autoDispose.family<List<TreeEntry>, ({ContentKey key, String dir})>((ref, args) async {
  final source = ref.watch(contentSourceProvider(args.key));
  return source == null ? const [] : source.list(args.dir);
});

final blobProvider = FutureProvider.autoDispose.family<BlobContent, ({ContentKey key, String path})>((ref, args) async {
  final source = ref.watch(contentSourceProvider(args.key));
  return source == null ? const MissingBlob() : source.read(args.path);
});
