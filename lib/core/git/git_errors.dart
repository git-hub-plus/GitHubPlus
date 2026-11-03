// Error patterns ported from dugite (MIT): lib/errors.ts `GitErrorRegexes`.
// GitHub+ classifies git's stderr the same way the Electron version did.

/// A specific failure git reported, recognised from its output.
enum GitError {
  badConfigValue,
  sshKeyAuditUnverified,
  httpsAuthenticationFailed,
  sshAuthenticationFailed,
  sshPermissionDenied,
  remoteDisconnection,
  hostDown,
  rebaseConflicts,
  mergeConflicts,
  httpsRepositoryNotFound,
  sshRepositoryNotFound,
  pushNotFastForward,
  branchDeletionFailed,
  defaultBranchDeletionFailed,
  revertConflicts,
  emptyRebasePatch,
  noMatchingRemoteBranch,
  noExistingRemoteBranch,
  nothingToCommit,
  noSubmoduleMapping,
  submoduleRepositoryDoesNotExist,
  invalidSubmoduleSha,
  localPermissionDenied,
  invalidMerge,
  invalidRebase,
  nonFastForwardMergeIntoEmptyHead,
  patchDoesNotApply,
  branchAlreadyExists,
  badRevision,
  notAGitRepository,
  cannotMergeUnrelatedHistories,
  lfsAttributeDoesNotMatch,
  branchRenameFailed,
  pathDoesNotExist,
  invalidObjectName,
  outsideRepository,
  lockFileAlreadyExists,
  noMergeToAbort,
  localChangesOverwritten,
  unresolvedConflicts,
  gpgFailedToSignData,
  conflictModifyDeletedInBranch,
  pushWithFileSizeExceedingLimit,
  hexBranchNameRejected,
  forcePushRejected,
  invalidRefLength,
  protectedBranchRequiresReview,
  protectedBranchForcePush,
  protectedBranchDeleteRejected,
  protectedBranchRequiredStatus,
  pushWithPrivateEmail,
  configLockFileAlreadyExists,
  remoteAlreadyExists,
  tagAlreadyExists,
  mergeWithLocalChanges,
  rebaseWithLocalChanges,
  mergeCommitNoMainlineOption,
  unsafeDirectory,
  pathExistsButNotInRef,
  pushWithSecretDetected,
  // GitHub+ additions
  authorIdentityUnknown,
  hubHistoryProtected,
}

