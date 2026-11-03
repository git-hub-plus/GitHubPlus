import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/git/in_progress.dart';
import 'package:github_plus/core/git/status.dart';
import 'package:github_plus/core/models/status.dart';

import 'helpers.dart';

void main() {
  group('parsePorcelainStatus', () {
    test('keeps spaces and Unicode in paths, reads renames and headers', () {
      const output =
          '# branch.oid abc\x00# branch.head main\x00'
          '1 .M N... 100644 100644 100644 aaa bbb dir/my file.txt\x00'
          '2 R. N... 100644 100644 100644 aaa bbb R87 새 이름.txt\x00옛 이름.txt\x00'
          '? 추적 안 함.md\x00'
          'u UU N... 100644 100644 100644 100644 a b c conflict.txt\x00';
      final items = parsePorcelainStatus(output);
      final entries = items.whereType<StatusEntry>().toList();
      expect(items.whereType<StatusHeader>().map((h) => h.value), ['branch.oid abc', 'branch.head main']);
      expect(entries.map((e) => e.path), ['dir/my file.txt', '새 이름.txt', '추적 안 함.md', 'conflict.txt']);
      expect(entries[1].oldPath, '옛 이름.txt');
      expect(entries[1].renameOrCopyScore, 87);
    });

    test('rejects truncated records', () {
      expect(() => parsePorcelainStatus('1 .M N...'), throwsFormatException);
    });
  });

  group('mapStatus', () {
    test('maps codes to kinds', () {
      expect(mapStatus('.M').kind, FileStatusKind.modified);
      expect(mapStatus('A.').kind, FileStatusKind.added);
      expect(mapStatus('.D').kind, FileStatusKind.deleted);
      expect(mapStatus('??').kind, FileStatusKind.untracked);
      expect(mapStatus('UU').conflictAction, ConflictAction.bothModified);
      expect(mapStatus('DU').conflictAction, ConflictAction.deletedByUs);
      final rename = mapStatus('R.', oldPath: 'a', renameOrCopyScore: 100);
      expect(rename.kind, FileStatusKind.renamed);
      expect(rename.renameIncludesModifications, isFalse);
      expect(mapStatus('RM', oldPath: 'a', renameOrCopyScore: 100).renameIncludesModifications, isTrue);
      final sub = mapStatus('.M', submoduleStatusCode: 'SCMU').submodule!;
      expect([sub.commitChanged, sub.modifiedChanges, sub.untrackedChanges], [true, true, true]);
    });
  });

  test('mergedBranchFromMessage reads local and remote branch merges', () {
    expect(mergedBranchFromMessage("Merge branch 'feature'\n\n# Conflicts:"), 'feature');
    expect(mergedBranchFromMessage("Merge remote-tracking branch 'origin/x' into main"), 'origin/x');
    expect(mergedBranchFromMessage('Some other message'), isNull);
    expect(mergedBranchFromMessage(null), isNull);
  });

  group('getStatus on real repositories', () {
    late TestRepos repos;
    setUp(() async => repos = await TestRepos.create());
    tearDown(() => repos.dispose());

    test('reports changed files of every kind', () async {
      final repo = await repos.init('work');
      await repos.commit(repo, 'base', files: {'keep.txt': 'a\n', 'gone.txt': 'b\n', 'old.txt': 'same content\n'});
      await repos.write(repo, 'keep.txt', 'a changed\n');
      await repos.run(repo, ['rm', '-q', 'gone.txt']);
      await repos.run(repo, ['mv', 'old.txt', 'new.txt']);
      await repos.write(repo, '새 파일.txt', 'x\n');
      final status = await getStatus(repos.git, repo);
      final kinds = {for (final f in status.files) f.path: f.status.kind};
      expect(kinds, {
        'keep.txt': FileStatusKind.modified,
        'gone.txt': FileStatusKind.deleted,
        'new.txt': FileStatusKind.renamed,
        '새 파일.txt': FileStatusKind.untracked,
      });
      expect(status.files.firstWhere((f) => f.path == 'new.txt').status.oldPath, 'old.txt');
      expect(status.currentBranch, 'main');
      expect(status.headSha, isNotNull);
      expect(status.inProgress, isNull);
    });

    test('counts ahead/behind against the upstream and unpublished commits without one', () async {
      final remote = await repos.init('remote.git', bare: true);
      final a = await repos.init('a');
      await repos.commit(a, 'one');
      expect((await getStatus(repos.git, a)).unpublished, 1);
      expect((await getStatus(repos.git, a)).toPush, 1);
      await repos.run(a, ['remote', 'add', 'origin', remote]);
      await repos.run(a, ['push', '-q', '-u', 'origin', 'main']);
      final b = await repos.clone(remote, 'b');
      await repos.commit(b, 'from b');
      await repos.run(b, ['push', '-q']);
      await repos.commit(a, 'local 1');
      await repos.commit(a, 'local 2');
      await repos.run(a, ['fetch', '-q']);
      final status = await getStatus(repos.git, a);
      expect(status.upstream, 'origin/main');
      expect((status.ahead, status.behind), (2, 1));
      expect(status.toPush, 2);
    });

    test('detects a merge in progress with its branch and conflict markers', () async {
      final repo = await repos.init('merge');
      await repos.commit(repo, 'base', files: {'doc.txt': 'title\n'});
      await repos.run(repo, ['checkout', '-q', '-b', 'feature']);
      await repos.commit(repo, 'feature', files: {'doc.txt': 'feature title\n'});
      await repos.run(repo, ['checkout', '-q', 'main']);
      await repos.commit(repo, 'main', files: {'doc.txt': 'main title\n'});
      await repos.git.run(['merge', 'feature'], cwd: repo, successExitCodes: {1});
      final status = await getStatus(repos.git, repo);
      expect(status.inProgress, isA<MergeInProgress>());
      expect((status.inProgress! as MergeInProgress).theirBranch, 'feature');
      expect(status.conflictCount, 1);
      expect(status.files.single.status.conflictMarkerCount, 1);
    });

    test('counts stashes and today\'s commits', () async {
      final repo = await repos.init('stash');
      await repos.commit(repo, 'base', files: {'a.txt': '1\n'});
      await repos.commit(repo, 'second', files: {'a.txt': '2\n'});
      await repos.write(repo, 'a.txt', '3\n');
      await repos.run(repo, ['stash', 'push', '-q']);
      expect((await getStatus(repos.git, repo)).stashCount, 1);
      expect(await countCommitsToday(repos.git, repo, email: 'test@example.com'), 2);
      expect(await countCommitsToday(repos.git, repo, email: 'other@example.com'), 0);
    });
  });
}
