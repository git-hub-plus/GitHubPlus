import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/git/git_runner.dart';
import '../../core/git/sync.dart';
import '../../core/models/app_models.dart';
import '../../core/models/status.dart';
import '../../l10n/app_localizations.dart';
import '../branches/branch_menu.dart';
import '../hub/client/publish_dialog.dart';
import '../../l10n/terms.dart';
import '../../state/repo_state.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/feedback.dart';
import '../library/library_panel.dart';

/// The big launcher banner: art, repository name, branch and the main button.
class RepoBanner extends ConsumerWidget {
  const RepoBanner({super.key, required this.repo, required this.status, required this.onCommitRequested});

  final RepositoryInfo repo;
  final RepoStatus? status;
  final VoidCallback onCommitRequested;

  static const height = 196.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = L10n.of(context);
    final t = Terms.of(context);
    final cover = coverColor(repo.id);
    final lastFetch = ref.watch(lastFetchProvider)[repo.id];
    final branch = status?.currentBranch ??
        (status?.headSha != null ? l.detachedHead(status!.headSha!.substring(0, 7)) : l.noBranch(t.branch));

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient banner art: the brand background, blurred and tinted with the
          // repository's cover color so every repository gets its own mood.
          ColoredBox(color: Color.lerp(c.background, cover, 0.18)!),
          Positioned(
            right: -40,
            top: -60,
            bottom: -60,
            width: 520,
            child: Opacity(
              opacity: 0.45,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Image.asset('assets/brand/logo_background.png', fit: BoxFit.cover),
              ),
            ),
          ),
          Positioned(
            right: Space.xxl + 8,
            top: Space.lg,
            child: Opacity(
              opacity: 0.16,
              child: Image.asset('assets/brand/emblem.png', width: 120, height: 120),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [c.background.withValues(alpha: 0.95), c.background.withValues(alpha: 0.55), Colors.transparent],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, c.background],
                stops: const [0.55, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _groupLabel(l, repo.group).toUpperCase(),
                        style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w700, color: cover),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        repo.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: c.text, height: 1.1),
                      ),
                      const SizedBox(height: Space.sm),
                      Wrap(
                        spacing: Space.sm,
                        runSpacing: Space.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Chip(
                            icon: Icons.account_tree_rounded,
                            label: branch,
                            emphasized: true,
                            onTap: () => showBranchMenu(context, ref, repo),
                          ),
                          if (status?.upstream != null) _Chip(icon: Icons.cloud_rounded, label: status!.upstream!),
                          _Chip(
                            icon: Icons.schedule_rounded,
                            label: lastFetch == null ? l.neverFetched(t.fetch) : l.lastFetched(t.fetch, formatAgo(context, lastFetch)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.xl),
                if (status != null)
                  _PrimaryButton(repo: repo, status: status!, onCommitRequested: onCommitRequested),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _groupLabel(L10n l, RepositoryGroup group) => switch (group) {
    RepositoryGroup.local => l.groupLocal,
    RepositoryGroup.hub => l.groupHub,
    RepositoryGroup.github => l.groupGithub,
  };
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.emphasized = false, this.onTap});
  final IconData icon;
  final String label;
  final bool emphasized;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm + 2, vertical: 5),
      decoration: BoxDecoration(
        color: (emphasized ? c.accentSoft : c.surface).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: emphasized ? c.accent.withValues(alpha: 0.6) : c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: emphasized ? c.accent : c.muted),
          const SizedBox(width: Space.xs + 2),
          Text(label, style: TextStyle(fontSize: 12, color: c.text, fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400)),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 14, color: c.muted),
          ],
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: chip);
  }
}

/// Context-aware main button, like a launcher's PLAY button.
class _PrimaryButton extends ConsumerStatefulWidget {
  const _PrimaryButton({required this.repo, required this.status, required this.onCommitRequested});
  final RepositoryInfo repo;
  final RepoStatus status;
  final VoidCallback onCommitRequested;

  @override
  ConsumerState<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends ConsumerState<_PrimaryButton> {
  var _busy = false;

  Future<void> _run(PrimaryAction action) async {
    final l = L10n.of(context);
    final t = Terms.of(context);
    if (action == PrimaryAction.commit || action == PrimaryAction.resolve) {
      widget.onCommitRequested();
      return;
    }
    // No remote at all: publishing means choosing a hub first.
    if (action == PrimaryAction.publish && widget.repo.remoteUrl == null) {
      await showPublishToHubDialog(context, ref, widget.repo);
      return;
    }
    setState(() => _busy = true);
    final remote = widget.status.upstream?.split('/').first ?? 'origin';
    final title = switch (action) {
      PrimaryAction.pull => l.jobPull(remote, t.pull),
      PrimaryAction.push => l.jobPush(remote, t.push),
      PrimaryAction.publish => l.jobPublish(widget.status.currentBranch ?? '', t.publish),
      _ => l.jobFetch(remote, t.fetch),
    };
    String describe(SyncOutcome o) => switch (action) {
      PrimaryAction.push || PrimaryAction.publish => l.resultSent(t.commitUnit, o.sent, t.push),
      _ => o.received == 0 ? l.resultUpToDate : l.resultReceived(t.commitUnit, o.received),
    };
    try {
      final ok = await ref.read(syncControllerProvider).run(widget.repo, action, describe: describe, title: title);
      if (!ok && mounted) showGhpToast(context, l.expeditionFailed, tone: ToastTone.error);
    } on GitException catch (e) {
      if (mounted) showGhpToast(context, l.expeditionFailed, tone: ToastTone.error, detail: redactCredentials(e.result.stderr));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = L10n.of(context);
    final t = Terms.of(context);
    final status = widget.status;
    final action = primaryActionFor(status);
    final (label, icon, color) = switch (action) {
      PrimaryAction.resolve => (l.actionResolve(t.conflict), Icons.healing_rounded, c.danger),
      PrimaryAction.commit => (l.actionCommit(t.commit), Icons.check_circle_rounded, c.success),
      PrimaryAction.publish => (l.actionPublish(t.publish), Icons.rocket_launch_rounded, c.accent),
      PrimaryAction.pull => (l.actionPull(t.pull, status.behind), Icons.download_rounded, c.warning),
      PrimaryAction.push => (l.actionPush(t.push, status.ahead), Icons.upload_rounded, c.accent),
      PrimaryAction.fetch => (l.actionFetch(t.fetch), Icons.sync_rounded, c.accent),
    };
    return AnimatedSwitcher(
      duration: context.motion(Motion.normal),
      child: SizedBox(
        key: ValueKey(action),
        height: 52,
        child: FilledButton.icon(
          onPressed: _busy ? null : () => _run(action),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
            elevation: 4,
            shadowColor: color.withValues(alpha: 0.5),
          ),
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(icon, size: 22),
          label: Text(label),
        ),
      ),
    );
  }
}
