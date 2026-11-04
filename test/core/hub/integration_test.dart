import 'dart:io';

import 'package:github_plus/core/content/repo_content.dart';
import 'package:github_plus/core/git/clone.dart';
import 'package:github_plus/core/git/git_runner.dart';
import 'package:github_plus/core/hub/client.dart';
import 'package:github_plus/core/hub/hub_models.dart';
import 'package:github_plus/core/hub/server.dart';
import 'package:github_plus/core/hub/validation.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../git/helpers.dart';

/// The real hub server and the real client together, over HTTP on loopback.
void main() {
  late TestRepos repos;
  late HubServer server;
  late String base;

  setUp(() async {
    repos = await TestRepos.create();
    server = HubServer(git: repos.git, appVersion: 'test', announce: false);
    final status = await server.start(
      HubSettings(enabled: true, port: 0, rootDirectory: p.join(repos.root.path, 'hub')),
    );
    expect(status.error, isNull);
    base = 'http://127.0.0.1:${status.port}';
  });
  tearDown(() async {
    await server.stop();
    await repos.dispose();
  });

  test('publish, clone, protect history, browse README and record pushes', () async {
    final work = await repos.init('work');
    await repos.commit(work, 'first', files: {'README.md': '# 팀 프로젝트\n', 'src/a.txt': 'a'});

    final progress = <double>[];
    final remote = await publishToHub(
      repos.git,
      work,
      hubUrl: base,
      name: 'team',
      onProgress: (v, _) => progress.add(v),
    );
    expect(remote, 'origin');

    final client = HubClient(base);
    addTearDown(client.close);
    expect((await client.listRepositories()).map((r) => r.name), ['team']);
    expect((await client.log('team')).single.summary, 'first');

    // Another PC clones over HTTP.
    final other = p.join(repos.root.path, 'other');
    await cloneRepository(repos.git, '$base/team.git', other);
    // Checkout follows MinGit's core.autocrlf, so compare without CRs.
    expect(File(p.join(other, 'README.md')).readAsStringSync().replaceAll('\r', ''), '# 팀 프로젝트\n');

    // Rewriting published history is refused and the hub keeps the original.
    await repos.run(work, ['commit', '--amend', '-m', 'rewritten']);
    await expectLater(repos.run(work, ['push', '--force', 'origin', 'main']), throwsA(isA<GitException>()));
    await expectLater(repos.run(work, ['push', 'origin', '--delete', 'main']), throwsA(isA<GitException>()));
    expect((await client.log('team')).single.summary, 'first');

    // The overview page can read the hub copy like a local one.
    final source = client.contentSource('team');
    expect((await source.list('')).map((e) => e.name), ['src', 'README.md']);
    expect(((await source.read('README.md')) as TextBlob).text, '# 팀 프로젝트\n');
    expect(await source.read('../secret'), isA<BlockedBlob>());

    final pushes = await client.pushes('team');
    expect(pushes.single.ref, 'refs/heads/main');
    // The clone URL is the hub's announced LAN address, so the push may come from it.
    expect(isPrivateAddress(pushes.single.clientAddress), isTrue);
  });
}
