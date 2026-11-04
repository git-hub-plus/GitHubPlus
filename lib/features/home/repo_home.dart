import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/models/status.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/terms.dart';
import '../../state/app_state.dart';
import '../../state/repo_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/hud.dart';
import '../expeditions/expedition_panel.dart';
import '../changes/changes_view.dart';
import '../history/history_view.dart';
import '../overview/overview_view.dart';
import '../stash/stash_panel.dart';
import 'repo_banner.dart';

enum HomeTab { overview, changes, history, expeditions }

/// Selected repository: banner, HUD, goal bars and the tabbed workspace.
class RepoHome extends ConsumerStatefulWidget {
  const RepoHome({super.key, required this.repo});
  final RepositoryInfo repo;

  @override
  ConsumerState<RepoHome> createState() => _RepoHomeState();
}

class _RepoHomeState extends ConsumerState<RepoHome> {
  // GHP_START_TAB (dart-define) opens another tab first, for screenshots without clicking.
  var _tab = HomeTab.values.asNameMap()[const String.fromEnvironment('GHP_START_TAB')] ?? HomeTab.overview;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(repoStatusProvider(widget.repo.id));
    final status = statusAsync.value;
    final c = context.colors;
    // Banner and HUD scroll away so the tab content (README, files) gets the
    // height; the tab bar sits on top of the body and stays visible.
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(
          child: Column(
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
                          ? Text('${statusAsync.error}', style: TextStyle(color: c.danger))
                          : const LinearProgressIndicator(minHeight: 2))
                    : _HudPanel(repo: widget.repo, status: status),
              ),
            ],
          ),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TabBar(tab: _tab, onChanged: (tab) => setState(() => _tab = tab), changes: status?.files.length ?? 0),
          Expanded(
            child: AnimatedSwitcher(
              duration: context.motion(Motion.fast),
              child: switch (_tab) {
                HomeTab.overview => OverviewView(key: ValueKey('overview-${widget.repo.id}'), repo: widget.repo),
                HomeTab.changes => ChangesView(key: ValueKey('changes-${widget.repo.id}'), repo: widget.repo),
                HomeTab.history => HistoryView(key: ValueKey('history-${widget.repo.id}'), repo: widget.repo),
                HomeTab.expeditions => ExpeditionPanel(key: const ValueKey('exp'), repoId: widget.repo.id),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// HUD stats plus the donation-goal style bars.
class _HudPanel extends ConsumerWidget {
  const _HudPanel({required this.repo, required this.status});
  final RepositoryInfo repo;
  String get repoId => repo.id;
  final RepoStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = Terms.of(context);
    final settings = ref.watch(settingsProvider);
    final today = ref.watch(todayCommitsProvider(repoId)).value ?? 0;
    // In plain mode every tooltip also names the Git term, so both audiences can read it.
    String tip(String text, String Function(Terms t) term) =>
        t.isPlain ? '$text\n${l.gitTermHint(Terms.gitHint(settings.language, term))}' : text;
    final toPush = status.toPush;
    final conflicts = status.conflictCount;

    final stats = [
      HudStat(
        icon: Icons.edit_note_rounded,
        label: l.hudChanges(t.changes),
        value: status.files.length,
        tone: status.files.isEmpty ? HudTone.neutral : HudTone.accent,
        tooltip: tip(l.hudChangesTip(t.commit), (t) => t.commit),
      ),
      HudStat(
        icon: Icons.upload_rounded,
        label: l.hudToPush(t.push),
        value: toPush,
        max: settings.pushGoal,
        tone: toPush == 0 ? HudTone.good : (toPush >= settings.pushGoal ? HudTone.danger : HudTone.attention),
        tooltip: tip(l.hudToPushTip(t.remote, t.push, t.commitUnit), (t) => t.push),
      ),
      HudStat(
        icon: Icons.download_rounded,
        label: l.hudToPull(t.pull),
        value: status.behind,
        tone: status.behind == 0 ? HudTone.good : HudTone.attention,
        tooltip: tip(l.hudToPullTip(t.remote, t.pull, t.commitUnit), (t) => t.pull),
      ),
      HudStat(
        icon: Icons.inventory_2_rounded,
        label: l.hudStashes(t.stash),
        value: status.stashCount,
        tone: HudTone.neutral,
        tooltip: tip(l.hudStashesTip(t.stash), (t) => t.stash),
        onTap: () => showStashPanel(context, ref, repo),
      ),
      HudStat(
        icon: Icons.bolt_rounded,
        label: l.hudConflicts(t.conflict),
        value: conflicts,
        tone: conflicts == 0 ? HudTone.good : HudTone.danger,
        tooltip: tip(l.hudConflictsTip, (t) => t.conflict),
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
                title: l.goalDailyCommits(t.commitUnit),
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
                title: l.goalPush(t.push),
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
                  child: Text(
                    '$badge',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          item(HomeTab.overview, l.tabOverview),
          item(HomeTab.changes, l.tabChanges(Terms.of(context).changes), badge: changes, badgeColor: c.accent),
          item(HomeTab.history, l.tabHistory(Terms.of(context).history)),
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
