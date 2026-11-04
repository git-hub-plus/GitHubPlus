// EXTENSION POINT (owner: worker U2). Public name and constructor are fixed.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/git/git_runner.dart';
import '../../core/history/graph.dart';
import '../../core/models/app_models.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/terms.dart';
import '../../state/history_state.dart';
import '../../state/repo_state.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/diff_view.dart';
import '../../ui/widgets/feedback.dart';

const _rowHeight = 44.0;
const _laneWidth = 16.0;

class HistoryView extends ConsumerStatefulWidget {
  const HistoryView({super.key, required this.repo});
  final RepositoryInfo repo;

  @override
  ConsumerState<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends ConsumerState<HistoryView> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _listFocus = FocusNode();
  double _fraction = .55;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < _rowHeight * 3) {
      unawaited(ref.read(historyProvider(widget.repo).notifier).loadMore());
    }
  }

  void _reveal(HistoryState state) {
    if (!_scroll.hasClients) return;
    final visible = state.visibleIndices;
    final index = visible.indexWhere((i) => state.commits[i].sha == state.selected?.sha);
    if (index < 0) return;
    final top = index * _rowHeight;
    final position = _scroll.position;
    if (top < position.pixels || top + _rowHeight > position.pixels + position.viewportDimension) {
      _scroll.animateTo(
        top.clamp(0, position.maxScrollExtent),
        duration: context.motion(Motion.normal),
        curve: Motion.curve,
      );
    }
  }

  void _move(int delta) {
    final state = ref.read(historyProvider(widget.repo));
    final indices = state.visibleIndices;
    if (indices.isEmpty) return;
    final current = indices.indexWhere((i) => state.commits[i].sha == state.selected?.sha);
    final next = current < 0 ? 0 : (current + delta).clamp(0, indices.length - 1);
    ref.read(historyProvider(widget.repo).notifier).select(state.commits[indices[next]]);
    if (next == indices.length - 1) unawaited(ref.read(historyProvider(widget.repo).notifier).loadMore());
  }

  @override
  Widget build(BuildContext context) {
    final provider = historyProvider(widget.repo);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final l = L10n.of(context);
    final t = Terms.of(context);
    final c = context.colors;
    final branch = ref.watch(repoStatusProvider(widget.repo.id)).value?.currentBranch;
    ref.listen(provider, (old, next) {
      if (_search.text != next.query) {
        _search.value = TextEditingValue(
          text: next.query,
          selection: TextSelection.collapsed(offset: next.query.length),
        );
      }
      if (old?.selected?.sha != next.selected?.sha) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _reveal(next);
        });
      }
    });
    final indices = state.visibleIndices;
    final graphWidth = math.max(
      40.0,
      state.graph.fold<int>(0, (n, r) => math.max(n, r.laneCount)) * _laneWidth + Space.lg,
    );
    final palette = graphPalette(c);
    final list = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l.historyCurrent(t.branch)), tooltip: branch),
                    ButtonSegment(value: true, label: Text(l.historyAll(t.branch))),
                  ],
                  selected: {state.all},
                  onSelectionChanged: (s) => controller.refresh(all: s.first),
                ),
              ),
              const SizedBox(height: Space.sm),
              TextField(
                key: const Key('history-search'),
                controller: _search,
                decoration: InputDecoration(hintText: l.historySearch, prefixIcon: const Icon(Icons.search)),
                onChanged: controller.filter,
              ),
            ],
          ),
        ),
        if (state.loading) const LinearProgressIndicator(),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Column(
              children: [
                SelectableText(state.error!, style: TextStyle(color: c.danger)),
                TextButton(
                  onPressed: () => state.commits.isEmpty ? controller.refresh() : controller.loadMore(),
                  child: Text(l.historyRetry),
                ),
              ],
            ),
          ),
        Expanded(
          child: Focus(
            focusNode: _listFocus,
            onKeyEvent: (_, event) {
              if (event is KeyUpEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                _move(1);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                _move(-1);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: state.commits.isEmpty && !state.loading && state.error == null
                ? Center(
                    child: Text(l.historyEmpty(t.commitUnit), style: TextStyle(color: c.muted)),
                  )
                : indices.isEmpty && !state.loading
                ? Center(
                    child: Text(l.historyNoResults, style: TextStyle(color: c.muted)),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) => Scrollbar(
                      controller: _scroll,
                      child: ListView.builder(
                        key: const Key('history-list'),
                        controller: _scroll,
                        itemExtent: _rowHeight,
                        itemCount: indices.length + (state.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == indices.length) {
                            return TextButton(
                              onPressed: state.loading ? null : controller.loadMore,
                              child: Text(l.historyLoadMore),
                            );
                          }
                          final i = indices[index];
                          final commit = state.commits[i];
                          return Semantics(
                            selected: state.selected?.sha == commit.sha,
                            child: Material(
                              color: state.selected?.sha == commit.sha ? c.accentSoft : c.surface,
                              child: InkWell(
                                key: ValueKey('commit-${commit.sha}'),
                                onTap: () {
                                  controller.select(commit);
                                  _listFocus.requestFocus();
                                },
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: math.min(graphWidth, constraints.maxWidth * .2),
                                      height: _rowHeight,
                                      child: ClipRect(
                                        child: CustomPaint(
                                          painter: CommitGraphPainter(
                                            row: state.graph[i],
                                            previous: i > 0 ? state.graph[i - 1] : null,
                                            palette: palette,
                                            background: state.selected?.sha == commit.sha ? c.accentSoft : c.surface,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        commit.summary,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    if (commit.refs.any((r) => r != 'HEAD'))
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: constraints.maxWidth * (constraints.maxWidth > 450 ? .35 : .25),
                                        ),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              for (final name in commit.refs.where((r) => r != 'HEAD'))
                                                Padding(
                                                  padding: const EdgeInsets.only(left: Space.xs),
                                                  child: _RefBadge(name: name, current: name == branch),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    SizedBox(
                                      width: constraints.maxWidth > 600 ? 90 : 56,
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: Space.sm),
                                        child: Text(
                                          commit.author.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: c.muted, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                                      child: Text(
                                        formatAgo(context, commit.author.date),
                                        style: TextStyle(color: c.muted, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
    final details = _CommitDetails(repo: widget.repo, state: state);
    return Material(
      color: c.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return Column(
              children: [
                Expanded(child: list),
                const Divider(),
                Expanded(child: details),
              ],
            );
          }
          final width = (constraints.maxWidth * _fraction).clamp(300.0, constraints.maxWidth - 300.0);
          return Row(
            children: [
              SizedBox(width: width, child: list),
              Semantics(
                label: l.historyResize,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    key: const Key('history-divider'),
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (d) =>
                        setState(() => _fraction = ((width + d.delta.dx) / constraints.maxWidth).clamp(.2, .8)),
                    child: Container(
                      width: Space.sm,
                      color: c.background,
                      alignment: Alignment.center,
                      child: Container(width: 1, color: c.border),
                    ),
                  ),
                ),
              ),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _RefBadge extends StatelessWidget {
  const _RefBadge({required this.name, required this.current});
  final String name;
  final bool current;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tag = name.startsWith('tag: ');
    return Tooltip(
      message: name,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 130),
        padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xs),
        decoration: BoxDecoration(
          color: current ? c.accentSoft : c.raised,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: current ? c.accent : c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tag
                  ? Icons.sell_outlined
                  : name.startsWith('origin/')
                  ? Icons.cloud_outlined
                  : Icons.account_tree_outlined,
              size: 12,
              color: current ? c.accent : c.muted,
            ),
            const SizedBox(width: Space.xs),
            Flexible(
              child: Text(
                tag ? name.substring(5) : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: c.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommitDetails extends ConsumerWidget {
  const _CommitDetails({required this.repo, required this.state});
  final RepositoryInfo repo;
  final HistoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final c = context.colors;
    final commit = state.selected;
    if (commit == null) {
      return Center(
        child: Text(l.historySelect, style: TextStyle(color: c.muted)),
      );
    }
    final files = ref.watch(historyFilesProvider((path: repo.path, sha: commit.sha)));
    final file = state.file;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(commit.summary, style: Theme.of(context).textTheme.titleLarge),
                if (commit.body.trim().isNotEmpty) ...[
                  const SizedBox(height: Space.sm),
                  SelectableText(commit.body.trim()),
                ],
                const SizedBox(height: Space.md),
                SelectableText(
                  '${commit.author.name} <${commit.author.email}>',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
                Text(
                  '${MaterialLocalizations.of(context).formatFullDate(commit.author.date.toLocal())} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(commit.author.date.toLocal()), alwaysUse24HourFormat: true)}',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        commit.sha,
                        style: TextStyle(color: c.muted, fontFamily: 'Consolas', fontSize: 11),
                      ),
                    ),
                    IconButton(
                      tooltip: l.historyCopySha,
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: commit.sha));
                        if (context.mounted) showGhpToast(context, l.historyCopied);
                      },
                    ),
                  ],
                ),
                if (commit.parentShas.isNotEmpty)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Space.xs,
                    children: [
                      Text(
                        l.historyParents(Terms.of(context).commitUnit),
                        style: TextStyle(color: c.muted, fontSize: 12),
                      ),
                      for (final sha in commit.parentShas)
                        TextButton(
                          key: ValueKey('parent-$sha'),
                          onPressed: () => ref.read(historyProvider(repo).notifier).selectSha(sha),
                          child: Text(
                            sha.substring(0, math.min(7, sha.length)),
                            style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                const Divider(),
                files.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => _HistoryError(
                    error: error,
                    retry: () => ref.invalidate(historyFilesProvider((path: repo.path, sha: commit.sha))),
                  ),
                  data: (files) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.historyFiles(files.length), style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (files.isEmpty) Text(l.historyNoFiles, style: TextStyle(color: c.muted)),
                      for (final f in files)
                        ListTile(
                          key: ValueKey('history-file-${f.path}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          selected: file?.path == f.path,
                          leading: Icon(Icons.description_outlined, size: 16, color: c.muted),
                          title: Text(f.path, style: const TextStyle(fontSize: 12)),
                          onTap: () => ref.read(historyProvider(repo).notifier).selectFile(f),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        Expanded(
          flex: 3,
          child: file == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: Text(l.historySelectFile, style: TextStyle(color: c.muted)),
                  ),
                )
              : ref
                    .watch(historyDiffProvider((path: repo.path, sha: commit.sha, file: file)))
                    .when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, _) => _HistoryError(
                        error: error,
                        retry: () =>
                            ref.invalidate(historyDiffProvider((path: repo.path, sha: commit.sha, file: file))),
                      ),
                      data: (diff) => FileDiffView(key: ValueKey('${commit.sha}:${file.path}'), diff: diff),
                    ),
        ),
      ],
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(Space.md),
    child: Column(
      children: [
        SelectableText(redactCredentials(error.toString()), style: TextStyle(color: context.colors.danger)),
        TextButton(onPressed: retry, child: Text(L10n.of(context).historyRetry)),
      ],
    ),
  );
}

/// Eight theme-derived colors. All strokes contrast with both surface themes.
List<Color> graphPalette(GhpColors c) => [
  c.accent,
  c.success,
  c.warning,
  c.danger,
  Color.lerp(c.accent, c.text, .3)!,
  Color.lerp(c.success, c.text, .3)!,
  Color.lerp(c.warning, c.text, .3)!,
  Color.lerp(c.danger, c.text, .3)!,
];

/// Each edge spans two half-rows so adjacent painters meet exactly at their boundary.
class CommitGraphPainter extends CustomPainter {
  CommitGraphPainter({required this.row, required this.previous, required this.palette, required this.background});
  final GraphRow row;
  final GraphRow? previous;
  final List<Color> palette;
  final Color background;
  double _x(int lane) => Space.sm + _laneWidth * lane;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    void segment(({int from, int to, int color}) edge, double top) {
      paint.color = palette[edge.color % palette.length];
      final path = Path()..moveTo(_x(edge.from), top);
      path.cubicTo(
        _x(edge.from),
        top + size.height * .5,
        _x(edge.to),
        top + size.height * .5,
        _x(edge.to),
        top + size.height,
      );
      canvas.drawPath(path, paint);
    }

    for (final edge in previous?.edges ?? <({int from, int to, int color})>[]) {
      segment(edge, -size.height / 2);
    }
    for (final edge in row.edges) {
      segment(edge, size.height / 2);
    }
    final color =
        row.edges.where((e) => e.from == row.lane).firstOrNull?.color ??
        previous?.edges.where((e) => e.to == row.lane).firstOrNull?.color ??
        row.lane;
    canvas.drawCircle(Offset(_x(row.lane), size.height / 2), 5, Paint()..color = background);
    canvas.drawCircle(Offset(_x(row.lane), size.height / 2), 4, Paint()..color = palette[color % palette.length]);
  }

  @override
  bool shouldRepaint(CommitGraphPainter oldDelegate) =>
      oldDelegate.row != row ||
      oldDelegate.previous != previous ||
      oldDelegate.background != background ||
      !listEqualsColors(oldDelegate.palette, palette);
  static bool listEqualsColors(List<Color> a, List<Color> b) =>
      a.length == b.length && Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
}
