import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/models/app_models.dart';
import 'package:github_plus/core/models/diff.dart';
import 'package:github_plus/core/storage/repository_store.dart';
import 'package:github_plus/features/changes/changes_view.dart';
import 'package:github_plus/l10n/app_localizations.dart';
import 'package:github_plus/l10n/terms.dart';
import 'package:github_plus/state/app_state.dart';
import 'package:github_plus/state/changes_state.dart';
import 'package:github_plus/state/repo_state.dart';
import 'package:github_plus/ui/theme.dart';
import 'package:github_plus/ui/widgets/diff_view.dart';
import 'package:path/path.dart' as p;

import '../../core/git/helpers.dart';

const summaryKey = Key('changes-summary');
const commitKey = Key('changes-commit');

Future<void> until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 600; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 20));
    if (ready()) return;
  }
  fail('Timed out waiting for Git/UI');
}

Finder gutter(String text) => find.descendant(
  of: find.ancestor(of: find.text(text), matching: find.byType(Row)).first,
  matching: find.byType(GestureDetector),
);

void main() {
  late TestRepos repos;
  late String path;
  late RepositoryInfo repo;
  late Bootstrap bootstrap;

  setUp(() async {
    repos = await TestRepos.create();
    path = await repos.init('changes');
    await repos.commit(path, 'Initial summary\n\nInitial description', files: {'folder/a.txt': 'one\ntwo\n'});
    await repos.write(path, 'folder/a.txt', 'one\ntwo\nthree\nfour\n');
    repo = RepositoryInfo(id: 'test', path: path, name: 'Test', group: RepositoryGroup.local, addedAt: DateTime(2026));
    bootstrap = Bootstrap(
      dataDirectory: repos.root,
      git: repos.git,
      repositoryStore: RepositoryStore(file: File(p.join(repos.root.path, 'repositories.json')), git: repos.git),
      settings: const AppSettings(),
      repositories: [repo],
    );
  });
  tearDown(() async => repos.dispose());

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    TermStyle style = TermStyle.plain,
    AppLanguage language = AppLanguage.ko,
  }) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bootstrapProvider.overrideWithValue(bootstrap)],
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          locale: Locale(language.name),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: TermsScope(
            terms: Terms.resolve(language, style),
            language: language,
            child: Scaffold(body: ChangesView(repo: repo)),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(ChangesView)));
    await until(tester, () => find.byType(FileDiffView).evaluate().isNotEmpty);
    return container;
  }

  testWidgets('renders real files, tri-state selection and an empty-summary disabled button', (tester) async {
    final container = await mount(tester);
    expect(find.text('수정'), findsOneWidget);
    expect(find.text('1개 중 1개 포함'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(commitKey)).onPressed, isNull);
    expect(tester.widget<Checkbox>(find.byKey(const Key('include-folder/a.txt'))).value, isTrue);
    await tester.tap(gutter('+four'));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byKey(const Key('include-folder/a.txt'))).value, isNull);
    expect(tester.widget<Checkbox>(find.byKey(const Key('changes-all'))).value, isNull);
    expect(container.read(changesProvider(repo.id)).selections['folder/a.txt']!.selectionType, SelectionType.partial);
    await tester.tap(find.byKey(const Key('changes-all')));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byKey(const Key('include-folder/a.txt'))).value, isTrue);
    await tester.tap(find.byKey(const Key('changes-all')));
    await tester.enterText(find.byKey(summaryKey), 'Valid');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(commitKey)).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('line selection commits only selected changes using Ctrl+Enter', (tester) async {
    final container = await mount(tester);
    await tester.tap(gutter('+four'));
    await tester.enterText(find.byKey(summaryKey), 'Only three');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await until(tester, () => container.read(changesProvider(repo.id)).summary.isEmpty);
    final committed = await tester.runAsync(() => repos.run(path, ['show', 'HEAD:folder/a.txt']));
    expect(committed!.stdout, 'one\ntwo\nthree\n');
    expect(await tester.runAsync(() => File(p.join(path, 'folder/a.txt')).readAsString()), 'one\ntwo\nthree\nfour\n');
    await until(tester, () => find.textContaining('완료 ·').evaluate().isNotEmpty);
    expect(container.read(changesProvider(repo.id)).description, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh retains partial selection and drafts, adds new paths and removes vanished paths', (
    tester,
  ) async {
    final container = await mount(tester);
    await tester.tap(gutter('+four'));
    await tester.enterText(find.byKey(summaryKey), 'Keep draft');
    await tester.runAsync(() => repos.write(path, 'new.txt', 'new\n'));
    container.invalidate(repoStatusProvider(repo.id));
    await until(tester, () => container.read(changesProvider(repo.id)).selections.containsKey('new.txt'));
    final state = container.read(changesProvider(repo.id));
    expect(state.selections['folder/a.txt']!.selectionType, SelectionType.partial);
    expect(state.selections['new.txt']!.selectionType, SelectionType.all);
    expect(state.summary, 'Keep draft');
    await tester.runAsync(() => File(p.join(path, 'new.txt')).delete());
    container.invalidate(repoStatusProvider(repo.id));
    await until(tester, () => !container.read(changesProvider(repo.id)).selections.containsKey('new.txt'));
    expect(container.read(changesProvider(repo.id)).selectedPath, 'folder/a.txt');
    expect(tester.takeException(), isNull);
  });

  testWidgets('discard needs confirmation and saves a backup before restoring the file', (tester) async {
    final container = await mount(tester);
    await tester.tap(find.text('이 파일 버리기'));
    await tester.pumpAndSettle();
    expect(find.text('파일 1개의 변경을 버릴까요?'), findsOneWidget);
    expect(find.text('백업 폴더에 사본을 남긴 뒤 되돌립니다.'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => File(p.join(path, 'folder/a.txt')).readAsString()), contains('four'));
    await tester.tap(find.text('이 파일 버리기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('버리기'));
    await until(tester, () => container.read(repoStatusProvider(repo.id)).value?.files.isEmpty == true);
    expect(await tester.runAsync(() => File(p.join(path, 'folder/a.txt')).readAsString()), 'one\ntwo\n');
    final backups = await tester.runAsync(
      () async =>
          Directory(p.join(repos.root.path, 'discarded')).list(recursive: true).where((e) => e is File).toList(),
    );
    expect(backups, hasLength(1));
    expect(await tester.runAsync(() => File(backups!.single.path).readAsString()), contains('four'));
    expect(find.text('모두 저장됨'), findsOneWidget);
    expect(find.text(backups!.single.parent.parent.path), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('amend loads the last message and writes the edited message', (tester) async {
    final container = await mount(tester);
    await tester.tap(find.byKey(const Key('changes-amend')));
    await until(tester, () => container.read(changesProvider(repo.id)).amend);
    expect(tester.widget<TextField>(find.byKey(summaryKey)).controller!.text, 'Initial summary');
    expect(container.read(changesProvider(repo.id)).description, 'Initial description');
    await tester.enterText(find.byKey(summaryKey), 'Amended');
    await tester.pump();
    await tester.tap(find.byKey(commitKey));
    await until(tester, () => container.read(changesProvider(repo.id)).summary.isEmpty);
    expect((await tester.runAsync(() => repos.run(path, ['rev-list', '--count', 'HEAD'])))!.stdout.trim(), '1');
    expect(
      (await tester.runAsync(() => repos.run(path, ['log', '-1', '--format=%B'])))!.stdout.trim(),
      'Amended\n\nInitial description',
    );
    expect(container.read(changesProvider(repo.id)).amend, isFalse);
    await until(tester, () => container.read(repoStatusProvider(repo.id)).value?.files.isEmpty == true);
    expect(tester.takeException(), isNull);
  });

  for (final style in TermStyle.values) {
    testWidgets('button vocabulary: ${style.name}', (tester) async {
      await mount(tester, style: style);
      expect(find.text(style == TermStyle.plain ? 'main에 버전 저장' : 'main에 커밋'), findsOneWidget);
      expect(find.text(style == TermStyle.plain ? '마지막 버전 고치기(amend)' : '마지막 커밋 고치기(amend)'), findsOneWidget);
    });
  }

  testWidgets('context menu offers discard and path copy; divider resizes the panel', (tester) async {
    await mount(tester, language: AppLanguage.en);
    final before = tester.getTopLeft(find.byType(FileDiffView)).dx;
    await tester.drag(find.byKey(const Key('changes-resize')), const Offset(70, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.byType(FileDiffView)).dx, greaterThan(before));
    await tester.tap(find.byKey(const Key('include-folder/a.txt')), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Copy path'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
