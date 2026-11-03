import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../git/git_errors.dart';
import '../git/git_runner.dart';
import '../models/app_models.dart';
import 'json_file.dart';

class NotARepositoryException implements Exception {
  NotARepositoryException(this.path);
  final String path;
  @override
  String toString() => '$path is not a Git repository';
}

/// Persists the repository library (`repositories.json` in the app data folder).
class RepositoryStore {
  RepositoryStore({required this.file, required this.git});

  final File file;
  final GitRunner git;
  final List<bool Function(String url)> _hubMatchers = [];

  /// Stable id from the normalized absolute path (case-insensitive on Windows).
  static String idForPath(String path) {
    var key = p.normalize(p.absolute(path)).replaceAll(r'\', '/');
    if (Platform.isWindows) key = key.toLowerCase();
    return sha1.convert(utf8.encode(key)).toString().substring(0, 16);
  }

  /// Hub URLs are registered by the hub client so their clones group as hub.
  void Function() registerHubMatcher(bool Function(String url) matcher) {
    _hubMatchers.add(matcher);
    return () => _hubMatchers.remove(matcher);
  }

  RepositoryGroup groupForRemote(String? url) {
    if (url == null || url.isEmpty) return RepositoryGroup.local;
    if (_hubMatchers.any((match) => match(url))) return RepositoryGroup.hub;
    return RegExp(r'(^|[@/])github\.com[:/]', caseSensitive: false).hasMatch(url)
        ? RepositoryGroup.github
        : RepositoryGroup.local;
  }

  /// Returns the repository root and origin URL, or null if [path] is not a repository.
  Future<({String root, String? remoteUrl})?> inspect(String path) async {
    if (!await Directory(path).exists()) return null;
    final top = await git.run(
      ['rev-parse', '--show-toplevel'],
      cwd: path,
      expectedErrors: {GitError.notAGitRepository},
      successExitCodes: {0},
    ).then<GitResult?>((r) => r, onError: (_) => null);
    if (top == null || top.exitCode != 0) return null;
    final root = p.normalize(top.stdout.trim());
    final remote = await git.run(['remote', 'get-url', 'origin'], cwd: root, successExitCodes: {0, 2});
    final url = remote.exitCode == 0 ? remote.stdout.trim() : null;
    return (root: root, remoteUrl: (url?.isEmpty ?? true) ? null : url);
  }

  Future<List<RepositoryInfo>> load() async {
    final stored = await readJsonFile(file);
    final items = stored is List ? stored.map(RepositoryInfo.fromJson).whereType<RepositoryInfo>() : <RepositoryInfo>[];
    return Future.wait(
      items.map((repo) async {
        final inspection = await inspect(repo.path);
        if (inspection == null) return repo.copyWith(available: false);
        return repo.copyWith(
          available: true,
          remoteUrl: inspection.remoteUrl,
          group: groupForRemote(inspection.remoteUrl),
        );
      }),
    );
  }

  Future<void> save(List<RepositoryInfo> repositories) =>
      writeJsonFile(file, repositories.map((r) => r.toJson()).toList());

  /// Creates the library entry for an existing repository folder.
  Future<RepositoryInfo> describe(String path) async {
    final inspection = await inspect(path);
    if (inspection == null) throw NotARepositoryException(path);
    return RepositoryInfo(
      id: idForPath(inspection.root),
      path: inspection.root,
      name: p.basename(inspection.root),
      group: groupForRemote(inspection.remoteUrl),
      remoteUrl: inspection.remoteUrl,
      addedAt: DateTime.now(),
    );
  }
}
