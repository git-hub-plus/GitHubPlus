// CONTRACT (owner: worker H1). Public members are fixed; H1 implements them.
// Port from GitHub+ v1 src/main/hub/server/{server,announcer,lifecycle}.ts.
//
// HTTP API (all JSON, LAN/private addresses only, 403 otherwise):
// - GET  /api/info                                      -> {name, version}
// - GET  /api/repos                                     -> [HubRepository]
// - POST /api/repos {name, description?}                -> HubRepository (409 if it exists, 400 bad name)
// - GET  /api/repos/:name/log?ref=&limit=&skip=         -> [commit]          (wire.dart)
// - GET  /api/repos/:name/commits/:sha/files            -> [committedFile]   (wire.dart)
// - GET  /api/repos/:name/commits/:sha/diff?path=       -> fileDiff          (wire.dart)
// - GET  /api/repos/:name/tree?ref=&path=               -> [treeEntry]       (wire.dart, GitTreeSource)
// - GET  /api/repos/:name/blob?ref=&path=               -> blob              (wire.dart, GitTreeSource)
// - GET  /api/repos/:name/pushes?limit=                 -> [HubPushRecord]
// - Git Smart HTTP under /:name.git/ (info/refs, git-upload-pack, git-receive-pack)
// LAN discovery: UDP broadcast to port 47321 every 5 s:
// {"type":"ghp-hub","name":<settings.name>,"port":<port>,"version":<appVersion>}
import 'dart:async';

import '../git/git_runner.dart';
import 'hub_models.dart';

const hubDiscoveryPort = 47321;

/// The hub host: serves bare repositories under [HubSettings.rootDirectory]
/// to LAN clients with no authentication, and keeps history safe: force
/// pushes and branch/tag deletions are refused, every accepted ref update is
/// appended to `push-log.jsonl` with the client's address and host name.
class HubServer {
  HubServer({required this.git, required this.appVersion, this.announce = true});

  final GitRunner git;
  final String appVersion;

  /// Off in tests so they do not broadcast on the LAN.
  final bool announce;

  /// Current status; [statusChanges] emits on every change.
  HubServerStatus get status => throw UnimplementedError('H1');
  Stream<HubServerStatus> get statusChanges => throw UnimplementedError('H1');

  /// Starts (or restarts with new settings). Binds all interfaces on
  /// [HubSettings.port] (0 = any free port, for tests). Errors such as a
  /// port in use are reported in [HubServerStatus.error], not thrown.
  Future<HubServerStatus> start(HubSettings settings) => throw UnimplementedError('H1');

  Future<void> stop() => throw UnimplementedError('H1');

  Future<List<HubRepository>> listRepositories() => throw UnimplementedError('H1');

  /// Creates `<name>.git` (bare, default branch main) with the protections.
  Future<HubRepository> createRepository(String name, {String? description}) => throw UnimplementedError('H1');

  /// Moves the bare repository into `<root>/.trash/<name>-<timestamp>.git`.
  Future<void> deleteRepository(String name) => throw UnimplementedError('H1');

  /// Newest first; [repository] filters.
  Future<List<HubPushRecord>> pushLog({String? repository, int limit = 100}) => throw UnimplementedError('H1');

  /// `git bundle create --all` of every repository into the backup folder.
  Future<({DateTime at, int repositories})> backupNow() => throw UnimplementedError('H1');
}
