import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/models/status.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../state/repo_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/hud.dart';
import '../expeditions/expedition_panel.dart';
import 'repo_banner.dart';

enum HomeTab { changes, history, expeditions }

/// Selected repository: banner, HUD, goal bars and the tabbed workspace.
class RepoHome extends ConsumerStatefulWidget {
  const RepoHome({super.key, required this.repo});
  final RepositoryInfo repo;

  @override
  ConsumerState<RepoHome> createState() => _RepoHomeState();
}

class _RepoHomeState extends ConsumerState<RepoHome> {
  var _tab = HomeTab.changes;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(repoStatusProvider(widget.repo.id));
    final status = statusAsync.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepoBanner(
          repo: widget.repo,
          status: status,
          onCommitRequested: () => setState(() => _tab = HomeTab.changes),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xxl, Space.sm, Space.xxl, Space.lg),
          child: status == null
              ? (statusAsync.hasError
                    ? Text('${statusAsync.error}', style: TextStyle(color: context.colors.danger))
                    : const LinearProgressIndicator(minHeight: 2))
              : _HudPanel(repoId: widget.repo.id, status: status),
        ),
        _TabBar(
          tab: _tab,
          onChanged: (tab) => setState(() => _tab = tab),
          changes: status?.files.length ?? 0,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: context.motion(Motion.fast),
            child: switch (_tab) {
              HomeTab.changes => _Placeholder(key: const ValueKey('changes'), text: L10n.of(context).tabChanges),
              HomeTab.history => _Placeholder(key: const ValueKey('history'), text: L10n.of(context).tabHistory),
              HomeTab.expeditions => ExpeditionPanel(key: const ValueKey('exp'), repoId: widget.repo.id),
            },
          ),
        ),
      ],
    );
  }
}

/// HUD stats plus the donation-goal style bars.
class _HudPanel extends ConsumerWidget {
  const _HudPanel({required this.repoId, required this.status});
  final String repoId;
  final RepoStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final settings = ref.watch(settingsProvider);
    final today = ref.watch(todayCommitsProvider(repoId)).value ?? 0;
    final toPush = status.toPush;
    final conflicts = status.conflictCount;

    final stats = [
      HudStat(
        icon: Icons.edit_note_rounded,
        label: l.hudChanges,
        value: status.files.length,
        tone: status.files.isEmpty ? HudTone.neutral : HudTone.accent,
        tooltip: l.hudChangesTip,
      ),
      HudStat(
        icon: Icons.upload_rounded,
        label: l.hudToPush,
        value: toPush,
        max: settings.pushGoal,
        tone: toPush == 0 ? HudTone.good : (toPush >= settings.pushGoal ? HudTone.danger : HudTone.attention),
        tooltip: l.hudToPushTip,
      ),
      HudStat(
        icon: Icons.download_rounded,
        label: l.hudToPull,
        value: status.behind,
        tone: status.behind == 0 ? HudTone.good : HudTone.attention,
        tooltip: l.hudToPullTip,
      ),
      HudStat(
        icon: Icons.inventory_2_rounded,
        label: l.hudStashes,
        value: status.stashCount,
        tone: HudTone.neutral,
        tooltip: l.hudStashesTip,
      ),
      HudStat(
        icon: Icons.bolt_rounded,
        label: l.hudConflicts,
        value: conflicts,
        tone: conflicts == 0 ? HudTone.good : HudTone.danger,
        tooltip: l.hudConflictsTip,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) const SizedBox(width: Space.sm),
              Expanded(child: stats[i]),
            ],
          ],
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            Expanded(
              child: GoalBar(
                title: l.goalDailyCommits,
                current: today,
                target: settings.dailyCommitGoal,
                tone: HudTone.good,
                caption: today >= settings.dailyCommitGoal
                    ? l.goalReached
                    : l.goalRemaining(settings.dailyCommitGoal - today),
              ),
            ),
            const SizedBox(width: Space.xl),
            Expanded(
              child: GoalBar(
                title: l.goalPush,
                current: toPush,
                target: settings.pushGoal,
                tone: toPush >= settings.pushGoal ? HudTone.danger : HudTone.attention,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TabBar extends ConsumerWidget {
  const _TabBar({required this.tab, required this.onChanged, required this.changes});
  final HomeTab tab;
  final ValueChanged<HomeTab> onChanged;
  final int changes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = L10n.of(context);
    final running = ref.watch(expeditionsProvider).where((e) => e.isRunning).length;
    final unseen = ref.watch(unseenExpeditionsProvider);
    Widget item(HomeTab value, String label, {int? badge, Color? badgeColor}) {
      final selected = tab == value;
      return InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm + 2),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: selected ? c.accent : Colors.transparent, width: 2)),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? c.text : c.muted,
                ),
              ),
              if (badge != null && badge > 0) ...[
                const SizedBox(width: Space.xs + 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: badgeColor ?? c.raised, borderRadius: BorderRadius.circular(10)),
                  child: Text('$badge', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: Row(
        children: [
          item(HomeTab.changes, l.tabChanges, badge: changes, badgeColor: c.accent),
          item(HomeTab.history, l.tabHistory),
          item(
            HomeTab.expeditions,
            l.tabExpeditions,
            badge: running + unseen,
            badgeColor: running > 0 ? c.warning : c.success,
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(text, style: TextStyle(color: context.colors.muted)));
}
