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
