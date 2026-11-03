import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/expeditions/expedition.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/terms.dart';
import '../../state/app_state.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/hud.dart';

/// "파견" board: running and finished long operations for a repository.
class ExpeditionPanel extends ConsumerStatefulWidget {
  const ExpeditionPanel({super.key, this.repoId});

  /// Only this repository's expeditions; all when null.
  final String? repoId;

  @override
  ConsumerState<ExpeditionPanel> createState() => _ExpeditionPanelState();
}

class _ExpeditionPanelState extends ConsumerState<ExpeditionPanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Elapsed/remaining labels tick once a second while something runs.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (ref.read(expeditionsProvider).any((e) => e.isRunning) && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = L10n.of(context);
    final items = ref
        .watch(expeditionsProvider)
        .where((e) => widget.repoId == null || e.repoId == widget.repoId)
        .toList();
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_rounded, size: 40, color: c.muted),
              const SizedBox(height: Space.md),
              SizedBox(
                width: 420,
                child: Text(
                  l.expeditionsEmpty(Terms.of(context).push, Terms.of(context).pull, Terms.of(context).clone),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(Space.xl),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.md),
      itemBuilder: (_, i) => ExpeditionCard(expedition: items[i]),
    );
  }
}

class ExpeditionCard extends ConsumerWidget {
  const ExpeditionCard({super.key, required this.expedition});
  final Expedition expedition;

  static IconData iconFor(ExpeditionKind kind) => switch (kind) {
    ExpeditionKind.clone => Icons.content_copy_rounded,
    ExpeditionKind.fetch => Icons.sync_rounded,
    ExpeditionKind.pull => Icons.download_rounded,
    ExpeditionKind.push => Icons.upload_rounded,
    ExpeditionKind.publish || ExpeditionKind.hubPublish => Icons.rocket_launch_rounded,
    ExpeditionKind.checkout => Icons.account_tree_rounded,
    ExpeditionKind.rebase => Icons.low_priority_rounded,
    ExpeditionKind.submodules => Icons.widgets_rounded,
    ExpeditionKind.backup => Icons.backup_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = L10n.of(context);
    final e = expedition;
    final now = DateTime.now();
    final (statusLabel, tone) = switch (e.status) {
      ExpeditionStatus.running => (l.expeditionRunning, HudTone.attention),
      ExpeditionStatus.succeeded => (l.expeditionDone, HudTone.good),
      ExpeditionStatus.failed => (l.expeditionFailed, HudTone.danger),
    };
    final color = tone.color(c);
    final remaining = e.remaining(now);
    final highlight = !e.isRunning && !e.seen;

    return AnimatedContainer(
      duration: context.motion(Motion.normal),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: highlight ? color : c.border, width: highlight ? 1.5 : 1),
        boxShadow: highlight ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 14)] : null,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(iconFor(e.kind), color: color),
          ),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: c.text)),
                    ),
                    Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    l.expeditionTo(e.destination),
                    l.expeditionElapsed(formatDuration(context, e.elapsed(now))),
                    if (remaining != null) l.expeditionRemaining(formatDuration(context, remaining)),
                  ].join('  ·  '),
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
                const SizedBox(height: Space.sm),
                if (e.isRunning && e.progress == 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(minHeight: 6, color: color, backgroundColor: c.track),
                  )
                else
                  GaugeBar(fraction: e.progress, color: color, height: 6, glow: highlight),
                if (e.stage != null && e.isRunning) ...[
                  const SizedBox(height: Space.xs),
                  Text(e.stage!, style: TextStyle(fontSize: 11.5, color: c.muted)),
                ],
                if (!e.isRunning && e.seen && (e.result ?? e.error) != null) ...[
                  const SizedBox(height: Space.sm),
                  SelectableText(
                    e.result ?? e.error!,
                    maxLines: 4,
                    style: TextStyle(fontSize: 12.5, color: e.error != null ? c.danger : c.text),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Space.lg),
          if (highlight)
            FilledButton(
              onPressed: () => ref.read(expeditionsProvider.notifier).collect(e.id),
              style: FilledButton.styleFrom(backgroundColor: color),
              child: Text(l.expeditionCollect),
            )
          else if (!e.isRunning)
            IconButton(
              tooltip: l.expeditionDismiss,
              onPressed: () => ref.read(expeditionsProvider.notifier).dismiss(e.id),
              icon: Icon(Icons.close_rounded, color: c.muted, size: 18),
            ),
        ],
      ),
    );
  }
}
