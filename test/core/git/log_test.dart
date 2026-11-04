// Ported from GitHub Desktop (MIT): app/test/unit/git/log-test.ts, app/src/lib/git/git-delimiter-parser.ts (via GitHub+ v1 tests/main/git/log.test.ts, git-delimiter-parser.test.ts)
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/git/log.dart';
import 'package:github_plus/core/git/delimiter_parser.dart';
import 'package:github_plus/core/git/git_runner.dart';
import 'package:github_plus/core/models/status.dart';
import 'helpers.dart';

void main() {
  late TestRepos repos;
  late String repo;
  setUp(() async {
    repos = await TestRepos.create();
    repo = await repos.init('history');
  });
  tearDown(() => repos.dispose());
  test('NUL parser preserves empty, multiline and control character fields', () {
    final parser = LogParser({'sha': '%H', 'body': '%b', 'parents': '%P'});
    expect(parser.formatArgs, ['-z', '--format=%H%x00%b%x00%P']);
    expect(parser.parse('first\x00line\n\x1e\x1f한글\x00\x00second\x00\x00first\x00'), [
      {'sha': 'first', 'body': 'line\n\x1e\x1f한글', 'parents': ''},
      {'sha': 'second', 'body': '', 'parents': 'first'},
    ]);
    expect(parser.parse(''), isEmpty);
    expect(parser.parse('incomplete\x00'), isEmpty);
    expect(() => LogParser({}), throwsArgumentError);
  });
  test('unborn and invalid revisions and pagination', () async {
    expect(await getCommits(repos.git, repo), isEmpty);
    await expectLater(getCommits(repos.git, repo, revision: 'missing'), throwsA(isA<GitException>()));
    for (final revision in ['--all', '-HEAD', '']) {
      await expectLater(getCommits(repos.git, repo, revision: revision), throwsArgumentError);
      await expectLater(getCommitFiles(repos.git, repo, revision), throwsArgumentError);
    }
    await expectLater(getCommits(repos.git, repo, limit: -1), throwsArgumentError);
    await expectLater(getCommits(repos.git, repo, skip: -1), throwsArgumentError);
    await expectLater(getCommits(repos.git, repo, path: '../outside'), throwsArgumentError);
    expect(await getCommits(repos.git, repo, limit: 0), isEmpty);
  });
  test('identities, decorations, Korean body, paging and literal paths preserve parents', () async {
    final first = await repos.commit(repo, '처음', files: {'HEAD': 'first'});
    await repos.run(repo, ['tag', 'release,one']);
    await repos.run(repo, ['tag', '-a', 'annotated', '-m', 'tag']);
    final second = await repos.commit(repo, '둘째\n\n본문 첫 줄\n둘째 줄\n', files: {'other': 'other'});
    final third = await repos.commit(repo, '셋째', files: {'HEAD': 'third'});
    final all = await getCommits(repos.git, repo);
    expect(all.map((c) => c.sha), [third, second, first]);
    expect(all.first.parentShas, [second]);
    expect(all.last.parentShas, isEmpty);
    expect(all[1].summary, '둘째');
    expect(all[1].body, '본문 첫 줄\n둘째 줄\n');
    expect(all.last.refs, containsAll(['tag: release,one', 'tag: annotated']));
    expect(all.first.refs, containsAll(['HEAD', 'main']));
    expect(all.first.author.name, 'Test');
    expect(all.first.committer.email, 'test@example.com');
    expect((await getCommits(repos.git, repo, limit: 1, skip: 1)).single.sha, second);
    final filtered = await getCommits(repos.git, repo, path: 'HEAD');
    expect(filtered.map((c) => c.sha), [third, first]);
    expect(filtered.first.parentShas, [second]);
    await repos.commit(repo, 'literal', files: {'[abc]': 'literal', 'a': 'not literal'});
    expect((await getCommits(repos.git, repo, path: '[abc]')).length, 1);
  });
  test('author and committer signed timezone offsets', () async {
    await repos.git.run(
      [...TestRepos.identity, 'commit', '--allow-empty', '-m', 'dated'],
      cwd: repo,
      environment: {'GIT_AUTHOR_DATE': '1234567890 -0330', 'GIT_COMMITTER_DATE': '1234567990 +0545'},
    );
    final commit = (await getCommits(repos.git, repo)).single;
    expect(commit.author.tzOffsetMinutes, -210);
    expect(commit.committer.tzOffsetMinutes, 345);
    expect(commit.author.date.millisecondsSinceEpoch, 1234567890000);
  });
  test('root additions, modifications, deletion and Unicode rename', () async {
    final root = await repos.commit(
      repo,
      'root',
      files: {'old name': 'rename me', 'delete': 'delete', 'modify': 'old'},
    );
    expect((await getCommitFiles(repos.git, repo, root)).map((f) => f.status.kind), everyElement(FileStatusKind.added));
    await repos.run(repo, ['mv', '--', 'old name', '새 이름']);
    await File('$repo/delete').delete();
    final sha = await repos.commit(repo, 'change', files: {'modify': 'new', 'added': 'added'});
    final files = {for (final f in await getCommitFiles(repos.git, repo, sha)) f.path: f.status};
    expect(files['added']!.kind, FileStatusKind.added);
    expect(files['delete']!.kind, FileStatusKind.deleted);
    expect(files['modify']!.kind, FileStatusKind.modified);
    expect(files['새 이름']!.kind, FileStatusKind.renamed);
    expect(files['새 이름']!.oldPath, 'old name');
    expect(files['새 이름']!.renameIncludesModifications, false);
  });
  test('merge includes parents in topo order and diffs exactly first parent', () async {
    final base = await repos.commit(repo, 'base', files: {'base': 'base'});
    await repos.run(repo, ['checkout', '-b', 'topic']);
    final topic = await repos.commit(repo, 'topic', files: {'topic': 'topic'});
    await repos.run(repo, ['checkout', 'main']);
    final main = await repos.commit(repo, 'main', files: {'main': 'main'});
    await repos.run(repo, ['merge', '--no-ff', 'topic', '-m', 'merge']);
    final all = await getCommits(repos.git, repo);
    expect(all.first.parentShas, [main, topic]);
    expect(all.last.sha, base);
    expect(all.map((c) => c.sha), containsAll([main, topic]));
    final files = await getCommitFiles(repos.git, repo, all.first.sha);
    expect(files.single.path, 'topic');
    expect(files.single.status.kind, FileStatusKind.added);
  });
  test('all: true includes commits that only other branches have', () async {
    expect(await getCommits(repos.git, repo, all: true), isEmpty);
    await repos.commit(repo, 'base');
    await repos.run(repo, ['switch', '-c', 'side']);
    await repos.commit(repo, 'side only');
    await repos.run(repo, ['switch', 'main']);
    final current = (await getCommits(repos.git, repo)).map((c) => c.summary);
    final everything = (await getCommits(repos.git, repo, all: true)).map((c) => c.summary);
    expect(current, ['base']);
    expect(everything, containsAll(['base', 'side only']));
  });
}
