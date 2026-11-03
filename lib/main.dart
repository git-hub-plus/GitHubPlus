import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/git/git_runner.dart';
import 'core/models/app_models.dart';
import 'core/storage/json_file.dart';
import 'core/storage/repository_store.dart';
import 'state/app_state.dart';

/// `%APPDATA%\GitHubPlus` (development builds use `GitHubPlus-dev` so they
/// never share settings with an installed copy).
Directory appDataDirectory() {
  final base = Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
  return Directory(p.join(base, kReleaseMode ? 'GitHubPlus' : 'GitHubPlus-dev'));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'GitHub+',
      size: Size(1360, 860),
      minimumSize: Size(1024, 680),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Color(0xFF0B0F17),
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  final dataDirectory = appDataDirectory()..createSync(recursive: true);
  final git = GitRunner(executable: GitRunner.locateExecutable());
  final repositoryStore = RepositoryStore(file: File(p.join(dataDirectory.path, 'repositories.json')), git: git);
  final settings = AppSettings.fromJson(await readJsonFile(File(p.join(dataDirectory.path, 'settings.json'))));
  final repositories = await repositoryStore.load();

  runApp(
    ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(
          Bootstrap(
            dataDirectory: dataDirectory,
            git: git,
            repositoryStore: repositoryStore,
            settings: settings,
            repositories: repositories,
          ),
        ),
      ],
      child: const GitHubPlusApp(),
    ),
  );
}
