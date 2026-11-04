import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/models/app_models.dart';
import 'package:github_plus/core/git/git_runner.dart';
import 'package:github_plus/core/git/git_errors.dart';
import 'package:github_plus/core/storage/repository_store.dart';
import 'package:github_plus/l10n/app_localizations.dart';
import 'package:github_plus/l10n/terms.dart';
import 'package:github_plus/state/app_state.dart';
import 'package:github_plus/ui/theme.dart';

import '../../core/git/helpers.dart';

class HistoryFixture {
  HistoryFixture(this.repos, this.repo) : git = ObservedGitRunner(executable: repos.git.executable);
  final TestRepos repos;
  final RepositoryInfo repo;
  final ObservedGitRunner git;
  static Future<HistoryFixture> create() async {
    final repos = await TestRepos.create();
    final path = await repos.init('history');
    return HistoryFixture(
      repos,
      RepositoryInfo(
        id: 'test-history',
        path: path,
        name: 'history',
        group: RepositoryGroup.local,
        addedAt: DateTime.now(),
      ),
    );
  }

  Bootstrap get bootstrap => Bootstrap(
    dataDirectory: repos.root,
    git: git,
    repositoryStore: RepositoryStore(file: File('${repos.root.path}/repositories.json'), git: repos.git),
    settings: const AppSettings(),
    repositories: [repo],
  );

  Widget app(
    Widget child, {
    Brightness brightness = Brightness.dark,
    AppLanguage language = AppLanguage.en,
    TermStyle terms = TermStyle.plain,
  }) => ProviderScope(
    overrides: [bootstrapProvider.overrideWithValue(bootstrap)],
    child: MaterialApp(
      theme: buildTheme(brightness),
      locale: Locale(language.name),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      builder: (context, child) => TermsScope(terms: Terms.resolve(language, terms), language: language, child: child!),
      home: Scaffold(body: child),
    ),
  );
}

/// Git processes need real event-loop time; pumpAndSettle alone cannot await them.
Future<void> pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 900; i++) {
    await tester.pump(const Duration(milliseconds: 30));
    if (condition()) return;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  }
  throw TestFailure('Timed out waiting for Git/UI state');
}

/// Observes real processes, without faking Git results or overriding feature providers.
class ObservedGitRunner extends GitRunner {
  ObservedGitRunner({required super.executable});
  int pending = 0;
  @override
  Future<GitResult> run(
    List<String> args, {
    required String cwd,
    Set<int> successExitCodes = const {0},
    Set<GitError> expectedErrors = const {},
    String? stdin,
    List<int>? stdinBytes,
    Map<String, String> environment = const {},
    void Function(String)? onStderrLine,
  }) async {
    pending++;
    try {
      return await super.run(
        args,
        cwd: cwd,
        successExitCodes: successExitCodes,
        expectedErrors: expectedErrors,
        stdin: stdin,
        stdinBytes: stdinBytes,
        environment: environment,
        onStderrLine: onStderrLine,
      );
    } finally {
      pending--;
    }
  }

  @override
  Future<List<int>> runBytes(List<String> args, {required String cwd}) async {
    pending++;
    try {
      return await super.runBytes(args, cwd: cwd);
    } finally {
      pending--;
    }
  }
}

Future<void> settleGit(WidgetTester tester, HistoryFixture fixture) async {
  for (var i = 0; i < 3; i++) {
    await pumpUntil(tester, () => fixture.git.pending == 0 && !tester.binding.hasScheduledFrame);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await pumpUntil(tester, () => fixture.git.pending == 0 && !tester.binding.hasScheduledFrame);
}

void drainGitOnTearDown(WidgetTester tester, HistoryFixture fixture) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await pumpUntil(tester, () => fixture.git.pending == 0);
  });
}
