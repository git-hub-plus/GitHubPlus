// Ported from GitHub Desktop (MIT): app/src/lib/git/push.ts (via GitHub+ v1 tests/main/hub/client/publish.test.ts)
import 'dart:convert';
import 'dart:io';
import 'package:github_plus/core/hub/client.dart';
import 'package:github_plus/core/hub/hub_models.dart';
import 'package:github_plus/core/hub/wire.dart';
import 'package:github_plus/core/models/commit.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../git/helpers.dart';

void main() {
  late TestRepos repos;
  late HttpServer server;
  late String url;
  late String target;
  var calls = 0;
  var conflict = false;
  var nonempty = false;
  final bodies = <Object?>[];
  setUp(() async {
    repos = await TestRepos.create();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = 'http://127.0.0.1:${server.port}';
    calls = 0;
    conflict = false;
    nonempty = false;
    bodies.clear();
    server.listen((r) async {
      calls++;
      final repo = HubRepository(name: 'team', url: target).toJson();
      Object? result = repo;
      if (r.method == 'POST') {
        bodies.add(jsonDecode(await utf8.decoder.bind(r).join()));
        if (conflict) {
          r.response.statusCode = 409;
          result = {'error': 'exists'};
        }
      } else if (r.uri.path.endsWith('/log')) {
        result = nonempty
            ? [
                commitToJson(
                  Commit(
                    sha: 'existing',
                    summary: 'existing',
                    body: '',
                    parentShas: [],
                    author: CommitIdentity(name: 'T', email: 't@x', date: DateTime(2026), tzOffsetMinutes: 0),
                    committer: CommitIdentity(name: 'T', email: 't@x', date: DateTime(2026), tzOffsetMinutes: 0),
                  ),
                ),
              ]
            : [];
      } else {
        result = [repo];
      }
      r.response.write(jsonEncode(result));
      await r.response.close();
    });
  });
  tearDown(() async {
    await server.close(force: true);
    await repos.dispose();
  });
  for (final hasOrigin in [false, true]) {
    test('publishes and sets upstream, origin exists: $hasOrigin', () async {
      final local = await repos.init('local');
      final sha = await repos.commit(local, 'first', files: {'README.md': 'hello'});
      target = await repos.init('team.git', bare: true);
      if (hasOrigin) await repos.run(local, ['remote', 'add', '--', 'origin', target]);
      final progress = <double>[];
      final remote = await publishToHub(
        repos.git,
        local,
        hubUrl: url,
        name: 'team',
        description: 'project',
        onProgress: (value, _) => progress.add(value),
      );
      expect(remote, hasOrigin ? 'hub' : 'origin');
      expect((await repos.run(local, ['remote', 'get-url', remote])).stdout.trim(), target);
      expect((await repos.run(target, ['rev-parse', 'refs/heads/main'])).stdout.trim(), sha);
      expect((await repos.run(local, ['config', '--get', 'branch.main.remote'])).stdout.trim(), remote);
      expect((await repos.run(local, ['config', '--get', 'branch.main.merge'])).stdout.trim(), 'refs/heads/main');
      expect(progress.first, 0);
      expect(progress.last, 1);
      expect(bodies, [
        {'name': 'team', 'description': 'project'},
      ]);
    });
  }
  test('rejects occupied remote and unborn HEAD before API calls', () async {
    final local = await repos.init('local');
    target = await repos.init('team.git', bare: true);
    await expectLater(publishToHub(repos.git, local, hubUrl: url, name: 'team'), throwsA(anything));
    expect(calls, 0);
    await repos.commit(local, 'first');
    for (final remote in ['origin', 'hub']) {
      await repos.run(local, ['remote', 'add', '--', remote, target]);
    }
    await expectLater(publishToHub(repos.git, local, hubUrl: url, name: 'team'), throwsArgumentError);
    expect(calls, 0);
  });
  test('reuses an existing empty hub repository', () async {
    final local = await repos.init('local');
    await repos.commit(local, 'first');
    target = await repos.init('team.git', bare: true);
    conflict = true;
    expect(await publishToHub(repos.git, local, hubUrl: url, name: 'team'), 'origin');
    expect(calls, 3);
  });
  test('does not reuse a nonempty existing repository', () async {
    final local = await repos.init('local');
    await repos.commit(local, 'first');
    target = await repos.init('team.git', bare: true);
    conflict = true;
    nonempty = true;
    await expectLater(publishToHub(repos.git, local, hubUrl: url, name: 'team'), throwsA(isA<HubApiException>()));
    expect((await repos.run(local, ['remote'])).stdout.trim(), isEmpty);
  });
  test('rejects public and executable server-provided remotes', () async {
    final local = await repos.init('local');
    await repos.commit(local, 'first');
    for (final unsafe in ['http://8.8.8.8/team.git', 'ext::arbitrary-command', '--upload-pack=bad']) {
      target = unsafe;
      await expectLater(publishToHub(repos.git, local, hubUrl: url, name: 'team'), throwsArgumentError);
      expect((await repos.run(local, ['remote'])).stdout.trim(), isEmpty);
    }
  });

  test('retains remote when push fails', () async {
    final local = await repos.init('local');
    await repos.commit(local, 'first');
    target = p.join(repos.root.path, 'missing.git');
    await expectLater(publishToHub(repos.git, local, hubUrl: url, name: 'team'), throwsA(anything));
    expect((await repos.run(local, ['remote', 'get-url', 'origin'])).stdout.trim(), target);
  });
}
