import 'dart:async';
import 'dart:io';

import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/expeditions/expedition.dart';
import 'package:github_plus/core/hub/client.dart';
import 'package:github_plus/core/hub/hub_models.dart';
import 'package:github_plus/core/hub/server.dart';
import 'package:github_plus/core/models/app_models.dart';
import 'package:github_plus/core/storage/repository_store.dart';
import 'package:github_plus/features/home/repo_banner.dart';
import 'package:github_plus/features/hub/client/hub_library_section.dart';
import 'package:github_plus/features/library/library_panel.dart';
import 'package:github_plus/l10n/app_localizations.dart';
import 'package:github_plus/l10n/app_localizations_en.dart';
import 'package:github_plus/l10n/app_localizations_ko.dart';
import 'package:github_plus/l10n/terms.dart';
import 'package:github_plus/state/app_state.dart';
import 'package:github_plus/state/hub_client_state.dart';
import 'package:github_plus/state/repo_state.dart';
import 'package:github_plus/ui/theme.dart';
import 'package:github_plus/ui/widgets/diff_view.dart';
import 'package:path/path.dart' as p;

import '../../../core/git/helpers.dart';
import '../../history/history_test_support.dart' show pumpUntil;

// Only the native directory chooser is replaced. HTTP, Git and providers are real.
class _Folders extends FilePickerPlatform {
  _Folders(this.path);
  final String path;
  String? initial;
  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    initial = initialDirectory;
    return path;
  }
}

