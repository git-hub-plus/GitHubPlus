/// A long-running operation shown like an "expedition" (원신 파견): it is sent
/// to a destination, progresses on its own and reports a result when done.
enum ExpeditionKind { clone, fetch, pull, push, publish, checkout, rebase, submodules, hubPublish, backup }

enum ExpeditionStatus { running, succeeded, failed }

class Expedition {
  const Expedition({
    required this.id,
    required this.kind,
    required this.title,
    required this.destination,
    required this.startedAt,
    this.repoId,
    this.progress = 0,
    this.stage,
    this.status = ExpeditionStatus.running,
    this.finishedAt,
    this.result,
    this.error,
    this.seen = false,
  });

  final String id;
  final ExpeditionKind kind;

  /// e.g. "origin에 푸시", "team-api 복제".
  final String title;

  /// Where it went: remote name, hub name or URL host.
  final String destination;
  final String? repoId;

  /// 0..1 (indeterminate while 0 and running).
  final double progress;

  /// Current git phase, e.g. "Receiving objects".
  final String? stage;
  final ExpeditionStatus status;
  final DateTime startedAt;
  final DateTime? finishedAt;

  /// Reward summary, e.g. "커밋 3개 올림".
  final String? result;
  final String? error;

  /// Whether the user opened the finished result ("보상 수령").
  final bool seen;

  bool get isRunning => status == ExpeditionStatus.running;

  Duration elapsed(DateTime now) => (finishedAt ?? now).difference(startedAt);

  /// Remaining time estimated from the average rate so far; null if unknown.
  Duration? remaining(DateTime now) {
    if (!isRunning || progress <= 0.02 || progress >= 1) return null;
    final spent = elapsed(now).inMilliseconds;
    if (spent < 1500) return null;
    return Duration(milliseconds: (spent / progress * (1 - progress)).round());
  }

  Expedition copyWith({
    double? progress,
    String? stage,
    ExpeditionStatus? status,
    DateTime? finishedAt,
    String? result,
    String? error,
    bool? seen,
  }) => Expedition(
    id: id,
    kind: kind,
    title: title,
    destination: destination,
    repoId: repoId,
    startedAt: startedAt,
    progress: progress ?? this.progress,
    stage: stage ?? this.stage,
    status: status ?? this.status,
    finishedAt: finishedAt ?? this.finishedAt,
    result: result ?? this.result,
    error: error ?? this.error,
    seen: seen ?? this.seen,
  );
}
