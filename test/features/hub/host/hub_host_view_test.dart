import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/hub/hub_models.dart';
import 'package:github_plus/core/hub/server.dart';
import 'package:github_plus/core/models/app_models.dart';
import 'package:github_plus/core/storage/json_file.dart';
import 'package:github_plus/core/storage/repository_store.dart';
import 'package:github_plus/features/hub/host/hub_host_view.dart';
import 'package:github_plus/l10n/app_localizations.dart';
import 'package:github_plus/l10n/terms.dart';
import 'package:github_plus/state/app_state.dart';
import 'package:github_plus/state/hub_host_state.dart';
import 'package:github_plus/ui/theme.dart';
import 'package:path/path.dart' as p;

import '../../../core/git/helpers.dart';

/// Runs the actual implementation; only OS port selection and LAN announcements differ.
class EphemeralHubServer extends HubServer {
  EphemeralHubServer(TestRepos repos) : super(git: repos.git, appVersion: '0.1.0', announce: false);
  int starts = 0;
  @override
  Future<HubServerStatus> start(HubSettings settings) {
    starts++;
    return super.start(settings.copyWith(port: 0));
  }
}

class RealHttpOverrides extends HttpOverrides {}

class HubFixture {
  HubFixture(this.repos) : server = EphemeralHubServer(repos);
  final TestRepos repos;
  final EphemeralHubServer server;
  Bootstrap get bootstrap => Bootstrap(
    dataDirectory: repos.root,
    git: repos.git,
    repositoryStore: RepositoryStore(file: File(p.join(repos.root.path, 'repositories.json')), git: repos.git),
    settings: const AppSettings(),
    repositories: const [],
  );
  List<Override> get overrides => [
    bootstrapProvider.overrideWithValue(bootstrap),
    hubServerProvider.overrideWith((ref) {
      ref.onDispose(() {
        server.stop();
      });
      return server;
    }),
  ];
  Widget app({
    AppLanguage language = AppLanguage.en,
    TermStyle terms = TermStyle.plain,
    Brightness brightness = Brightness.dark,
  }) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: buildTheme(brightness),
      locale: Locale(language.name),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      builder: (context, child) => TermsScope(terms: Terms.resolve(language, terms), language: language, child: child!),
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) =>
              TextButton(onPressed: () => showHubHost(context, ref), child: const Text('Open')),
        ),
      ),
    ),
  );
}

Future<void> until(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 600; i++) {
    await tester.pump(const Duration(milliseconds: 30));
    if (condition()) return;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  }
  throw TestFailure('Timed out waiting for actual hub server/UI');
}

