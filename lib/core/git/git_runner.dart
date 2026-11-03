import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'git_errors.dart';

/// Extra `-c` config and environment for a git command (e.g. an Authorization
/// header for github.com, or disabling credential prompts for hub remotes).
/// The values never appear in logs or [GitException] messages.
typedef GitAuthProvider = GitAuthExtras? Function(List<String> args, String cwd);

class GitAuthExtras {
  const GitAuthExtras({this.configArgs = const [], this.environment = const {}});
  final List<String> configArgs;
  final Map<String, String> environment;
}

class GitResult {
  const GitResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.error,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  /// Parsed error when the exit code was not a success code.
  final GitError? error;
}

/// Thrown when git fails unexpectedly. Carries the parsed error and stderr.
class GitException implements Exception {
  GitException(this.args, this.result) : kind = classifyGitError(result.error);

  final List<String> args;
  final GitResult result;
  final GitErrorKind kind;

  @override
  String toString() {
    final tail = redactCredentials(result.stderr.trim());
    return 'git ${redactCredentials(args.join(' '))} failed (${result.exitCode})'
        '${tail.isEmpty ? '' : ': ${tail.length > 500 ? tail.substring(tail.length - 500) : tail}'}';
  }
}

final _urlCredentials = RegExp(r'(\b[a-z][a-z0-9+.-]*://)[^/\s@]+@', caseSensitive: false);

/// Hides `user:token@` in URLs so messages and logs never show credentials.
String redactCredentials(String text) => text.replaceAllMapped(_urlCredentials, (m) => '${m[1]}***@');

const _lenientUtf8 = Utf8Decoder(allowMalformed: true);

/// Runs git. Prefers the portable git shipped next to the executable
/// (`git/cmd/git.exe`), falling back to `git` on PATH.
class GitRunner {
  GitRunner({required this.executable});

  /// Path or command name used to start git.
  final String executable;

  final List<GitAuthProvider> _authProviders = [];

  static String locateExecutable({String? appDirectory}) {
    final directory = appDirectory ?? p.dirname(Platform.resolvedExecutable);
    final candidates = [
      p.join(directory, 'git', 'cmd', 'git.exe'),
      // Development only: `flutter test` / `dart run` from the project root.
      if (!const bool.fromEnvironment('dart.vm.product'))
        p.join(Directory.current.path, 'third_party', 'git', 'cmd', 'git.exe'),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    return _findOnPath() ?? 'git';
  }

  /// Absolute git from PATH. A bare `git` would let Windows try the current
  /// directory first, where a planted git.exe could run instead.
  static String? _findOnPath() {
    final separator = Platform.isWindows ? ';' : ':';
    final name = Platform.isWindows ? 'git.exe' : 'git';
    for (final entry in (Platform.environment['PATH'] ?? '').split(separator)) {
      final dir = entry.trim().replaceAll('"', '');
      if (dir.isEmpty || !p.isAbsolute(dir)) continue;
      final candidate = p.join(dir, name);
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  /// Registers a provider; returns a function that unregisters it.
  void Function() registerAuthProvider(GitAuthProvider provider) {
    _authProviders.add(provider);
    return () => _authProviders.remove(provider);
  }

  static const _baseEnvironment = {
    // Never block on a terminal prompt; credential helpers may still run.
    'GIT_TERMINAL_PROMPT': '0',
    'TERM': 'dumb',
    // Machine-readable, English output regardless of the user's locale.
    'LC_ALL': 'C',
    'LANG': 'C',
  };

  // Always applied: unquoted UTF-8 paths in output, and no fsmonitor hook.
  // A repository's own .git/config could set core.fsmonitor to a command that
  // would run as soon as GitHub+ reads the status of a folder someone handed us.
  static const _baseConfig = [
    '-c', 'core.quotepath=false',
    '-c', 'i18n.logOutputEncoding=utf-8',
    '-c', 'core.fsmonitor=false',
  ];

  /// Runs `git <args>` in [cwd]. Throws [GitException] unless the exit code is
  /// in [successExitCodes] or the parsed error is in [expectedErrors].
  Future<GitResult> run(
    List<String> args, {
    required String cwd,
    Set<int> successExitCodes = const {0},
    Set<GitError> expectedErrors = const {},
    String? stdin,
    List<int>? stdinBytes,
    Map<String, String> environment = const {},
    void Function(String line)? onStderrLine,
  }) async {
    final extraConfig = <String>[];
    final extraEnvironment = <String, String>{};
    for (final provider in _authProviders) {
      final extras = provider(args, cwd);
      if (extras == null) continue;
      extraConfig.addAll(extras.configArgs);
      extraEnvironment.addAll(extras.environment);
    }

    final process = await Process.start(
      executable,
      [..._baseConfig, ...extraConfig, ...args],
      workingDirectory: cwd,
      environment: {..._baseEnvironment, ...extraEnvironment, ...environment},
    );

    final stdoutFuture = process.stdout.transform(_lenientUtf8).join();
    final stderrBuffer = StringBuffer();
    final stderrDone = process.stderr
        .transform(_lenientUtf8)
        .transform(const LineSplitter())
        .listen((line) {
          stderrBuffer.writeln(line);
          onStderrLine?.call(line);
        })
        .asFuture<void>();

    if (stdinBytes != null) {
      process.stdin.add(stdinBytes);
    } else if (stdin != null) {
      process.stdin.write(stdin);
    }
    await process.stdin.close();

    final exitCode = await process.exitCode;
    final stdout = await stdoutFuture;
    await stderrDone;
    final stderr = stderrBuffer.toString();

    final success = successExitCodes.contains(exitCode);
    final error = success ? null : (parseGitError(stderr) ?? parseGitError(stdout));
    final result = GitResult(exitCode: exitCode, stdout: stdout, stderr: stderr, error: error);
    if (success || (error != null && expectedErrors.contains(error))) return result;
    // `args` (not the provider config) is reported, so secrets never leak.
    throw GitException(args, result);
  }

  /// Runs git and returns raw stdout bytes (binary files, images).
  Future<List<int>> runBytes(List<String> args, {required String cwd}) async {
    final result = await Process.run(
      executable,
      [..._baseConfig, ...args],
      workingDirectory: cwd,
      environment: _baseEnvironment,
      stdoutEncoding: null,
      stderrEncoding: const Utf8Codec(allowMalformed: true),
    );
    if (result.exitCode != 0) {
      throw GitException(
        args,
        GitResult(
          exitCode: result.exitCode,
          stdout: '',
          stderr: result.stderr as String,
          error: parseGitError(result.stderr as String),
        ),
      );
    }
    return result.stdout as List<int>;
  }
}
