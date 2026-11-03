import 'dart:io';

import 'package:github_plus/core/content/repo_content.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../git/helpers.dart';

void main() {
  group('paths', () {
    test('repository paths cannot climb out', () {
      expect(normalizeRepoPath('docs/../README.md'), 'README.md');
      expect(normalizeRepoPath(''), '');
      expect(normalizeRepoPath('../secret'), isNull);
      expect(normalizeRepoPath('docs/../../secret'), isNull);
      expect(normalizeRepoPath('/etc/passwd'), isNull);
      expect(normalizeRepoPath(r'C:\Windows\win.ini'), isNull);
      expect(normalizeRepoPath(r'\\server\share'), isNull);
      expect(normalizeRepoPath(r'docs\guide.md'), 'docs/guide.md');
    });

    test('README links resolve like GitHub', () {
      expect(resolveRepoLink('docs', 'guide.md#install'), 'docs/guide.md');
      expect(resolveRepoLink('docs', '../LICENSE'), 'LICENSE');
      expect(resolveRepoLink('docs', '/src/main.dart'), 'src/main.dart');
      expect(resolveRepoLink('', 'my%20notes.md'), 'my notes.md');
      expect(resolveRepoLink('', '../../outside.md'), isNull);
      expect(resolveRepoLink('', '%E0%A4%A'), isNull);
    });
  });

  test('README choice follows GitHub priority', () {
    TreeEntry file(String path) => TreeEntry(path: path, kind: EntryKind.file);
    expect(findReadme([file('README'), file('readme.MD'), file('a.txt')])?.name, 'readme.MD');
    expect(findReadme([TreeEntry(path: 'README.md', kind: EntryKind.directory)]), isNull);
  });

  test('blob classification', () {
    expect(classifyBlob('a.txt', [0xEF, 0xBB, 0xBF, 0x68, 0x69]), isA<TextBlob>().having((b) => b.text, 'text', 'hi'));
    expect(classifyBlob('a.bin', [1, 0, 2]), isA<BinaryBlob>());
    expect(classifyBlob('logo.PNG', [1, 0, 2]), isA<ImageBlob>());
  });

  test('ls-tree records parse into entries', () {
    const output = '100644 blob 1111 12\tREADME.md\x00'
        '040000 tree 2222 -\tdocs\x00'
        '160000 commit 3333 -\tvendor/lib\x00'
        '120000 blob 4444 9\tlink\x00';
    expect(parseLsTree(output).map((e) => (e.path, e.kind, e.size)), [
      ('README.md', EntryKind.file, 12),
      ('docs', EntryKind.directory, null),
      ('vendor/lib', EntryKind.submodule, null),
      ('link', EntryKind.symlink, 9),
    ]);
  });

  group('sources', () {
    late TestRepos repos;
    late String repo;

    setUp(() async {
      repos = await TestRepos.create();
      repo = await repos.init('content');
      await repos.commit(repo, 'first', files: {'README.md': '# Hello', 'docs/guide.md': 'guide', 'src/a.dart': 'x'});
      await repos.write(repo, 'README.md', '# Edited');
      await repos.write(repo, 'notes.txt', 'new file');
      await repos.write(repo, '.gitignore', 'build/\n');
      await repos.write(repo, 'build/out.bin', 'ignored');
    });
    tearDown(() => repos.dispose());

    test('working folder shows edits and new files, hides ignored ones', () async {
      final source = WorkingTreeSource(repos.git, repo);
      final names = (await source.list('')).map((e) => e.name).toList();
      expect(names, ['docs', 'src', '.gitignore', 'notes.txt', 'README.md']);
      expect(((await source.read('README.md')) as TextBlob).text, '# Edited');
      expect((await source.list('docs')).single.path, 'docs/guide.md');
    });

    test('HEAD shows the committed content', () async {
      final source = GitTreeSource(repos.git, repo);
      expect((await source.list('')).map((e) => e.name), ['docs', 'src', 'README.md']);
      expect(((await source.read('README.md')) as TextBlob).text, '# Hello');
      expect(await source.read('notes.txt'), isA<MissingBlob>());
      expect((await source.list('docs')).single.path, 'docs/guide.md');
    });

    test('a bare hub repository can be browsed the same way', () async {
      final bare = await repos.init('hub.git', bare: true);
      await repos.run(repo, ['push', bare, 'main']);
      final source = GitTreeSource(repos.git, bare, ref: 'main');
      expect(((await source.read('docs/guide.md')) as TextBlob).text, 'guide');
    });

    test('reads outside the repository are refused', () async {
      await File(p.join(repos.root.path, 'secret.txt')).writeAsString('secret');
      for (final source in [WorkingTreeSource(repos.git, repo), GitTreeSource(repos.git, repo)]) {
        expect(await source.read('../secret.txt'), isA<BlockedBlob>());
        expect(await source.list('../'), isEmpty);
      }
    });

    test('large files are not loaded', () async {
      await repos.write(repo, 'big.txt', 'a' * (maxPreviewBytes + 1));
      expect(await WorkingTreeSource(repos.git, repo).read('big.txt'), isA<TooLargeBlob>());
    });
  });
}
