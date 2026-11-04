// Ported from GitHub Desktop (MIT): app/src/lib/git (via GitHub+ v1 tests/main/hub/server/server.test.ts)
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:github_plus/core/hub/server.dart';
import 'package:github_plus/core/hub/server_api.dart';
import 'package:github_plus/core/hub/hub_models.dart';
import 'package:github_plus/core/hub/wire.dart';
import 'package:github_plus/core/content/repo_content.dart';
import 'package:github_plus/core/models/diff.dart';
import 'package:github_plus/core/hub/validation.dart';
import '../git/helpers.dart';

void main() {
  late TestRepos repos;
  late HubServer hub;
  late HubSettings settings;
  late HttpClient client;
  String url() => 'http://127.0.0.1:${hub.status.port}';
  Future<({int status, dynamic body})> api(String path, {String? body}) async {
    final request = await client.openUrl(body == null ? 'GET' : 'POST', Uri.parse('${url()}$path'));
    if (body != null) request.write(body);
    final response = await request.close();
    return (status: response.statusCode, body: jsonDecode(await utf8.decoder.bind(response).join()));
  }

  setUp(() async {
    repos = await TestRepos.create();
    hub = HubServer(git: repos.git, appVersion: 'test-1', announce: false);
    client = HttpClient();
    settings = HubSettings(
      enabled: true,
      port: 0,
      rootDirectory: p.join(repos.root.path, 'hub'),
      backupDirectory: p.join(repos.root.path, 'backup'),
      name: 'Test Hub',
    );
    final status = await hub.start(settings);
    expect(status.running, true, reason: status.error);
  });
  tearDown(() async {
    client.close(force: true);
    await hub.stop();
    await repos.dispose();
  });

  test('address gate denies public and malformed addresses without trusting headers', () {
    for (final ip in ['8.8.8.8', '2001:4860:4860::8888', '::ffff:8.8.8.8', 'invalid', '']) {
      expect(hubAddressStatus(ip), 403);
    }
    for (final ip in ['127.0.0.1', '::1', '::ffff:127.0.0.1', '192.168.1.2', '10.2.3.4', 'fc00::1']) {
      expect(hubAddressStatus(ip), 200);
    }
  });

  test('real clone push fetch, protection, wire APIs, gzip, backup and trash', () async {
    expect((await api('/api/info')).body, {'name': 'Test Hub', 'version': 'test-1'});
    final created = await api('/api/repos', body: jsonEncode({'name': 'team', 'description': 'Team repo'}));
    expect(created.status, 201);
    expect(HubRepository.fromJson(created.body)!.name, 'team');
    expect((await api('/api/repos', body: '{"name":"team"}')).status, 409);
    expect((await api('/api/repos/team/log')).body, isEmpty);
    final one = await repos.clone('${url()}/team.git', 'one');
    final first = await repos.commit(one, 'first', files: {'README.md': '# Hello\n'});
    await repos.run(one, ['push', 'origin', 'HEAD:refs/heads/main']);
    final two = await repos.clone('${url()}/team.git', 'two');
    final second = await repos.commit(one, 'second', files: {'README.md': '# Hello again\n'});
    await repos.run(one, ['push', 'origin', 'HEAD:refs/heads/main']);
    await repos.run(two, ['fetch', 'origin']);
    expect((await repos.run(two, ['rev-parse', 'origin/main'])).stdout.trim(), second);
    await repos.run(one, ['tag', 'v1']);
    await repos.run(one, ['push', 'origin', 'refs/tags/v1']);
    final bare = p.join(settings.rootDirectory, 'team.git');
    final before = (await repos.run(bare, ['show-ref'])).stdout;
    final accepted = await hub.pushLog();
    for (final args in [
      ['push', '--force', 'origin', '$first:refs/heads/main'],
      ['push', 'origin', ':refs/heads/main'],
      ['push', 'origin', ':refs/tags/v1'],
      ['push', '--force', 'origin', '$first:refs/tags/v1'],
    ]) {
      final result = await repos.git.run(args, cwd: one, successExitCodes: {0, 1});
      expect(result.exitCode, 1, reason: result.stderr);
      expect((await repos.run(bare, ['show-ref'])).stdout, before);
    }
    final records = await hub.pushLog(repository: 'team');
    expect(records.length, 3);
    expect(records.map((r) => r.toJson()), accepted.map((r) => r.toJson()));
    expect(records.first.ref, 'refs/tags/v1');
    expect(records.last.oldSha, '0' * 40);
    expect(records.last.newSha, first);
    expect(records[1].oldSha, first);
    expect(records[1].newSha, second);
    expect(records.every((r) => r.clientAddress == '127.0.0.1'), true);
    expect(await hub.pushLog(repository: 'other'), isEmpty);
    expect((await hub.pushLog(limit: 1)).single.ref, 'refs/tags/v1');
    expect(await File(p.join(settings.rootDirectory, 'push-log.jsonl')).readAsLines(), hasLength(3));
    final pushes = (await api('/api/repos/team/pushes?limit=1')).body as List;
    expect(HubPushRecord.fromJson(pushes.single)!.newSha, second);
    final listed = (await api('/api/repos')).body as List;
    expect(HubRepository.fromJson(listed.single)!.description, 'Team repo');
    final log = (await api('/api/repos/team/log?limit=1')).body as List;
    expect(commitFromJson(log.single as Map).sha, second);
    final page = (await api('/api/repos/team/log?skip=1')).body as List;
    expect(commitFromJson(page.single as Map).sha, first);
    final files = (await api('/api/repos/team/commits/$first/files')).body as List;
    expect(committedFileFromJson(files.single as Map).path, 'README.md');
    final diff = (await api('/api/repos/team/commits/$first/diff?path=README.md')).body;
    expect((fileDiffFromJson(diff as Map) as TextDiff).text, contains('+# Hello'));
    final tree = (await api('/api/repos/team/tree?ref=main')).body as List;
    expect(treeEntryFromJson(tree.single as Map).path, 'README.md');
    final blob = (await api('/api/repos/team/blob?ref=main&path=README.md')).body;
    expect((blobFromJson(blob as Map) as TextBlob).text, '# Hello again\n');
    final want = 'want $second\n';
    final packet = '${(utf8.encode(want).length + 4).toRadixString(16).padLeft(4, '0')}${want}00000009done\n';
    final req = await client.postUrl(Uri.parse('${url()}/team.git/git-upload-pack'));
    req.headers.set('Content-Encoding', 'gzip');
    req.add(gzip.encode(utf8.encode(packet)));
    final res = await req.close();
    expect(res.statusCode, 200);
    expect(latin1.decode(await res.fold<List<int>>([], (a, b) => a..addAll(b))), contains('PACK'));
    final backup = await hub.backupNow();
    expect(backup.repositories, 1);
    final bundle = (await Directory(settings.backupDirectory!).list().toList()).single.path;
    expect(p.basename(bundle), matches(r'^team-\d{8}-\d{6}\.bundle$'));
    await repos.run(one, ['bundle', 'verify', '--', bundle]);
    await hub.deleteRepository('team');
    expect(await hub.listRepositories(), isEmpty);
    expect(hub.status.repositoryCount, 0);
    expect(await Directory(p.join(settings.rootDirectory, '.trash')).list().length, 1);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('input bounds, traversal, unsupported encoding and bind error', () async {
    for (final name in ['../escape', 'x/y', 'x\\y', 'CON', 'a..b', '', '-option']) {
      expect((await api('/api/repos', body: jsonEncode({'name': name}))).status, 400);
    }
    for (final body in ['null', '{', '{"name":1}', '{"name":"valid","description":4}']) {
      expect((await api('/api/repos', body: body)).status, 400);
    }
    expect((await api('/api/repos', body: 'x' * (1024 * 1024 + 1))).status, 413);
    await hub.createRepository('empty');
    for (final path in [
      '/api/repos/..%2Fescape/log',
      '/api/repos/x%5Cy/log',
      '/..%2Fescape.git/info/refs?service=git-upload-pack',
      '/x%5Cy.git/info/refs?service=git-upload-pack',
      '/api/repos/empty/log?ref=-x',
      '/api/repos/empty/log?limit=-1',
      '/api/repos/empty/log?skip=oops',
      '/api/repos/empty/tree?path=../outside',
      '/api/repos/empty/blob?path=.git/config',
      '/api/repos/empty/tree?ref=-x',
    ]) {
      expect((await api(path)).status, 400, reason: path);
    }
    final req = await client.postUrl(Uri.parse('${url()}/empty.git/git-upload-pack'));
    req.headers.set('Content-Encoding', 'br');
    final res = await req.close();
    expect(res.statusCode, 415);
    await res.drain<void>();
    final conflict = HubServer(git: repos.git, appVersion: 'test', announce: false);
    try {
      final status = await conflict.start(settings.copyWith(port: hub.status.port));
      expect(status.running, false);
      expect(status.error, isNotEmpty);
    } finally {
      await conflict.stop();
    }
  });

  test('restart restores protection and first published branch sets HEAD', () async {
    final events = <HubServerStatus>[];
    final subscription = hub.statusChanges.listen(events.add);
    await hub.createRepository('custom');
    final one = await repos.clone('${url()}/custom.git', 'custom-client');
    await repos.commit(one, 'first');
    await repos.run(one, ['push', 'origin', 'HEAD:refs/heads/published']);
    final bare = p.join(settings.rootDirectory, 'custom.git');
    expect((await repos.run(bare, ['symbolic-ref', '--short', 'HEAD'])).stdout.trim(), 'published');
    await hub.stop();
    await repos.run(bare, ['config', 'receive.denyDeletes', 'false']);
    await File(p.join(bare, 'hooks', 'pre-receive')).writeAsString('#!/bin/sh\nexit 0\n');
    expect((await hub.start(settings)).running, true);
    expect((await repos.run(bare, ['config', '--get', 'receive.denyDeletes'])).stdout.trim(), 'true');
    expect(await File(p.join(bare, 'hooks', 'pre-receive')).readAsString(), contains('rewriting tags'));
    expect((await hub.pushLog()).single.ref, 'refs/heads/published');
    await repos.clone('${url()}/custom.git', 'fresh');
    expect(hub.status.repositoryCount, 1);
    await subscription.cancel();
    expect(events.any((s) => s.running), true);
    expect(events.any((s) => !s.running), true);
  }, timeout: const Timeout(Duration(minutes: 1)));

  test(
    'simultaneous publishes are serialized and audit ties retain append order',
    () async {
      await hub.createRepository('parallel');
      final one = await repos.clone('${url()}/parallel.git', 'one');
      final sha = await repos.commit(one, 'publish');
      await Future.wait([
        repos.run(one, ['push', 'origin', 'HEAD:refs/heads/one']),
        repos.run(one, ['push', 'origin', 'HEAD:refs/heads/two']),
      ]);
      final records = await hub.pushLog();
      expect(records, hasLength(2));
      expect(records.map((r) => r.ref).toSet(), {'refs/heads/one', 'refs/heads/two'});
      expect(records.every((r) => r.oldSha == '0' * 40 && r.newSha == sha), true);
      final log = File(p.join(settings.rootDirectory, 'push-log.jsonl'));
      final at = DateTime.fromMillisecondsSinceEpoch(1000);
      final tied = [
        for (var i = 0; i < 30; i++)
          HubPushRecord(
            at: at,
            repository: 'parallel',
            ref: 'refs/heads/$i',
            oldSha: '0' * 40,
            newSha: sha,
            clientAddress: '127.0.0.1',
          ),
      ];
      await log.writeAsString('${tied.map((r) => jsonEncode(r.toJson())).join('\n')}\n{partial');
      expect((await hub.pushLog()).map((r) => r.ref), tied.reversed.map((r) => r.ref));
      expect(await hub.pushLog(limit: 0), isEmpty);
      final ranks = hub.status.addresses.map((s) => lanAddressRank(Uri.parse(s).host)).toList();
      expect(ranks, orderedEquals([...ranks]..sort()));
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test('linked repository cannot expose a directory outside hub root', () async {
    final outside = await repos.init('outside', bare: true);
    final link = Link(p.join(settings.rootDirectory, 'escape.git'));
    // Windows directory links use junctions and require no developer-mode privilege.
    await link.create(outside);
    expect((await api('/api/repos/escape/log')).status, anyOf(403, 404));
    expect((await api('/escape.git/info/refs?service=git-upload-pack')).status, anyOf(403, 404));
    expect((await hub.listRepositories()).where((r) => r.name == 'escape'), isEmpty);
    await link.delete();
  });
}
