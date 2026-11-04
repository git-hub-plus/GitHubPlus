// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'GitHub+';

  @override
  String get libraryTitle => 'Library';

  @override
  String get libraryFilter => 'Search repositories  (Ctrl+P)';

  @override
  String get libraryEmpty => 'No repositories yet.';

  @override
  String get libraryAdd => 'Add repository';

  @override
  String get groupLocal => 'Local';

  @override
  String get groupHub => 'Hub';

  @override
  String get groupGithub => 'GitHub';

  @override
  String get repoMissing => 'Missing';

  @override
  String repoChanges(int count) {
    return '$count changed';
  }

  @override
  String get addExisting => 'Add local repository…';

  @override
  String get addCreate => 'Create new repository…';

  @override
  String addClone(String clone) {
    return '$clone…';
  }

  @override
  String get pickRepositoryFolder => 'Choose a repository folder';

  @override
  String notARepository(String path) {
    return '$path is not a Git repository.';
  }

  @override
  String get addFailed => 'Could not add the repository.';

  @override
  String get welcomeTitle => 'Welcome to GitHub+';

  @override
  String get welcomeBody =>
      'A lightweight Git client with a LAN hub and at-a-glance status. Add a repository to get started.';

  @override
  String get questFirstTitle => 'First quest';

  @override
  String get questAddRepo => 'Add a repository';

  @override
  String questFirstCommit(String commit) {
    return '$commit for the first time';
  }

  @override
  String questFirstPush(String remote, String push) {
    return 'First $push to a $remote';
  }

  @override
  String branchLabel(String branch) {
    return '$branch';
  }

  @override
  String detachedHead(String sha) {
    return 'Detached HEAD $sha';
  }

  @override
  String noBranch(String branch) {
    return 'No $branch';
  }

  @override
  String actionCommit(String commit) {
    return '$commit';
  }

  @override
  String actionPush(String push, int count) {
    return '$push $count';
  }

  @override
  String actionPull(String pull, int count) {
    return '$pull $count';
  }

  @override
  String actionPublish(String publish) {
    return '$publish';
  }

  @override
  String actionFetch(String fetch) {
    return '$fetch';
  }

  @override
  String actionResolve(String conflict) {
    return 'Resolve: $conflict';
  }

  @override
  String lastFetched(String fetch, String time) {
    return 'Last $fetch: $time';
  }

  @override
  String neverFetched(String fetch) {
    return '$fetch: not yet';
  }

  @override
  String hudChanges(String changes) {
    return '$changes';
  }

  @override
  String hudToPush(String push) {
    return '$push queue';
  }

  @override
  String hudToPull(String pull) {
    return '$pull queue';
  }

  @override
  String hudStashes(String stash) {
    return '$stash';
  }

  @override
  String hudConflicts(String conflict) {
    return '$conflict';
  }

  @override
  String get hudHub => 'Hub';

  @override
  String get hudHubOnline => 'Online';

  @override
  String get hudHubOffline => 'Offline';

  @override
  String get hudHubNone => 'None';

  @override
  String hudChangesTip(String commit) {
    return 'Changed files not saved with $commit yet';
  }

  @override
  String hudToPushTip(String remote, String push, String commitUnit) {
    return '$commitUnit only on this PC, not sent with $push yet';
  }

  @override
  String hudToPullTip(String remote, String pull, String commitUnit) {
    return 'New $commitUnit on the $remote not received with $pull yet';
  }

  @override
  String goalPush(String push) {
    return '$push queue goal';
  }

  @override
  String goalDailyCommits(String commitUnit) {
    return 'Today\'s $commitUnit';
  }

  @override
  String get goalReached => 'Goal reached!';

  @override
  String goalRemaining(int count) {
    return '$count to go';
  }

  @override
  String tabChanges(String changes) {
    return '$changes';
  }

  @override
  String get changesSelectAll => 'Select all';

  @override
  String changesIncluded(int total, int included) {
    return '$included of $total included';
  }

  @override
  String changesConflicts(int count) {
    return 'Resolve $count conflicts first';
  }

  @override
  String get changesAdded => 'Added';

  @override
  String get changesModified => 'Modified';

  @override
  String get changesDeleted => 'Deleted';

  @override
  String get changesRenamed => 'Renamed';

  @override
  String changesConflict(String count) {
    return 'Conflict ? $count';
  }

  @override
  String get changesSummary => 'Summary (required)';

  @override
  String get changesDescription => 'Description';

  @override
  String changesRemaining(int count) {
    return '$count characters to recommended limit';
  }

  @override
  String changesAmend(String commit) {
    return 'Amend last $commit';
  }

  @override
  String changesCommit(String branch, String commit) {
    return '$commit to $branch';
  }

  @override
  String changesCommitted(String commit, String sha) {
    return '$commit complete ? $sha';
  }

  @override
  String get changesDiscard => 'Discard';

  @override
  String get changesDiscardFile => 'Discard this file';

  @override
  String get changesCopyPath => 'Copy path';

  @override
  String changesDiscardTitle(int count) {
    return 'Discard changes in $count files?';
  }

  @override
  String get changesDiscardBody =>
      'A copy is saved in the backup folder before restoring.';

  @override
  String get changesCancel => 'Cancel';

  @override
  String get changesDiscarded => 'Changes discarded ? Open backup folder';

  @override
  String get changesSaved => 'Everything saved';

  @override
  String changesEmptyHint(String push, int count) {
    return 'Check task activity or $count waiting to $push.';
  }

  @override
  String get changesPickFile => 'Select a file to view its changes.';

  @override
  String get changesFailed => 'Could not complete the operation.';

  @override
  String get changesRetry => 'Retry';

  @override
  String get changesDetached => 'Current location';

  @override
  String get changesResize => 'Resize file list';

  @override
  String get changesBusy => 'Working?';

  @override
  String tabHistory(String history) {
    return '$history';
  }

  @override
  String get tabExpeditions => 'Activity';

  @override
  String get expeditionsTitle => 'Activity';

  @override
  String expeditionsEmpty(String push, String pull, String clone) {
    return 'Nothing running. Long operations such as $push, $pull and $clone show up here.';
  }

  @override
  String conflictQuestTitle(String operation, String name) {
    return '$operation in progress · $name';
  }

  @override
  String conflictRebaseStep(String operation, int step, int total) {
    return '$operation step $step/$total';
  }

  @override
  String conflictProgress(int resolved, int total) {
    return 'Resolved $resolved/$total conflict files';
  }

  @override
  String get conflictSteps =>
      '① Resolve conflicts → ② Mark resolved → ③ Continue';

  @override
  String conflictContinue(String operation) {
    return 'Continue $operation';
  }

  @override
  String conflictAbort(String operation) {
    return 'Abort $operation';
  }

  @override
  String get conflictAbortBody =>
      'Cancel this operation and its conflict resolutions, returning to the starting state.';

  @override
  String mergeMessage(String merge) {
    return 'Review $merge message';
  }

  @override
  String get conflictOurs => 'My side (current)';

  @override
  String get conflictTheirs => 'Incoming side';

  @override
  String get conflictBoth => 'Both';

  @override
  String get conflictAllOurs => 'Use my side for entire file';

  @override
  String get conflictAllTheirs => 'Use incoming side for entire file';

  @override
  String get conflictSave => 'Save and mark resolved';

  @override
  String get conflictSideOnly =>
      'Binary, deleted or unreadable file. Choose one side for the entire file.';

  @override
  String get conflictStale =>
      'The file changed. Reopen it to review the current contents.';

  @override
  String mergeInto(String branch, String merge) {
    return '$merge into current $branch';
  }

  @override
  String rebaseOnto(String branch, String rebase) {
    return '$rebase onto this $branch';
  }

  @override
  String rebaseWarning(String rebase) {
    return '$rebase can rewrite versions already uploaded. Coordinate with collaborators before continuing.';
  }

  @override
  String mergeConflicts(String changes) {
    return 'Conflicts found. Resolve them in $changes.';
  }

  @override
  String mergeCompleted(String operation) {
    return '$operation completed';
  }

  @override
  String get mergeNothing => 'Already up to date';

  @override
  String get expeditionRunning => 'Running';

  @override
  String get expeditionDone => 'Done';

  @override
  String get expeditionFailed => 'Failed';

  @override
  String get expeditionCollect => 'View result';

  @override
  String get expeditionDismiss => 'Dismiss';

  @override
  String expeditionElapsed(String time) {
    return 'Elapsed $time';
  }

  @override
  String expeditionRemaining(String time) {
    return 'About $time left';
  }

  @override
  String expeditionTo(String destination) {
    return 'Target: $destination';
  }

  @override
  String get settingsTitle => 'Preferences';

  @override
  String get settingsLanguage => '언어 / Language';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get settingsGoals => 'Goal bars';

  @override
  String settingsDailyGoal(String commitUnit) {
    return 'Daily $commitUnit goal';
  }

  @override
  String settingsPushGoal(String push) {
    return '$push queue goal';
  }

  @override
  String get settingsReduceMotion => 'Reduce animations';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonDetails => 'Details';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowClose => 'Close';

  @override
  String get openSettings => 'Preferences';

  @override
  String get hubOpen => 'Local hub';

  @override
  String hudStashesTip(String stash) {
    return 'Work set aside ($stash)';
  }

  @override
  String get hudConflictsTip =>
      'Files changed on both sides that need a decision';

  @override
  String jobPull(String name, String pull) {
    return '$pull from $name';
  }

  @override
  String jobPush(String name, String push) {
    return '$push to $name';
  }

  @override
  String jobPublish(String name, String publish) {
    return '$publish $name';
  }

  @override
  String jobFetch(String name, String fetch) {
    return '$fetch: $name';
  }

  @override
  String resultSent(String commitUnit, int count, String push) {
    return '$count $commitUnit sent ($push)';
  }

  @override
  String resultReceived(String commitUnit, int count) {
    return '$count new $commitUnit received';
  }

  @override
  String get resultUpToDate => 'Already up to date';

  @override
  String get settingsTerms => 'Terminology';

  @override
  String get hubHostTitle => 'LAN hub management';

  @override
  String get hubHostSubtitle =>
      'Keep your team’s repositories and version history on this PC.';

  @override
  String get hubHostRunning => 'Running';

  @override
  String get hubHostStopped => 'Stopped';

  @override
  String get hubHostError => 'Server error';

  @override
  String get hubHostPower => 'Turn hub on / off';

  @override
  String get hubHostName => 'Hub name';

  @override
  String get hubHostPort => 'Port';

  @override
  String get hubHostAddresses => 'Connection addresses';

  @override
  String get hubHostConnectHint => 'Connect from another PC using this address';

  @override
  String get hubHostStartHint =>
      'Turn on the hub to see connection addresses and repositories.';

  @override
  String get hubHostRepositories => 'Repositories';

  @override
  String hubHostToday(String push) {
    return 'Today’s $push';
  }

  @override
  String get hubHostSettings => 'Server settings';

  @override
  String get hubHostRoot => 'Repository folder';

  @override
  String get hubHostBackupFolder => 'Backup folder (optional)';

  @override
  String get hubHostChoose => 'Choose folder';

  @override
  String get hubHostClear => 'Clear backup folder';

  @override
  String get hubHostKeepRunning => 'Keep running when the window closes';

  @override
  String get hubHostTrayHint =>
      'This preference is saved. Tray support is coming in a later step.';

  @override
  String get hubHostSave => 'Save and apply';

  @override
  String get hubHostSaved => 'Settings saved.';

  @override
  String get hubHostRestartHint => 'Applying settings restarts a running hub.';

  @override
  String get hubHostInvalidPort => 'Enter a port between 1024 and 65535.';

  @override
  String get hubHostRequired => 'Enter a value.';

  @override
  String get hubHostNewRepository => 'New repository';

  @override
  String get hubHostRepositoryName => 'Repository name';

  @override
  String get hubHostDescription => 'Description';

  @override
  String get hubHostInvalidName =>
      'Use 1–100 letters, digits, _, - or .; no .., trailing dot, leading -, or Windows reserved names.';

  @override
  String get hubHostCreate => 'Create';

  @override
  String get hubHostCreated => 'Repository created.';

  @override
  String get hubHostDelete => 'Delete';

  @override
  String hubHostDeleteTitle(String name) {
    return 'Delete repository $name?';
  }

  @override
  String get hubHostTrashHint =>
      'The repository moves to the trash folder and is no longer accessible from this hub.';

  @override
  String get hubHostDeleted => 'Repository moved to the trash folder.';

  @override
  String hubHostClone(String clone) {
    return 'Copy $clone address';
  }

  @override
  String get hubHostCopy => 'Copy address';

  @override
  String get hubHostCopied => 'Address copied.';

  @override
  String hubHostDefaultBranch(String branch, String name) {
    return 'Default $branch: $name';
  }

  @override
  String hubHostLastPush(String push, String time) {
    return 'Last $push: $time';
  }

  @override
  String get hubHostNever => 'None yet';

  @override
  String get hubHostNoRepositories =>
      'No repositories yet. Create one to share with your team.';

  @override
  String hubHostPushLog(String push) {
    return '$push log · latest 100';
  }

  @override
  String get hubHostAllRepositories => 'All repositories';

  @override
  String get hubHostNoPushes => 'No updates received yet.';

  @override
  String hubHostSender(String address, String host) {
    return 'Sender: $address · $host';
  }

  @override
  String get hubHostUnknownHost => 'No hostname';

  @override
  String hubHostProtection(String push, String branch, String commitUnit) {
    return 'The hub rejects forced $push and $branch deletion — all $commitUnit remain in history.';
  }

  @override
  String get hubHostBackup => 'Back up now';

  @override
  String get hubHostBackupHint =>
      'Choose a backup folder and turn on the hub to back up.';

  @override
  String hubHostBackupDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Backed up $count repositories.',
      one: 'Backed up 1 repository.',
    );
    return '$_temp0';
  }

  @override
  String get hubHostFailed => 'Could not complete the operation.';

  @override
  String get hubHostRetry => 'Retry';

  @override
  String get hubHostRefresh => 'Refresh';

  @override
  String get hubHostClose => 'Close';

  @override
  String get hubHostCancel => 'Cancel';

  @override
  String get termPlain => 'Plain words (new to Git)';

  @override
  String get termGit => 'Git terms (GitHub users)';

  @override
  String termExample(String plain, String git) {
    return 'e.g. $plain  ↔  $git';
  }

  @override
  String gitTermHint(String term) {
    return 'Git term: $term';
  }

  @override
  String get tabOverview => 'Overview';

  @override
  String get overviewWorkingTree => 'Working folder';

  @override
  String historyCurrent(String branch) {
    return 'Current $branch';
  }

  @override
  String historyAll(String branch) {
    return 'All ${branch}es';
  }

  @override
  String get historySearch => 'Search summary or author (loaded history)';

  @override
  String historyEmpty(String commitUnit) {
    return 'No $commitUnit yet';
  }

  @override
  String get historyNoResults => 'No matching history';

  @override
  String get historySelect => 'Select an entry from the list';

  @override
  String historyFiles(int count) {
    return 'Changed files ($count)';
  }

  @override
  String get historyNoFiles => 'No changed files';

  @override
  String get hubClientTitle => 'Hubs';

  @override
  String get hubClientAdd => 'Add hub by address';

  @override
  String get hubClientAddress => 'Hub address';

  @override
  String get hubClientAddressHint => 'e.g. 192.168.0.10:8765';

  @override
  String get hubClientConnect => 'Connect';

  @override
  String get hubClientCancel => 'Cancel';

  @override
  String get hubClientOffline => 'Offline';

  @override
  String get hubClientOnline => 'Online';

  @override
  String get hubClientEmpty =>
      'No repositories yet. Publish one from your library.';

  @override
  String get hubClientNone =>
      'Looking for hubs on your network. You can also add an address.';

  @override
  String get hubClientOverview => 'Overview';

  @override
  String hubClientHistory(String history) {
    return '$history';
  }

  @override
  String hubClientPushes(String push) {
    return '$push activity';
  }

  @override
  String hubClientClone(String clone) {
    return '$clone to my PC';
  }

  @override
  String get hubClientPublish => 'Publish to hub';

  @override
  String get hubClientName => 'Repository name';

  @override
  String get hubClientDescription => 'Description (optional)';

  @override
  String get hubClientInvalidName =>
      'Use 1-100 letters, numbers, dots, underscores or hyphens. Avoid consecutive dots, a trailing dot, a leading hyphen and Windows reserved names.';

  @override
  String get hubClientFailed =>
      'Could not finish. Check the connection and repository folder, then try again.';

  @override
  String get hubClientUnavailable =>
      'Cannot reach the hub. Check that it is on and on the same network.';

  @override
  String get hubClientTimeout =>
      'The hub is taking too long. Try again shortly.';

  @override
  String get hubClientConflict =>
      'That repository name is taken. Choose another name.';

  @override
  String get hubClientInvalidAddress =>
      'Check the LAN hub address, e.g. 192.168.0.10:8765.';

  @override
  String hubClientNoPush(String push) {
    return 'No $push activity yet.';
  }

  @override
  String hubClientLastPush(String push, String time) {
    return 'Last $push: $time';
  }

  @override
  String get hubClientBack => 'Hub repositories';

  @override
  String get hubClientFolder => 'Choose a parent folder';

  @override
  String hubClientBranch(String branch) {
    return 'Choose or enter a $branch';
  }

  @override
  String get hubClientMore => 'Load older history';

  @override
  String get hubClientDone => 'Completed.';

  @override
  String get historySelectFile => 'Select a file to inspect changes';

  @override
  String historyParents(String commitUnit) {
    return 'Parent $commitUnit';
  }

  @override
  String get historyCopySha => 'Copy SHA';

  @override
  String get historyCopied => 'SHA copied';

  @override
  String get historyLoadMore => 'Load next 200';

  @override
  String get historyRetry => 'Retry';

  @override
  String get historyResize => 'Resize list and details';

  @override
  String get historyClose => 'Close';

  @override
  String branchSearch(String branch) {
    return 'Search $branch';
  }

  @override
  String get branchCurrent => 'Current';

  @override
  String branchLocal(String branch) {
    return 'Local ${branch}es';
  }

  @override
  String branchRemote(String branch) {
    return 'Remote ${branch}es';
  }

  @override
  String branchCreate(String branch) {
    return 'Create $branch';
  }

  @override
  String branchName(String branch) {
    return '$branch name';
  }

  @override
  String get branchNameHint => 'Spaces become hyphens';

  @override
  String get branchExists => 'This name already exists';

  @override
  String get branchInvalid => 'Enter a valid name';

  @override
  String get branchRename => 'Rename';

  @override
  String get branchDelete => 'Delete';

  @override
  String get branchCancel => 'Cancel';

  @override
  String get branchSave => 'Save';

  @override
  String branchSwitch(String name) {
    return 'Switch to $name';
  }

  @override
  String branchSwitchWarning(String name) {
    return 'There are changed files. Switch to $name? Git will refuse if changes overlap.';
  }

  @override
  String get branchContinue => 'Switch';

  @override
  String branchDeleteConfirm(String name) {
    return 'Delete $name?';
  }

  @override
  String branchForce(String merge) {
    return 'Delete even if not yet ${merge}d';
  }

  @override
  String get branchDeleteRemote => 'Also delete on the remote';

  @override
  String get branchRemoteWarning =>
      'Without remote deletion, only this PC\'s tracking reference is removed.';

  @override
  String get branchFailed => 'Could not complete the operation';

  @override
  String get branchEmpty => 'No matching entries';

  @override
  String branchMenu(String name) {
    return 'Menu for $name';
  }

  @override
  String branchAheadBehind(int ahead, int behind) {
    return 'Ahead $ahead / behind $behind';
  }

  @override
  String overviewWorkingTreeTip(String commit) {
    return 'Shows the folder as it is now, including edits not yet ${commit}ted. Files hidden by .gitignore are left out.';
  }

  @override
  String overviewHead(String commitUnit) {
    return 'Last $commitUnit (HEAD)';
  }

  @override
  String overviewHeadTip(String branch) {
    return 'Shows what is saved on the current $branch, the same as other PCs and the hub see it.';
  }

  @override
  String get overviewRefresh => 'Refresh';

  @override
  String stashTitle(String stash) {
    return '$stash';
  }

  @override
  String stashCreate(String stash) {
    return '$stash current changes';
  }

  @override
  String get stashMessage => 'Message (optional)';

  @override
  String get stashUntracked => 'Include new files';

  @override
  String get stashEmpty => 'Nothing set aside yet.';

  @override
  String get stashPop => 'Pop';

  @override
  String get stashApply => 'Apply only';

  @override
  String get stashDrop => 'Drop';

  @override
  String get stashDropConfirm =>
      'Drop this entry? Its saved changes cannot be recovered.';

  @override
  String get stashSelect => 'Expand an entry and select a file.';

  @override
  String get historyActionMenu => 'Actions';

  @override
  String get historyActionCancel => 'Cancel';

  @override
  String get historyActionClose => 'Close';

  @override
  String get historyActionConfirm => 'Continue';

  @override
  String get historyActionDone => 'Operation completed.';

  @override
  String get historyActionNothing => 'Nothing to do.';

  @override
  String historyActionConflicts(String changes) {
    return 'Conflicts found. Resolve them in the $changes tab.';
  }

  @override
  String get historyActionFailed => 'Operation failed.';

  @override
  String historyActionRevert(String commitUnit, String revert) {
    return '$revert: $commitUnit';
  }

  @override
  String historyActionRevertConfirm(String commitUnit) {
    return 'Create new $commitUnit that undo the selected changes?';
  }

  @override
  String historyActionPick(String branch, String cherryPick) {
    return '$cherryPick into the current $branch';
  }

  @override
  String historyActionUndo(String commitUnit) {
    return 'Undo last $commitUnit';
  }

  @override
  String historyActionUndoConfirm(String commitUnit) {
    return 'Undo the last $commitUnit and keep its changes?';
  }

  @override
  String historyActionUndoMessage(String message) {
    return 'Undone. Message: $message';
  }

  @override
  String get historyActionCopyMessage => 'Copy message';

  @override
  String historyActionSquash(String squash) {
    return '$squash…';
  }

  @override
  String get historyActionMessage => 'Message';

  @override
  String get historyActionUp => 'Move up';

  @override
  String get historyActionDown => 'Move down';

  @override
  String get historyActionPublished =>
      'This changes history already uploaded to a remote. Coordinate with collaborators before continuing.';

  @override
  String historyActionSelection(int count) {
    return '$count selected · Ctrl/Shift+click to select multiple';
  }

  @override
  String tagCreate(String tag) {
    return 'Create $tag…';
  }

  @override
  String get tagName => 'Name';

  @override
  String get tagDescription => 'Description (optional)';

  @override
  String tagPush(String tag) {
    return 'Upload $tag to remote';
  }

  @override
  String tagDelete(String tag) {
    return 'Delete $tag';
  }

  @override
  String get tagRemote => 'Delete from remote too';

  @override
  String tagDeleteConfirm(String name) {
    return 'Delete $name?';
  }

  @override
  String get overviewOpenFolder => 'Open in Explorer';

  @override
  String get overviewEmptyFolder => 'This folder is empty.';

  @override
  String get overviewNoReadme =>
      'No README yet. Add a README.md file and it will introduce this repository here.';

  @override
  String overviewNoCommits(String commitUnit) {
    return 'No $commitUnit yet. Switch to the working folder view.';
  }

  @override
  String overviewTooLarge(String size) {
    return 'Too large to preview ($size).';
  }

  @override
  String overviewBinary(String size) {
    return 'Binary file, no preview ($size).';
  }

  @override
  String get overviewMissing => 'File not found.';

  @override
  String get overviewBlocked =>
      'Points outside the repository, so it was not opened.';

  @override
  String get overviewSubmodule => 'Submodule';

  @override
  String get overviewSymlink => 'Symbolic link';

  @override
  String overviewRemoteImage(String alt) {
    return 'External image: $alt';
  }

  @override
  String get overviewRaw => 'Source';

  @override
  String get overviewRendered => 'Preview';

  @override
  String overviewLoadError(String error) {
    return 'Could not load: $error';
  }

  @override
  String get diffNoChanges => 'No changes.';

  @override
  String diffLarge(String size) {
    return 'This diff is large ($size), so it is collapsed.';
  }

  @override
  String get diffShowAnyway => 'Show anyway';

  @override
  String get diffBinary => 'Binary file, no diff to show.';

  @override
  String get diffUnrenderable => 'This diff cannot be displayed.';

  @override
  String diffSubmodule(String from, String to) {
    return 'Submodule changed from $from to $to.';
  }

  @override
  String get diffBidiWarning =>
      'Hidden bidirectional Unicode characters: the code may not be what it looks like.';

  @override
  String diffLineEndings(String from, String to) {
    return 'Line endings change from $from to $to.';
  }

  @override
  String get diffImageBefore => 'Before';

  @override
  String get diffImageAfter => 'After';
}
