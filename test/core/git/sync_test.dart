import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/git/git_errors.dart';
import 'package:github_plus/core/git/git_runner.dart';
import 'package:github_plus/core/git/progress.dart';
import 'package:github_plus/core/git/status.dart';
import 'package:github_plus/core/git/sync.dart';

import 'helpers.dart';

void main() {
  group('progress', () {
    test('parses git progress lines', () {
      final line = parseProgressLine('Receiving objects:  45% (450/1000), 1.20 MiB | 2.00 MiB/s')!;
      expect((line.title, line.percent, line.value, line.total), ('Receiving objects', 45, 450, 1000));
      expect(parseProgressLine('remote: Enumerating objects: 5, done.'), isNull);
    });

    test('weights steps into one increasing value', () {
      final progress = WeightedProgress(WeightedProgress.fetch);
      expect(progress.feed('remote: Compressing objects: 100% (10/10)')!.value, closeTo(0.1, 1e-9));
      expect(progress.feed('Receiving objects:  50% (5/10)')!.value, closeTo(0.45, 1e-9));
      expect(progress.feed('Resolving deltas: 100% (3/3)')!.value, closeTo(1.0, 1e-9));
      // Out-of-order or unknown lines never move progress backwards.
      expect(progress.feed('Receiving objects:  10% (1/10)'), isNull);
      expect(progress.feed('Something else: 50% (1/2)'), isNull);
    });
  });

  group('sync with a local bare remote', () {
    late TestRepos repos;
    setUp(() async => repos = await TestRepos.create());
    tearDown(() => repos.dispose());

    test('publishes, pushes, fetches and pulls with outcomes', () async {
      final remote = await repos.init('remote.git', bare: true);
      final a = await repos.init('a');
      await repos.commit(a, 'one');
      await repos.commit(a, 'two');
      await repos.run(a, ['remote', 'add', 'origin', remote]);

      final published = await push(repos.git, a, branch: 'main', setUpstream: true);
      expect(published.sent, 2);
      expect((await getStatus(repos.git, a)).upstream, 'origin/main');

      final b = await repos.clone(remote, 'b');
      await repos.commit(b, 'from b 1');
      await repos.commit(b, 'from b 2');
      await repos.commit(b, 'from b 3');
      final values = <double>[];
      expect((await push(repos.git, b, onProgress: (v, _) => values.add(v))).sent, 3);
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThanOrEqualTo(values[i - 1]));
      }

      expect((await fetch(repos.git, a)).received, 3);
      expect((await getStatus(repos.git, a)).behind, 3);
      expect((await pull(repos.git, a)).received, 3);
      expect((await getStatus(repos.git, a)).behind, 0);
    });

    test('a push behind the remote is classified as needing a pull', () async {
      final remote = await repos.init('remote.git', bare: true);
      final a = await repos.init('a');
      await repos.commit(a, 'one');
      await repos.run(a, ['remote', 'add', 'origin', remote]);
      await push(repos.git, a, branch: 'main', setUpstream: true);
      final b = await repos.clone(remote, 'b');
      await repos.commit(b, 'b');
      await push(repos.git, b);
      await repos.commit(a, 'a');
      final failure = await push(repos.git, a).then<Object?>((_) => null, onError: (Object e) => e);
      expect((failure as GitException).kind, GitErrorKind.pushNeedsPull);
    });
  });
}
