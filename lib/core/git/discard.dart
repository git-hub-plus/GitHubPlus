// CONTRACT (owner: worker G1). Signatures are fixed; G1 implements the bodies.
// Port from GitHub+ v1 src/main/git/discard.ts (GitHub Desktop, MIT).
import '../models/status.dart';
import 'git_runner.dart';

/// Throws away working-tree changes to [files] (tracked: back to HEAD,
/// untracked/new: deleted, renames: both paths restored). Before touching
/// anything, copies the current contents of every affected file into a new
/// timestamped folder under [backupDirectory] and returns that folder, so the
/// user can recover what was discarded.
Future<String> discardChanges(GitRunner git, String repoPath, List<WorkingFile> files, {required String backupDirectory}) =>
    throw UnimplementedError('G1');
