// Ported from GitHub Desktop (MIT): app/src/lib/git (via GitHub+ v1 src/main/hub/server/{server,lifecycle}.ts)
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
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../content/repo_content.dart';
import '../git/git_runner.dart';
import '../git/log.dart';
import '../git/diff.dart';
import 'hub_models.dart';
import 'validation.dart';
import 'wire.dart';
import 'announcer.dart';
import 'server_api.dart';
part 'server_git_http.dart';

const hubDiscoveryPort = 47321;

/// Serves bare repositories on the LAN, protects history and records pushes.
class HubServer {
  HubServer({required this.git, required this.appVersion, this.announce = true});
  final GitRunner git;
  final String appVersion;

  /// Off in tests so they do not broadcast on the LAN.
  final bool announce;
  HubServerStatus _status = const HubServerStatus(running: false, port: 0);
  final _changes = StreamController<HubServerStatus>.broadcast();
  HttpServer? _server;
  HubAnnouncer? _announcer;
  HubSettings _settings = const HubSettings();
  final _queues = <String, Future<void>>{};
  final _requests = <Future<void>>{};
  final _children = <Process>{};
  Future<void> _lifecycle = Future.value();

  /// Current status; [statusChanges] emits on every change.
  HubServerStatus get status => _status;
  Stream<HubServerStatus> get statusChanges => _changes.stream;

  void _update({bool? running, int? port, List<String>? addresses, int? count, String? error}) {
    _status = HubServerStatus(
      running: running ?? _status.running,
      port: port ?? _status.port,
      addresses: List.unmodifiable(addresses ?? _status.addresses),
      repositoryCount: count ?? _status.repositoryCount,
      error: error,
    );
    _changes.add(_status);
  }

