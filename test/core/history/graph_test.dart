import 'package:flutter_test/flutter_test.dart';
import 'package:github_plus/core/history/graph.dart';
import 'package:github_plus/core/models/commit.dart';

Commit c(String sha, List<String> parents) {
  final identity = CommitIdentity(name: '', email: '', date: DateTime.utc(2026), tzOffsetMinutes: 0);
  return Commit(sha: sha, summary: '', body: '', author: identity, committer: identity, parentShas: parents);
}

void main() {
  test('empty and linear history, stable trunk color', () {
    expect(layoutGraph([]), isEmpty);
    final rows = layoutGraph([
      c('c', ['b']),
      c('b', ['a']),
      c('a', []),
    ]);
    expect(rows.map((r) => r.lane), [0, 0, 0]);
    expect(rows.map((r) => r.laneCount), [1, 1, 1]);
    expect(rows[0].edges, [(from: 0, to: 0, color: 0)]);
    expect(rows[1].edges, rows[0].edges);
    expect(rows.last.edges, isEmpty);
  });
  test('merge branches pass through and converge, then one trunk', () {
    final rows = layoutGraph([
      c('m', ['a', 'b']),
      c('a', ['root']),
      c('b', ['root']),
      c('root', ['old']),
      c('old', []),
    ]);
    expect(rows.map((r) => r.lane), [0, 0, 1, 0, 0]);
    expect(rows[0].edges.map((e) => (e.from, e.to)), [(0, 0), (0, 1)]);
    expect(rows[1].edges.map((e) => (e.from, e.to)), contains((1, 1)));
    expect(rows[2].edges.map((e) => (e.from, e.to)), contains((1, 0)));
    expect(rows[2].edges.firstWhere((e) => e.from == 1).color, rows[0].edges[1].color);
    expect(rows.last.laneCount, 1);
    expect(rows[0].edges[0].color, rows[3].edges.single.color);
  });
  test('octopus has three lanes and stable distinct branch colors', () {
    final rows = layoutGraph([
      c('m', ['a', 'b', 'c']),
      c('a', ['r']),
      c('b', ['r']),
      c('c', ['r']),
      c('r', []),
    ]);
    expect(rows.first.laneCount, 3);
    expect(rows.first.edges.map((e) => e.to), [0, 1, 2]);
    expect(rows.first.edges.map((e) => e.color).toSet().length, 3);
    expect(rows[1].edges.map((e) => (e.from, e.to)), containsAll([(1, 1), (2, 2)]));
    expect(rows.last.edges, isEmpty);
  });
  test('outside parents end lanes at page boundary', () {
    final rows = layoutGraph([
      c('m', ['outside', 'b']),
      c('b', ['older']),
    ]);
    expect(rows.first.edges.map((e) => e.to), [0]);
    expect(rows.last.edges, isEmpty);
    expect(rows.every((r) => r.laneCount == 1), true);
  });
  test('released lanes are reused across merges', () {
    final rows = layoutGraph([
      c('m', ['a', 'b']),
      c('b', []),
      c('a', ['x', 'y']),
      c('y', []),
      c('x', []),
    ]);
    expect(rows.map((r) => r.lane), [0, 1, 0, 1, 0]);
    expect(rows.every((r) => r.laneCount <= 2), true);
    expect(rows[2].edges.map((e) => e.to), [0, 1]);
    expect(rows[0].edges[1].color, isNot(rows[2].edges[1].color));
  });
}
