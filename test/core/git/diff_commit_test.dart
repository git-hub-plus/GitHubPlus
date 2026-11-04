// Ported from GitHub Desktop (MIT): app/test/unit/git/diff-test.ts and commit-test.ts (via GitHub+ v1 tests/main/git/diff-commit.test.ts)
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:github_plus/core/git/commit.dart';
import 'package:github_plus/core/git/diff.dart';
import 'package:github_plus/core/git/diff_parser.dart';
import 'package:github_plus/core/git/git_runner.dart';
import 'package:github_plus/core/models/commit.dart';
import 'package:github_plus/core/models/diff.dart';
import 'package:github_plus/core/models/status.dart';
import 'helpers.dart';

WorkingFile file(String path, [FileStatusKind kind = FileStatusKind.modified]) => WorkingFile(
  path: path,
  status: FileStatus(kind: kind),
);
DiffSelection lines(TextDiff diff, List<String> texts) {
  var selection = DiffSelection.none(diff.selectableLines);
  for (final line in diff.hunks.expand((h) => h.lines)) {
    if (texts.contains(line.text)) selection = selection.withLineSelection(line.originalLineNumber, true);
  }
  return selection;
}

void main() {
  late TestRepos repos;
  late String repo;
  Future<String> run(List<String> args) async => (await repos.run(repo, args)).stdout;
  Future<String> commit(
    List<WorkingFile> files, {
    List<DiffSelection>? selections,
    bool amend = false,
    String message = 'selected\n\nbody',
  }) => createCommit(
    repos.git,
    repo,
    message: message,
    amend: amend,
    files: [
      for (var i = 0; i < files.length; i++)
        CommitFileSelection(file: files[i], selection: selections?[i] ?? DiffSelection.all()),
    ],
  );
  setUp(() async {
    repos = await TestRepos.create();
    repos.git.registerAuthProvider((args, cwd) => const GitAuthExtras(configArgs: TestRepos.identity));
    repo = await repos.init('repo');
    await repos.commit(repo, 'initial', files: {'file.txt': 'one\ntwo\nthree\nfour\n', 'other.txt': 'original\n'});
  });
  tearDown(() async => repos.dispose());
  test('v1: commits replacement selection against HEAD, excluding already staged files', () async {
    await repos.write(repo, 'file.txt', 'ONE\ntwo\nTHREE\nfour\n');
    await repos.write(repo, 'other.txt', 'staged elsewhere\n');
    await run(['add', '-A']);
    final f = file('file.txt');
    final diff = await getWorkingDiff(repos.git, repo, f) as TextDiff;
    final sha = await commit(
      [f],
      selections: [
        lines(diff, ['-one', '+ONE']),
      ],
    );
    expect(await run(['show', '$sha:file.txt']), 'ONE\ntwo\nthree\nfour\n');
    expect(await File(p.join(repo, 'file.txt')).readAsString(), 'ONE\ntwo\nTHREE\nfour\n');
    expect(await run(['show', '$sha:other.txt']), 'original\n');
    expect(await run(['diff', '--cached', '--name-only']), isEmpty);
  });
  test('v1: new, deleted, renamed files and recreated rename source', () async {
    await repos.write(repo, 'new.txt', 'new\n');
    await File(p.join(repo, 'other.txt')).delete();
    await File(p.join(repo, 'file.txt')).rename(p.join(repo, 'renamed.txt'));
    await run(['add', '-A']);
    await repos.write(repo, 'file.txt', 'keep untracked source\n');
    const renamed = WorkingFile(
      path: 'renamed.txt',
      status: FileStatus(kind: FileStatusKind.renamed, oldPath: 'file.txt'),
    );
    final sha = await commit([
      file('new.txt', FileStatusKind.untracked),
      file('other.txt', FileStatusKind.deleted),
      renamed,
    ]);
    expect(await run(['ls-tree', '--name-only', sha]), 'new.txt\nrenamed.txt\n');
    expect(await File(p.join(repo, 'file.txt')).readAsString(), 'keep untracked source\n');
    expect(
      await getCommitDiff(
        repos.git,
        repo,
        sha,
        const CommittedFile(
          path: 'renamed.txt',
          status: FileStatus(kind: FileStatusKind.renamed, oldPath: 'file.txt'),
        ),
      ),
      isA<TextDiff>(),
    );
  });
  test('v1: amend content and multiline message, then message-only amend', () async {
    final parent = (await run(['rev-parse', 'HEAD'])).trim();
    await repos.write(repo, 'file.txt', 'changed\n');
    await commit([file('file.txt')]);
    await repos.write(repo, 'other.txt', 'amended\n');
    final sha = await commit([file('other.txt')], amend: true, message: 'amended "summary"\n\nbody');
    expect((await run(['rev-parse', '$sha^'])).trim(), parent);
    expect(await run(['show', '$sha:file.txt']), 'changed\n');
    expect(await run(['show', '$sha:other.txt']), 'amended\n');
    expect((await run(['log', '-1', '--format=%B'])).trim(), 'amended "summary"\n\nbody');
    await commit([], amend: true, message: 'message only');
    expect((await run(['log', '-1', '--format=%s'])).trim(), 'message only');
  });
  test('v1: partial new file without trailing newline', () async {
    await repos.write(repo, 'new.txt', 'first\nsecond');
    final f = file('new.txt', FileStatusKind.untracked);
    final diff = await getWorkingDiff(repos.git, repo, f) as TextDiff;
    final sha = await commit(
      [f],
      selections: [
        lines(diff, ['+second']),
      ],
    );
    expect(await run(['show', '$sha:new.txt']), 'second');
    expect(await File(p.join(repo, 'new.txt')).readAsString(), 'first\nsecond');
  });
  test('v1: partial rename includes staged modifications', () async {
    await File(p.join(repo, 'file.txt')).rename(p.join(repo, 'new name.txt'));
    await repos.write(repo, 'new name.txt', 'ONE\ntwo\nTHREE\nfour\n');
    await run(['add', '-A']);
    const f = WorkingFile(
      path: 'new name.txt',
      status: FileStatus(kind: FileStatusKind.renamed, oldPath: 'file.txt'),
    );
    final diff = await getWorkingDiff(repos.git, repo, f) as TextDiff;
    final sha = await commit(
      [f],
      selections: [
        lines(diff, ['-one', '+ONE']),
      ],
    );
    expect(await run(['show', '$sha:new name.txt']), 'ONE\ntwo\nthree\nfour\n');
    expect(await run(['ls-tree', '--name-only', sha]), isNot(contains('file.txt')));
  });
  test('v1: first commit and root history diff', () async {
    repo = await repos.init('unborn');
    await repos.write(repo, 'initial.txt', 'hello\n');
    final f = file('initial.txt', FileStatusKind.untracked);
    expect((await getWorkingDiff(repos.git, repo, f) as TextDiff).text, contains('+hello'));
    final sha = await commit([f]);
    final diff = await getCommitDiff(repos.git, repo, sha, CommittedFile(path: f.path, status: f.status)) as TextDiff;
    expect(diff.text, contains('+hello'));
  });
  test('v1: failed partial binary selection preserves HEAD and index', () async {
    await File(p.join(repo, 'binary.dat')).writeAsBytes([0, 1, 2]);
    final before = await run(['rev-parse', 'HEAD']);
    final index = await File(p.join(repo, '.git', 'index')).readAsBytes();
    await expectLater(
      commit(
        [file('binary.dat', FileStatusKind.untracked)],
        selections: [DiffSelection.none().withLineSelection(1, true)],
      ),
      throwsArgumentError,
    );
    expect(await run(['rev-parse', 'HEAD']), before);
    expect(await File(p.join(repo, '.git', 'index')).readAsBytes(), index);
  });
  test('v1: reject implicit unlisted file deletion', () async {
    await File(p.join(repo, 'other.txt')).delete();
    await repos.write(repo, 'other.txt/nested.txt', 'nested\n');
    final before = await run(['rev-parse', 'HEAD']);
    await expectLater(commit([file('other.txt/nested.txt', FileStatusKind.untracked)]), throwsArgumentError);
    expect(await run(['rev-parse', 'HEAD']), before);
    expect(await run(['show', ':other.txt']), 'original\n');
  });
  test('modified EOF without newline, selection across multiple hunks', () async {
    final original = List.generate(30, (i) => 'line $i').join('\n');
    await repos.commit(repo, 'base', files: {'eof.txt': original});
    await repos.write(
      repo,
      'eof.txt',
      original.replaceFirst('line 1\n', 'ONE\nEXTRA\n').replaceFirst('line 29', 'LAST'),
    );
    final f = file('eof.txt');
    final diff = await getWorkingDiff(repos.git, repo, f) as TextDiff;
    final sha = await commit(
      [f],
      selections: [
        lines(diff, ['-line 29', '+LAST']),
      ],
    );
    expect(await run(['show', '$sha:eof.txt']), original.replaceFirst('line 29', 'LAST'));
    expect(await run(['diff', 'HEAD', '--', 'eof.txt']), contains('+EXTRA'));
  });
  test('v1: binary, images, image deletion, large lines, Korean name and line endings', () async {
    for (final name in ['binary.dat', 'IMAGE.PNG']) {
      await File(p.join(repo, name)).writeAsBytes([0, 1, 2, 3]);
    }
    expect(await getWorkingDiff(repos.git, repo, file('binary.dat', FileStatusKind.untracked)), isA<BinaryDiff>());
    final image = await getWorkingDiff(repos.git, repo, file('IMAGE.PNG', FileStatusKind.untracked)) as ImageDiff;
    expect(image.current!.bytes, [0, 1, 2, 3]);
    expect(image.current!.mediaType, 'image/png');
    expect(image.previous, isNull);
    final sha = await commit([file('IMAGE.PNG', FileStatusKind.untracked)]);
    expect(
      await getCommitDiff(
        repos.git,
        repo,
        sha,
        const CommittedFile(
          path: 'IMAGE.PNG',
          status: FileStatus(kind: FileStatusKind.added),
        ),
      ),
      isA<ImageDiff>(),
    );
    await File(p.join(repo, 'IMAGE.PNG')).delete();
    final deleted = await getWorkingDiff(repos.git, repo, file('IMAGE.PNG', FileStatusKind.deleted)) as ImageDiff;
    expect(deleted.previous!.bytes, [0, 1, 2, 3]);
    expect(deleted.current, isNull);
    await repos.write(repo, 'long.txt', 'a' * 5001);
    expect(await getWorkingDiff(repos.git, repo, file('long.txt', FileStatusKind.untracked)), isA<LargeDiff>());
    await repos.commit(repo, 'endings', files: {'한글.txt': 'one\r\ntwo\r\n'});
    await repos.write(repo, '한글.txt', 'one\ntwo\n');
    final endings = await getWorkingDiff(repos.git, repo, file('한글.txt')) as TextDiff;
    expect(endings.lineEndingsChange, (from: LineEnding.crlf, to: LineEnding.lf));
    await repos.write(repo, '한글.txt', 'one\r\ntwo\r\n');
    await commit([], amend: true);
  });
  test('v1: gitlink mode identifies submodules, ordinary matching text does not', () async {
    final sha = (await run(['rev-parse', 'HEAD'])).trim();
    await run(['update-index', '--add', '--cacheinfo', '160000', sha, 'sub']);
    await run(['commit', '-m', 'submodule']);
    final tip = (await run(['rev-parse', 'HEAD'])).trim();
    final diff =
        await getCommitDiff(
              repos.git,
              repo,
              tip,
              const CommittedFile(
                path: 'sub',
                status: FileStatus(kind: FileStatusKind.added),
              ),
            )
            as SubmoduleDiff;
    expect(diff.newSha, sha);
    expect(diff.oldSha, isNull);
    await repos.write(repo, 'ordinary.txt', 'Subproject commit abc123\n');
    expect(await getWorkingDiff(repos.git, repo, file('ordinary.txt', FileStatusKind.untracked)), isA<TextDiff>());
  });
  test('size thresholds, image limit, bidi and unsafe paths', () async {
    await repos.write(repo, 'huge.txt', ('${'a' * 1023}\n') * (maxDiffBytes ~/ 1024 + 1));
    final huge = await getWorkingDiff(repos.git, repo, file('huge.txt', FileStatusKind.untracked));
    expect(huge, isA<LargeDiff>());
    await File(p.join(repo, 'big.png')).writeAsBytes(List.filled(10 * 1024 * 1024 + 1, 0));
    expect(await getWorkingDiff(repos.git, repo, file('big.png', FileStatusKind.untracked)), isA<BinaryDiff>());
    expect((DiffParser().parse('--- a/x\n+++ b/x\n@@ -0,0 +1 @@\n+\u202etest') as TextDiff).hasHiddenBidiChars, isTrue);
    for (final path in ['../outside', '.git/config', '/absolute']) {
      await expectLater(getWorkingDiff(repos.git, repo, file(path)), throwsArgumentError);
    }
    await expectLater(
      getCommitDiff(
        repos.git,
        repo,
        '--help',
        const CommittedFile(
          path: 'file.txt',
          status: FileStatus(kind: FileStatusKind.modified),
        ),
      ),
      throwsArgumentError,
    );
  });
}
