// CONTRACT (owner: worker H2). Public members are fixed; H2 implements them.
// Port from GitHub+ v1 src/main/hub/client/{api,discovery,publish,groups}.ts.
// The server side and its HTTP API are described in server.dart.
import 'dart:async';

import '../content/repo_content.dart';
import '../git/git_runner.dart';
import '../models/commit.dart';
import '../models/diff.dart';
import 'hub_models.dart';

/// Talks to one hub's JSON API ([baseUrl] like `http://192.168.0.10:8765`).
/// Only private/LAN addresses are allowed (ArgumentError otherwise). Errors
/// are [HubApiException] with the HTTP status.
class HubClient {
  HubClient(this.baseUrl, {Duration timeout = const Duration(seconds: 10)});

  final String baseUrl;

  Future<({String name, String version})> info() => throw UnimplementedError('H2');
  Future<List<HubRepository>> listRepositories() => throw UnimplementedError('H2');
  Future<HubRepository> createRepository(String name, {String? description}) => throw UnimplementedError('H2');
  Future<List<Commit>> log(String repository, {String? ref, int limit = 200, int skip = 0}) =>
      throw UnimplementedError('H2');
  Future<List<CommittedFile>> commitFiles(String repository, String sha) => throw UnimplementedError('H2');
  Future<FileDiff> commitDiff(String repository, String sha, String path) => throw UnimplementedError('H2');
  Future<List<HubPushRecord>> pushes(String repository, {int limit = 100}) => throw UnimplementedError('H2');

  /// The hub repository as a [RepoContentSource], so the overview page can
  /// show its files and README at [ref] (default: its default branch).
  RepoContentSource contentSource(String repository, {String? ref}) => throw UnimplementedError('H2');

  void close() => throw UnimplementedError('H2');
}

class HubApiException implements Exception {
  HubApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'Hub error $statusCode: $message';
}

/// Hubs on the LAN: listens for UDP announcements on port 47321 (private
/// sender addresses only), keeps manual hubs, marks hubs offline after 15 s
/// of silence (manual ones are pinged with `/api/info`). Manual hubs are
/// saved to [storeFile] (JSON list of DiscoveredHub).
class HubDiscovery {
  HubDiscovery({required String storeFile, bool listen = true});

  Stream<List<DiscoveredHub>> get changes => throw UnimplementedError('H2');
  List<DiscoveredHub> get hubs => throw UnimplementedError('H2');

  Future<void> start() => throw UnimplementedError('H2');
  Future<void> stop() => throw UnimplementedError('H2');

  /// Adds a hub by address (`192.168.0.10:8765` or a full URL); checks it
  /// answers `/api/info` first.
  Future<DiscoveredHub> addManual(String address) => throw UnimplementedError('H2');
  Future<void> removeManual(String url) => throw UnimplementedError('H2');
}

/// Creates [name] on the hub (or reuses it when it exists and is empty),
/// adds it as remote `origin` (or `hub` when origin exists), and pushes the
/// current branch with upstream. Progress goes through [onProgress].
/// Returns the remote name used.
Future<String> publishToHub(
  GitRunner git,
  String repoPath, {
  required String hubUrl,
  required String name,
  String? description,
  void Function(double value, String? stage)? onProgress,
}) => throw UnimplementedError('H2');

/// True when [remoteUrl] points at a hub (`http://<private address>:<port>/<name>.git`
/// that answered as a hub before, or a known hub base URL). Used by the
/// library to group repositories under "허브".
bool isHubRemote(String remoteUrl, Iterable<DiscoveredHub> knownHubs) => throw UnimplementedError('H2');
