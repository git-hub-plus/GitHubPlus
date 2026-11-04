// CONTRACT (owner: worker G2). Signatures are fixed; G2 implements the bodies.
import '../models/commit.dart';

/// One row of the history graph: the commit's lane and the lines to draw
/// from this row to the next one.
class GraphRow {
  const GraphRow({required this.lane, required this.edges, required this.laneCount});

  /// Column of this commit's dot (0 = leftmost).
  final int lane;

  /// Segments from this row (top) to the next row (bottom): `from` lane at
  /// this row to `to` lane at the next row. Includes pass-through lanes.
  final List<({int from, int to, int color})> edges;

  /// Lanes in use on this row (for sizing the graph column).
  final int laneCount;
}

/// Lays out [commits] (newest first, topo order, as from `getCommits`) into
/// lanes like `git log --graph`: first parents keep the lane, merges branch
/// out, lanes are reused once free. Commits whose parents are not in the list
/// (paging) just end their lane. `color` is a stable small index per lane run.
List<GraphRow> layoutGraph(List<Commit> commits) {
  final remaining = commits.map((c) => c.sha).toSet();
  final lanes = <({String sha, int color})?>[];
  var nextColor = 0;
  int allocate(String sha) {
    var index = lanes.indexOf(null);
    if (index < 0) {
      index = lanes.length;
      lanes.add(null);
    }
    lanes[index] = (sha: sha, color: nextColor++ % 8);
    return index;
  }

  final rows = <GraphRow>[];
  for (final commit in commits) {
    final matches = [
      for (var i = 0; i < lanes.length; i++)
        if (lanes[i]?.sha == commit.sha) i,
    ];
    final lane = matches.isEmpty ? allocate(commit.sha) : matches.first;
    final color = lanes[lane]!.color;
    final before = List.of(lanes);
    remaining.remove(commit.sha);
    for (final i in matches) {
      lanes[i] = null;
    }
    lanes[lane] = null;
    final parents = commit.parentShas.where(remaining.contains).toSet().toList();
    final edges = <({int from, int to, int color})>[];
    for (var i = 0; i < before.length; i++) {
      if (before[i] != null && before[i]!.sha != commit.sha) edges.add((from: i, to: i, color: before[i]!.color));
    }
    for (var p = 0; p < parents.length; p++) {
      final parent = parents[p];
      var target = lanes.indexWhere((l) => l?.sha == parent);
      if (target < 0) {
        if (p == 0) {
          target = lane;
          lanes[target] = (sha: parent, color: color);
        } else {
          target = allocate(parent);
        }
      }
      // A converging first-parent line keeps its child trunk's color until
      // it reaches the shared parent dot on the next row.
      edges.add((from: lane, to: target, color: p == 0 ? color : lanes[target]!.color));
    }
    // Multiple child lanes converge at this dot. All point to the same next trunk.
    for (final other in matches.skip(1)) {
      if (parents.isNotEmpty) {
        final target = lanes.indexWhere((l) => l?.sha == parents.first);
        edges.add((from: other, to: target, color: before[other]!.color));
      }
    }
    while (lanes.isNotEmpty && lanes.last == null) {
      lanes.removeLast();
    }
    final width = before.length > lanes.length ? before.length : lanes.length;
    rows.add(GraphRow(lane: lane, edges: edges, laneCount: width));
  }
  return rows;
}
