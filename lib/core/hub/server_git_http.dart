// Ported from GitHub Desktop (MIT): app/src/lib/git (via GitHub+ v1 src/main/hub/server/server.ts)
part of 'server.dart';

extension _GitHttp on HubServer {
  Future<Map<String, String>> _refs(String repo) async {
    final result = await git.run(['for-each-ref', '--format=%(refname) %(objectname)'], cwd: repo);
    return {
      for (final line in const LineSplitter().convert(result.stdout))
        if (line.contains(' ')) line.split(' ')[0]: line.split(' ')[1],
    };
  }

  Future<void> _recordPush(String address, String name, String path, Map<String, String> before) async {
    final after = await _refs(path);
    if (!before.keys.any((r) => r.startsWith('refs/heads/'))) {
      final first = after.keys.where((r) => r.startsWith('refs/heads/')).firstOrNull;
      final head = (await git.run(['symbolic-ref', 'HEAD'], cwd: path)).stdout.trim();
      if (first != null && !after.containsKey(head)) {
        await git.run(['symbolic-ref', '--', 'HEAD', first], cwd: path);
      }
    }
    final changed = after.entries.where((e) => before[e.key] != e.value).toList();
    if (changed.isEmpty) return;
    String? host;
    try {
      host = (await InternetAddress(address).reverse().timeout(const Duration(seconds: 1))).host;
    } catch (_) {
      /* Optional DNS cannot prevent recording accepted updates. */
    }
    final at = DateTime.now();
    final lines = changed
        .map(
          (e) => jsonEncode(
            HubPushRecord(
              at: at,
              repository: name,
              ref: e.key,
              oldSha: before[e.key] ?? '0' * e.value.length,
              newSha: e.value,
              clientAddress: address,
              clientHost: host,
            ).toJson(),
          ),
        )
        .join('\n');
    // One append per push; serialize across repositories too to avoid interleaving.
    await _locked(
      '@push-log',
      () => File(
        p.join(_settings.rootDirectory, 'push-log.jsonl'),
      ).writeAsString('$lines\n', mode: FileMode.append, flush: true),
    );
  }

  Future<void> _rpc(HttpRequest req, String name, String path, String service, bool advertise) async {
    if (_server == null) throw const HubHttpError(503, 'Hub is stopping');
    // Capture before streaming: the connection may be gone when Git finishes.
    final address = (req.connectionInfo?.remoteAddress.address ?? '').replaceFirst(RegExp(r'^::ffff:'), '');
    final encoding = req.headers.value(HttpHeaders.contentEncodingHeader);
    if (!advertise && encoding != null && encoding != 'gzip' && encoding != 'identity') {
      throw const HubHttpError(415, 'Unsupported content encoding');
    }
    final receiving = !advertise && service == 'git-receive-pack';
    final before = receiving ? await _refs(path) : <String, String>{};
    final child = await Process.start(
      git.executable,
      [
        '-c',
        'core.fsmonitor=false',
        service.substring(4),
        '--stateless-rpc',
        if (advertise) '--advertise-refs',
        '--',
        path,
      ],
      workingDirectory: path,
      environment: {'GIT_TERMINAL_PROMPT': '0', 'LC_ALL': 'C', 'LANG': 'C'},
    );
    _children.add(child);
    final stderrDone = child.stderr.drain<void>();
    final response = req.response;
    response.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/x-$service-${advertise ? 'advertisement' : 'result'}',
    );
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    if (advertise) {
      final header = '# service=$service\n';
      response.add(utf8.encode('${(utf8.encode(header).length + 4).toRadixString(16).padLeft(4, '0')}${header}0000'));
    }
    // Both pipes are drained concurrently so large packs cannot deadlock.
    Future<void> input() async {
      try {
        if (!advertise) {
          final Stream<List<int>> stream = encoding == 'gzip' ? gzip.decoder.bind(req) : req;
          await child.stdin.addStream(stream);
        }
        await child.stdin.close();
      } catch (_) {
        child.kill();
        rethrow;
      }
    }

    Future<void> output() async {
      try {
        await response.addStream(child.stdout);
      } catch (_) {
        child.kill();
        rethrow;
      }
    }

    // An HTTP disconnect must terminate the pack process even if it is waiting
    // for input; otherwise stopping the server could wait forever.
    unawaited(
      response.done.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {
          child.kill();
        },
      ),
    );
    try {
      await Future.wait([input(), output(), stderrDone]);
      final code = await child.exitCode;
      if (code != 0) throw StateError('$service exited $code');
      if (receiving) await _recordPush(address, name, path, before);
    } finally {
      child.kill();
      await child.exitCode;
      _children.remove(child);
    }
  }
}