class _Harness extends ConsumerWidget {
  const _Harness(this.focus);
  final FocusNode focus;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(libraryProvider).selected;
    return Row(
      children: [
        LibraryPanel(searchFocus: focus),
        Expanded(
          child:
              hubClientScreen(ref) ??
              (repo == null
                  ? const SizedBox()
                  : Column(
                      children: [
                        RepoBanner(
                          repo: repo,
                          status: ref.watch(repoStatusProvider(repo.id)).value,
                          onCommitRequested: () {},
                        ),
                        Text(repo.group.name),
                      ],
                    )),
        ),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides? originalHttpOverrides;
  late TestRepos repos;
  late HubServer server;
  late HubDiscovery discovery;
  late HubClient api;
  late Bootstrap bootstrap;
  late RepositoryInfo local;
  late _Folders picker;
  late FilePickerPlatform originalPicker;
  late FocusNode focus;
  String getUrl() => 'http://127.0.0.1:${server.status.port}';
  setUp(() async {
    originalHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    repos = await TestRepos.create();
    final path = await repos.init('my-project');
    await repos.commit(path, 'initial version', files: {'README.md': '# Hello from the hub\n', 'hello.txt': 'hello\n'});
    final store = RepositoryStore(file: File(p.join(repos.root.path, 'repositories.json')), git: repos.git);
    local = await store.describe(path);
    bootstrap = Bootstrap(
      dataDirectory: repos.root,
      git: repos.git,
      repositoryStore: store,
      settings: AppSettings(defaultRepositoryDirectory: p.join(repos.root.path, 'downloads')),
      repositories: [local],
    );
    server = HubServer(git: repos.git, appVersion: 'test', announce: false);
    final status = await server.start(
      HubSettings(port: 0, rootDirectory: p.join(repos.root.path, 'hub'), name: 'Office Hub'),
    );
    expect(status.running, true, reason: status.error);
    api = HubClient(getUrl());
    discovery = HubDiscovery(storeFile: p.join(repos.root.path, 'hubs.json'), listen: false);
    originalPicker = FilePickerPlatform.instance;
    picker = _Folders(p.join(repos.root.path, 'downloads'));
    FilePickerPlatform.instance = picker;
    focus = FocusNode();
  });
  tearDown(() async {
    HttpOverrides.global = originalHttpOverrides;
    focus.dispose();
    FilePickerPlatform.instance = originalPicker;
    api.close();
    await discovery.stop();
    await server.stop();
    await repos.dispose();
  });
  Future<ProviderContainer> open(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.en,
    TermStyle terms = TermStyle.plain,
  }) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Use real discovery without UDP and the same repository matcher as production;
    // only disable UDP in the discovery object's constructor via a dedicated scope.
    final unregister = bootstrap.repositoryStore.registerHubMatcher((url) => isHubRemote(url, discovery.hubs));
    addTearDown(unregister);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(bootstrap),
          hubDiscoveryProvider.overrideWith((ref) {
            ref.onDispose(() {
              unawaited(discovery.stop());
            });
            return discovery;
          }),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          locale: Locale(language.name),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          builder: (context, child) =>
              TermsScope(terms: Terms.resolve(language, terms), language: language, child: child!),
          home: Scaffold(body: _Harness(focus)),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
    });
    await pumpUntil(
      tester,
      () =>
          find.text('Publish for the first time').evaluate().isNotEmpty ||
          !ProviderScope.containerOf(
            tester.element(find.byType(_Harness)),
          ).read(repoStatusProvider(local.id)).isLoading,
    );
    return ProviderScope.containerOf(tester.element(find.byType(_Harness)));
  }

  testWidgets('manual hub -> README, graph, files, diff, activity -> real clone in hub library', (tester) async {
    await tester.runAsync(() async {
      await repos.commit(
        local.path,
        'newer version\n\n${'Long message line\n' * 200}',
        files: {'newer-only.txt': 'newer\n'},
      );
      await publishToHub(repos.git, local.path, hubUrl: getUrl(), name: 'team', description: 'Shared project');
    });
    final container = await open(tester);
    await tester.tap(find.text('Add hub by address'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('hub-address')), '127.0.0.1:${server.status.port}');
    await tester.tap(find.text('Connect'));
    await pumpUntil(tester, () => find.text('team').evaluate().isNotEmpty);
    expect(discovery.hubs.single.name, 'Office Hub');
    expect(File(p.join(repos.root.path, 'hubs.json')).existsSync(), true);
    await tester.tap(find.text('team'));
    await pumpUntil(tester, () => find.text('Hello from the hub').evaluate().isNotEmpty);
    await tester.enterText(find.byKey(const Key('hub-branch')), 'main');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await pumpUntil(tester, () => find.text('Hello from the hub').evaluate().isNotEmpty);
    await tester.tap(find.text('Version history'));
    await pumpUntil(tester, () => find.text('initial version').evaluate().isNotEmpty);
    await tester.tap(find.text('newer version'));
    await pumpUntil(tester, () => find.text('newer-only.txt').evaluate().isNotEmpty);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('initial version'));
    await tester.pump();
    expect(find.text('newer-only.txt'), findsNothing);
    await pumpUntil(tester, () => find.text('hello.txt').evaluate().isNotEmpty);
    await tester.tap(find.text('hello.txt'));
    await pumpUntil(tester, () => find.byType(FileDiffView).evaluate().isNotEmpty);
    await tester.tap(find.text('Upload activity'));
    await pumpUntil(tester, () => find.textContaining('refs/heads/main').evaluate().isNotEmpty);
    await tester.tap(find.byKey(const Key('hub-clone')));
    await pumpUntil(
      tester,
      () => container.read(expeditionsProvider).firstOrNull?.status == ExpeditionStatus.succeeded,
    );
    await pumpUntil(tester, () => container.read(libraryProvider).repositories.length == 2);
    final clone = container.read(libraryProvider).selected!;
    expect(clone.name, 'team');
    expect(clone.group, RepositoryGroup.hub);
    expect(clone.remoteUrl, '${getUrl()}/team.git');
    expect(File(p.join(clone.path, 'hello.txt')).readAsStringSync().replaceAll('\r\n', '\n'), 'hello\n');
    expect(picker.initial, bootstrap.settings.defaultRepositoryDirectory);
    expect(container.read(selectedHubProvider), isNull);
    await pumpUntil(tester, () => !container.read(repoStatusProvider(clone.id)).isLoading);
  });
  testWidgets('banner publishes local repo, updates remote/group/status, and lists it on hub', (tester) async {
    final container = await open(tester);
    final l = L10n.of(tester.element(find.byType(_Harness)));
    final terms = Terms.resolve(AppLanguage.en, TermStyle.plain);
    await tester.tap(find.text(l.actionPublish(terms.publish)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('publish-hub-name')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('publish-hub-address')), getUrl());
    await tester.tap(find.byKey(const Key('publish-hub-submit')));
    await pumpUntil(
      tester,
      () => container.read(expeditionsProvider).firstOrNull?.status == ExpeditionStatus.succeeded,
    );
    await pumpUntil(tester, () => find.byKey(const Key('publish-hub-submit')).evaluate().isEmpty);
    final updated = container.read(libraryProvider).selected!;
    expect(updated.group, RepositoryGroup.hub);
    expect(updated.remoteUrl, '${server.status.addresses.first}/my-project.git');
    await pumpUntil(tester, () => !container.read(repoStatusProvider(local.id)).isLoading);
    expect(container.read(repoStatusProvider(local.id)).value!.upstream, isNotNull);
    await tester.pumpAndSettle();
    expect(find.text(l.actionPublish(terms.publish)), findsNothing);
    final remote = await tester.runAsync(api.listRepositories);
    expect(remote!.single.name, 'my-project');
    await tester.tap(find.text('Office Hub'));
    await pumpUntil(tester, () => find.text('my-project').evaluate().length >= 2);
  });
  testWidgets('invalid name is blocked and duplicate name is explained without raw errors', (tester) async {
    await tester.runAsync(() => publishToHub(repos.git, local.path, hubUrl: getUrl(), name: 'taken'));
    // A second local repo has no remote and tries to publish to the occupied name.
    final other = await tester.runAsync(() async {
      final path = await repos.init('other');
      await repos.commit(path, 'other initial');
      return bootstrap.repositoryStore.describe(path);
    });
    local = other!;
    bootstrap = Bootstrap(
      dataDirectory: bootstrap.dataDirectory,
      git: repos.git,
      repositoryStore: bootstrap.repositoryStore,
      settings: bootstrap.settings,
      repositories: [local],
    );
    final container = await open(tester);
    final l = L10n.of(tester.element(find.byType(_Harness)));
    await tester.tap(find.text(l.actionPublish(Terms.resolve(AppLanguage.en, TermStyle.plain).publish)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('publish-hub-address')), getUrl());
    await tester.enterText(find.byKey(const Key('publish-hub-name')), '../escape');
    await tester.tap(find.byKey(const Key('publish-hub-submit')));
    await tester.pumpAndSettle();
    expect(find.text(l.hubClientInvalidName), findsOneWidget);
    expect(container.read(expeditionsProvider), isEmpty);
    await tester.enterText(find.byKey(const Key('publish-hub-name')), 'taken');
    await tester.tap(find.byKey(const Key('publish-hub-submit')));
    await pumpUntil(tester, () => container.read(expeditionsProvider).firstOrNull?.status == ExpeditionStatus.failed);
    await tester.pumpAndSettle();
    expect(find.text(l.hubClientConflict), findsOneWidget);
    expect(container.read(libraryProvider).selected!.remoteUrl, isNull);
  });

  testWidgets('offline hub shows recovery toast with Korean Git vocabulary', (tester) async {
    await open(tester, language: AppLanguage.ko, terms: TermStyle.git);
    final l = L10n.of(tester.element(find.byType(_Harness)));
    await tester.runAsync(() => discovery.addManual(getUrl()));
    await pumpUntil(tester, () => find.text('Office Hub').evaluate().isNotEmpty);
    await tester.tap(find.text('Office Hub'));
    await pumpUntil(tester, () => find.text(l.hubClientEmpty).evaluate().isNotEmpty);
    await tester.runAsync(server.stop);
    await tester.tap(find.byTooltip(l.overviewRefresh));
    await pumpUntil(tester, () => find.text(l.hubClientUnavailable).evaluate().isNotEmpty);
    expect(find.textContaining('Hub error'), findsNothing);
    expect(find.text(l.hubClientUnavailable), findsWidgets);
  });
  test('errors have localized recovery guidance in both vocabularies', () {
    for (final language in [L10nEn(), L10nKo()]) {
      expect(hubClientError(language, HubApiException(409, 'secret')), language.hubClientConflict);
      expect(hubClientError(language, HubApiException(0, 'Hub request timed out')), language.hubClientTimeout);
      expect(hubClientError(language, HubApiException(0, 'cannot connect')), language.hubClientUnavailable);
      expect(hubClientError(language, ArgumentError('secret')), language.hubClientInvalidAddress);
    }
  });
}