final Map<RegExp, GitError> _patterns = {
  RegExp(r"fatal: bad (?:numeric|boolean) config value '(.+)' for '(.+)'"): GitError.badConfigValue,
  RegExp(r'ERROR: ([\s\S]+?)\n+\[EPOLICYKEYAGE\]\n+fatal: Could not read from remote repository.'):
      GitError.sshKeyAuditUnverified,
  RegExp(r"fatal: Authentication failed for 'https?://"): GitError.httpsAuthenticationFailed,
  RegExp(r'fatal: Authentication failed'): GitError.sshAuthenticationFailed,
  RegExp(r'fatal: Could not read from remote repository.'): GitError.sshPermissionDenied,
  RegExp(r'The requested URL returned error: 403'): GitError.httpsAuthenticationFailed,
  RegExp(r'fatal: [Tt]he remote end hung up unexpectedly'): GitError.remoteDisconnection,
  RegExp(r"fatal: unable to access '(.+)': Failed to connect to (.+): Host is down"): GitError.hostDown,
  RegExp(r"Cloning into '(.+)'...\nfatal: unable to access '(.+)': Could not resolve host: (.+)"):
      GitError.hostDown,
  RegExp(r'Resolve all conflicts manually, mark them as resolved with'): GitError.rebaseConflicts,
  RegExp(r'(Merge conflict|Automatic merge failed; fix conflicts and then commit the result)'):
      GitError.mergeConflicts,
  RegExp(r"fatal: repository '(.+)' not found"): GitError.httpsRepositoryNotFound,
  RegExp(r'ERROR: Repository not found'): GitError.sshRepositoryNotFound,
  RegExp(r"\((non-fast-forward|fetch first)\)\nerror: failed to push some refs to '.*'"):
      GitError.pushNotFastForward,
  RegExp(r"error: unable to delete '(.+)': remote ref does not exist"): GitError.branchDeletionFailed,
  RegExp(r'\[remote rejected\] (.+) \(deletion of the current branch prohibited\)'):
      GitError.defaultBranchDeletionFailed,
  RegExp(r"error: could not revert .*\nhint: after resolving the conflicts, mark the corrected paths\nhint: with 'git add <paths>' or 'git rm <paths>'\nhint: and commit the result with 'git commit'"):
      GitError.revertConflicts,
  RegExp(r"Applying: .*\nNo changes - did you forget to use 'git add'\?\nIf there is nothing left to stage, chances are that something else\n.*"):
      GitError.emptyRebasePatch,
  RegExp(r'There are no candidates for (rebasing|merging) among the refs that you just fetched.\nGenerally this means that you provided a wildcard refspec which had no\nmatches on the remote end.'):
      GitError.noMatchingRemoteBranch,
  RegExp(r"Your configuration specifies to merge with the ref '(.+)'\nfrom the remote, but no such ref was fetched."):
      GitError.noExistingRemoteBranch,
  RegExp(r'nothing to commit'): GitError.nothingToCommit,
  RegExp(r"[Nn]o submodule mapping found in .gitmodules for path '(.+)'"): GitError.noSubmoduleMapping,
  RegExp(r"fatal: repository '(.+)' does not exist\nfatal: clone of '.+' into submodule path '(.+)' failed"):
      GitError.submoduleRepositoryDoesNotExist,
  RegExp(r"Fetched in submodule path '(.+)', but it did not contain (.+). Direct fetching of that commit failed."):
      GitError.invalidSubmoduleSha,
  RegExp(r"fatal: could not create work tree dir '(.+)'.*: Permission denied"): GitError.localPermissionDenied,
  RegExp(r'merge: (.+) - not something we can merge'): GitError.invalidMerge,
  RegExp(r'invalid upstream (.+)'): GitError.invalidRebase,
  RegExp(r'fatal: Non-fast-forward commit does not make sense into an empty head'):
      GitError.nonFastForwardMergeIntoEmptyHead,
  RegExp(r'error: (.+): (patch does not apply|already exists in working directory)'): GitError.patchDoesNotApply,
  RegExp(r"fatal: [Aa] branch named '(.+)' already exists.?"): GitError.branchAlreadyExists,
  RegExp(r"fatal: bad revision '(.*)'"): GitError.badRevision,
  RegExp(r'fatal: [Nn]ot a git repository \(or any of the parent directories\): (.*)'): GitError.notAGitRepository,
  RegExp(r'fatal: refusing to merge unrelated histories'): GitError.cannotMergeUnrelatedHistories,
  RegExp(r'[Tt]he .+ attribute should be .+ but is .+'): GitError.lfsAttributeDoesNotMatch,
  RegExp(r'fatal: Branch rename failed'): GitError.branchRenameFailed,
  RegExp(r"fatal: path '(.+)' does not exist .+"): GitError.pathDoesNotExist,
  RegExp(r"fatal: invalid object name '(.+)'."): GitError.invalidObjectName,
  RegExp(r"fatal: .+: '(.+)' is outside repository"): GitError.outsideRepository,
  RegExp(r'Another git process seems to be running in this repository, e.g.'): GitError.lockFileAlreadyExists,
  RegExp(r'fatal: There is no merge to abort'): GitError.noMergeToAbort,
  RegExp(r'error: (?:Your local changes to the following|The following untracked working tree) files would be overwritten by checkout:'):
      GitError.localChangesOverwritten,
  RegExp(r'You must edit all merge conflicts and then\nmark them as resolved using git add|fatal: Exiting because of an unresolved conflict'):
      GitError.unresolvedConflicts,
  RegExp(r'error: gpg failed to sign the data'): GitError.gpgFailedToSignData,
  RegExp(r'CONFLICT \(modify/delete\): (.+) deleted in (.+) and modified in (.+)'):
      GitError.conflictModifyDeletedInBranch,
  RegExp(r'error: GH001: '): GitError.pushWithFileSizeExceedingLimit,
  RegExp(r'error: GH002: '): GitError.hexBranchNameRejected,
  RegExp(r'error: GH003: Sorry, force-pushing to (.+) is not allowed.'): GitError.forcePushRejected,
  RegExp(r'error: GH005: Sorry, refs longer than (.+) bytes are not allowed'): GitError.invalidRefLength,
  RegExp(r'error: GH006: Protected branch update failed for (.+)\nremote: error: At least one approved review is required'):
      GitError.protectedBranchRequiresReview,
  RegExp(r'error: GH006: Protected branch update failed for (.+)\nremote: error: Cannot force-push to a protected branch'):
      GitError.protectedBranchForcePush,
  RegExp(r'error: GH006: Protected branch update failed for (.+)\nremote: error: Cannot delete a protected branch'):
      GitError.protectedBranchDeleteRejected,
  RegExp(r'error: GH006: Protected branch update failed for (.+).\nremote: error: Required status check "(.+)" is expected'):
      GitError.protectedBranchRequiredStatus,
  RegExp(r'error: GH007: Your push would publish a private email address.'): GitError.pushWithPrivateEmail,
  RegExp(r'error: could not lock config file (.+): File exists'): GitError.configLockFileAlreadyExists,
  RegExp(r'error: remote (.+) already exists.'): GitError.remoteAlreadyExists,
  RegExp(r"fatal: tag '(.+)' already exists"): GitError.tagAlreadyExists,
  RegExp(r'error: Your local changes to the following files would be overwritten by merge:\n'):
      GitError.mergeWithLocalChanges,
  RegExp(r'error: cannot (pull with rebase|rebase): You have unstaged changes\.\n\s*error: [Pp]lease commit or stash them\.'):
      GitError.rebaseWithLocalChanges,
  RegExp(r'error: commit (.+) is a merge but no -m option was given'): GitError.mergeCommitNoMainlineOption,
  RegExp(r'fatal: detected dubious ownership in repository at (.+)'): GitError.unsafeDirectory,
  RegExp(r"fatal: path '(.+)' exists on disk, but not in '(.+)'"): GitError.pathExistsButNotInRef,
  RegExp(r'GITHUB PUSH PROTECTION[.\s\S]+Push cannot contain secrets'): GitError.pushWithSecretDetected,
};

