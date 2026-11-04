// Ported from GitHub Desktop (MIT): app/src/lib/git/push.ts (via GitHub+ v1 tests/main/hub/client/api.test.ts)
import 'dart:convert';
import 'dart:io';

import 'package:github_plus/core/content/repo_content.dart';
import 'package:github_plus/core/hub/client.dart';
import 'package:github_plus/core/hub/hub_models.dart';
import 'package:github_plus/core/hub/wire.dart';
import 'package:github_plus/core/models/commit.dart';
import 'package:github_plus/core/models/diff.dart';
import 'package:github_plus/core/models/status.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late HubClient client;
  final requests = <Uri>[];
  final bodies = <Object?>[];
  late Object? Function(HttpRequest) reply;
  setUp(() async {
    requests.clear();
    bodies.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = HubClient('http://127.0.0.1:${server.port}');
    server.listen((r) async {
      requests.add(r.uri);
      if (r.method == 'POST') bodies.add(jsonDecode(await utf8.decoder.bind(r).join()));
      final result = reply(r);
      if (result == null) return;
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode(result));
      await r.response.close();
    });
  });
  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  test('API and content round trips use the shared wire format', () async {
    final identity = CommitIdentity(name: 'tester', email: 't@x', date: DateTime(2026), tzOffsetMinutes: 540);
    final commit = Commit(
      sha: 'abcdef',
      summary: 'first',
      body: 'body',
      author: identity,
      committer: identity,
      parentShas: ['parent'],
      refs: ['main'],
    );
    const file = CommittedFile(
      path: '한 글.txt',
      status: FileStatus(kind: FileStatusKind.added),
    );
    const diff = TextDiff(text: '+hello', hunks: [], maxLineNumber: 1);
    final repo = HubRepository(name: 'team', url: '${client.baseUrl}/team.git', description: 'project');
    final record = HubPushRecord(
      at: DateTime(2026),
      repository: 'team',
      ref: 'refs/heads/main',
      oldSha: 'old',
      newSha: 'new',
      clientAddress: '127.0.0.1',
    );
    reply = (r) {
      if (r.uri.path == '/api/info') return {'name': 'office', 'version': '1'};
      if (r.uri.path == '/api/repos') return r.method == 'POST' ? repo.toJson() : [repo.toJson()];
      return switch (r.uri.pathSegments.last) {
        'log' => [commitToJson(commit)],
        'files' => [committedFileToJson(file)],
        'diff' => fileDiffToJson(diff),
        'pushes' => [record.toJson()],
        'tree' => [treeEntryToJson(const TreeEntry(path: '한 글.txt', kind: EntryKind.file, size: 5))],
        'blob' => blobToJson(const TextBlob('hello', 5)),
        _ => throw StateError('Unexpected route'),
      };
    };
    expect(await client.info(), (name: 'office', version: '1'));
    expect((await client.listRepositories()).single.description, 'project');
    expect((await client.createRepository('team', description: 'project')).name, 'team');
    expect(bodies.single, {'name': 'team', 'description': 'project'});
    expect((await client.log('../team /한?', ref: 'feature/a&b', limit: 20, skip: 3)).single.body, 'body');
    expect(requests.last.pathSegments, ['api', 'repos', '../team /한?', 'log']);
    expect(requests.last.queryParameters, {'limit': '20', 'skip': '3', 'ref': 'feature/a&b'});
    expect((await client.commitFiles('team', '../sha /?')).single.path, '한 글.txt');
    expect(requests.last.pathSegments, ['api', 'repos', 'team', 'commits', '../sha /?', 'files']);
    expect((await client.commitDiff('team', 'abc', 'dir/a & 한.txt') as TextDiff).text, '+hello');
    expect(requests.last.queryParameters['path'], 'dir/a & 한.txt');
    expect((await client.pushes('team', limit: 4)).single.newSha, 'new');
    expect(requests.last.queryParameters['limit'], '4');
    final source = client.contentSource('team', ref: 'feature/x');
    expect((await source.list('')).single.size, 5);
    expect(requests.last.queryParameters['ref'], 'feature/x');
    expect((await source.read('한 글.txt') as TextBlob).text, 'hello');
    final count = requests.length;
    for (final path in ['../escape', '/absolute', '.git/config', 'C:/secret', r'..\escape']) {
      expect(await source.list(path), isEmpty);
      expect(await source.read(path), isA<BlockedBlob>());
    }
    expect(requests.length, count);
    await expectLater(client.log('..'), throwsArgumentError);
  });

  test('typed errors, malformed JSON and malformed shapes', () async {
    reply = (r) {
      r.response.statusCode = 409;
      return {'error': 'exists http://u:secret@host'};
    };
    await expectLater(
      client.createRepository('team'),
      throwsA(
        isA<HubApiException>()
            .having((e) => e.statusCode, 'status', 409)
            .having((e) => e.message, 'redacted', isNot(contains('secret'))),
      ),
    );
    reply = (r) => {'name': 4};
    await expectLater(client.info(), throwsA(isA<HubApiException>()));
    reply = (r) {
      r.response.write('broken');
      r.response.close();
      return null;
    };
    await expectLater(client.info(), throwsA(isA<HubApiException>()));
  });
  test('timeout bounds headers and streaming body', () async {
    final short = HubClient(client.baseUrl, timeout: const Duration(milliseconds: 80));
    addTearDown(short.close);
    reply = (_) => null;
    await expectLater(short.info(), throwsA(isA<HubApiException>().having((e) => e.statusCode, 'status', 0)));
    reply = (r) {
      r.response.write('{');
      r.response.flush();
      return null;
    };
    await expectLater(short.info(), throwsA(isA<HubApiException>()));
  });
  test('redirects are refused', () async {
    reply = (r) {
      r.response.statusCode = 302;
      r.response.headers.set('location', '${client.baseUrl}/other');
      return {};
    };
    await expectLater(client.info(), throwsA(isA<HubApiException>().having((e) => e.statusCode, 'status', 302)));
    expect(requests.length, 1);
  });
  test('base URLs reject public addresses, credentials, schemes and paths', () {
    for (final url in [
      'http://8.8.8.8',
      'https://127.0.0.1',
      'file:///tmp',
      'http://u:p@127.0.0.1',
      'http://127.0.0.1/path',
      'http://127.0.0.1?q=x',
      'http://[2001:4860:4860::8888]',
    ]) {
      expect(() => HubClient(url), throwsArgumentError);
    }
  });
  test('DNS hostnames are checked immediately before connecting', () async {
    final named = HubClient('http://localhost:${server.port}');
    addTearDown(named.close);
    reply = (_) => {'name': 'office', 'version': '1'};
    expect((await named.info()).name, 'office');
  });
  test('hub remotes match known origins exactly, including offline hubs', () {
    final known = [
      DiscoveredHub(url: 'http://192.168.0.2:8765', name: 'office', lastSeen: DateTime(2026), online: false),
    ];
    expect(isHubRemote('http://192.168.0.2:8765/team.git', known), isTrue);
    for (final url in [
      'http://192.168.0.2:8766/team.git',
      'http://192.168.0.2.evil:8765/x.git',
      'http://u:p@192.168.0.2:8765/x.git',
      'https://github.com/a/b.git',
      'garbage',
    ]) {
      expect(isHubRemote(url, known), isFalse);
    }
  });
}
