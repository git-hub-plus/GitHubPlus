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
  String get addClone => 'Clone repository…';

  @override
  String get pickRepositoryFolder => 'Choose a repository folder';

  @override
  String notARepository(String path) {
    return '$path is not a Git repository.';
  }

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
  String get questFirstCommit => 'Make your first commit';

  @override
  String get questFirstPush => 'Push to a remote';

  @override
  String get branchLabel => 'Branch';

  @override
  String detachedHead(String sha) {
    return 'Detached HEAD $sha';
  }

  @override
  String get noBranch => 'No branch';

  @override
  String get actionCommit => 'Commit';

  @override
  String actionPush(int count) {
    return 'Push $count';
  }

  @override
  String actionPull(int count) {
    return 'Pull $count';
  }

  @override
  String get actionPublish => 'Publish';

  @override
  String get actionFetch => 'Fetch';

  @override
  String get actionResolve => 'Resolve conflicts';

  @override
  String lastFetched(String time) {
    return 'Last fetched $time';
  }

  @override
  String get neverFetched => 'Never fetched';

  @override
  String get hudChanges => 'Changed files';

  @override
  String get hudToPush => 'To push';

  @override
  String get hudToPull => 'To pull';

  @override
  String get hudStashes => 'Stashes';

  @override
  String get hudConflicts => 'Conflicts';

  @override
  String get hudHub => 'Hub';

  @override
  String get hudHubOnline => 'Online';

  @override
  String get hudHubOffline => 'Offline';

  @override
  String get hudHubNone => 'None';

  @override
  String get hudChangesTip => 'Files with uncommitted changes';

  @override
  String get hudToPushTip => 'Commits only on this PC, not pushed yet';

  @override
  String get hudToPullTip => 'Commits on the remote you have not pulled yet';

  @override
  String get goalPush => 'Push backlog goal';

  @override
  String get goalDailyCommits => 'Today\'s commits';

  @override
  String get goalReached => 'Goal reached!';

  @override
  String goalRemaining(int count) {
    return '$count to go';
  }

  @override
  String get tabChanges => 'Changes';

  @override
  String get tabHistory => 'History';

  @override
  String get tabExpeditions => 'Expeditions';

  @override
  String get expeditionsTitle => 'Expeditions';

  @override
  String get expeditionsEmpty =>
      'No expeditions running. Long operations such as push, pull and clone show up here.';

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
    return 'Destination: $destination';
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
  String get settingsDailyGoal => 'Daily commit goal';

  @override
  String get settingsPushGoal => 'Push backlog goal';

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
}