// Checked before the upstream table: these would otherwise match less specific patterns.
final Map<RegExp, GitError> _gitHubPlusPatterns = {
  RegExp(r'Author identity unknown|Please tell me who you are'): GitError.authorIdentityUnknown,
  // The local hub denies rewriting or deleting history (receive.denyNonFastForwards/Deletes).
  RegExp(r'denying non-fast-forward|pre-receive hook declined|deletion prohibited|denying ref deletion'):
      GitError.hubHistoryProtected,
};

/// Finds the first known error in git's output, or null.
GitError? parseGitError(String output) {
  for (final entry in _gitHubPlusPatterns.entries) {
    if (entry.key.hasMatch(output)) return entry.value;
  }
  for (final entry in _patterns.entries) {
    if (entry.key.hasMatch(output)) return entry.value;
  }
  return null;
}

/// Coarse categories the UI reacts to (same set as GitHub+ v1).
enum GitErrorKind {
  notARepository,
  authenticationFailed,
  pushRejected,
  pushNeedsPull,
  mergeConflicts,
  localChangesOverwritten,
  branchExists,
  noUpstream,
  network,
  hubHistoryProtected,
  identityMissing,
  unknown,
}

GitErrorKind classifyGitError(GitError? error) => switch (error) {
  GitError.notAGitRepository => GitErrorKind.notARepository,
  GitError.sshAuthenticationFailed ||
  GitError.sshPermissionDenied ||
  GitError.httpsAuthenticationFailed => GitErrorKind.authenticationFailed,
  GitError.pushNotFastForward => GitErrorKind.pushNeedsPull,
  GitError.pushWithFileSizeExceedingLimit ||
  GitError.forcePushRejected ||
  GitError.protectedBranchForcePush ||
  GitError.protectedBranchRequiresReview ||
  GitError.protectedBranchDeleteRejected ||
  GitError.pushWithSecretDetected => GitErrorKind.pushRejected,
  GitError.mergeConflicts || GitError.rebaseConflicts || GitError.revertConflicts => GitErrorKind.mergeConflicts,
  GitError.localChangesOverwritten ||
  GitError.mergeWithLocalChanges ||
  GitError.rebaseWithLocalChanges => GitErrorKind.localChangesOverwritten,
  GitError.branchAlreadyExists => GitErrorKind.branchExists,
  GitError.noMatchingRemoteBranch || GitError.noExistingRemoteBranch => GitErrorKind.noUpstream,
  GitError.hostDown ||
  GitError.remoteDisconnection ||
  GitError.httpsRepositoryNotFound ||
  GitError.sshRepositoryNotFound => GitErrorKind.network,
  GitError.hubHistoryProtected => GitErrorKind.hubHistoryProtected,
  GitError.authorIdentityUnknown => GitErrorKind.identityMissing,
  _ => GitErrorKind.unknown,
};
