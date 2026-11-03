import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/expeditions/expedition.dart';

void main() {
  final start = DateTime(2026, 11, 3, 12);
  Expedition at(double progress) => Expedition(
    id: '1',
    kind: ExpeditionKind.push,
    title: 'push',
    destination: 'origin',
    startedAt: start,
    progress: progress,
  );

  test('estimates remaining time from the average rate', () {
    final remaining = at(0.25).remaining(start.add(const Duration(seconds: 10)));
    expect(remaining, const Duration(seconds: 30));
  });

  test('does not guess too early or without progress', () {
    expect(at(0.5).remaining(start.add(const Duration(milliseconds: 500))), isNull);
    expect(at(0).remaining(start.add(const Duration(seconds: 10))), isNull);
  });

  test('finished expeditions report elapsed time until they ended', () {
    final done = at(1).copyWith(
      status: ExpeditionStatus.succeeded,
      finishedAt: start.add(const Duration(seconds: 7)),
    );
    expect(done.elapsed(start.add(const Duration(minutes: 5))), const Duration(seconds: 7));
    expect(done.remaining(start.add(const Duration(minutes: 5))), isNull);
  });
}
