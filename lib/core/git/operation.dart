// Ported from GitHub Desktop (MIT): app/src/lib/git/merge.ts (via GitHub+ v1 src/main/git/merge.ts)
import '../models/advanced.dart';
import 'git_runner.dart';
import 'in_progress.dart';
import 'status.dart';

final _nothingToDo = RegExp(
  r'^(?:Already up.to.date\.?|Current branch .+ is up to date\.|nothing to commit[^\n]*|nothing added to commit[^\n]*)\r?$',
  multiLine: true,
  caseSensitive: false,
);

/// Runs a conflict-capable operation without opening an editor.
/// [stdin] supports merge commit messages passed with `-F -`.
Future<OperationOutcome> runOperation(GitRunner git, String repoPath, List<String> args, {String? stdin}) async {
  try {
    final result = await git.run(args, cwd: repoPath, stdin: stdin, environment: const {'GIT_EDITOR': 'true'});
    return _nothingToDo.hasMatch('${result.stdout}\n${result.stderr}')
        ? OperationOutcome.nothingToDo
        : OperationOutcome.completed;
  } on GitException catch (error) {
    try {
      if (await getInProgress(git, repoPath) != null || (await getStatus(git, repoPath)).conflictCount > 0) {
        return OperationOutcome.conflicts;
      }
    } catch (_) {
      // Diagnostics must never replace the original command failure.
    }
    if (_nothingToDo.hasMatch('${error.result.stdout}\n${error.result.stderr}')) {
      return OperationOutcome.nothingToDo;
    }
    rethrow;
  }
}
