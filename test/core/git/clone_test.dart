import 'dart:io';

import 'package:github_plus/core/git/clone.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late TestRepos repos;
  setUp(() async => repos = await TestRepos.create());
  tearDown(() => repos.dispose());

  test('refuses transports that can run commands or read local files', () async {
    for (final url in ['ext::sh -c touch% x', 'fd::0', 'file:///C:/Windows', r'C:\some\repo', '-upload-pack=x']) {
      await expectLater(
        cloneRepository(repos.git, url, p.join(repos.root.path, 'out')),
        throwsArgumentError,
        reason: url,
      );
    }
  });

  test('refuses a non-empty destination', () async {
    final target = Directory(p.join(repos.root.path, 'busy'))..createSync();
    File(p.join(target.path, 'keep.txt')).writeAsStringSync('x');
    await expectLater(cloneRepository(repos.git, 'http://127.0.0.1:1/x.git', target.path), throwsStateError);
  });
}