// A server started by a widget has callbacks in the test clock's zone. Keep
// pumping that zone while real Git/HTTP work runs outside it.
Future<T> drive<T>(WidgetTester tester, Future<T> Function() action) async {
  T? value;
  Object? failure;
  var done = false;
  await tester.runAsync(() async {
    action().then(
      (result) {
        value = result;
        done = true;
      },
      onError: (Object error) {
        failure = error;
        done = true;
      },
    );
  });
  await until(tester, () => done);
  if (failure != null) throw failure!;
  return value as T;
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late HubFixture fixture;
  setUp(() async {
    fixture = HubFixture(await TestRepos.create());
  });
  tearDown(() async {
    await fixture.server.stop();
    await fixture.repos.dispose();
  });

  Future<ProviderContainer> open(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.en,
    TermStyle terms = TermStyle.plain,
    Brightness brightness = Brightness.dark,
    Size size = const Size(1200, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(fixture.app(language: language, terms: terms, brightness: brightness));
    final container = ProviderScope.containerOf(tester.element(find.text('Open')));
    await tester.tap(find.text('Open'));
    await until(tester, () => container.read(hubSettingsProvider).hasValue);
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  testWidgets('power, addresses, create, real HTTP push, protection, filter, backup and trash', (tester) async {
    final container = await open(tester);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('hub-host-backup'))).onPressed, isNull);
    await tapVisible(tester, find.byKey(const Key('hub-host-power')));
    await until(tester, () => fixture.server.status.running);
    await until(tester, () => find.text(fixture.server.status.addresses.first).evaluate().isNotEmpty);
    expect(find.text('Connect from another PC using this address'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('hub-host-new')));
    await tester.enterText(find.byKey(const Key('hub-new-name')), '../escape');
    await tapVisible(tester, find.byKey(const Key('hub-new-create')));
    expect(find.textContaining('Use 1–100'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('hub-new-name')), 'team');
    await tester.enterText(find.byKey(const Key('hub-new-description')), 'Team archive');
    await tapVisible(tester, find.byKey(const Key('hub-new-create')));
    await until(tester, () => find.byKey(const ValueKey('hub-repository-team')).evaluate().isNotEmpty);
    expect(find.text('Team archive'), findsOneWidget);
    late String first;
    late String second;
    await drive(tester, () async {
      final repo = await fixture.repos.init('sender');
      first = await fixture.repos.commit(repo, 'first', files: {'README.md': 'one\n'});
      final url = 'http://127.0.0.1:${fixture.server.status.port}/team.git';
      await fixture.repos.run(repo, ['push', '--', url, 'HEAD:refs/heads/main']);
      second = await fixture.repos.commit(repo, 'second', files: {'README.md': 'two\n'});
      await fixture.repos.run(repo, ['push', '--', url, 'HEAD:refs/heads/main']);
      final rejected = await fixture.repos.git.run(
        ['push', '--force', '--', url, '$first:refs/heads/main'],
        cwd: repo,
        successExitCodes: {0, 1},
      );
      expectSync(rejected.exitCode, 1);
      expectSync(rejected.stderr, contains('rejected'));
      expectSync(await fixture.server.pushLog(), hasLength(2));
    });
    // No feature override or manual invalidation: the screen's poll must discover the push.
    await tester.pump(const Duration(seconds: 5));
    await until(tester, () => find.byKey(ValueKey('hub-push-team-$second')).evaluate().isNotEmpty);
    expect(find.text('${first.substring(0, 8)} → ${second.substring(0, 8)}'), findsOneWidget);
    expect(find.textContaining('Sender: 127.0.0.1'), findsNWidgets(2));

    final today = container.read(hubHostSnapshotProvider).value!;
    expect(today.todayPushes, 2);

    await drive(
      tester,
      () => container
          .read(hubSettingsProvider.notifier)
          .save((s) => s.copyWith(backupDirectory: p.join(fixture.repos.root.path, 'backups'))),
    );
    await until(tester, () => fixture.server.status.running && !container.read(hubHostSnapshotProvider).isLoading);

    await tapVisible(tester, find.byKey(const Key('hub-host-backup')));
    await until(tester, () => container.read(expeditionsProvider).any((e) => !e.isRunning));
    expect(container.read(expeditionsProvider).first.result, 'Backed up 1 repository.');

    await tapVisible(tester, find.byKey(const ValueKey('hub-delete-team')));
    expect(find.textContaining('moves to the trash folder'), findsOneWidget);
    await tapVisible(tester, find.text('Cancel'));
    expect(await drive(tester, fixture.server.listRepositories), hasLength(1));

    await tapVisible(tester, find.byKey(const ValueKey('hub-delete-team')));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Delete'));
    await until(tester, () => find.byKey(const ValueKey('hub-repository-team')).evaluate().isEmpty);

    final settings = container.read(hubSettingsProvider).value!;
    expect(await tester.runAsync(() => Directory(p.join(settings.rootDirectory, 'team.git')).exists()), false);
    expect(await tester.runAsync(() => Directory(p.join(settings.rootDirectory, '.trash')).list().length), 1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());

    await drive(tester, fixture.server.stop);
  });

  testWidgets('invalid port is rejected; settings persist, restart and switch off', (tester) async {
    final container = await open(tester);
    await tapVisible(tester, find.byKey(const Key('hub-host-power')));
    await until(tester, () => fixture.server.status.running);
    final starts = fixture.server.starts;
    for (final bad in ['0', '1023', '65536', 'abc']) {
      await tester.enterText(find.byKey(const Key('hub-host-port')), bad);
      await tapVisible(tester, find.byKey(const Key('hub-host-save')));
      expect(find.text('Enter a port between 1024 and 65535.'), findsOneWidget);
      expect(fixture.server.starts, starts);
    }
    await tester.enterText(find.byKey(const Key('hub-host-port')), '12345');
    await tester.enterText(find.byKey(const Key('hub-host-name')), 'Office archive');
    await tapVisible(tester, find.byKey(const Key('hub-host-save')));
    await until(
      tester,
      () =>
          fixture.server.starts > starts &&
          fixture.server.status.running &&
          tester.widget<FilledButton>(find.byKey(const Key('hub-host-save'))).onPressed != null,
    );
    final saved = await tester.runAsync(() => readJsonFile(File(p.join(fixture.repos.root.path, 'hub.json'))));
    expect(HubSettings.fromJson(saved).name, 'Office archive');
    expect(HubSettings.fromJson(saved).port, 12345);
    final client = RealHttpOverrides().createHttpClient(null);
    await drive(tester, () async {
      final response = await (await client.getUrl(
        Uri.parse('http://127.0.0.1:${fixture.server.status.port}/api/info'),
      )).close();
      expectSync(await response.transform(SystemEncoding().decoder).join(), contains('Office archive'));
      client.close(force: true);
    });
    await tapVisible(tester, find.byKey(const Key('hub-host-power')));
    await until(tester, () => !fixture.server.status.running);
    expect(container.read(hubSettingsProvider).value!.enabled, false);
    final reloaded = ProviderContainer(overrides: fixture.overrides);
    expect((await tester.runAsync(() => reloaded.read(hubSettingsProvider.future)))!.port, 12345);
    reloaded.dispose();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());

    await drive(tester, fixture.server.stop);
  });

  testWidgets('folder picker, backup clearing, tray preference, and root change persist', (tester) async {
    const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    String? picked;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'dir');
      return picked;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
    );
    final container = await open(tester);
    final root = p.join(fixture.repos.root.path, 'chosen-root');
    final backup = p.join(fixture.repos.root.path, 'chosen-backups');
    Future<void> choose(String key, String? path) async {
      picked = path;
      await tapVisible(tester, find.descendant(of: find.byKey(Key(key)), matching: find.byTooltip('Choose folder')));
      await until(tester, () => tester.widget<FilledButton>(find.byKey(const Key('hub-host-save'))).onPressed != null);
    }

    await choose('hub-host-root', root);
    await choose('hub-host-backup-folder', backup);
    await choose('hub-host-backup-folder', null); // Cancellation retains the chosen folder.
    await tapVisible(tester, find.byType(SwitchListTile));
    await tapVisible(tester, find.byKey(const Key('hub-host-save')));
    await until(
      tester,
      () =>
          container.read(hubSettingsProvider).value?.rootDirectory == root &&
          tester.widget<FilledButton>(find.byKey(const Key('hub-host-save'))).onPressed != null,
    );
    expect(container.read(hubSettingsProvider).value!.backupDirectory, backup);
    expect(container.read(hubSettingsProvider).value!.keepRunningInTray, false);
    await tapVisible(tester, find.byTooltip('Clear backup folder'));
    await tapVisible(tester, find.byKey(const Key('hub-host-save')));
    await until(
      tester,
      () =>
          container.read(hubSettingsProvider).value!.backupDirectory == null &&
          tester.widget<FilledButton>(find.byKey(const Key('hub-host-save'))).onPressed != null,
    );
    await tapVisible(tester, find.byKey(const Key('hub-host-power')));
    await until(tester, () => fixture.server.status.running);
    expect(await tester.runAsync(() => Directory(root).exists()), true);
    final json = await tester.runAsync(() => readJsonFile(File(p.join(fixture.repos.root.path, 'hub.json'))));
    expect(HubSettings.fromJson(json).rootDirectory, root);
    expect(HubSettings.fromJson(json).backupDirectory, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await drive(tester, fixture.server.stop);
  });

  testWidgets('repository filter queries latest records and retains log after stopping', (tester) async {
    final container = await open(tester);
    await tapVisible(tester, find.byKey(const Key('hub-host-power')));
    await until(tester, () => fixture.server.status.running);
    await drive(tester, () async {
      await fixture.server.createRepository('alpha');
      await fixture.server.createRepository('beta');
      // Seed the public on-disk format to exercise pagination without 102 Git processes.
      final settings = container.read(hubSettingsProvider).value!;
      final file = File(p.join(settings.rootDirectory, 'push-log.jsonl'));
      await file.writeAsString(
        [
          for (var i = 0; i < 102; i++)
            jsonEncode(
              HubPushRecord(
                at: DateTime.now().subtract(Duration(seconds: i)),
                repository: i == 101 ? 'beta' : 'alpha',
                ref: 'refs/heads/main',
                oldSha: i.toRadixString(16).padLeft(40, '0'),
                newSha: (i + 1).toRadixString(16).padLeft(40, '0'),
                clientAddress: '127.0.0.1',
                clientHost: 'sender-pc',
              ).toJson(),
            ),
        ].join('\n'),
      );
    });
    await tester.pump(const Duration(seconds: 5));
    await until(tester, () => container.read(hubHostSnapshotProvider).value?.pushes.length == 102);
    expect(find.textContaining('sender-pc'), findsNWidgets(100));
    await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
    await tapVisible(tester, find.text('beta').last);
    expect(find.textContaining('sender-pc'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('hub-host-power')));
    await until(tester, () => !fixture.server.status.running && !container.read(hubHostSnapshotProvider).isLoading);
    expect(find.textContaining('sender-pc'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await drive(tester, fixture.server.stop);
  });

  testWidgets('closing the host panel during save keeps the application server alive', (tester) async {
    final container = await open(tester);
    await tapVisible(tester, find.byKey(const Key('hub-host-power')));
    await until(tester, () => fixture.server.status.running);
    await tester.enterText(find.byKey(const Key('hub-host-name')), 'Saved after closing');
    await tapVisible(tester, find.byKey(const Key('hub-host-save')));
    await tapVisible(tester, find.byTooltip('Close'));
    await until(
      tester,
      () =>
          fixture.server.status.running &&
          container.read(hubSettingsProvider).value?.name == 'Saved after closing' &&
          fixture.server.starts == 2,
    );
    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 400));
    await until(tester, () => tester.widget<FilledButton>(find.byKey(const Key('hub-host-save'))).onPressed != null);
    expect(find.text('Saved after closing'), findsWidgets);
    expect(fixture.server.status.running, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await drive(tester, fixture.server.stop);
  });

  testWidgets('real startup failure is visible and a corrected root recovers', (tester) async {
    final container = await open(tester);
    final blocked = File(p.join(fixture.repos.root.path, 'blocked-root'));
    await tester.runAsync(() => blocked.writeAsString('not a directory'));
    await drive(
      tester,
      () => container
          .read(hubSettingsProvider.notifier)
          .save((s) => s.copyWith(enabled: true, rootDirectory: blocked.path)),
    );
    await until(tester, () => find.text('Server error').evaluate().isNotEmpty);
    expect(fixture.server.status.running, false);
    expect(fixture.server.status.error, isNotNull);
    expect(tester.widget<Switch>(find.byKey(const Key('hub-host-power'))).value, true);
    await tapVisible(tester, find.byKey(const Key('hub-host-power')));
    await until(tester, () => container.read(hubSettingsProvider).value?.enabled == false);
    await drive(
      tester,
      () => container
          .read(hubSettingsProvider.notifier)
          .save((s) => s.copyWith(enabled: true, rootDirectory: p.join(fixture.repos.root.path, 'recovered-root'))),
    );
    await until(tester, () => find.text('Running').evaluate().isNotEmpty);
    expect(fixture.server.status.error, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await drive(tester, fixture.server.stop);
  });

  test('startup reads persisted settings and starts once; disabled remains stopped', () async {
    final file = File(p.join(fixture.repos.root.path, 'hub.json'));
    await writeJsonFile(
      file,
      HubSettings(
        enabled: true,
        name: 'Auto hub',
        rootDirectory: p.join(fixture.repos.root.path, 'hub-repos'),
      ).toJson(),
    );
    final container = ProviderContainer(overrides: fixture.overrides);
    container.read(hubStartupProvider);
    container.read(hubStartupProvider);
    for (var i = 0; i < 300 && !fixture.server.status.running; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(fixture.server.status.running, true, reason: fixture.server.status.error);
    expect(fixture.server.starts, 1);
    await expectLater(
      container.read(hubSettingsProvider.notifier).save((s) => s.copyWith(port: 1)),
      throwsArgumentError,
    );
    container.dispose();
    await fixture.server.stop();
    expect(fixture.server.status.running, false);
    await writeJsonFile(file, const HubSettings(enabled: false).toJson());
    final off = ProviderContainer(overrides: fixture.overrides);
    off.read(hubStartupProvider);
    await off.read(hubSettingsProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fixture.server.starts, 1);
    expect((await off.read(hubSettingsProvider.future)).rootDirectory, p.join(fixture.repos.root.path, 'hub-repos'));
    off.dispose();
  });

  for (final style in TermStyle.values) {
    testWidgets('Korean ${style.name}, narrow light layout and empty settings validation', (tester) async {
      await open(
        tester,
        language: AppLanguage.ko,
        terms: style,
        brightness: Brightness.light,
        size: const Size(600, 900),
      );
      final terms = Terms.resolve(AppLanguage.ko, style);
      expect(find.textContaining('강제 ${terms.push}와 ${terms.branch} 삭제'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('hub-host-name')), '');
      await tapVisible(tester, find.byKey(const Key('hub-host-save')));
      expect(find.text('값을 입력하세요.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());

      await drive(tester, fixture.server.stop);
    });
  }
}
