// Ported from GitHub Desktop (MIT): app/src/lib/git/push.ts (via GitHub+ v1 src/main/hub/client/{api,discovery,publish,groups}.ts)
// CONTRACT (owner: worker H2). Public members are fixed.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as p;

import '../content/repo_content.dart';
import '../git/git_runner.dart';
import '../git/sync.dart' as sync;
import '../models/commit.dart';
import '../models/diff.dart';
import '../storage/json_file.dart';
import 'hub_models.dart';
import 'validation.dart';
import 'wire.dart';

Uri _base(String input) {
  final uri = Uri.parse(input.trim());
  if (uri.scheme != 'http' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.port < 1 ||
      uri.port > 65535) {
    throw ArgumentError('Invalid hub address');
  }
  final host = uri.host.replaceAll(RegExp(r'^\[|\]$'), '');
  if (InternetAddress.tryParse(host) != null && !isPrivateAddress(host)) {
    throw ArgumentError('Hub must use a private address');
  }
  return uri.replace(path: '');
}

/// JSON API for one LAN hub. DNS is checked and pinned on every connection.
class HubClient {
  HubClient(this.baseUrl, {Duration timeout = const Duration(seconds: 10)})
    : _uri = _base(baseUrl),
      // Public constructor signature is fixed by the H2 contract.
      // ignore: prefer_initializing_formals
      _timeout = timeout {
    final transport = HttpClient();
    transport.findProxy = (_) => 'DIRECT';
    transport.connectionTimeout = _timeout;
    transport.connectionFactory = (uri, proxyHost, proxyPort) async {
      final host = uri.host.replaceAll(RegExp(r'^\[|\]$'), '');
      final literal = InternetAddress.tryParse(host);
      final addresses = literal == null ? await InternetAddress.lookup(host) : [literal];
      if (addresses.isEmpty || addresses.any((a) => !isPrivateAddress(a.address))) {
        throw ArgumentError('Hub must resolve only to private addresses');
      }
      ConnectionTask<Socket>? pending;
      var cancelled = false;
      Future<Socket> connect() async {
        for (final address in addresses) {
          if (cancelled) throw const SocketException('Connection cancelled');
          pending = await Socket.startConnect(address, uri.port);
          if (cancelled) pending!.cancel();
          try {
            return await pending!.socket.timeout(
              _timeout,
              onTimeout: () {
                pending!.cancel();
                throw const SocketException('Connection timed out');
              },
            );
          } on SocketException {
            if (identical(address, addresses.last)) rethrow;
          }
        }
        throw const SocketException('No private address available');
      }

      return ConnectionTask.fromSocket(connect(), () {
        cancelled = true;
        pending?.cancel();
      });
    };
    _client = IOClient(transport);
  }

  final String baseUrl;
  final Uri _uri;
  final Duration _timeout;
  late final http.Client _client;