  Future<T> _serialLifecycle<T>(Future<T> Function() action) {
    final next = _lifecycle.then((_) => action());
    _lifecycle = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  /// Starts or restarts on all interfaces (port 0 chooses a free port).
  /// Startup failures are returned in [HubServerStatus.error], not thrown.
  Future<HubServerStatus> start(HubSettings settings) => _serialLifecycle(() async {
    await _stop();
    _settings = settings.copyWith(rootDirectory: p.absolute(settings.rootDirectory));
    try {
      if (settings.rootDirectory.isEmpty) throw ArgumentError('Root directory is required');
      await Directory(_settings.rootDirectory).create(recursive: true);
      for (final name in await _names()) {
        await _locked(name, () async => _protect(await _existing(name)));
      }
      final server = await HttpServer.bind(InternetAddress.anyIPv6, settings.port, v6Only: false);
      _server = server;
      final addresses = <String>{};
      final interfaces = await NetworkInterface.list(includeLoopback: true);
      final ips = interfaces.expand((i) => i.addresses).where((a) => isPrivateAddress(a.address)).toList()
        ..sort((a, b) {
          final rank = lanAddressRank(a.address).compareTo(lanAddressRank(b.address));
          return rank == 0 ? a.address.compareTo(b.address) : rank;
        });
      for (final ip in ips) {
        addresses.add(Uri(scheme: 'http', host: ip.address, port: server.port).toString());
      }
      _update(running: true, port: server.port, addresses: addresses.toList(), count: (await _names()).length);
      server.listen((request) {
        final task = _handle(request);
        _requests.add(task);
        unawaited(task.whenComplete(() => _requests.remove(task)));
      }, onError: (Object e) => _update(error: redactCredentials(e.toString())));
      if (announce) {
        try {
          _announcer = await HubAnnouncer.start(settings.name, server.port, appVersion);
        } on SocketException {
          /* Discovery must not prevent serving HTTP. */
        }
      }
    } catch (e) {
      await _stop();
      _update(running: false, port: settings.port, error: redactCredentials(e.toString()));
    }
    return status;
  });

  Future<void> stop() => _serialLifecycle(_stop);
  Future<void> _stop() async {
    _announcer?.stop();
    _announcer = null;
    final server = _server;
    _server = null;
    await server?.close(force: true);
    for (final child in _children.toList()) {
      child.kill();
    }
    await Future.wait(_requests.toList());
    await Future.wait(_queues.values.toList());
    _update(running: false, addresses: []);
  }

  Future<T> _locked<T>(String name, Future<T> Function() action) async {
    final key = name.toLowerCase();
    final next = (_queues[key] ?? Future<void>.value()).then((_) => action());
    final done = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _queues[key] = done;
    try {
      return await next;
    } finally {
      if (identical(_queues[key], done)) _queues.remove(key);
    }
  }

  String _path(String name) {
    if (!isValidRepositoryName(name)) throw const HubHttpError(400, 'Invalid repository name');
    return p.join(_settings.rootDirectory, '$name.git');
  }

  Future<String> _existing(String name) async {
    final path = _path(name);
    if (await FileSystemEntity.type(path, followLinks: false) != FileSystemEntityType.directory) {
      throw const HubHttpError(404, 'Repository not found');
    }
    final root = await Directory(_settings.rootDirectory).resolveSymbolicLinks();
    final resolved = await Directory(path).resolveSymbolicLinks();
    if (!p.isWithin(root, resolved)) throw const HubHttpError(403, 'Repository outside hub root');
    return resolved;
  }

  Future<List<String>> _names() async {
    final root = Directory(_settings.rootDirectory);
    if (!await root.exists()) return [];
    final names = <String>[];
    await for (final entry in root.list(followLinks: false)) {
      final file = p.basename(entry.path);
      if (entry is Directory && file.endsWith('.git') && isValidRepositoryName(file.substring(0, file.length - 4))) {
        final name = file.substring(0, file.length - 4);
        await _existing(name);
        names.add(name);
      }
    }
    return names..sort();
  }

  Future<HubRepository> _repository(String name) async {
    final path = await _existing(name);
    final description = File(p.join(path, 'description'));
    final head = await git.run(['symbolic-ref', '--short', 'HEAD'], cwd: path, successExitCodes: {0, 1});
    return HubRepository(
      name: name,
      url: '${status.addresses.firstOrNull ?? 'http://127.0.0.1:${status.port}'}/$name.git',
      description: await description.exists() ? (await description.readAsString()).trim() : null,
      defaultBranch: head.stdout.trim().isEmpty ? null : head.stdout.trim(),
      lastPushAt: (await pushLog(repository: name, limit: 1)).firstOrNull?.at,
    );
  }

  Future<List<HubRepository>> listRepositories() async => [for (final name in await _names()) await _repository(name)];

  Future<void> _protect(String path) async {
    final hooks = p.join(path, 'hooks');
    // Do not follow an externally supplied hooks junction or pre-receive link.
    final root = await Directory(_settings.rootDirectory).resolveSymbolicLinks();
    if (await FileSystemEntity.type(hooks, followLinks: false) == FileSystemEntityType.link) {
      throw const HubHttpError(403, 'Linked hooks directory');
    }
    await Directory(hooks).create(recursive: true);
    if (!p.isWithin(root, await Directory(hooks).resolveSymbolicLinks())) {
      throw const HubHttpError(403, 'Hooks outside hub root');
    }
    final hook = File(p.join(hooks, 'pre-receive'));
    if (await FileSystemEntity.type(hook.path, followLinks: false) == FileSystemEntityType.link) {
      throw const HubHttpError(403, 'Linked hook');
    }
    await hook.writeAsString(_protectionHook);
    if (!Platform.isWindows) {
      // Git update-index cannot set filesystem executable bits; use an absolute chmod.
      final chmod = File('/bin/chmod');
      await Process.run(chmod.path, ['755', '--', hook.path]);
    }
    for (final entry in {
      'receive.denyNonFastForwards': 'true',
      'receive.denyDeletes': 'true',
      'core.logAllRefUpdates': 'true',
      'gc.reflogExpire': 'never',
      'gc.reflogExpireUnreachable': 'never',
      'http.receivepack': 'true',
      'core.hooksPath': hooks,
    }.entries) {
      await git.run(['config', '--local', '--', entry.key, entry.value], cwd: path);
    }
  }

  /// Creates `<name>.git` (bare, default branch main) with history protection.
  Future<HubRepository> createRepository(String name, {String? description}) async {
    final path = _path(name);
    return _locked(name, () async {
      await Directory(_settings.rootDirectory).create(recursive: true);
      if (await FileSystemEntity.type(path, followLinks: false) != FileSystemEntityType.notFound) {
        throw const HubHttpError(409, 'Repository already exists');
      }
      await Directory(path).create();
      await git.run(['init', '--bare', '--initial-branch=main', '--', path], cwd: _settings.rootDirectory);
      await _protect(await _existing(name));
      await File(p.join(path, 'description')).writeAsString(description ?? '');
      _update(count: (await _names()).length);
      return _repository(name);
    });
  }

  /// Moves the bare repository into `<root>/.trash/<name>-<timestamp>.git`.
  Future<void> deleteRepository(String name) async {
    _path(name);
    await _locked(name, () async {
      final path = await _existing(name);
      final trash = Directory(p.join(_settings.rootDirectory, '.trash'));
      if (await FileSystemEntity.type(trash.path, followLinks: false) == FileSystemEntityType.link) {
        throw const HubHttpError(403, 'Linked trash directory');
      }
      await trash.create(recursive: true);
      final root = await Directory(_settings.rootDirectory).resolveSymbolicLinks();
      if (!p.isWithin(root, await trash.resolveSymbolicLinks())) throw const HubHttpError(403, 'Invalid trash path');
      await Directory(path).rename(p.join(trash.path, '$name-${DateTime.now().microsecondsSinceEpoch}.git'));
      _update(count: (await _names()).length);
    });
  }

  /// Newest first; [repository] filters.
  Future<List<HubPushRecord>> pushLog({String? repository, int limit = 100}) async {
    if (limit < 0) throw const HubHttpError(400, 'Invalid push log limit');
    if (repository != null) _path(repository);
    final file = File(p.join(_settings.rootDirectory, 'push-log.jsonl'));
    if (!await file.exists()) return [];
    final records = <HubPushRecord>[];
    for (final line in await file.readAsLines()) {
      try {
        final record = HubPushRecord.fromJson(jsonDecode(line));
        if (record != null && (repository == null || record.repository == repository)) records.add(record);
      } on FormatException {
        /* A partial final line after an interrupted write is ignored. */
      }
    }
    final sorted = records.indexed.toList();
    sorted.sort((a, b) {
      final date = b.$2.at.compareTo(a.$2.at);
      return date == 0 ? b.$1.compareTo(a.$1) : date;
    });
    return sorted.take(limit).map((r) => r.$2).toList();
  }

  /// `git bundle create --all` of every repository into the backup folder.
  Future<({DateTime at, int repositories})> backupNow() async {
    final directory = _settings.backupDirectory;
    if (directory == null || directory.isEmpty) throw StateError('Backup directory is required');
    await Directory(directory).create(recursive: true);
    final at = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    final stamp = '${at.year}${pad(at.month)}${pad(at.day)}-${pad(at.hour)}${pad(at.minute)}${pad(at.second)}';
    final names = await _names();
    for (final name in names) {
      await _locked(name, () async {
        final repo = await _existing(name);
        final target = p.absolute(p.join(directory, '$name-$stamp.bundle'));
        await git.run(['bundle', 'create', '--', target, '--all'], cwd: repo);
      });
    }
    return (at: at, repositories: names.length);
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      await _route(request);
    } catch (e) {
      try {
        _json(
          request.response,
          e is HubHttpError
              ? e.status
              : e is ArgumentError || e is FormatException
              ? 400
              : 500,
          {'error': e is HubHttpError ? e.message : 'Hub request failed'},
        );
      } catch (_) {
        /* A disconnected peer cannot receive an error response. */
      }
    } finally {
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  void _json(HttpResponse response, int code, Object? value) {
    response.statusCode = code;
    response.headers.contentType = ContentType.json;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.write(jsonEncode(value));
  }

  String _ref(String value) {
    if (value.isEmpty || value.startsWith('-') || value.contains('\x00') || value.contains(':')) {
      throw const HubHttpError(400, 'Invalid ref');
    }
    return value;
  }

  String _contentPath(String value) {
    final normalized = normalizeRepoPath(value);
    if (normalized == null || value.contains('\x00')) throw const HubHttpError(400, 'Invalid path');
    return normalized;
  }

  int _number(Uri uri, String key, int fallback) {
    final raw = uri.queryParameters[key];
    final n = raw == null ? fallback : int.tryParse(raw);
    if (n == null || n < 0 || n > 100000) throw const HubHttpError(400, 'Invalid pagination');
    return n;
  }

  Future<void> _route(HttpRequest req) async {
    if (hubAddressStatus(req.connectionInfo?.remoteAddress.address ?? '') == 403) {
      throw const HubHttpError(403, 'LAN access only');
    }
    final uri = req.uri;
    final parts = uri.pathSegments;
    final res = req.response;
    final get = req.method == 'GET';
    if (get && uri.path == '/api/info') {
      _json(res, 200, {'name': _settings.name, 'version': appVersion});
      return;
    }
    if (uri.path == '/api/repos') {
      if (get) {
        _json(res, 200, (await listRepositories()).map((r) => r.toJson()).toList());
        return;
      }
      if (req.method == 'POST') {
        final bytes = <int>[];
        var oversized = false;
        await for (final chunk in req) {
          if (bytes.length + chunk.length > 1024 * 1024) oversized = true;
          if (!oversized) bytes.addAll(chunk);
        }
        if (oversized) throw const HubHttpError(413, 'Request too large');
        final body = jsonDecode(utf8.decode(bytes));
        if (body is! Map ||
            body['name'] is! String ||
            (body['description'] != null && body['description'] is! String)) {
          throw const HubHttpError(400, 'Invalid repository');
        }
        final repo = await createRepository(body['name'] as String, description: body['description'] as String?);
        _json(res, 201, repo.toJson());
        return;
      }
    }
    if (get && parts.length >= 4 && parts[0] == 'api' && parts[1] == 'repos') {
      final name = parts[2];
      await _locked(name, () async {
        final path = await _existing(name);
        final ref = _ref(uri.queryParameters['ref'] ?? 'HEAD');
        final contentPath = _contentPath(uri.queryParameters['path'] ?? '');
        Object? value;
        if (parts.length == 4) {
          switch (parts[3]) {
            case 'log':
              value = (await getCommits(
                git,
                path,
                revision: ref,
                limit: _number(uri, 'limit', 100).clamp(0, 1000),
                skip: _number(uri, 'skip', 0),
              )).map(commitToJson).toList();
            case 'tree':
              value = (await GitTreeSource(git, path, ref: ref).list(contentPath)).map(treeEntryToJson).toList();
            case 'blob':
              value = blobToJson(await GitTreeSource(git, path, ref: ref).read(contentPath));
            case 'pushes':
              value = (await pushLog(
                repository: name,
                limit: _number(uri, 'limit', 100),
              )).map((r) => r.toJson()).toList();
            default:
              throw const HubHttpError(404, 'Not found');
          }
        } else if (parts.length == 6 && parts[3] == 'commits') {
          final sha = _ref(parts[4]);
          final files = await getCommitFiles(git, path, sha);
          if (parts[5] == 'files') {
            value = files.map(committedFileToJson).toList();
          } else if (parts[5] == 'diff') {
            final file = files.where((f) => f.path == contentPath).firstOrNull;
            if (file == null) throw const HubHttpError(404, 'File not in commit');
            value = fileDiffToJson(await getCommitDiff(git, path, sha, file));
          } else {
            throw const HubHttpError(404, 'Not found');
          }
        } else {
          throw const HubHttpError(404, 'Not found');
        }
        _json(res, 200, value);
      });
      return;
    }
    if (parts.isNotEmpty && parts[0].endsWith('.git')) {
      final name = parts[0].substring(0, parts[0].length - 4);
      _path(name);
      final advertise = get && parts.length == 3 && parts[1] == 'info' && parts[2] == 'refs';
      final service = advertise
          ? uri.queryParameters['service']
          : parts.length == 2
          ? parts[1]
          : null;
      if ((advertise || (req.method == 'POST' && parts.length == 2)) &&
          (service == 'git-upload-pack' || service == 'git-receive-pack')) {
        await _locked(name, () async => _rpc(req, name, await _existing(name), service!, advertise));
        return;
      }
    }
    throw const HubHttpError(404, 'Not found');
  }
}

const _protectionHook = r'''#!/bin/sh
while read old new ref; do
  case "$new" in
    *[!0]*) ;;
    *) echo "Hub history protection: deleting refs is forbidden" >&2; exit 1 ;;
  esac
  case "$ref" in
    refs/tags/*) case "$old" in
      *[!0]*) echo "Hub history protection: rewriting tags is forbidden" >&2; exit 1 ;;
    esac ;;
  esac
done
''';
