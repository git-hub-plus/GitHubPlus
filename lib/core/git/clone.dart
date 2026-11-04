// Ported from GitHub Desktop (MIT): app/src/lib/git/clone.ts (via GitHub+ v1 src/main/git/clone.ts)
import 'dart:io';

import 'git_runner.dart';
import 'progress.dart';
import 'sync.dart';

/// Transports a clone may use. `ext::` and `fd::` can run commands and
/// `file://` would read anywhere on disk, so they are refused here even
/// though git's own `protocol.allow` defaults also block `ext`.
final _allowedUrl = RegExp(r'^(https?://|ssh://|git://|[\w.-]+@[\w.-]+:)', caseSensitive: false);

/// Clones [url] into [targetPath] (which must not exist or be empty) with
/// progress through [onProgress]. [branch] checks out that branch.
Future<void> cloneRepository(
  GitRunner git,
  String url,
  String targetPath, {
  String? branch,
  ProgressReport? onProgress,
}) async {
  if (!_allowedUrl.hasMatch(url)) throw ArgumentError.value(url, 'url', 'Unsupported clone URL');
  if (branch != null && (branch.isEmpty || branch.startsWith('-'))) throw ArgumentError.value(branch, 'branch');
  final target = Directory(targetPath);
  if (await target.exists() && !await target.list().isEmpty) {
    throw StateError('The destination folder is not empty');
  }
  await target.parent.create(recursive: true);
  final parser = WeightedProgress(WeightedProgress.clone);
  await git.run(
    ['clone', '--progress', '--recurse-submodules', if (branch != null) ...['--branch', branch], '--', url, targetPath],
    cwd: target.parent.path,
    onStderrLine: (line) {
      final update = parser.feed(line);
      if (update != null) onProgress?.call(update.value, update.title);
    },
  );
}