  Future<T> _request<T>(
    List<String> parts,
    T Function(dynamic) decode, {
    Map<String, String>? query,
    Object? body,
  }) async {
    // Uri preserves slashes inside a segment as %2F. Dot-only identifiers
    // must be rejected because URI implementations normalize dot segments.
    if (parts.any((p) => p == '.' || p == '..' || p.isEmpty)) {
      throw ArgumentError('Invalid API path segment');
    }
    final uri = _uri.replace(pathSegments: ['api', ...parts], queryParameters: query);
    final aborted = Completer<void>();
    Future<T> perform() async {
      final request = http.AbortableRequest(body == null ? 'GET' : 'POST', uri, abortTrigger: aborted.future)
        ..followRedirects = false
        ..persistentConnection = false;
      request.headers['accept'] = 'application/json';
      if (body != null) {
        request.headers['content-type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await _client.send(request);
      final text = await response.stream.bytesToString();
      dynamic json;
      try {
        json = jsonDecode(text);
      } on FormatException {
        throw HubApiException(response.statusCode, 'Invalid JSON response');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = json is Map ? json['error'] ?? json['message'] : null;
        throw HubApiException(
          response.statusCode,
          message is String ? redactCredentials(message) : 'Hub request failed',
        );
      }
      try {
        return decode(json);
      } catch (_) {
        throw HubApiException(response.statusCode, 'Invalid API response');
      }
    }

    try {
      return await perform().timeout(_timeout);
    } on HubApiException {
      rethrow;
    } on ArgumentError {
      rethrow;
    } on TimeoutException {
      throw HubApiException(0, 'Hub request timed out');
    } catch (_) {
      throw HubApiException(0, 'Cannot connect to hub');
    } finally {
      aborted.complete();
    }
  }

  Future<({String name, String version})> info() => _request(['info'], (j) {
    final name = j['name'] as String;
    if (name.trim().isEmpty || name.length > 200) throw const FormatException();
    return (name: name, version: j['version'] as String);
  });
  Future<List<HubRepository>> listRepositories() =>
      _request(['repos'], (j) => [for (final r in j as List) HubRepository.fromJson(r)!]);
  Future<HubRepository> createRepository(String name, {String? description}) {
    if (!isValidRepositoryName(name)) throw ArgumentError('Invalid repository name');
    return _request(['repos'], (j) => HubRepository.fromJson(j)!, body: {'name': name, 'description': ?description});
  }

  Future<List<Commit>> log(String repository, {String? ref, int limit = 200, int skip = 0}) => _request(
    ['repos', repository, 'log'],
    (j) => [for (final c in j as List) commitFromJson(c as Map)],
    query: {'limit': '$limit', 'skip': '$skip', 'ref': ?ref},
  );
  Future<List<CommittedFile>> commitFiles(String repository, String sha) => _request([
    'repos',
    repository,
    'commits',
    sha,
    'files',
  ], (j) => [for (final f in j as List) committedFileFromJson(f as Map)]);
  Future<FileDiff> commitDiff(String repository, String sha, String path) {
    final safe = normalizeRepoPath(path);
    if (safe == null || safe.isEmpty) throw ArgumentError('Invalid repository path');
    return _request(
      ['repos', repository, 'commits', sha, 'diff'],
      (j) => fileDiffFromJson(j as Map),
      query: {'path': safe},
    );
  }

  Future<List<HubPushRecord>> pushes(String repository, {int limit = 100}) => _request(
    ['repos', repository, 'pushes'],
    (j) => [for (final p in j as List) HubPushRecord.fromJson(p)!],
    query: {'limit': '$limit'},
  );
  RepoContentSource contentSource(String repository, {String? ref}) => HubContentSource._(this, repository, ref);
  void close() => _client.close();
}

/// Repository content over the same bounded, LAN-only API transport.
class HubContentSource implements RepoContentSource {
  HubContentSource._(this._client, this._repository, this._ref);
  final HubClient _client;
  final String _repository;
  final String? _ref;
  @override
  Future<List<TreeEntry>> list(String dir) async {
    final safe = normalizeRepoPath(dir);
    if (safe == null) return const [];
    return _client._request(
      ['repos', _repository, 'tree'],
      (j) => [for (final e in j as List) treeEntryFromJson(e as Map)],
      query: {'path': safe, if (_ref != null) 'ref': _ref},
    );
  }

  @override
  Future<BlobContent> read(String path) async {
    final safe = normalizeRepoPath(path);
    if (safe == null || safe.isEmpty) return const BlockedBlob();
    return _client._request(
      ['repos', _repository, 'blob'],
      (j) => blobFromJson(j as Map),
      query: {'path': safe, if (_ref != null) 'ref': _ref},
    );
  }
}

class HubApiException implements Exception {
  HubApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'Hub error $statusCode: ${redactCredentials(message)}';
}

/// Timers use the current Zone, allowing expiry and polling to be advanced in tests.
class HubDiscovery {
  HubDiscovery({required String storeFile, bool listen = true})
    : _file = File(storeFile),
      // Keep the public parameter name from the contract.
      // ignore: prefer_initializing_formals
      _listen = listen;
  final File _file;
  final bool _listen;
  final _changes = StreamController<List<DiscoveredHub>>.broadcast();
  final _hubs = <String, DiscoveredHub>{};
  final _expiry = <String, Timer>{};
  final _pings = <HubClient>{};
  RawDatagramSocket? _socket;
  Timer? _poll;
  bool _running = false;
  Future<void>? _starting;
  Stream<List<DiscoveredHub>> get changes => _changes.stream;
  List<DiscoveredHub> get hubs => List.unmodifiable(_hubs.values.toList()..sort((a, b) => a.url.compareTo(b.url)));
  void _emit() => _changes.add(hubs);
  Future<void> start() => _starting ??= _start();
  Future<void> _start() async {
    if (_running) return;
    _running = true;
    try {
      final stored = await readJsonFile(_file);
      if (stored is List) {
        for (final item in stored) {
          try {
            final h = DiscoveredHub.fromJson(item);
            if (h == null || !h.manual || h.name.length > 200) continue;
            final url = _base(h.url).toString();
            _hubs[url] = DiscoveredHub(url: url, name: h.name, lastSeen: h.lastSeen, manual: true, online: false);
          } catch (_) {
            /* Ignore malformed stored entries. */
          }
        }
      }
      if (!_running) return;
      if (_listen) {
        final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 47321, reuseAddress: true);
        if (!_running) {
          socket.close();
          return;
        }
        _socket = socket;
        socket.listen((event) {
          if (event != RawSocketEvent.read) return;
          Datagram? packet;
          while ((packet = socket.receive()) != null) {
            _receive(packet!);
          }
        });
      }
      _emit();
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => _pingManual());
      _pingManual();
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  void _receive(Datagram packet) {
    if (packet.data.length > 4096 || !isPrivateAddress(packet.address.address)) return;
    try {
      final j = jsonDecode(utf8.decode(packet.data));
      if (j is! Map || j['type'] != 'ghp-hub' || j['name'] is! String || j['version'] is! String) return;
      final name = j['name'] as String, port = j['port'];
      if (name.trim().isEmpty || name.length > 200 || port is! int || port < 1 || port > 65535) return;
      final url = Uri(scheme: 'http', host: packet.address.address, port: port).toString();
      _seen(url, name, manual: _hubs[url]?.manual ?? false);
    } catch (_) {
      /* Unrelated LAN traffic is ignored. */
    }
  }

  void _seen(String url, String name, {required bool manual}) {
    _hubs[url] = DiscoveredHub(url: url, name: name, lastSeen: DateTime.now(), manual: manual);
    _expiry.remove(url)?.cancel();
    _expiry[url] = Timer(const Duration(seconds: 15), () {
      final h = _hubs[url];
      if (h == null) return;
      _hubs[url] = DiscoveredHub(url: url, name: h.name, lastSeen: h.lastSeen, manual: h.manual, online: false);
      _emit();
    });
    _emit();
  }

  final _pinging = <String>{};
  void _pingManual() {
    for (final h in hubs.where((h) => h.manual)) {
      if (!_pinging.add(h.url)) continue;
      final client = HubClient(h.url, timeout: const Duration(seconds: 4));
      _pings.add(client);
      () async {
        try {
          final info = await client.info();
          if (_running && _hubs[h.url]?.manual == true) _seen(h.url, info.name, manual: true);
        } catch (_) {
          /* The silence timer handles failed probes. */
        } finally {
          client.close();
          _pings.remove(client);
          _pinging.remove(h.url);
        }
      }();
    }
  }

  Future<void> stop() async {
    _running = false;
    _socket?.close();
    _socket = null;
    _poll?.cancel();
    _poll = null;
    for (final timer in _expiry.values) {
      timer.cancel();
    }
    _expiry.clear();
    for (final client in _pings.toList()) {
      client.close();
    }
    _starting = null;
  }

  Future<void> _save() => writeJsonFile(_file, [
    for (final h in hubs)
      if (h.manual) h.toJson(),
  ]);
  Future<DiscoveredHub> addManual(String address) async {
    final url = _base(address.contains('://') ? address : 'http://$address').toString();
    final client = HubClient(url);
    try {
      final info = await client.info();
      _seen(url, info.name, manual: true);
      await _save();
      return _hubs[url]!;
    } finally {
      client.close();
    }
  }

  Future<void> removeManual(String url) async {
    final key = _base(url).toString();
    if (_hubs[key]?.manual != true) return;
    _hubs.remove(key);
    _expiry.remove(key)?.cancel();
    await _save();
    _emit();
  }
}

Future<String> publishToHub(
  GitRunner git,
  String repoPath, {
  required String hubUrl,
  required String name,
  String? description,
  void Function(double value, String? stage)? onProgress,
}) async {
  final branch = (await git.run(['symbolic-ref', '--quiet', '--short', 'HEAD'], cwd: repoPath)).stdout.trim();
  if (branch.isEmpty || branch.startsWith('-')) throw ArgumentError('Invalid branch');
  await git.run(['rev-parse', '--verify', '--end-of-options', 'HEAD'], cwd: repoPath);
  final remotes = (await git.run(['remote'], cwd: repoPath)).stdout.split(RegExp(r'\s+'));
  final remote = remotes.contains('origin') ? 'hub' : 'origin';
  if (remotes.contains(remote)) throw ArgumentError('Hub remote already exists');
  final client = HubClient(hubUrl);
  try {
    onProgress?.call(0, 'create');
    HubRepository repository;
    try {
      repository = await client.createRepository(name, description: description);
    } on HubApiException catch (e) {
      if (e.statusCode != 409) rethrow;
      final existing = (await client.listRepositories()).where((r) => r.name == name).firstOrNull;
      if (existing == null || (await client.log(name, limit: 1)).isNotEmpty) rethrow;
      repository = existing;
    }
    // File paths also support offline/testing hubs. Reject executable Git
    // transports such as ext:: and option-like URLs supplied by a server.
    if (!p.isAbsolute(repository.url)) {
      final remoteUri = Uri.parse(repository.url);
      final remoteBase = _base(remoteUri.replace(path: '').toString());
      final host = remoteBase.host.replaceAll(RegExp(r'^\[|\]$'), '');
      final literal = InternetAddress.tryParse(host);
      final addresses = literal == null ? await InternetAddress.lookup(host) : [literal];
      if (addresses.isEmpty || addresses.any((a) => !isPrivateAddress(a.address))) {
        throw ArgumentError('Hub remote must resolve only to private addresses');
      }
    }
    await git.run(['remote', 'add', '--', remote, repository.url], cwd: repoPath);
    await sync.push(git, repoPath, remote: remote, branch: branch, setUpstream: true, onProgress: onProgress);
    onProgress?.call(1, 'complete');
    return remote;
  } finally {
    client.close();
  }
}

bool isHubRemote(String remoteUrl, Iterable<DiscoveredHub> knownHubs) {
  try {
    final remote = Uri.parse(remoteUrl);
    final base = _base(remote.replace(path: '', query: null, fragment: null).toString());
    if (remote.hasQuery || remote.hasFragment) return false;
    return knownHubs.any((h) {
      try {
        return _base(h.url) == base;
      } catch (_) {
        return false;
      }
    });
  } catch (_) {
    return false;
  }
}
