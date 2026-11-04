// Ported from GitHub Desktop (MIT): app/test/unit/git/{branch,checkout}-test.ts (via GitHub+ v1 tests/main/git/branches-sync.test.ts)
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/git/branches.dart';
import 'package:github_plus/core/git/git_errors.dart';
import 'package:github_plus/core/git/git_runner.dart';
import 'package:github_plus/core/models/commit.dart';
import 'helpers.dart';

void main() {
  late TestRepos repos;
  late String repo;
  Future<Branch> branch(String name) async => (await getBranches(repos.git, repo)).firstWhere((b) => b.name == name);
  setUp(() async {
    repos = await TestRepos.create();
    repo = await repos.init('branches');
    await repos.commit(repo, 'base', files: {'base': 'base'});
  });
  tearDown(() => repos.dispose());
  test('create, duplicate, rename, local checkout and delete', () async {
    await createBranch(repos.git, repo, 'feature/nested');
    expect((await branch('feature/nested')).isCurrent, true);
    expect((await branch('main')).tipDate, isNotNull);
    await expectLater(
      createBranch(repos.git, repo, 'feature/nested'),
      throwsA(isA<GitException>().having((e) => e.result.error, 'error', GitError.branchAlreadyExists)),
    );
    await renameBranch(repos.git, repo, 'feature/nested', 'Feature');
    await renameBranch(repos.git, repo, 'Feature', 'FEATURE');
    await expectLater(renameBranch(repos.git, repo, 'FEATURE', 'main'), throwsA(isA<GitException>()));
    final events = <double>[];
    await checkoutBranch(repos.git, repo, await branch('main'), onProgress: (v, s) => events.add(v));
    expect(events.first, 0);
    expect(events.last, 1);
    await deleteBranch(repos.git, repo, await branch('FEATURE'));
    expect((await getBranches(repos.git, repo)).map((b) => b.name), ['main']);
  });
  test('unmerged deletion requires force and dirty checkout preserves data', () async {
    await createBranch(repos.git, repo, 'topic');
    await repos.commit(repo, 'topic', files: {'base': 'topic'});
    await checkoutBranch(repos.git, repo, await branch('main'));
    await expectLater(deleteBranch(repos.git, repo, await branch('topic')), throwsA(isA<GitException>()));
    await repos.write(repo, 'base', 'dirty');
    final events = <double>[];
    await expectLater(
      checkoutBranch(repos.git, repo, await branch('topic'), onProgress: (v, s) => events.add(v)),
      throwsA(isA<GitException>()),
    );
    expect(events, isNot(contains(1.0)));
    expect(await File('$repo/base').readAsString(), 'dirty');
    await deleteBranch(repos.git, repo, await branch('topic'), force: true);
  });
  test('rejects option-shaped branch names and refs', () async {
    await expectLater(createBranch(repos.git, repo, '-bad'), throwsArgumentError);
    await expectLater(createBranch(repos.git, repo, 'good', startPoint: '--all'), throwsArgumentError);
    await expectLater(renameBranch(repos.git, repo, 'main', '-bad'), throwsArgumentError);
    const bad = Branch(name: '-bad', type: BranchType.local, tipSha: '');
    await expectLater(checkoutBranch(repos.git, repo, bad), throwsArgumentError);
    await expectLater(deleteBranch(repos.git, repo, bad), throwsArgumentError);
  });
  test('remote tracking, HEAD exclusion, ahead/behind, start point and remote deletion', () async {
    final bare = await repos.init('remote.git', bare: true);
    await repos.run(repo, ['remote', 'add', 'origin', bare]);
    await repos.run(repo, ['push', '-u', 'origin', 'main']);
    await createBranch(repos.git, repo, 'feature/nested', checkout: false, startPoint: 'origin/main');
    expect((await branch('feature/nested')).upstream, isNull);
    await repos.run(repo, ['push', '-u', 'origin', 'feature/nested']);
    final other = await repos.clone(bare, 'other');
    expect((await getBranches(repos.git, other)).any((b) => b.name == 'origin/HEAD'), false);
    final remote = (await getBranches(repos.git, other)).firstWhere((b) => b.name == 'origin/feature/nested');
    expect(remote.remoteName, 'origin');
    await repos.run(other, ['config', 'branch.autoSetupMerge', 'false']);
    await checkoutBranch(repos.git, other, remote);
    expect((await getBranches(repos.git, other)).firstWhere((b) => b.isCurrent).upstream, 'origin/feature/nested');
    await checkoutBranch(repos.git, other, remote); // existing counterpart
    await repos.commit(other, 'remote advance', files: {'remote': 'remote'});
    await repos.run(other, ['push']);
    await repos.commit(repo, 'local advance', files: {'local': 'local'});
    await repos.run(repo, ['fetch', 'origin']);
    final main = await branch('main');
    expect(main.ahead, 1);
    // Advance the main remote independently too.
    await repos.run(other, ['push', 'origin', 'HEAD:main']);
    await repos.run(repo, ['fetch', 'origin']);
    expect((await branch('main')).ahead, 1);
    expect((await branch('main')).behind, 1);
    await deleteBranch(repos.git, repo, await branch('feature/nested'), includeRemote: true);
    expect((await getBranches(repos.git, repo)).any((b) => b.name.endsWith('feature/nested')), false);
    expect((await repos.run(bare, ['branch', '--list', 'feature/nested'])).stdout.trim(), isEmpty);
    await createBranch(repos.git, repo, 'remote-only', checkout: false);
    await repos.run(repo, ['push', 'origin', 'remote-only']);
    await deleteBranch(repos.git, repo, await branch('origin/remote-only'), includeRemote: true);
    expect((await repos.run(bare, ['branch', '--list', 'remote-only'])).stdout.trim(), isEmpty);
  });
}
