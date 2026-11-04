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
List<GraphRow> layoutGraph(List<Commit> commits) => throw UnimplementedError('G2');
